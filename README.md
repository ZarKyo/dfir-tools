# DFIR-tools

[![Super-Linter](https://github.com/ZarKyo/dfir-tools/actions/workflows/linter.yml/badge.svg)](https://github.com/marketplace/actions/super-linter)

Post-installation scripts to configure a DFIR workstation on Ubuntu. Supports three installation modes: SIFT, REMnux, or DFIR (SIFT + REMnux addon). Do not run SIFT and REMnux installers in the same VM — use `install-dfir` for the combined setup.

## Installation

Clone the repository and use `make` to run the desired installer:

```bash
sudo apt-get install -y git
mkdir ~/src/git/
git clone https://github.com/ZarKyo/dfir-tools.git ~/src/git/dfir-tools
cd ~/src/git/dfir-tools
```

| Target | Command | Description |
| ------ | ------- | ----------- |
| SIFT | `make install-sift` | SIFT workstation via `cast` + additional tools |
| REMnux | `make install-remnux` | REMnux malware analysis VM + additional tools |
| DFIR | `make install-dfir` | SIFT base + REMnux as addon |

## What each installer does

### `make install-sift`

- Updates Ubuntu and installs general packages (vim, tshark, curl, git, tmux, sqlite3, jq…)
- Installs `open-vm-tools-desktop` for VMware
- Installs SIFT via `cast install teamdfir/sift-saltstack`
- Installs Google Chrome
- Sets up Python virtualenvwrapper with isolated environments
- Installs additional tools: chaosreader, FLOSS, RecuperaBit
- Deploys SIFT aliases to `~/.sift_aliases`
- Applies GNOME preferences (dark theme, 24h clock, dock config)
- Runs `make dotfiles` to deploy `.bashrc`, `.vimrc`, `.bash_aliases`

### `make install-remnux`

- Updates Ubuntu and installs general packages
- Installs `open-vm-tools-desktop` for VMware
- Installs REMnux via `remnux install`
- Installs Google Chrome
- Sets up Python virtualenvwrapper with isolated environments
- Installs additional tools: chaosreader, pcodedmp, sleuthkit, testdisk
- Deploys REMnux aliases to `~/.remnux_aliases`
- Applies GNOME preferences (dark theme, 24h clock, dock config)
- Runs `make dotfiles`

### `make install-dfir`

Runs `install-sift` then adds REMnux as an addon (`remnux install --mode=addon`). This is the only supported way to run both on the same VM.

## Update

```bash
make update-sift     # git pull + update SIFT
make update-remnux   # git pull + update REMnux
make update-dfir     # git pull + update SIFT
```

## Dotfiles

```bash
make dotfiles
```

Copies `common/files/.bashrc`, `.vimrc`, and `.bash_aliases` to `~/`.

## Lint

```bash
make test   # shellcheck on all scripts → checkstyle.out
```

---

## Thanks to

- [reuteras/remnux-tools](https://github.com/reuteras/remnux-tools) – Most of the work in this repository is based on this project. I have adapted and customized it extensively to suit my workflow, preferences, and additional tools.
