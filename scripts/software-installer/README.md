software-installer
---

A small installer for user software and configs on Debian/Ubuntu.
It installs programs, dependencies and configs. It can show a plan, continue
after a failure, and run again safely.

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
-v, --verbose         full phase matrix and all dependency packages
    --color WHEN      color mode: auto, always or never (default: auto)
    --install-only    dependencies + __install
    --configure-only  only __configure
-f, --force           run phases again, ignore saved state
-r, --reset           remove saved state for the selected modules and exit
-m, --mark-installed  mark selected modules as installed and exit
    --keep-going      continue after errors
```

Installation always runs for the user who started the script. Root is needed
only for system changes. sudo asks for a password only when it is really
needed. For example, `./installer.sh -y starship` does not ask for a password.

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

`-m` writes only `install.done` with the current module fingerprint. It does
not touch `configure.done`: if you request that module explicitly later, its
configure phase can still run.

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
       └─ modules/orchestrator.sh   queue, dependencies, phases, state, continue
            ├─ lib/state.sh   phase markers, fingerprint, lock, logs
            ├─ lib/apt.sh     package metadata and installation
            ├─ lib/root.sh    sudo when needed
            └─ lib/*          files, binaries, output
```

1. `command.sh` reads the arguments, sets `HOME`/`USER` for the current user,
   finds modules and asks the orchestrator to build a plan.
2. The orchestrator collects modules, finds their dependencies, and the
   dependencies of those dependencies (a module or an apt package). It puts
   all apt packages into one list.
3. `lib__apt_install` installs only missing packages.
4. Each module runs in phases (steps):
   - `install` → `module__install`;
   - `configure` → `module__configure`.
5. The result of each phase is saved in the state. The next run skips `done`
   phases and continues from a failed phase.
6. If a module file changes, its saved fingerprint (a hash of the file) no
   longer matches, so the phases of that module run again.

Saved progress (state) is stored in:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/software-installer/
├── lock
└── modules/
    └── user-software__cli__zsh/
        ├── fingerprint
        ├── install.done
        ├── configure.done
        ├── install.failed
        ├── configure.failed
        ├── install.running
        ├── configure.running
        ├── install.log
        └── configure.log
```

Phase logs are also printed to the terminal.

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

The file name sets the function prefix: `rg.sh` → `rg__get_dependencies`,
`rg__install`, `rg__configure`.

File names must be unique under `modules/software`. If two modules have the
same name, the installer reports an error.

### 2. Required contract

Every module must follow this contract: it must have three functions.

```bash
name__get_dependencies() {
  local deps='
  package-one
  package-two
  '
  echo "$deps"
}

name__install() {
  # install the main program
}

name__configure() {
  # configure files
}
```

- `__get_dependencies` — packages/modules needed to install or build the
  program, plus a runtime without which the program cannot start;
- `__install` — install the main program;
- `__configure` — configuration only.

Modules must not ask questions or read stdin. All phases run with
`/dev/null` as stdin.

### 3. Dependencies

`__get_dependencies` is a declaration, not an installation.

```bash
rg__get_dependencies() {
  local deps='
  git
  make
  gcc
  '
  echo "$deps"
}
```

Each entry is resolved in this order:

1. If a module with this name exists, that module is installed (with its own
   dependencies, and their dependencies too).
2. Otherwise the entry is an apt package name.

For example, `alacritty` declares `rust`, so `./installer.sh alacritty` first
installs the `rust` module and then alacritty. The `git` dependency also points
to the `cli/git` module, not only to the `git` package. Module dependencies are
installed without their config.

`__get_dependencies` is for install/build and for a runtime the tool cannot
start without. Do not put the desktop environment here. Xorg, fonts, dmenu,
terminals, panels, compositors, wallpaper and lock tools are separate modules.
Ask for them explicitly:

```bash
./installer.sh dwm xorg dmenu fonts
```

A runtime that the program itself cannot work without (for example Java for
Ghidra or Perl for enum4linux) may stay in the list.

Rules:

- you can use module names and apt package names;
- a module name wins over a package with the same name;
- module dependencies are installed before the module that needs them;
- module dependencies run only `__install`, without `__configure`;
- a module you ask for explicitly always runs all phases for the selected mode;
- with `--configure-only`, module dependencies are not added;
- dependency cycles are an error;
- do not list the runtime desktop environment: Xorg, fonts, dmenu, terminals,
  panels, compositors, wallpaper and lock tools;
- do not list the main program (it goes in `__install`);
- no `sudo`, `apt-get`, downloads or other actions;
- duplicates are OK: `lib__apt_install` removes them;
- do not add `wget` if you use `lib__wget_download` — the library installs it
  when needed;
- do not add `unzip`/`xz-utils`/`bzip2` only for `lib__mv_to_local_bin` — it
  installs the unpacking program it needs;
- for builds, list the smallest package set, not `build-essential`.

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
name__get_dependencies() {
  return 0
}

name__install() {
  lib__wget_download 'https://github.com/org/name/releases/latest/download/name-linux-x64.tar.gz'
  lib__mv_to_local_bin 'name'
}
```

`lib__mv_to_local_bin` extracts the archive, finds the executable, installs it
to `/usr/local/bin/name`, and removes the archive.

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
name__get_dependencies() {
  local deps='
  git
  make
  gcc
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

`lib__apt_install` is for main programs, dependencies and local `.deb` files:

```bash
lib__apt_install ripgrep fd-find
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

### 7. Available variables

- `SCRIPT_DIR` — project root;
- `SOFTWARE_DIR` — `modules/software`;
- `CONFIG_DIR` — repository `config/` folder;
- `LOCAL_DIR` — repository `local/` folder;
- `HOME` — home folder of the current user;
- `USER` — name of the current user;
- `STATE_ROOT` — state folder.

### 8. Library helpers

```text
lib__as_root <command...>

lib__file_write <path> [mode]         # content from stdin, sudo if needed
lib__cp_config <file> [exact path]    # keeps modes and exec bit

lib__install_binary <file> <name>
lib__mv_to_local_bin <name>           # archive from current folder; installs unzip/xz/bzip2

lib__wget_download <url>              # installs wget if needed
lib__wget_download_github_release <repo> <file regex>

lib__apt_install <packages...|.deb files>
lib__apt_run <apt-get or dpkg command...>   # always non-interactive
lib__apt_update                             # apt-get update once per process
lib__log_info|warn|error|success <text>
```

### 9. Full template

```bash
name__get_dependencies() {
  local deps='
  git
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
```

### 10. Checklist

Before adding a module, check:

- [ ] the file is in `modules/software/<group>/<category>/`;
- [ ] the file name is unique;
- [ ] all three functions exist and have the correct prefix;
- [ ] `__get_dependencies` has no side effects, no main program, and no runtime
      desktop environment;
- [ ] `__install` is idempotent (safe to run twice);
- [ ] there is no plain `sudo`;
- [ ] apt packages use `lib__apt_install`;
- [ ] the module does not ask questions or read stdin;
- [ ] temporary files are removed;
- [ ] configs use `lib__cp_config` or `lib__file_write`;
- [ ] the installer runs twice in a row without errors.

Check:

```bash
bash -n modules/software/user-software/<category>/name.sh
./installer.sh -n name
./installer.sh -n -v name       # full phase and package matrix
./installer.sh -y name
./installer.sh -y name          # the second run must skip phases
./installer.sh -y --force name  # must run without duplicates
```

## Common errors

- **Module not found** — check the file name and path.
- **`Module ... does not implement the module contract`** — one of the three
  functions is missing, or its prefix does not match the file name.
- **`Circular module dependency`** — modules point to each other via
  `__get_dependencies`; break the cycle.
- **`Failed to get sudo privileges`** — sudo is missing, there is no terminal,
  or the password prompt was cancelled; run `sudo -v` first or set up NOPASSWD.
- **apt or dpkg asked a question** — the installer runs them non-interactively.
  If a package needs a choice, use `sudo dpkg-reconfigure <package>` after the
  installation.
- **A phase is skipped but you need to reinstall** — use `--force` or `--reset`.
- **A config did not update** — config changes do not affect the fingerprint;
  use `--force`.
