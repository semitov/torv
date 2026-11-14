#!/usr/bin/env bash
# Lab 0 environment check (docs/labs/lab0_setup.md).
# Usage, from the repository root:  ./scripts/lab0_check.sh
# Prints one OK / WARN / FAIL line per item; exits 1 if any item FAILs.

set -u
TORV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBRELANE_VENV="${LIBRELANE_VENV:-$HOME/.venv/librelane}"
PDK_ROOT="${PDK_ROOT:-$HOME/.ciel}"
LL_VERSION="3.0.16"
LL_IMAGE="ghcr.io/librelane/librelane:${LL_VERSION}"
PDK_HASH="c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c"

fails=0; warns=0
ok()   { printf '  OK    %-18s %s\n' "$1" "$2"; }
warn() { printf '  WARN  %-18s %s\n' "$1" "$2"; warns=$((warns+1)); }
fail() { printf '  FAIL  %-18s %s\n' "$1" "$2"; fails=$((fails+1)); }

echo "TORV Lab 0 check  ($(date '+%Y-%m-%d %H:%M'))"

# --- machine ---------------------------------------------------------------
os="$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
if grep -qi microsoft /proc/version 2>/dev/null; then os="$os (WSL2)"; fi
ok "system" "${os:-unknown}"

cores=$(nproc)
mem_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
if (( cores >= 4 )); then ok "cpu cores" "$cores"; else warn "cpu cores" "$cores (4 or more recommended; raise processors in .wslconfig)"; fi
if (( mem_gb >= 7 )); then ok "memory" "${mem_gb} GB"; else fail "memory" "${mem_gb} GB (need 8 GB or more; raise memory in .wslconfig, then wsl --shutdown)"; fi

# Under WSL the Linux disk is a growing virtual disk on C:, so the real limit is C:'s free space.
disk_path="$HOME"; disk_label="\$HOME"
if [[ -d /mnt/c ]] && grep -qi microsoft /proc/version 2>/dev/null; then disk_path=/mnt/c; disk_label="Windows C:"; fi
free_gb=$(df -BG --output=avail "$disk_path" | tail -1 | tr -dc '0-9')
if (( free_gb >= 30 )); then ok "free disk" "${free_gb} GB on $disk_label"; else warn "free disk" "${free_gb} GB on $disk_label (30 GB or more recommended)"; fi

case "$TORV_ROOT" in
  /mnt/*) fail "repo location" "$TORV_ROOT is on the Windows drive; clone it under ~/project instead" ;;
  "$HOME"/*) ok "repo location" "$TORV_ROOT" ;;
  *) fail "repo location" "$TORV_ROOT is outside \$HOME; LibreLane's container cannot see it" ;;
esac

# --- git / GitHub ----------------------------------------------------------
gname=$(git config --global user.name || true); gmail=$(git config --global user.email || true)
if [[ -n "$gname" && -n "$gmail" ]]; then ok "git identity" "$gname <$gmail>"; else fail "git identity" "set git config --global user.name / user.email"; fi
if command -v gh >/dev/null 2>&1; then
  if gh_user=$(gh api user --jq .login 2>/dev/null); then ok "github login" "@$gh_user"; else fail "github login" "run: gh auth login"; fi
else
  fail "github login" "gh not installed (sudo apt-get install gh)"
fi

# --- simulation tools ------------------------------------------------------
if command -v verilator >/dev/null 2>&1; then
  vv=$(verilator --version | awk '{print $2}')
  if [[ "${vv%%.*}" -ge 5 ]]; then ok "verilator" "$vv"; else fail "verilator" "$vv (need 5.0 or newer)"; fi
else fail "verilator" "not installed (sudo apt-get install verilator)"; fi
if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
  ok "riscv gcc" "$(riscv64-unknown-elf-gcc -dumpversion)"
else fail "riscv gcc" "not installed (sudo apt-get install gcc-riscv64-unknown-elf)"; fi
if command -v gtkwave >/dev/null 2>&1; then ok "gtkwave" "installed"; else warn "gtkwave" "not installed (only needed to view waveforms)"; fi
if [[ -d "$TORV_ROOT/ip/third_party" ]] && [[ -n "$(ls -A "$TORV_ROOT/ip/third_party" 2>/dev/null)" ]]; then
  ok "third-party IP" "ip/third_party/"
else fail "third-party IP" "run: ./scripts/fetch_ip.sh"; fi

# --- Docker / LibreLane / PDK ----------------------------------------------
if docker info >/dev/null 2>&1; then
  ok "docker" "$(docker version --format '{{.Server.Version}}' 2>/dev/null)"
  if docker image inspect "$LL_IMAGE" >/dev/null 2>&1; then ok "librelane image" "$LL_IMAGE"
  else fail "librelane image" "missing; run the LibreLane smoke test (lab0_setup.md §4)"; fi
else
  fail "docker" "not usable by $USER (docker group? daemon running?)"
  fail "librelane image" "cannot check without docker"
fi
if [[ -x "$LIBRELANE_VENV/bin/python" ]]; then
  llv=$("$LIBRELANE_VENV/bin/python" -m pip show librelane 2>/dev/null | awk '/^Version:/{print $2}')
  if [[ "$llv" == "$LL_VERSION" ]]; then ok "librelane" "$llv ($LIBRELANE_VENV)"
  else fail "librelane" "found '${llv:-none}', need $LL_VERSION: $LIBRELANE_VENV/bin/pip install librelane==$LL_VERSION"; fi
else fail "librelane" "no venv at $LIBRELANE_VENV (lab0_setup.md §4)"; fi
if ls "$PDK_ROOT"/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_*.v >/dev/null 2>&1; then
  cur=$(readlink -f "$PDK_ROOT/ihp-sg13g2" 2>/dev/null)
  if [[ "$cur" == *"$PDK_HASH"* ]] || grep -qs "$PDK_HASH" "$PDK_ROOT/ihp-sg13g2/SOURCES"; then
    ok "ihp-sg13g2 pdk" "${PDK_HASH:0:7} in $PDK_ROOT"
  else warn "ihp-sg13g2 pdk" "present, but not revision ${PDK_HASH:0:7} (run the ciel enable line again)"; fi
else fail "ihp-sg13g2 pdk" "missing under $PDK_ROOT (ciel enable … lab0_setup.md §4)"; fi

echo
if (( fails == 0 )); then
  echo "Result: PASS ($warns warning(s)). Paste this output into your Lab 0 pull request."
  exit 0
else
  echo "Result: FAIL ($fails item(s)). Fix the FAIL lines and run again."
  exit 1
fi
