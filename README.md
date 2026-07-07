# Базовая настройка окружения сервера под управлением операционной системы Linux
Описание этапов базовой настройки сервера под управлением операционной системы Linux.
Под базовой настройкой понимается создание общего окружения, обеспечивающего возможность развертывания специализированных сервисов,
например создание пользователя от имени которого будет производиться развертывание, настройка безопасной среды подключения данного пользователя,
установка общих пакетов, настройка общих для всех пользователей параметров и правил межсетевого экрана.

## Этапы настройки

1. Роль `bootstrap` - инициализация окружения для станции управления:
- Создание пользователя для станции управления Ansible (например `deploy`) и установка соответствующих прав;
- Настройка параметров сервера `SSH`
- Установка/генерация `hostname`
- Смена пароля пользователя `root`
- Настройка параметров `NTP` клиента
- Настройка параметров локализации

> [!NOTE]
> [Подробное описание](roles/bootstrap/README.md)

> [!NOTE]
> Роли ниже запланированы, но пока не реализованы (в `roles/` присутствует только `bootstrap`).

2. Роль `common` (планируется) - конфигурирование общих параметров:
- Установка базовых пакетов;
- Настройка файлов конфигурации, общих для всех пользователей;
3. Роль `firewall` (планируется) - конфигурирование межсетевого экрана.

## Требования

- `Python 3` с модулем `venv`;
- Внешние коллекции Ansible (ставятся в `.venv` через `make deps`):
  - [`ansible.posix`](https://galaxy.ansible.com/ui/repo/published/ansible/posix/) - модуль `authorized_key`;
  - [`community.general`](https://galaxy.ansible.com/ui/repo/published/community/general/) - модуль `timezone`.

Все инструменты работают в изолированном виртуальном окружении `.venv` —
Makefile создаёт и использует его автоматически, отдельная активация не нужна.

Python-зависимости разделены:
- [`requirements.txt`](requirements.txt) — **runtime** control-node (`ansible`, `passlib`);
- [`requirements-dev.txt`](requirements-dev.txt) — **dev/CI** (линтеры, pre-commit; включает runtime);
- [`requirements.yml`](requirements.yml) — коллекции Ansible Galaxy.

```shell
# Разработка:
make dev-deps    # .venv + runtime + линтеры, pre-commit, gitleaks
make deps        # коллекции Ansible

# Продуктив (только runtime, без линтеров):
make install     # .venv + ansible, passlib
make deps        # коллекции Ansible
```

## Подготовка

1. Добавить IP-адреса или FQDN-имена узлов в файл инвентаризации, например ```inventory/inventory.yml```. Пример: [inventory/inventory.sample.yml](inventory/inventory.sample.yml)


2. Добавить публичную часть SSH-ключа management станции Ansible в директорию [files](files/) для настройки авторизации по SSH-ключу

```shell
cp ~/.ssh/id_rsa.pub files/agent_rsa.pub
```

3. Добавить значения переменных для каждого хоста (Пример: [host_vars/0.0.0.1/](host_vars/0.0.0.1)) и групп хостов (Пример: [group_vars/sample/](group_vars/sample/)).

> [!NOTE]
> [Перечень используемых переменных](roles/bootstrap/README.md#Используемые%20переменные)

## Запуск

> [!NOTE]
> Возможно осуществлять запуск `playbook` двумя способами: make и прямой запуск playbook

1. С помощью ```Makefile```:

```shell
make setup
```

Также возможно передать путь к специфичному файлу инвентаризации посредством переменной окружения

```shell
make setup INVENTORY=inventory/my_inventory_file.yml
```

2. Явный запуск Ansible playbook

```shell
ansible-playbook -i inventory/inventory.yml base_server_setup.yml
```

## Makefile

Доступные цели (`make help` выводит список):

| Цель | Назначение |
| :--- | :--- |
| `make install` | Создание `.venv` и runtime pip-зависимостей (`requirements.txt`: ansible, passlib) |
| `make deps` | Установка коллекций Ansible из `requirements.yml` (в `.venv`) |
| `make dev-deps` | `.venv` + dev/CI-инструменты (и runtime) и бинарь `gitleaks` |
| `make setup` | Запуск плейбука `base_server_setup.yml` (переопределяется `INVENTORY=...`) |
| `make check` | Прогон плейбука в режиме `--check` (dry-run) |
| `make syntax-check` | Проверка синтаксиса плейбука (`--syntax-check`) |
| `make lint` | Линтинг: `ansible-lint --strict` и `yamllint` |
| `make gitleaks` | Сканирование истории git на утечку секретов |
| `make pre-commit` | Прогон всех pre-commit-хуков по всем файлам |
| `make validate` | Комплексная проверка: `gitleaks` + `check` + `syntax-check` + `lint` |
| `make help` | Список доступных целей |

## Проверка секретов (gitleaks) и pre-commit

Секреты не должны попадать в репозиторий — за этим следит [`gitleaks`](https://github.com/gitleaks/gitleaks)
(в `pre-commit`, в `make` и в CI). Разовая настройка окружения разработчика:

```shell
make dev-deps        # .venv + линтеры, pre-commit и бинарный файл gitleaks
pre-commit install   # включит хуки на git commit
```

`make dev-deps` создаёт `.venv`, ставит в него Python-инструменты и кладёт бинарный файл
`gitleaks` в `~/.local/bin` (если его ещё нет), поэтому `make gitleaks` и
`make validate` работают из коробки. Версия gitleaks задаётся переменной
`GITLEAKS_VERSION` в `Makefile`. В `pre-commit` и CI `gitleaks` подтягивается
независимо.

Ручной прогон:

```shell
make gitleaks        # скан истории на секреты
make pre-commit      # все хуки по всем файлам
```
