INVENTORY ?= inventory/inventory.yml
GITLEAKS_VERSION ?= 8.30.1
VENV ?= .venv

# Все Python-инструменты запускаются из виртуального окружения — активация не нужна.
# Два stamp: runtime (requirements.txt) и dev/CI (requirements-dev.txt).
DEPS_STAMP := $(VENV)/.deps-installed
DEV_STAMP := $(VENV)/.dev-deps-installed
PIP := $(VENV)/bin/pip
ANSIBLE_GALAXY := $(VENV)/bin/ansible-galaxy
ANSIBLE_PLAYBOOK := $(VENV)/bin/ansible-playbook
ANSIBLE_LINT := $(VENV)/bin/ansible-lint
YAMLLINT := $(VENV)/bin/yamllint
PRE_COMMIT := $(VENV)/bin/pre-commit

.DEFAULT_GOAL := help

.PHONY: help install deps dev-deps setup lint gitleaks pre-commit check syntax-check validate

.SILENT: lint check syntax-check

validate: gitleaks check syntax-check lint

help: # Show help for each of the Makefile recipes.
	@grep -E '^[a-zA-Z0-9 -]+:.*#' Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

# Runtime: .venv + зависимости для прогона плейбука (ansible, passlib).
$(DEPS_STAMP): requirements.txt
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	touch $(DEPS_STAMP)

# Dev/CI: линтеры, pre-commit, gitleaks. requirements-dev.txt включает runtime через -r.
$(DEV_STAMP): requirements-dev.txt requirements.txt
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements-dev.txt
	command -v gitleaks >/dev/null 2>&1 || { \
		echo "Installing gitleaks $(GITLEAKS_VERSION) into $(HOME)/.local/bin"; \
		mkdir -p $(HOME)/.local/bin; \
		curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v$(GITLEAKS_VERSION)/gitleaks_$(GITLEAKS_VERSION)_$$(uname -s | tr '[:upper:]' '[:lower:]')_$$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/').tar.gz" \
			| tar -xz -C $(HOME)/.local/bin gitleaks; \
	}
	touch $(DEPS_STAMP) $(DEV_STAMP)

install: $(DEPS_STAMP) # Create .venv and install runtime Python deps (ansible, passlib)

dev-deps: $(DEV_STAMP) # Create .venv and install dev/CI tools and gitleaks binary

deps: $(DEPS_STAMP) # Install required Ansible collections from requirements.yml
	$(ANSIBLE_GALAXY) collection install -r requirements.yml

setup: $(DEPS_STAMP) # Run base server setup playbook
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) base_server_setup.yml

lint: $(DEV_STAMP) # Lint playbooks with ansible-lint and yamllint
	$(ANSIBLE_LINT) base_server_setup.yml --strict -v
	$(YAMLLINT) .

gitleaks: # Scan git repository history for leaked secrets
	gitleaks git . --verbose

pre-commit: $(DEV_STAMP) # Run all pre-commit hooks against all files
	$(PRE_COMMIT) run --all-files

check: $(DEPS_STAMP) # Run ansible playbook in --check mode
	$(ANSIBLE_PLAYBOOK) --check base_server_setup.yml

syntax-check: $(DEPS_STAMP) # Run ansible playbook in --syntax-check mode
	$(ANSIBLE_PLAYBOOK) --syntax-check base_server_setup.yml
