# Lab 0 · Set up your environment

**Goal:** a working open-source chip-design environment on your laptop, and your first pull request.
**Time:** about 1 hour, most of it downloads.
**Hand in:** one pull request that adds you to [`members.md`](members.md), with the output of
`./scripts/lab0_check.sh` in the description.

Everything in this lab runs on Windows 11 (or 10) through WSL2 with Ubuntu 24.04. If you use
Linux natively, read the Native Linux note at the end, then skip §1. If you use a Mac, read
the note at the end before you start.

```text
Windows
 └─ WSL2: Ubuntu 24.04              ← you work here, in a terminal
     ├─ apt tools                   Verilator, RISC-V GCC, GTKWave, git, gh
     ├─ Docker Engine               runs the LibreLane image (Yosys, OpenROAD, KLayout, Magic, Netgen)
     ├─ ~/.venv/librelane           LibreLane 3.0.16
     ├─ ~/.ciel/ihp-sg13g2          IHP SG13G2 open PDK (pinned revision)
     └─ ~/project/torv              this repository
```

| Item | Version |
|------|---------|
| Ubuntu (WSL2) | 24.04 |
| LibreLane | 3.0.16, Docker image `ghcr.io/librelane/librelane:3.0.16` |
| IHP SG13G2 PDK | `c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c` |
| Verilator / RISC-V GCC | Ubuntu 24.04 packages (5.020 / 13.2) |

## 0. Before you start

| | Minimum | Recommended |
|---|---|---|
| RAM | 16 GB | 32 GB |
| CPU | 4 cores | 8 cores |
| Free disk (SSD) | 50 GB | 100 GB |
| Windows | 10 21H2 or 11, virtualization enabled in the BIOS | Windows 11 |

The Docker image is about 7.5 GB once unpacked, the PDK about 1 GB, and each full RTL-to-GDS
run of TORV about 1.3 GB.

## 1. Windows: install WSL2 and Ubuntu

1. Open **PowerShell as administrator** and run:

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

   Restart Windows if it asks. Ubuntu then opens and asks for a **Linux username and password**.
   Pick a short lowercase username and remember the password: `sudo` asks for it.

2. Give WSL enough memory. In Windows, create the file `C:\Users\<you>\.wslconfig` with
   Notepad (keep the leading dot, no `.txt` at the end):

   ```ini
   [wsl2]
   memory=10GB      # 16 GB laptop: 10GB · 32 GB laptop: 24GB
   processors=4     # number of CPU cores to give WSL, at most what you have
   swap=8GB
   ```

3. Apply it. In PowerShell:

   ```powershell
   wsl --shutdown
   ```

   Open **Ubuntu** again from the Start menu and check:

   ```bash
   free -g     # "total" close to the memory you set
   nproc       # the processors you set
   ```

From here on, every command runs in the **Ubuntu terminal**, not in PowerShell.

## 2. Ubuntu: system packages

```bash
sudo apt-get update
sudo apt-get install -y build-essential git make curl ca-certificates \
    python3-venv python3-pip \
    verilator gcc-riscv64-unknown-elf gtkwave gh
```

Verilator, the RISC-V compiler and GTKWave are for simulation (Lab 1). `gh` is the GitHub
command-line tool.

## 3. Docker Engine

Install Docker Engine inside Ubuntu (not Docker Desktop):

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
sudo usermod -aG docker "$USER"
```

Restart WSL so the group change takes effect. In **PowerShell**: `wsl --shutdown`, then open
Ubuntu again and check:

```bash
docker run --rm hello-world        # prints "Hello from Docker!"
```

If Docker does not start, run `cat /etc/wsl.conf`. It must contain `[boot]` and
`systemd=true`; add them if missing, then `wsl --shutdown` again.

## 4. LibreLane and the IHP PDK

```bash
python3 -m venv ~/.venv/librelane
~/.venv/librelane/bin/pip install librelane==3.0.16

# PDK revision pinned by LibreLane 3.0.16
~/.venv/librelane/bin/ciel enable --pdk-family ihp-sg13g2 c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c
```

Run the LibreLane smoke test. The first time it downloads the Docker image (7.5 GB unpacked,
a few minutes), then takes a small design through the whole flow on IHP SG13G2 (about 3 minutes):

```bash
~/.venv/librelane/bin/python -m librelane --dockerized --pdk ihp-sg13g2 --smoke-test
```

It must end with three `Passed ✅` lines (DRC, LVS, antenna) and `Smoke test passed.`

## 5. GitHub and TORV

1. **GitHub account.** Turn on two-factor authentication (Settings → Password and
   authentication). Send your username to the ASIC TF lead on Telegram and accept the
   `semitov` invitation (you get it by email and at <https://github.com/semitov>).

2. **Git identity and login** (use the e-mail of your GitHub account):

   ```bash
   git config --global user.name  "Your Name"
   git config --global user.email "you@example.com"
   gh auth login        # GitHub.com → HTTPS → Yes (authenticate Git) → Login with a web browser
   ```

   `gh` prints a one-time code. Open the link it shows in your Windows browser and enter the code.

3. **Clone TORV inside your Linux home** (never under `/mnt/c`: it is slow, and the LibreLane
   container only sees `$HOME`):

   ```bash
   mkdir -p ~/project && cd ~/project
   git clone https://github.com/semitov/torv.git
   cd torv
   ./scripts/fetch_ip.sh          # third-party IP into ip/third_party/
   source scripts/env.sh          # every line it prints should end in "ok" or a path
   ```

4. **First simulation and LibreLane check:**

   ```bash
   ./scripts/run_case.sh tests/core/asm/smoke.S     # prints "TORV SoC test passed: smoke"
   make -C librelane check-env                      # no error message means OK
   ```

## 6. Check your setup

```bash
./scripts/lab0_check.sh
```

Every line must say `OK`. Fix anything that says `FAIL` (the line tells you what to do), then
run it again. Keep the output: it goes into your pull request.

## 7. Your first pull request

1. Create a branch, named after you:

   ```bash
   cd ~/project/torv
   git switch -c docs/add-<your-github-username>
   ```

2. Open `docs/labs/members.md` and add **one row** for yourself at the end of the table.
   You can edit it from Windows with VS Code (`code .` in the Ubuntu terminal, with the WSL
   extension) or with `nano docs/labs/members.md`.

3. Commit and push:

   ```bash
   git add docs/labs/members.md
   git commit -m "docs(labs): add <your name> to members"
   git push -u origin HEAD
   ```

   If `git push` says *permission denied*, you have not accepted the `semitov` invitation yet.

4. Open the pull request:

   ```bash
   gh pr create --fill
   ```

   Then open the link it prints, and paste the output of `./scripts/lab0_check.sh` into the
   description under *How it was tested*.

5. Wait for the two CI checks (`lint`, `regress`) to turn green and for a review. Answer the
   review comments if there are any. A maintainer merges it.

You are done with Lab 0 when your pull request is merged.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `wsl --install` fails, or "virtualization is not enabled" | Enable Intel VT-x / AMD-V (SVM) in the BIOS, then retry |
| `free -g` still shows the old memory | `.wslconfig` is in the wrong folder or saved as `.wslconfig.txt`; then `wsl --shutdown` |
| `permission denied … /var/run/docker.sock` | You are not in the `docker` group yet: `sudo usermod -aG docker $USER`, then `wsl --shutdown` |
| `Cannot connect to the Docker daemon` | `sudo systemctl start docker`; if `systemctl` itself fails, enable systemd in `/etc/wsl.conf` (§3) |
| `cannot attach stdin to a TTY-enabled container` | You ran LibreLane from a script or without a terminal. Add `--docker-no-tty` before `--dockerized` |
| `ciel: command not found` | Use the full path `~/.venv/librelane/bin/ciel` |
| `IHP SRAM models: MISSING` from `env.sh` | The PDK step in §4 did not finish; run the `ciel enable` line again |
| LibreLane cannot find files | The repository is outside `$HOME`; move it to `~/project/torv` |
| The smoke test or a run stops halfway | WSL ran out of memory or was shut down; raise `memory` in `.wslconfig`, close other programs, rerun |
| Anything else | Post the command and the full error in the ASIC Task Force Telegram topic. Don't stay stuck for more than 30 minutes |

## Mac users

This guide is not tested on macOS yet. LibreLane's Docker image runs on Apple silicon through
Docker Desktop, and the apt packages have Homebrew equivalents, but paths and versions differ.
Tell the ASIC TF lead before you start, and we go through it together.

## Native Linux

Skip §1. The rest works as written, except for four things that depend on your distro:

1. **Packages (§2, §3).** Use your own package manager. Package names can differ from the
   Ubuntu ones.
2. **RISC-V GCC (§2).** `lab0_check.sh` looks for the command `riscv64-unknown-elf-gcc`. If
   your distro has no package with that name, use a prebuilt bare-metal toolchain and put its
   `bin/` on your `PATH`.
3. **Python (§4).** LibreLane's dependencies may fail to build on a very new system Python.
   Keep the system Python and create the LibreLane venv with an older one, for example 3.12.
4. **SELinux (§3, §4).** On distros that run SELinux (Fedora, RHEL family), the LibreLane
   container cannot read your `$HOME`. See the Fedora notes below.

### Fedora (tested on Fedora 45)

**Packages.** Instead of §2 and the Docker repository in §3:

```bash
sudo dnf install -y git make gcc curl ca-certificates python3.12 python3-pip \
    verilator gtkwave gh moby-engine docker-cli
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"      # then log out and back in
```

**RISC-V GCC.** Fedora only packages the Linux cross compiler (`gcc-riscv64-linux-gnu`),
not the bare-metal one. Download the prebuilt `riscv64-elf-ubuntu-24.04-gcc` archive from
<https://github.com/riscv-collab/riscv-gnu-toolchain/releases> and extract it so that
`~/project/riscv_toolchain/bin/riscv64-unknown-elf-gcc` exists. `scripts/env.sh` finds it
there; for `lab0_check.sh`, also add it to your `PATH`:

```bash
echo 'export PATH="$HOME/project/riscv_toolchain/bin:$PATH"' >> ~/.bashrc
```

**Python.** Fedora 45 ships Python 3.15, and some LibreLane dependencies do not build on it.
The system Python can stay; create the venv with 3.12 and run the rest of §4 as written:

```bash
python3.12 -m venv ~/.venv/librelane
```

**SELinux.** LibreLane mounts your whole `$HOME` into the container, and SELinux blocks the
container from reading it. Do not turn SELinux off. Instead, start only the Docker daemon
without `--selinux-enabled`, with a systemd drop-in (a small file that overrides part of a
service without editing the packaged one). Create
`/etc/systemd/system/docker.service.d/no-selinux.conf` (`sudo systemctl edit docker` also
works):

```ini
# LibreLane mounts all of $HOME; SELinux labels block that. Remove this file to restore.
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd \
    -H fd:// \
    --containerd=/run/containerd/containerd.sock \
    --userland-proxy-path /usr/bin/docker-proxy \
    --init-path /usr/bin/tini-static
```

The empty `ExecStart=` clears the packaged command; the second line is Fedora's own command
without `--selinux-enabled` (compare with `systemctl cat docker`). Apply it:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

SELinux stays enforcing for the rest of the system; only Docker containers lose SELinux
confinement. To undo it, delete the file and run the two commands again.
