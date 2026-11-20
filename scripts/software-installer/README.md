software-installer
---

A small installer for user software and configs on Debian/Ubuntu.
The target platform is Ubuntu LTS 24.04 (amd64); package names use the 24.04
variants, other distributions are not covered.
It installs only the requested modules and their runtime dependencies, removes
temporary build dependencies after a successful run, and can keep them for
later builds with `--keep-build-deps`. It can show a plan, continue after a
failure, and run again safely.

## Quick start

```bash
./installer.sh -h
./installer.sh -l                      # list all modules
./installer.sh -n all                  # show the plan, change nothing
./installer.sh -n -v all               # detailed plan: phases and packages
./installer.sh -y zsh                  # install one module
./installer.sh binwalk alacritty       # install several modules
./installer.sh cli                     # all modules in a category
./installer.sh user-software           # all modules in a group
./installer.sh all                     # all modules
./installer.sh -m git                  # mark a module as installed
./installer.sh --keep-build-deps -y dwm  # keep build deps for a later build
```

`-l` prints modules grouped by folder. You can pass any name from the list
to the installer.

The first folder under `modules/software` is a group (`user-software`,
`system-setup`). A folder inside a group is a category (`cli`, `desktop`,
`infosec`, ...). A target is what you ask the installer to install: a group
name, a category name, or one module.

Main options:

```text
-h, --help            show help
-l, --list            list all modules
-y, --yes             do not ask for confirmation
-n, --dry-run         show the plan and exit
-v, --verbose         detailed plan: phase matrix, package versions, descriptions
                      (short options can be combined: -vn = -v -n)
    --color WHEN      color mode: auto, always or never (default: auto)
    --install-only    dependencies + __install
    --configure-only  only __configure
-f, --force           run phases again, ignore saved state
-r, --reset           remove saved state for the selected modules and exit
-m, --mark-installed  mark selected modules as installed and exit
    --keep-going      continue after errors
    --keep-build-deps keep build dependencies and build-only modules
    --force-clean     run autoremove even after a module failure
```

Installation always runs for the user who started the script. Root is needed
only for system changes. sudo asks for a password only when it is really
needed. Modules that only write to the home directory (for example
`wallpapers`) do not ask for a password; packages, `/opt` and `/usr/local/bin`
do.

```bash
sudo ./installer.sh -y zsh
```

means installation **for root** (configs in `/root`, `chsh` for root). It does
not mean "install with root rights". Usually you should not do this. Run the
script without sudo.

## Settings

Global settings are in `config.sh` next to `installer.sh`:

- `SOFTWARE_DIR` — folder with modules;
- `CONFIG_DIR` — folder with configs that modules copy;
- `LOCAL_DIR` — folder with local repository data;
- `UI_COLOR` — color mode: `auto`, `always` or `never`;
- `LIB_DOWNLOAD__ATTEMPTS`, `LIB_DOWNLOAD__*_TIMEOUT` — download retries and
  timeouts;
- `DEBIAN_FRONTEND` — non-interactive apt mode.

You can edit the file or override values for one run:

```bash
CONFIG_DIR=/srv/dotfiles ./installer.sh -n zsh
```

## Manual install marks

If a program is already installed outside the installer, mark its module as
installed. The installer will not run its install phase again:

```bash
./installer.sh -m git
./installer.sh -n dwm      # the git module is already done
```

`-m` writes `install.done` with the current module fingerprint and a
`manual.mark`. The mark protects the module from `__remove` even if another
module uses it as a build-only dependency. It does not touch
`configure.done`: if you request that module explicitly later, its configure
phase can still run. An explicit install request clears `manual.mark`.

Use `-n -m git` to preview. Use `-r git` to remove the mark. If the module file
changes, its fingerprint changes and the module will run again; mark it again
after the change.

## Non-interactive installs

The installer runs apt and dpkg in non-interactive mode. All phases also
cannot read input: their stdin is `/dev/null`. If a package needs a choice,
configure it after the installation. For example:

```bash
sudo dpkg-reconfigure keyboard-configuration
sudo dpkg-reconfigure wireshark-common
```

Modules must not ask questions or wait for input.

## How it works

```text
installer.sh
  └─ modules/command.sh       command line, environment, plan, confirmation
       └─ modules/orchestrator.sh   roles, dependencies, phases, cleanup, state
            ├─ lib/state.sh     phase markers, fingerprint, lock, logs, pending cleanup
            ├─ lib/apt.sh       package metadata, batch install, auto-mark, autoremove
            ├─ lib/manifest.sh  JSON run manifest
            ├─ lib/root.sh      sudo when needed
            └─ lib/*            files, binaries, output
```

1. `command.sh` reads the arguments, sets `HOME`/`USER` for the current user,
   finds modules and asks the orchestrator to build a plan.
2. The orchestrator collects modules and classifies each dependency as
   `build` or `runtime`. Module dependencies are resolved recursively and get
   a role: `requested`, `runtime` or `build`. A build-only module is used only
   when a module that actually installs in this run depends on it; otherwise
   it is left untouched.
3. All apt dependencies of the run are installed in one batch. Runtime
   dependencies become `manual` immediately (including ones that were already
   installed as `auto`); build dependencies are marked `auto` and are
   removable.
4. Each module runs in phases:
   - `install` → `module__install`;
   - `configure` → `module__configure`.
5. After a successful run, build-only modules get `module__remove`, then
   `apt autoremove --purge` removes build packages that are no longer needed.
6. The result of each phase is saved in the state. The next run skips `done`
   phases and continues from a failed phase.
7. If a module file changes, its saved fingerprint (a hash of the file) no
   longer matches, so the phases of that module run again.

`--keep-build-deps` disables both `module__remove` and `apt autoremove`, so
build dependencies are not marked `auto` and are not removed. Dependencies
installed by this run stay `manual` and can be reused for a later build.

Saved progress (state) is stored in:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/software-installer/
├── lock
├── cleanup.pending
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
        ├── manual.mark
        ├── owned
        ├── install.done
        ├── configure.done
        ├── install.failed
        ├── configure.failed
        ├── install.running
        ├── configure.running
        ├── install.log
        └── configure.log
```

Phase logs are also printed to the terminal. `manual.mark` is written by
`-m/--mark-installed` and protects a module from `__remove`. `owned` is an
optional marker used by modules that may already exist before installation.

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
modules/software/user-software/<category>/<name>.sh
```

For example:

```text
modules/software/user-software/cli/rg.sh
```

The file name sets the function prefix: `rg.sh` →
`rg__get_build_dependencies`, `rg__get_runtime_dependencies`, `rg__install`,
`rg__configure`, and optionally `rg__remove`.

File names must be unique under `modules/software`. If two modules have the
same name, the installer reports an error.

### 2. Required contract

Every module must follow this contract. The first four functions are required;
`__remove` is required for every module that can be used as a build-only
dependency.

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

name__install() {
  # install the main program
}

name__configure() {
  # configure files
}

name__remove() {
  # fully undo __install and __configure
}
```

- `__get_build_dependencies` — packages/modules needed only for the build;
- `__get_runtime_dependencies` — packages/modules needed after installation;
  they are never removed automatically;
- `__install` — install the main program only;
- `__configure` — configuration only, no package installation;
- `__remove` — remove binaries, generated files, cache and configs created by
  the module. It must be safe to run twice and must not delete something that
  existed before the module was installed. If it decides to keep a pre-existing
  program, it calls `lib__state_mark_kept` so the manifest reports it as kept,
  not removed.

An old `__get_dependencies` is still accepted as a deprecated alias. Its result
is treated as both build and runtime, so those dependencies are never removed
automatically.

Modules must not ask questions or read stdin. All phases run with
`/dev/null` as stdin.

### 3. Dependencies

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
`./installer.sh alacritty` installs those modules for the build. Since they are
build-only, the orchestrator calls their `__remove` after alacritty is built.
Runtime libraries such as `libfontconfig1` stay installed.

Roles are computed from the graph:

- a requested module is `requested`;
- a runtime edge makes a module `runtime`;
- a build edge makes a module `build`;
- everything reachable from a `build` module is also `build`;
- if a module is reachable both ways, `runtime` wins;
- a `build` module without `__remove` is promoted to `runtime`.

Rules:

- you can use module names and apt package names;
- a module name wins over a package with the same name;
- module dependencies are installed before the module that needs them;
- module dependencies run `__install` only, without `__configure`, unless they
  are explicitly requested;
- a module you ask for explicitly always runs all phases for the selected mode;
- with `--configure-only`, module dependencies are not added;
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
- for builds, list the smallest package set, not `build-essential`;
- if the program may already exist on the machine, write an ownership marker
  with `lib__state_mark_owned` and check it in `__remove`.

### 4. Install

`__install` must be idempotent (safe to run again): a second run must not break
anything and must not create duplicates.

Main techniques:

- check what is already installed;
- build in `mktemp -d`;
- remove only folders you manage (`/opt/<name>`);
- use `mkdir -p`, `ln -sf`, `install -m`, `mv -f`;
- do not clone into an existing folder without cleaning it;
- remove downloaded archives and `.deb` files after installation.

The main program installed by apt:

```bash
rg__install() {
  lib__apt_install ripgrep
}
```

Example: a binary in an archive from GitHub Releases.

```bash
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
name__get_build_dependencies() {
  local deps='
  git
  make
  gcc
  '
  echo "$deps"
}

name__get_runtime_dependencies() {
  local deps='
  libexample1
  '
  echo "$deps"
}

name__install() {
  local workdir

  workdir="$(mktemp -d)"

  (
    cd "$workdir"
    git clone --depth 1 'https://github.com/org/name'
    cd name
    make
    lib__as_root make install
  )

  rm -rf "$workdir"
}
```

List the runtime libraries the built binary links to. If you omit them, the
global `autoremove` can remove them after the build dependencies are deleted.

Example: install a `.deb` from GitHub Releases.

```bash
name__install() {
  rm -f ./name_*.deb

  lib__wget_download_github_release 'org/name' 'name_.*_amd64.deb'
  lib__apt_install ./name_*.deb

  rm -f ./name_*.deb
}
```

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
```

### 5. Configuration

`__configure` handles only configs and must also be idempotent (safe to run
again).

A ready config from the repository `config/` folder:

```bash
name__configure() {
  lib__cp_config 'name'
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

### 6. Root access and user

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
installed itself. Check ownership first so a pre-existing package is kept.
`lib__apt_remove` also refuses to purge a package that other installed
packages depend on and marks the module as kept:

```bash
git__remove() {
  lib__state_is_owned || {
    lib__state_mark_kept
    return 0
  }

  lib__apt_remove git
}
```

`lib__as_root` asks for the sudo password only on the first call.
If a module does not need root, no password is asked.

Do not:

| Do not | Do this |
|---|---|
| `sudo ...` | `lib__as_root ...` |
| `sudo -u ...` | not needed: code already runs as the user |
| `chown ...` | not needed: files are created by the user |
| `apt-get install ...` | `lib__apt_install ...` |
| `apt-get purge ...` | `lib__apt_remove ...` (with an ownership check) |

### 7. Available variables

- `SCRIPT_DIR` — project root;
- `SOFTWARE_DIR` — `modules/software`;
- `CONFIG_DIR` — repository `config/` folder;
- `LOCAL_DIR` — repository `local/` folder;
- `HOME` — home folder of the current user;
- `USER` — name of the current user;
- `STATE_ROOT` — state folder;
- `MODULE_STATE_DIR` — state folder of the current module phase;
- `MODULE_KEY` — state key of the current module;
- `MODULE_NAME` — current module name during `__remove`.

### 8. Library helpers

```text
lib__as_root <command...>

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
lib__state_mark_owned
lib__state_is_owned
lib__state_mark_kept        # __remove kept a pre-existing program
lib__log_info|warn|error|success <text>
```

### 9. Full template

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

name__install() {
  local workdir

  lib__wget_download 'https://example.com/name.tar.gz'
  lib__mv_to_local_bin 'name'

  workdir="$(mktemp -d)"
  (
    cd "$workdir"
    # build and install if needed
  )
  rm -rf "$workdir"
}

name__configure() {
  lib__cp_config 'name'
}

name__remove() {
  lib__as_root rm -f /usr/local/bin/name
  rm -rf "$HOME/.config/name"
}
```

### 10. Checklist

Before adding a module, check:

- [ ] the file is in `modules/software/<group>/<category>/`;
- [ ] the file name is unique;
- [ ] `__get_build_dependencies`, `__get_runtime_dependencies`, `__install` and
      `__configure` exist and have the correct prefix;
- [ ] `__remove` exists if the module can be used as a build-only dependency;
- [ ] build and runtime dependencies are separated correctly;
- [ ] dependency functions have no side effects, no main program, and no
      runtime desktop environment;
- [ ] `__install` is idempotent (safe to run twice);
- [ ] `__remove` is idempotent and checks the ownership marker if the program
      may already exist;
- [ ] there is no plain `sudo`;
- [ ] apt packages use `lib__apt_install` or `lib__apt_remove`;
- [ ] tools such as `wget`, `ca-certificates`, `unzip`, `xz-utils`, `bzip2` are
      declared in build dependencies;
- [ ] the module does not ask questions or read stdin;
- [ ] temporary files are removed;
- [ ] configs use `lib__cp_config` or `lib__file_write`;
- [ ] the installer runs twice in a row without errors.

Check:

```bash
bash -n modules/software/user-software/<category>/name.sh
./installer.sh -n name
./installer.sh -n -v name          # full phase and package matrix
./installer.sh -y name
./installer.sh -y name             # the second run must skip phases
./installer.sh -y --force name     # must run without duplicates
./installer.sh -y --keep-build-deps name  # build deps stay manual
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
- **A build-only module was not removed** — it has no `__remove`, was marked
  with `-m`, was already present before the run, or another installed package
  depends on it. It is kept on purpose.
- **Build dependencies stayed installed** — `--keep-build-deps` was used, or a
  module failed and `--force-clean` was not passed.
- **`autoremove` wants to remove unrelated packages** — this is the global
  autoremove behavior; use `--keep-build-deps` to skip it, or inspect the
  manifest and `autoremove_preview` first.
- **`Failed to get sudo privileges`** — sudo is missing, there is no terminal,
  or the password prompt was cancelled; run `sudo -v` first or set up NOPASSWD.
- **apt or dpkg asked a question** — the installer runs them non-interactively.
  If a package needs a choice, use `sudo dpkg-reconfigure <package>` after the
  installation.
- **A phase is skipped but you need to reinstall** — use `--force` or `--reset`.
- **A config did not update** — config changes do not affect the fingerprint;
  use `--force`.
