# AGENTS.md

Руководство для AI-агентов (и людей) по работе с этим репозиторием Ansible.
Ожидаемый уровень исполнения — **senior DevOps engineer**: изменения безопасны,
идемпотентны, документированы и проверены автоматикой до коммита.

---

## 0. Окружение (Python venv — обязательно)

Все Python-инструменты (`ansible*`, `ansible-lint`, `yamllint`, `pre-commit`)
работают **только** из виртуального окружения `.venv`. Установка в системный
Python запрещена (сломает системные пакеты, PEP 668 / `externally-managed`).

**Makefile venv-aware — активация не нужна.** Цели сами создают `.venv` при
первом запуске и вызывают инструменты по пути `.venv/bin/...`. Достаточно:

```shell
make dev-deps        # .venv + runtime (ansible, passlib) + линтеры, pre-commit, gitleaks
make deps            # коллекции Ansible (в то же .venv)
pre-commit install   # хуки на git commit
```

В **продуктивной** среде управляющего узла ставятся только runtime-зависимости
(без линтеров): `make install && make deps`.

Любая цель (`make lint`, `make validate`, …) при необходимости досоздаёт
окружение автоматически — отдельный `source .venv/bin/activate` не требуется.

Активация нужна только для **ad-hoc** команд в обход Makefile (что само по себе
нежелательно — см. правило 4):

```shell
source .venv/bin/activate        # Windows: .venv\Scripts\activate
```

Каталог `.venv/` — в `.gitignore` (в репозиторий не попадает). Окружение
пересобирается при изменении `requirements-dev.txt` (stamp-файл в `.venv`).

---

## 1. Золотые правила (обязательны к соблюдению)

1. **Только внутри Python venv.** Python-инструменты — исключительно из `.venv`.
   Никаких установок в системный Python (PEP 668). Makefile обеспечивает это
   автоматически (venv-aware); ручная активация нужна лишь для ad-hoc команд.
   См. раздел «0. Окружение».
2. **Отдельная ветка на сессию.** Никогда не работать напрямую в `main`.
   В начале сессии создать ветку: `git switch -c <тип>/<краткое-описание>`
   (`feat/…`, `fix/…`, `refactor/…`, `docs/…`, `ci/…`).
3. **Каждая правка — с подтверждением и линтером.** Перед применением
   изменения согласовать с пользователем, после — прогнать `make lint`
   (и `make validate` для изменений в плейбуках/ролях). Не коммитить с
   ошибками линтера.
4. **Только через Makefile.** Все стандартные операции (установка зависимостей,
   запуск, проверки, сканирование секретов) выполнять целями Makefile, а не
   «сырыми» командами. Нет цели под задачу — сначала добавить цель.
5. **Секреты только в vault.** Любые чувствительные данные (пароли, хэши,
   токены, ключи) — исключительно в зашифрованных `ansible-vault` файлах.
   Открытый секрет в репозитории недопустим.
6. **Секреты проверяются gitleaks.** Перед коммитом обязателен `make gitleaks`.
   gitleaks встроен в pre-commit, Makefile и CI — обойти нельзя.
7. **Документация — часть Definition of Done.** Новая переменная или
   зависимость без описания в README считается незавершённой работой.

---

## 2. Структура проекта

```
.
├── ansible.cfg                 # inventory, roles_path, interpreter_python, vault_password_file
├── base_server_setup.yml       # корневой плейбук (подключает роли)
├── inventory/                  # инвентарь (реальный — в .gitignore, в репо только *.sample)
├── group_vars/                 # переменные групп: <group>/vars + <group>/vault
├── host_vars/                  # переменные хостов: <host>/vars + <host>/vault
├── files/                      # публичные артефакты (напр. agent_rsa.pub)
├── requirements.txt            # runtime: pip-зависимости control-node (ansible, passlib)
├── requirements.yml            # runtime: коллекции Ansible Galaxy
├── requirements-dev.txt        # dev/CI: линтеры/pre-commit (+ -r requirements.txt)
├── Makefile                    # единая точка входа для всех операций
├── .pre-commit-config.yaml     # хуки (gitleaks, линтеры, гигиена файлов)
├── .github/workflows/          # CI
└── roles/<role>/
    ├── defaults/main.yml       # значения по умолчанию (префикс <role>_)
    ├── tasks/
    │   ├── main.yml            # оркестровка: include_tasks includes/NN-*.yml
    │   └── includes/NN-*.yml   # атомарные шаги, нумерованные (00, 10, 20…)
    ├── handlers/
    │   ├── main.yml            # оркестровка: import_tasks includes/NN-*.yml
    │   └── includes/NN-*.yml
    ├── templates/              # Jinja2 (*.j2), путь зеркалит целевую ФС
    └── README.md               # назначение роли + таблица переменных
```

**Проверять при каждом изменении структуры:**
- новый шаг задачи — отдельный файл `includes/NN-<glagol>_<obj>.yml` с шагом
  нумерации 10, встроенный в `tasks/main.yml` через `include_tasks`;
- имена файлов, задач и переменных согласованы со стилем соседей;
- реальные `inventory`, `*/vault`, `.vaultpass`, `files/*` остаются в `.gitignore`.

---

## 3. Вложенные задачи (include / import)

- **`tasks/main.yml`** только оркеструет: последовательность
  `ansible.builtin.include_tasks: includes/NN-*.yml` с осмысленными `name`.
- **`handlers/main.yml`** подключает хендлеры через
  `ansible.builtin.import_tasks` (статически), имена хендлеров = `name`
  вложенных задач; `notify` в задачах должен ссылаться именно на них.
- Файлы `includes/*` нумеровать (`00-`, `10-`, `20-`…) — порядок и шаг видны сразу.
- Один файл `includes/*` — один логически завершённый шаг.
- Условия и `block` располагать внутри include-файла, а не в оркестраторе.
- Проверять, что каждый `notify:` имеет соответствующий хендлер, а каждый
  `include_tasks`/`import_tasks` указывает на существующий файл.

---

## 4. Переменные и их документирование

- Все переменные роли — с префиксом имени роли (напр. `bootstrap_*`).
- Значения по умолчанию — в `defaults/main.yml`; обязательные переменные без
  дефолта — валидировать в `tasks/includes/00-validate_vars.yml`
  (`ansible.builtin.assert` с понятными `fail_msg`).
- Модули — строго **FQCN** (`ansible.builtin.*`, `ansible.posix.*`,
  `community.general.*`).
- **Идемпотентность.** Никаких операций, дающих `changed` на каждом прогоне.
  Хэши паролей — с детерминированной солью (seed от `inventory_hostname`),
  а не случайной.
- **Документация переменных обязательна.** Каждая переменная описывается в
  `roles/<role>/README.md` в таблице: `Название | Описание | Обязательная |
  Значение по умолчанию | Vault | Комментарий`. Значения в таблице должны
  совпадать с `defaults/main.yml` и `00-validate_vars.yml`.

---

## 5. Секреты и Vault (обязательно)

- Чувствительные значения хранятся **только** в `group_vars/*/vault` и
  `host_vars/*/vault`, зашифрованных `ansible-vault`.
- Файлы `vars` содержат несекретные переменные и ссылки на `vault_*` из vault.
- Пароль vault — в `.vaultpass` (в `.gitignore`), путь прописан в `ansible.cfg`
  (`vault_password_file`).
- Никогда не коммитить: `.vaultpass`, расшифрованные vault, реальный inventory,
  приватные ключи.
- Перед коммитом — обязательный `make gitleaks` (детект секретов). CI повторяет
  ту же проверку — красный gitleaks блокирует merge.
- Зашифровать файл: `ansible-vault encrypt group_vars/<group>/vault`.

---

## 6. Документация (Definition of Done)

Изменение считается завершённым, только если в документации отражены:
- **Зависимости** — runtime pip в `requirements.txt` (control-node: ansible,
  passlib и т.п.), коллекции в `requirements.yml`, dev-инструменты в
  `requirements-dev.txt`; секции «Требования»/«Makefile» в `README.md` актуальны.
  Runtime-зависимости прогона плейбука не помещать в `requirements-dev.txt`.
- **Переменные** — таблица в `roles/<role>/README.md` дополнена/исправлена.
- Ссылки, якоря и примеры команд в README рабочие и соответствуют реальности.

---

## 7. Линтинг, проверки и CI

Все проверки — через Makefile (см. таблицу ниже). Обязательный минимум перед
коммитом: `make gitleaks && make lint` (для правок ролей/плейбуков — `make validate`).

CI (`.github/workflows/validate.yml`) прогоняет те же цели: сканирование
секретов (`gitleaks`), синтаксис, `--check` и линтинг. Локальный и CI-набор
проверок должны совпадать.

### Цели Makefile

| Цель | Назначение |
| :--- | :--- |
| `make help` | Список доступных целей |
| `make install` | `.venv` + runtime pip-зависимости (`requirements.txt`: ansible, passlib) |
| `make deps` | Установка коллекций Ansible из `requirements.yml` |
| `make dev-deps` | dev/CI-инструменты (+ runtime) и бинарь `gitleaks` |
| `make setup` | Запуск плейбука (`INVENTORY=...` переопределяет инвентарь) |
| `make lint` | `ansible-lint --strict` + `yamllint` |
| `make check` | Прогон плейбука в режиме `--check` (dry-run) |
| `make syntax-check` | Проверка синтаксиса плейбука |
| `make gitleaks` | Сканирование репозитория на утечку секретов |
| `make pre-commit` | Прогон всех pre-commit-хуков по всем файлам |
| `make validate` | Комплекс: `gitleaks` + `check` + `syntax-check` + `lint` |

---

## 8. Чек-лист перед коммитом

- [ ] Проверки прогнаны через `make` (использует `.venv` автоматически).
- [ ] Работа ведётся в отдельной ветке (не `main`).
- [ ] Изменения согласованы с пользователем.
- [ ] `make gitleaks` — чисто (нет секретов).
- [ ] `make lint` (и `make validate` при правках ролей/плейбуков) — без ошибок.
- [ ] Новые переменные/зависимости описаны в README и `requirements*`.
- [ ] Секреты — только в зашифрованном vault; `.vaultpass`/vault не в коммите.
- [ ] Структура и нумерация `includes/*`, `notify`→хендлеры — согласованы.

> Основа этого документа — требования пользователя и конвенции, устоявшиеся в
> репозитории (роль `bootstrap`). При добавлении новых ролей поддерживать те же
> правила и обновлять этот файл.
