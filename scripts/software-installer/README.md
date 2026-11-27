software-installer
==================

A small installer for user software and configs on Debian/Ubuntu.
The target platform is Ubuntu LTS 24.04 (amd64); package names use the 24.04
variants, other distributions are not covered.

It installs only the requested modules and their runtime dependencies, removes
temporary build dependencies after a successful run, and can keep them for
later builds with `--keep-build-deps`. Programs installed by the installer can
later be removed independently from their configuration.

## Quick start

```bash
./installer.sh -h
./installer.sh list
./installer.sh -d install all                  # show the plan, change nothing
./installer.sh -d -v install all               # detailed plan
./installer.sh install zsh                     # install one module
./installer.sh install binwalk alacritty       # install several modules
./installer.sh install cli                     # all modules in a category
./installer.sh install user-software           # all modules in a group
./installer.sh install all                     # all modules
./installer.sh configure zsh                   # run only __configure
./installer.sh reinstall zsh                   # force install + configure
./installer.sh remove zsh                      # remove the program, keep config
./installer.sh deconfigure zsh                 # remove config, keep the program
./installer.sh remove --deconfigure zsh        # remove both
./installer.sh --keep-build-deps install dwm   # keep build deps for later
./installer.sh install $(cat lists/xorg-dwm-base.list | xargs)  # use lists
```

`list` prints modules grouped by folder with an install status marker:
`✓` (green) means the program is installed (recorded or detected), `○` (dim)
means it is not installed. You can pass any name from the list to the installer.

The first folder under `modules/software` is a group (`user-software`,
`system-setup`). A folder inside a group is a category (`cli`, `desktop`,
`infosec`, ...). A target is what you ask the installer to work on: a group
name, a category name, or one module.

Main options:

```text
-h, --help            show help
-d, --dry-run         show the plan and exit
-y, --yes             do not ask for confirmation
-v, --verbose         detailed plan: phase matrix, package versions, descriptions
    --color WHEN      color mode: auto, always or never (default: auto)
    --keep-going      continue after errors
```

Install/reinstall options:

```text
--keep-build-deps     keep build dependencies and build-only modules
--force-clean         run autoremove even after a module failure
```

Install option:

```text
--no-configure        install the program only; do not run __configure
```

Remove option:

```text
--deconfigure         also run __deconfigure after a successful __remove
```

Installation always runs for the user who started the script. Root is needed
only for system changes. sudo asks for a password only when it is really
needed. Modules that only write to the home directory (for example
`wallpapers`) do not ask for a password; packages, `/opt` and `/usr/local/bin`
do.

```bash
sudo ./installer.sh install zsh
```

means installation **for root** (configs in `/root`, `chsh` for root). It does
not mean "install with root rights". Usually you should not do this. Run the
script without sudo.

## Settings

Global settings are in `config.sh` next to `installer.sh`:

- `SOFTWARE_DIR` — folder with modules;
- `CONFIG_DIR` — folder with configs that modules copy;
- `LOCAL_DIR` — folder with local repository data;
- `PATCHES_DIR` - folder with patches for programs;
- `UI_COLOR` — color mode: `auto`, `always` or `never`;
- `LIB_DOWNLOAD__ATTEMPTS`, `LIB_DOWNLOAD__*_TIMEOUT` — download retries and
  timeouts;
- `DEBIAN_FRONTEND` — non-interactive apt mode.

You can edit the file or override values for one run:

```bash
CONFIG_DIR=/srv/dotfiles ./installer.sh -d install zsh
```

## Installed state, external programs and adoption

The installer keeps a small state database per module:

- `install.done` — the program was installed by the installer;
- `configure.done` — configuration was applied;
- `manual` — the module was explicitly requested and must not be removed by an
  automatic orphan sweep (like `apt manual`);
- `external` — the program already existed before the installer ran and is not
  managed by it.

A program is **managed** when `install.done` exists and `external` does not.
Only managed programs can be removed by `remove`.

If a program is already present outside the installer, `install` detects it
through the module's `__is_installed` hook, records `external`, skips
`__install`, and can still run `__configure`. Such a program is never removed
automatically.

To take an external program under management, run `reinstall`. It explicitly
reruns `__install` and `__configure`; on success `external` is removed and the
module becomes managed. After that `remove` can remove it.

An explicit `install` of a module marks it `manual`, even when the install phase
was already done. This is how you pin a dependency: install it explicitly once,
and a later `remove` of its parent will not sweep it away. `reinstall` is the
explicit way to run the install and configure phases again.

Existing installs from the old state format are marked `manual` on the first
run after the upgrade. This is deliberate: no old module is swept away by the
new orphan logic before the user has a chance to review it.

## Non-interactive installs

The installer runs apt and dpkg in non-interactive mode. All phases also
cannot read input: their stdin is `/dev/null`. If a package needs a choice,
configure it after the installation. For example:

```bash
sudo dpkg-reconfigure keyboard-configuration
sudo dpkg-reconfigure wireshark-common
```

Modules must not ask questions or wait for input.

## Remove and deconfigure

The two operations are independent:

```text
__install     <->  __remove        program
__configure   <->  __deconfigure   configuration
```

- `remove` calls only `__remove`: the program disappears, configuration stays.
- `deconfigure` calls only `__deconfigure`: configuration disappears, the
  program stays.
- `remove --deconfigure` runs both.

This means a module can be left in three useful states:

- program installed, configuration removed — the user can configure it by hand;
- program removed, configuration kept — a later install reuses the settings;
- neither.

If a program cannot run without `__configure`, the module is wrong:
`__install` must leave a runnable program, and `__configure` must only add
convenience or customization. For example, `dirsearch__install` leaves a
runnable `/opt/dirsearch`, while `dirsearch__configure` adds the convenient
`/usr/local/bin/dirsearch` wrapper. `remove` removes `/opt/dirsearch`;
`deconfigure` removes the wrapper.

The same rule applies to symlinks and wrappers: whatever `__install` creates
belongs to `__remove`, whatever `__configure` creates belongs to
`__deconfigure`.

`remove` refuses to touch an `external` program. It also refuses to remove a
module that another installed module depends on at runtime, and prints which
module to remove first.

`remove --deconfigure` checks the program part first. If the program cannot be
removed, the whole command is refused and configuration is left untouched. Use
`deconfigure` alone when you only want to remove configuration.

After a successful `remove`, the installer sweeps orphan dependency modules:
managed modules that are not `manual`, not `external`, and are not reachable
from any installed `manual`/`external` module. Configuration of swept modules is
kept. `deconfigure` never triggers this sweep because the program stays
installed.

`remove` and `deconfigure` remove module artifacts, not apt dependencies.
Runtime apt packages stay protected as `manual`; build packages are handled by
the existing `autoremove` step after a build.

## How it works

```text
installer.sh
  └─ modules/command.sh       command line, environment, plan, confirmation
       └─ modules/orchestrator.sh   roles, dependencies, phases, removal, state
            ├─ lib/state.sh     phase markers, fingerprint, lock, logs, runner
            ├─ lib/apt.sh       package metadata, batch install, auto-mark, autoremove
            ├─ lib/manifest.sh  JSON run manifest
            ├─ lib/root.sh      sudo when needed
            └─ lib/*            files, binaries, output
```

1. `command.sh` reads the subcommand and options, sets `HOME`/`USER` for the
   current user, finds modules and asks the orchestrator to build a plan.
2. The orchestrator collects modules and classifies each dependency as
   `build` or `runtime`. Module dependencies are resolved recursively and get
   a role: `requested`, `runtime` or `build`.
3. All apt dependencies of the run are installed in one batch. Runtime
   dependencies become `manual` immediately; build dependencies are marked
   `auto` and are removable.
4. Each install/configure phase runs in a clean subshell with `set -eE -o
   pipefail`. The first failed command aborts the phase. Output is streamed to
   the terminal and appended to the phase log. The runner prints one error line
   with the module file, line and failing command. Modules do not need their own
   subshell for error handling; a nested `( ... )` is only for local `cwd` or
   variable isolation.
5. Before `__install`, the orchestrator calls `__is_installed`. If the program
   is already present and this is not `reinstall`, it records `external` and
   skips `__install`.
6. After a successful run, build-only modules get `__remove`, then
   `apt autoremove --purge` removes build packages that are no longer needed.
7. The result of each phase is saved in the state. The next run skips `done`
   phases and continues from a failed phase.
8. If a module file changes, its saved fingerprint no longer matches, so the
   phases of that module run again.

`--keep-build-deps` disables both build-only `__remove` and `apt autoremove`,
and marks the build-only modules `manual`, so a later orphan sweep keeps them.

Saved progress (state) is stored in:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/software-installer/
├── lock
├── cleanup.pending
├── migration.v2
├── manifests/
│   └── 20260101T120000Z.XXXXXX/
│       ├── manifest.json
│       ├── installed_before.txt
│       ├── installed_after.txt
│       ├── installed_before_cleanup.txt
│       └── installed_after_cleanup.txt
└── modules/
    └── user-software__cli__zsh/
        ├── fingerprint
        ├── manual
        ├── external
        ├── install.done
        ├── configure.done
        ├── install.failed
        ├── configure.failed
        ├── remove.failed
        ├── deconfigure.failed
        ├── install.running
        ├── configure.running
        ├── install.log
        ├── configure.log
        ├── remove.log
        └── deconfigure.log
```

`manual` is written by an explicit `install`/`reinstall` or by
`--keep-build-deps`. `external` is written when `__is_installed` reports a
pre-existing program. Phase logs are also printed to the terminal.

## Project structure

```text
installer.sh
config.sh
modules/
├── command.sh
├── imports.sh
├── orchestrator.sh
└── software/
    ├── system-setup/
    │   ├── audio/
    │   └── desktop/
    └── user-software/
        ├── cli/
        ├── desktop/
        ├── develop/
        ├── gui/
        └── infosec/
lib/
├── apt.sh
├── downloading.sh
├── file.sh
├── installation.sh
├── log.sh
├── main.sh
├── manifest.sh
├── root.sh
├── state.sh
└── ui.sh
```

## Creating a new module

### 1. File and name

One module is one file:

```text
modules/software/<class>/<category>/<name>.sh
```

For example:

```text
modules/software/user-software/cli/rg.sh
```

The file name sets the function prefix: `rg.sh` →
`rg__get_build_dependencies`, `rg__get_runtime_dependencies`,
`rg__is_installed`, `rg__install`, `rg__configure`, `rg__remove`,
`rg__deconfigure`.

File names must be unique under `modules/software`. If two modules have the
same name, the installer reports an error.

### 2. Required contract

Every module must implement all functions:

```bash
name__get_build_dependencies() {
  local deps='
  build-package
  '
  echo "$deps"
}

name__get_runtime_dependencies() {
  local deps='
  runtime-package
  '
  echo "$deps"
}

name__is_installed() {
  # Return 0 when the program installed by __install is already present.
}

name__install() {
  # install the main program
}

name__configure() {
  # configure files
}

name__remove() {
  # remove only what __install created
}

name__deconfigure() {
  # remove only what __configure created
}
```

Rules:

- `__get_build_dependencies` — packages/modules needed only for the build;
- `__get_runtime_dependencies` — packages/modules needed after installation;
  they are never removed automatically;
- `__is_installed` — a read-only predicate for the program installed by
  `__install`. It must not write state or install anything;
- `__install` — install the main program only. After it, the program must be
  runnable without `__configure`;
- `__configure` — configuration and convenience only. It must be safe to skip;
- `__remove` — remove only install artifacts: binaries, `/opt/<name>`, files
  generated by `__install`. It must not remove configuration;
- `__deconfigure` — remove only configure artifacts: config files, wrappers,
  symlinks or desktop files created by `__configure`. It must not remove the
  program.

`__remove` and `__deconfigure` must be idempotent: running them twice must not
fail, and a missing file is not an error. They must work independently:

- `__remove` works even when no configuration exists;
- `__deconfigure` works even when the program is already removed.

An old `__get_dependencies` is still accepted as a deprecated alias. Its result
is treated as both build and runtime, so those dependencies are never removed
automatically.

Modules must not ask questions or read stdin. All phases run with
`/dev/null` as stdin.

### 3. Error handling and logs

Do not put `||` after every command. The phase runner already runs the module
with `set -e`, so the first failed command aborts the phase and the runner
prints one line like:

```text
[ERROR] picom: install failed: picom.sh:91: ninja -C build
```

Use `|| true` or an `if` only for a command that may legitimately fail:

```bash
grep -q 'something' file || true
```

Do not wrap a whole build in `if ! ( ... )`: that disables `set -e` inside the
subshell and hides the first failure. The phase runner already runs the module
in a subshell, so write a plain sequence of commands:

```bash
name__install() {
  local workdir

  workdir="$(lib__tmpdir)"
  cd "$workdir"

  git clone --depth 1 'https://github.com/org/name'
  cd name

  make
  lib__as_root make install
}
```

`lib__tmpdir` creates a directory under the phase root; the runner removes it
when the phase finishes, successfully or not.

A nested subshell is not required for error handling, but it is not forbidden.
A plain `( ... )` is a normal command and inherits `set -e`. Use it when you
need to change `cwd` locally and return to the previous directory afterwards:

```bash
name__install() {
  (
    cd /some/dir
    make
  )

  # cwd is unchanged here
  install -m 755 /some/dir/bin/name /usr/local/bin/name
}
```

If the rest of the phase works in the new directory, a plain `cd` is enough,
because the phase itself is already isolated. When a command accepts a
directory argument, prefer it over `cd`. For example, this:

```bash
lib__as_root cp -r "$conf_dir/Topping" "$work_dir"/
lib__as_root patch -d "$work_dir" -p1 < "$conf_dir/USB-Audio.conf.diff"
```

is equivalent to the `( cd "$work_dir"; patch -p1 ... )` form and keeps the
paths explicit. This is the reason `topping_ucm__configure` does not need its
own subshell: `patch -d` and explicit `cp` destinations say the same thing more
directly. Do not add `set -e` inside the module: the runner already sets it.

Do not use `local x="$(cmd)"` when `cmd` can fail: `local` hides its exit
status. Declare and assign separately:

```bash
local x
x="$(cmd)"
```

`lib__log_info`, `lib__log_warn` and `lib__log_error` from a module still appear
on the terminal and in the phase log. The runner adds the final error line; do
not duplicate build-failure messages.

### 4. Dependencies

The dependency functions are declarations, not installations.

```bash
rg__get_build_dependencies() {
  local deps='
  git
  make
  gcc
  '
  echo "$deps"
}

rg__get_runtime_dependencies() {
  local deps='
  libpcre2-8-0
  '
  echo "$deps"
}
```

Each entry is resolved in this order:

1. If a module with this name exists, that module is installed (with its own
   dependencies, and their dependencies too).
2. Otherwise the entry is an apt package name.

For example, `alacritty` declares `rust` and `git` as build dependencies, so
`./installer.sh install alacritty` installs those modules for the build. Since
they are build-only, the orchestrator calls their `__remove` after alacritty is
built. Runtime libraries such as `libfontconfig1` stay installed.

Roles are computed from the graph:

- a requested module is `requested`;
- a runtime edge makes a module `runtime`;
- a build edge makes a module `build`;
- everything reachable from a `build` module is also `build`;
- if a module is reachable both ways, `runtime` wins.

Rules:

- you can use module names and apt package names;
- a module name wins over a package with the same name;
- module dependencies are installed before the module that needs them;
- module dependencies run `__install` only, without `__configure`, unless they
  are explicitly requested;
- a module you ask for explicitly always runs the phases for the selected
  command;
- with `configure`, module dependencies are not added;
- dependency cycles are an error;
- do not list the runtime desktop environment: Xorg, fonts, dmenu, terminals,
  panels, compositors, wallpaper and lock tools;
- do not list the main program (it goes in `__install`);
- no `sudo`, `apt-get`, downloads or other actions;
- duplicates are OK: `lib__apt_install` removes them;
- declare `wget` and `ca-certificates` in build dependencies if you use
  `lib__wget_download` with an HTTPS URL;
- declare `unzip`/`xz-utils`/`bzip2` in build dependencies if you use the
  corresponding archive format with `lib__mv_to_local_bin`;
- for builds, list the smallest package set, not `build-essential`.

### 5. Install

`__install` must be idempotent (safe to run again): a second run must not break
anything and must not create duplicates.

Main techniques:

- check what is already installed;
- build in `lib__tmpdir`;
- remove only folders you manage (`/opt/<name>`);
- use `mkdir -p`, `ln -sf`, `install -m`, `mv -f`;
- do not clone into an existing folder without cleaning it;
- remove downloaded archives and `.deb` files after installation.

The main program installed by apt:

```bash
rg__is_installed() {
  lib__apt_is_installed ripgrep
}

rg__install() {
  lib__apt_install ripgrep
}

rg__remove() {
  lib__apt_remove ripgrep
}
```

Example: a binary in an archive from GitHub Releases.

```bash
name__is_installed() {
  command -v name > /dev/null 2>&1
}

name__get_build_dependencies() {
  local deps='
  wget
  '
  echo "$deps"
}

name__get_runtime_dependencies() {
  return 0
}

name__install() {
  lib__wget_download 'https://github.com/org/name/releases/latest/download/name-linux-x64.tar.gz'
  lib__mv_to_local_bin 'name'
}

name__remove() {
  lib__as_root rm -f /usr/local/bin/name
}
```

`lib__mv_to_local_bin` extracts the archive, finds the executable, installs it
to `/usr/local/bin/name`, and removes the archive. Declare `wget` and the
archive tool (`xz-utils`, `unzip`, `bzip2`) in build dependencies; the helper
does not install them itself.

Example: a ready binary without an archive.

```bash
name__install() {
  lib__wget_download 'https://github.com/org/name/releases/latest/download/name-linux-x64'

  lib__install_binary 'name-linux-x64' 'name'
  rm -f 'name-linux-x64'
}
```

Example: build from source.

```bash
name__install() {
  local workdir

  workdir="$(lib__tmpdir)"
  cd "$workdir"

  git clone --depth 1 'https://github.com/org/name'
  cd name
  make
  lib__as_root make install
}

name__remove() {
  lib__as_root rm -f /usr/local/bin/name
}
```

List the runtime libraries the built binary links to. If you omit them, the
global `autoremove` can remove them after the build dependencies are deleted.

Example: a managed folder in `/opt`.

```bash
name__install() {
  lib__wget_download 'https://example.com/name.tar.xz'

  lib__as_root rm -rf /opt/name
  lib__as_root mkdir -p /opt
  lib__as_root tar -xJf 'name.tar.xz' -C /opt

  if [[ ! -d /opt/name ]]; then
    lib__as_root mv /opt/name* /opt/name
  fi

  rm -f 'name.tar.xz'
}

name__remove() {
  lib__as_root rm -rf /opt/name
}
```

### 6. Configuration

`__configure` handles only configs and must also be idempotent (safe to run
again).

A ready config from the repository `config/` folder:

```bash
name__configure() {
  lib__cp_config 'name'
}

name__deconfigure() {
  rm -rf "$HOME/.config/name"
}
```

Result: `$CONFIG_DIR/name` is copied to `$HOME/.config/name`.
Old content at the destination is replaced. Nested copies never appear.
Permissions: `700` for folders, `600` for files. If the source file has an
executable bit (exec bit), the copy keeps it and gets `700`.

An explicit destination (fully replaced):

```bash
zsh__configure() {
  lib__cp_config 'zsh/zshrc' "$HOME/.zshrc"
}
```

A file you need to generate:

```bash
name__configure() {
  lib__file_write "$HOME/.config/name/config.conf" 600 << EOF
user=$USER
EOF
}

name__deconfigure() {
  rm -f "$HOME/.config/name/config.conf"
}
```

Writing to `/etc` and `/usr/local/share` also uses `lib__file_write`:
if the folder is not writable, the function calls sudo itself.

Configuration as the current user (this is the default mode):

```bash
name__configure() {
  local config_dir="$HOME/.config/name"

  mkdir -p "$config_dir"
  /usr/local/bin/name --init "$config_dir"
}
```

### 7. Remove and deconfigure

```bash
name__remove() {
  lib__as_root rm -f /usr/local/bin/name
}

name__deconfigure() {
  rm -rf "$HOME/.config/name"
}
```

For a main program installed by apt:

```bash
name__remove() {
  lib__apt_remove name
}
```

`lib__apt_remove` refuses to purge a package that other installed packages
depend on. In that case it returns 3 and the phase runner reports the module as
kept instead of removed. The module does not write any state.

### 8. Root access and user

Module code always runs as the current user. The installer sets `HOME` and
`USER` for this user, so you can use them directly.

`lib__as_root` is the only way to get root:

```bash
lib__as_root mkdir -p /opt/name
lib__as_root ln -sf /opt/name/name /usr/local/bin/name
```

`lib__apt_install` is for main programs and local `.deb` files. Dependencies
are installed by the orchestrator, not by the module:

```bash
lib__apt_install ripgrep fd-find
```

In `__remove`, use `lib__apt_remove` for a main program that the module
installed itself. Do not check ownership in the module: the orchestrator
already skips `external` and blocked programs.

Do not:

| Do not | Do this |
|---|---|
| `sudo ...` | `lib__as_root ...` |
| `sudo -u ...` | not needed: code already runs as the user |
| `chown ...` | not needed: files are created by the user |
| `apt-get install ...` | `lib__apt_install ...` |
| `apt-get purge ...` | `lib__apt_remove ...` |
| `mktemp -d` for build work | `lib__tmpdir` |
| writing ownership/kept markers in a module | nothing: ownership is orchestrator state |

### 9. Available variables

- `SCRIPT_DIR` — project root;
- `SOFTWARE_DIR` — `modules/software`;
- `CONFIG_DIR` — repository `config/` folder;
- `LOCAL_DIR` — repository `local/` folder;
- `HOME` — home folder of the current user;
- `USER` — name of the current user;
- `STATE_ROOT` — state folder;
- `MODULE_STATE_DIR` — state folder of the current module phase;
- `MODULE_KEY` — state key of the current module;
- `MODULE_NAME` — current module name during a phase.

### 10. Library helpers

```text
lib__as_root <command...>

lib__tmpdir                           # per-phase temporary directory
lib__file_write <path> [mode]         # content from stdin, sudo if needed
lib__cp_config <file> [exact path]    # keeps modes and exec bit

lib__install_binary <file> <name>
lib__mv_to_local_bin <name>           # archive from current folder; no implicit apt

lib__wget_download <url>              # requires wget in build dependencies
lib__wget_download_github_release <repo> <file regex>

lib__apt_install <packages...|.deb files>
lib__apt_install_batch <packages...>  # one batch for build + runtime deps
lib__apt_remove <packages...>
lib__apt_reverse_dependencies <package>
lib__apt_mark_manual <packages...>
lib__apt_mark_auto <packages...>
lib__apt_autoremove
lib__apt_autoremove_preview
lib__apt_run <apt-get or dpkg command...>   # always non-interactive
lib__apt_update [--force]                   # --force after adding a repository

lib__require_command <command> [package]
lib__log_info|warn|error|success <text>
```

### 11. Full template

```bash
name__get_build_dependencies() {
  local deps='
  wget
  git
  '
  echo "$deps"
}

name__get_runtime_dependencies() {
  local deps='
  libexample1
  '
  echo "$deps"
}

name__is_installed() {
  command -v name > /dev/null 2>&1
}

name__install() {
  local workdir

  workdir="$(lib__tmpdir)"
  cd "$workdir"

  git clone --depth 1 'https://github.com/org/name'
  cd name
  make
  lib__as_root make install
}

name__configure() {
  lib__cp_config 'name'
}

name__remove() {
  lib__as_root rm -f /usr/local/bin/name
}

name__deconfigure() {
  rm -rf "$HOME/.config/name"
}
```

### 12. Checklist

Before adding a module, check:

- [ ] the file is in `modules/software/<group>/<category>/`;
- [ ] the file name is unique;
- [ ] `__get_build_dependencies`, `__get_runtime_dependencies`,
      `__is_installed`, `__install`, `__configure`, `__remove` and
      `__deconfigure` exist and have the correct prefix;
- [ ] build and runtime dependencies are separated correctly;
- [ ] dependency functions have no side effects, no main program, and no
      runtime desktop environment;
- [ ] `__install` is idempotent and leaves a runnable program without
      `__configure`;
- [ ] `__remove` is idempotent and removes only install artifacts;
- [ ] `__deconfigure` is idempotent and removes only configure artifacts;
- [ ] there is no plain `sudo`;
- [ ] apt packages use `lib__apt_install` or `lib__apt_remove`;
- [ ] tools such as `wget`, `ca-certificates`, `unzip`, `xz-utils`, `bzip2` are
      declared in build dependencies;
- [ ] the module does not ask questions or read stdin;
- [ ] temporary files are removed; build work uses `lib__tmpdir`;
- [ ] configs use `lib__cp_config` or `lib__file_write`;
- [ ] the installer runs twice in a row without errors.

Check:

```bash
bash -n modules/software/user-software/<category>/name.sh
./installer.sh -d install name
./installer.sh -d -v install name      # full phase and package matrix
./installer.sh -y install name
./installer.sh -y install name         # the second run must skip phases
./installer.sh -y reinstall name       # must run without duplicates
./installer.sh -y --keep-build-deps install name  # build deps stay manual
./installer.sh -y deconfigure name     # program must still run
./installer.sh -y remove name          # program removed, config kept
./installer.sh -y remove --deconfigure name
```

## Common errors

- **Module not found** — check the file name and path.
- **`Module ... does not implement the module contract`** — one of the required
  functions is missing, or its prefix does not match the file name.
- **`Module ... does not declare build or runtime dependencies`** — add
  `__get_build_dependencies` and `__get_runtime_dependencies`. The old
  `__get_dependencies` is accepted as a deprecated alias.
- **`Module ... must implement both __get_build_dependencies and
  __get_runtime_dependencies`** — when using the new contract, both functions
  must exist. Return 0 from the empty one.
- **`Circular module dependency`** — modules point to each other via
  dependency functions; break the cycle.
- **A build-only module was not removed** — it was marked `manual`, was already
  present before the run, or another installed package depends on it. It is
  kept on purpose.
- **Build dependencies stayed installed** — `--keep-build-deps` was used, or a
  module failed and `--force-clean` was not passed.
- **`remove` says the module is installed outside the installer** — the program
  is `external`. Run `deconfigure` to remove only its configuration, or
  `reinstall` to adopt it, then `remove`.
- **A failed install left partial files** — run `remove` for that module. A
  recorded failed install attempt is treated as removable even if
  `__is_installed` now sees a partial program.
- **`remove` says another module needs this one** — remove the dependent module
  first. There is no recursive cascade.
- **`deconfigure` says nothing to do** — the module has no recorded
  configuration; `configure.done` is absent.
- **`autoremove` wants to remove unrelated packages** — this is the global
  autoremove behavior; use `--keep-build-deps` to skip it, or inspect the
  manifest and `autoremove_preview` first.
- **`Failed to get sudo privileges`** — sudo is missing, there is no terminal,
  or the password prompt was cancelled; run `sudo -v` first or set up NOPASSWD.
- **apt or dpkg asked a question** — the installer runs them non-interactively.
  If a package needs a choice, use `sudo dpkg-reconfigure <package>` after the
  installation.
- **A phase is skipped but you need to reinstall** — use `reinstall`.
- **A config did not update** — config changes do not affect the fingerprint;
  use `configure` or `reinstall`.
