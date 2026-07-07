INVENTORY ?= inventory/inventory.yml

default: help
validate: check syntax-check lint

.PHONY: help
help: # Show help for each of the Makefile recipes.
	@grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

.PHONY: setup
setup: # Playbook for create user to deploy
	ansible-playbook -i $(INVENTORY) base_server_setup.yml

.SILENT:
.PHONY: lint
lint: # Lint playbooks with ansible-lint
	ansible-lint base_server_setup.yml --strict -v
	yamllint .

.SILENT:
.PHONY: check
check: # run ansible playbook with --check mode
	ansible-playbook --check base_server_setup.yml
	ansible-playbook --check base_server_setup.yml

.SILENT:
.PHONY: syntax-check
syntax-check: # run ansible playbook with --syntax-check mode
	ansible-playbook --syntax-check base_server_setup.yml
	ansible-playbook --syntax-check base_server_setup.yml
