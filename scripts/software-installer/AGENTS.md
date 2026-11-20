# AGENTS.md — Модульный оркестратор установки ПО (Linux / Debian-based)

## 1. Назначение

Целевая платформа — Ubuntu LTS 24.04 (amd64). Имена пакетов в модулях
указываются в варианте для 24.04; совместимость с другими версиями
дистрибутивов не гарантируется.

Оркестратор устанавливает только запрошенные модули и их runtime-зависимости.
Build-зависимости ставятся на время сборки, помечаются `auto` и удаляются после
успешного завершения. Пользователь может отключить очистку флагом
`--keep-build-deps`.

Все `apt`-операции выполняются с `--no-install-recommends`. Пользователь ведёт
явный учёт зависимостей вручную, поэтому оркестратор доверяет контракту модулей
и не «додумывает» за них.

---

## 2. Контракт модуля

Модуль — это файл `<module>.sh`, экспортирующий функции с префиксом
`<module>__`:

```
<module>__get_build_dependencies   → строка (whitespace-separated список)
<module>__get_runtime_dependencies → строка (whitespace-separated список)
<module>__install                  → установка основного пакета
<module>__configure                → пост-установочная настройка
<module>__remove                   → полный откат install + configure
```

`__remove` обязательна для любого модуля, который может попасть в граф как
build-only. Валидатор проверяет это в момент вычисления ролей: если build-only
модуль не умеет удаляться, он повышается до runtime и остаётся в системе.

Если используется новый контракт, обе функции
`__get_build_dependencies` и `__get_runtime_dependencies` обязательны; для
пустого списка достаточно `return 0`.

Опционально: старый `<module>__get_dependencies` принимается как
deprecated-alias. Его результат считается одновременно build и runtime, поэтому
такие зависимости никогда не удаляются автоматически.

### 2.1. Семантика списков

- Элемент — имя `apt`-пакета (`libfontconfig1-dev`) или имя другого модуля
  (`rust`).
- Если элемент совпадает с именем существующего модуля, это модульная
  зависимость: модуль устанавливается раньше, его собственные зависимости
  вливаются в общие множества.
- `get_build_dependencies` — нужно только для сборки.
- `get_runtime_dependencies` — нужно после установки, никогда не удаляется
  автоматически.
- Пересечение допустимо: пакет может быть в build одного модуля и runtime
  другого. Runtime побеждает.
- `__install` ставит только основной пакет. Зависимости ставит оркестратор.
- `__configure` не ставит пакеты. Всё нужное объявляется в зависимостях.
- `__remove` удаляет бинарники, каталоги, кэш, конфиги и сгенерированные файлы,
  созданные `__install`/`__configure`. Он не должен удалять то, что существовало
  до установки. Для этого используется ownership-маркер (см. §2.2).

### 2.2. Ownership-маркер

Перед вызовом фазы оркестратор выставляет `MODULE_STATE_DIR`. Модуль, который
мог существовать до установки, проверяет это сам и вызывает
`lib__state_mark_owned` только если действительно создал объект. `__remove`
проверяет `lib__state_is_owned` и иначе ничего не делает.

Пример: `rust__install` смотрит, были ли `~/.cargo`/`~/.rustup` до установки.
`rust__remove` удаляет их только при наличии маркера.

### 2.3. Роли модулей

- `requested` — модуль запрошен пользователем.
- `runtime` — нужен после установки.
- `build` — нужен только для сборки.

Роли распространяются по графу:

- build-ребро из requested/runtime-модуля → build;
- runtime-ребро из requested/runtime-модуля → runtime;
- всё, что достижимо из build-модуля, тоже build;
- если модуль достижим и как build, и как runtime — побеждает runtime;
- запрошенный модуль всегда requested.

Если build-модуль не реализует `__remove`, он повышается до runtime.

### 2.4. Основные пакеты

«Один `apt install`» относится к batch-у зависимостей. Основные пакеты
по-прежнему ставит `__install` модуля через `lib__apt_install`. Модули, которые
добавляют репозиторий, вызывают `lib__apt_update --force`.

---

## 3. Полный цикл оркестратора

### Шаг 1. Discovery и роли

1. Собрать запрошенные модули.
2. Для каждого вызвать `__get_build_dependencies` и
   `__get_runtime_dependencies`.
3. Разделить элементы на apt-пакеты и модули.
4. Построить граф, проверить циклы.
5. Топологически отсортировать модули.
6. Вычислить роли и итоговые множества:
   - `build_all` — build-пакеты всех модулей; runtime-пакеты build-модулей;
   - `runtime_all` — runtime-пакеты requested/runtime-модулей.

Для запуска дополнительно фильтруются:

- `build_for_run` — build-пакеты модулей, у которых фаза `install` реально
  будет выполняться, плюс runtime-пакеты активных build-only модулей;
- `runtime_for_run` — runtime-пакеты всех requested/runtime-модулей (проверяются
  и чинятся даже для уже установленных модулей);
- `build_only_modules` — активные build-only модули, которые нужно удалить.
  Build-only модуль активен, только если от него зависит модуль, который
  действительно устанавливается в этом запуске; иначе он не трогается.

Недоступные в текущем дистрибутиве имена (например, `libssl3` vs `libssl3t64`)
отбрасываются до установки.

### Шаг 2. Снапшот состояния

```
apt-mark showmanual  → manual_before
dpkg --get-selections → installed_before
```

`manual_before` — единственная защита пользовательских пакетов. Пакеты из него
не помечаются `auto`.

### Шаг 3. Один batch apt install

```
apt update
apt install --no-install-recommends -y $(build_for_run ∪ runtime_for_run)
```

Всё ставится одной командой: runtime-зависимости сразу становятся manual,
транзитивные hard-зависимости приходят как auto.

Если runtime-зависимость уже была установлена как auto (например, как
зависимость `-dev`-пакета), оркестратор дополнительно вызывает
`apt-mark manual` для `runtime_for_run`. Иначе `autoremove` мог бы удалить
библиотеку, которая нужна установленной программе.

### Шаг 4. Пометка build-зависимостей

```
build_only = build_for_run − runtime_for_run − manual_before
```

К `build_only` добавляются пакеты из `cleanup.pending` предыдущих запусков.
Они считаются установленными установщиком и могут быть помечены `auto` даже
если сейчас находятся в `manual_before`: это нужно для восстановления после
падения между `apt install` и `apt-mark auto`.

Для каждого установленного пакета из `build_only`:

```
apt-mark auto <package>
```

Build-депы, установленные пользователем вручную, не трогаются.

### Шаг 5. Сборка, установка, конфигурация

Для каждого модуля в топологическом порядке:

1. `__install`
2. `__configure`

Метки apt на этом шаге не меняются. При падении модуля зависимые от него модули
получают `skipped`. С `--keep-going` независимые модули продолжают выполняться.

### Шаг 6. Очистка

Запускается только если все модули успешны, либо при `--force-clean`.

1. Для build-only модулей вызывается `__remove` в обратном топологическом
   порядке. После успешного удаления состояние модуля сбрасывается.
2. `apt autoremove --purge -y` — один проход на весь батч.

`--keep-build-deps` отменяет весь шаг:

- build-депы не помечаются `auto`;
- `__remove` не вызывается;
- `autoremove` не запускается.

### Шаг 7. Отложенная очистка

Перед сборкой создаётся `${XDG_STATE_HOME:-$HOME/.local/state}/software-installer/cleanup.pending`
со списком build-пакетов и build-only модулей. Он нужен, чтобы прерванная
очистка не потерялась: модули уже `done`, и следующий запуск иначе решит, что
делать нечего.

- При ошибке очистки файл сохраняется.
- Следующий успешный запуск объединяет pending с текущим батчем.
- После успешной очистки файл удаляется.
- `--keep-build-deps` pending не трогает.

### Шаг 8. Манифест

Пишется в:

```
$XDG_STATE_HOME/software-installer/manifests/<timestamp>/manifest.json
```

Поля: `timestamp`, `status`, `modules_requested`, `modules_succeeded`,
`modules_failed`, `modules_skipped`, `modules_removed`, `modules_kept`,
`build_all`, `runtime_all`, `build_only`, `manual_before`, `installed_by_us`,
`auto_marked`, `autoremove_preview`, `autoremove_removed`, `autoremove_ran`,
`keep_build_deps`, `force_clean`, `pending_cleanup_processed`.

Манифест пишется через `trap EXIT`, включая падение и прерывание. Рядом
сохраняются снапшоты `installed_before.txt`, `installed_after.txt`,
`installed_before_cleanup.txt`, `installed_after_cleanup.txt`.

---

## 4. Правила

1. `manual_before` неприкосновенен.
2. Runtime-зависимости всегда manual: они ставятся явным `apt install`.
3. `build_only = build_for_run − runtime_for_run − manual_before`.
4. Один `apt update` и один `apt install` для зависимостей, один `autoremove`.
5. При падении очистка не запускается без `--force-clean`.
6. `--no-install-recommends` всегда.
7. `__remove` вызывается только для build-only модулей и только после успеха
   или при `--force-clean`.
8. `--keep-build-deps` и `--force-clean` взаимоисключающие.

---

## 5. Отказоустойчивость

- **Падение до batch install.** Ничего не изменено, манифест записан.
- **Падение между install и mark-auto.** Build-депы остались manual. Они
  записаны в `cleanup.pending` до сборки, поэтому следующий успешный запуск
  пометит их auto и удалит.
- **Падение после mark-auto.** Runtime manual, build auto. Cleanup не
  запускается; pending сохраняется.
- **Падение `__remove`.** Модуль остаётся, pending сохраняется, cleanup
  считается незавершённым.
- **Пакет в build и runtime.** Runtime побеждает.
- **Пакет в build одного модуля и runtime другого.** Runtime побеждает на
  уровне множеств.
- **Модуль без `__remove`.** Повышается до runtime и не удаляется.
- **Модуль помечен `-m`.** Считается пользовательским, `__remove` не вызывается.
- **`apt` залочен.** Abort с явным сообщением.
- **Пользователь хочет оставить build-депы.** `--keep-build-deps`.

---

## 6. Библиотечные хелперы

```
lib__as_root <command...>

lib__file_write <path> [mode]
lib__cp_config <file> [exact path]

lib__install_binary <file> <name>
lib__mv_to_local_bin <name>

lib__wget_download <url>
lib__wget_download_github_release <repo> <file regex>

lib__apt_install <packages...|.deb files>
lib__apt_install_batch <packages...>
lib__apt_remove <packages...>
lib__apt_mark_manual <packages...>
lib__apt_mark_auto <packages...>
lib__apt_autoremove
lib__apt_autoremove_preview
lib__apt_update [--force]

lib__require_command <command> [package]
lib__state_mark_owned
lib__state_is_owned
lib__state_mark_kept

lib__log_info|warn|error|success <text>
```

`lib__wget_download`, `lib__mv_to_local_bin` и `lib__install_binary` не ставят
пакеты сами. Модуль обязан объявить `wget`, `ca-certificates` (для HTTPS),
`unzip`, `xz-utils`, `bzip2` и другие инструменты в
`__get_build_dependencies`.
