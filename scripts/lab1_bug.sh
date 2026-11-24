#!/usr/bin/env bash
# Lab 1 bug hunt (docs/labs/lab1_sim.md): put one known bug into rtl/, then find it with the
# regression, the PC trace and the waveform. The bugs are encoded so the answer is not visible
# at a glance; please don't decode them.
#
#   ./scripts/lab1_bug.sh list        bugs and hints
#   ./scripts/lab1_bug.sh apply N     put bug N into rtl/ (rtl/ must be clean)
#   ./scripts/lab1_bug.sh status      which bug is in rtl/ now, if any
#   ./scripts/lab1_bug.sh reset       restore rtl/ to the committed version
set -euo pipefail
TORV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TORV_ROOT"

declare -a BUG_DATA BUG_HINT
BUG_DATA[1]="W1sicnRsL3RvcnZfZm9yd2FyZGluZ191bml0LnN2IiwgIihleF9tZW1fcmQgPT0gaWRfZXhfcnMyKSlcbiAgICAgIGZvcndhcmRfYiA9IDInYjEwOyIsICIoZXhfbWVtX3JkID09IGlkX2V4X3JzMSkpXG4gICAgICBmb3J3YXJkX2IgPSAyJ2IxMDsiXV0="
BUG_HINT[1]="(warm-up) Almost everything fails, and not even with FAIL. Start with the smallest test."
BUG_DATA[2]="W1sicnRsL3RvcnZfaGF6YXJkX3VuaXQuc3YiLCAiT1BfUkVHLCBPUF9TVE9SRSwgT1BfQlI6IHVzZXNfcnMyIiwgIk9QX1JFRywgT1BfQlI6IHVzZXNfcnMyIl1d"
BUG_HINT[2]="A value read from memory is not always the value that gets stored next."
BUG_DATA[3]="W1sicnRsL3RvcnZfY29yZS5zdiIsICJlbmQgZWxzZSBpZiAoZmx1c2ggJiYgIXN0YWxsX2lkX2V4KSBiZWdpbiIsICJlbmQgZWxzZSBpZiAoZmx1c2ggJiYgaWRfZXhfanVtcCAmJiAhc3RhbGxfaWRfZXgpIGJlZ2luIl0sIFsicnRsL3RvcnZfY29yZS5zdiIsICJpZiAoKGZsdXNoIHx8IGJ1YmJsZV9pZF9leCkgJiYgIXN0YWxsX2lkX2V4KSBiZWdpbiIsICJpZiAoKChmbHVzaCAmJiBpZF9leF9qdW1wKSB8fCBidWJibGVfaWRfZXgpICYmICFzdGFsbF9pZF9leCkgYmVnaW4iXV0="
BUG_HINT[3]="After some taken control-flow instructions, the program does more than it should."
BUG_DATA[4]="W1sicnRsL3RvcnZfZm9yd2FyZGluZ191bml0LnN2IiwgImVsc2UgaWYgKG1lbV93Yl9yZWd3cml0ZSAmJiAobWVtX3diX3JkICE9IDUnZDApICYmIChtZW1fd2JfcmQgPT0gaWRfZXhfcnMyKSkiLCAiZWxzZSBpZiAobWVtX3diX3JlZ3dyaXRlICYmIChtZW1fd2JfcmQgPT0gaWRfZXhfcnMyKSkiXV0="
BUG_HINT[4]="(bonus) One register is special. Is it special everywhere?"
NBUGS=${#BUG_DATA[@]}

die() { echo "lab1_bug: $*" >&2; exit 1; }

# edit DATA MODE   (MODE=apply makes the edits; MODE=check exits 0 if they are all present)
edit() {
  python3 - "$@" <<'EOF'
import base64, json, sys
edits, mode = json.loads(base64.b64decode(sys.argv[1])), sys.argv[2]
text = {f: open(f).read() for f, _, _ in edits}
if mode == "check":
    sys.exit(0 if all(new in text[f] for f, _, new in edits) else 1)
for f, old, new in edits:
    if text[f].count(old) != 1:
        sys.exit(f"lab1_bug: {f} does not match this version of the script; git pull and retry")
    text[f] = text[f].replace(old, new)
for f, s in text.items():
    open(f, "w").write(s)
EOF
}

case "${1:-}" in
  list)
    for i in $(seq 1 "$NBUGS"); do printf '  %d  %s\n' "$i" "${BUG_HINT[$i]}"; done ;;
  apply)
    n="${2:-}"
    [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= NBUGS )) || die "usage: $0 apply 1..$NBUGS"
    git diff --quiet -- rtl || die "rtl/ has changes; run '$0 reset' first"
    edit "${BUG_DATA[$n]}" apply
    echo "Bug $n is in rtl/. Hint: ${BUG_HINT[$n]}"
    echo "Now run ./scripts/regress.sh. Restore with: $0 reset" ;;
  status)
    found=0
    for i in $(seq 1 "$NBUGS"); do
      if edit "${BUG_DATA[$i]}" check; then echo "bug $i is applied"; found=1; fi
    done
    if (( !found )); then
      if git diff --quiet -- rtl; then echo "rtl/ is clean"; else echo "rtl/ has other changes:"; git diff --stat -- rtl; fi
    fi ;;
  reset)
    git checkout -- rtl
    echo "rtl/ restored" ;;
  *)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
