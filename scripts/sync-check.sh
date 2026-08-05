#!/usr/bin/env bash
#
# sync-check.sh — report drift between this tap's qemu-spice formula and the
# homebrew-core qemu formula it is derived from.
#
# This tap exists for exactly one reason: homebrew-core will not ship QEMU with
# SPICE enabled (Homebrew/homebrew-core#226935 was merged then reverted by
# #227722, "Too many dependencies"). Everything else in our formula should track
# core. This script tells you when core has moved.
#
# Written for bash 3.2 (the version macOS ships) — no mapfile, no associative
# arrays.
#
# Exit codes: 0 = in sync, 1 = drift detected, 2 = could not check.

set -eo pipefail

CORE_URL="https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/q/qemu.rb"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OURS="${REPO_ROOT}/Formula/qemu-spice.rb"

if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""
fi

# Dependencies and configure args we add on purpose. Drift in these is expected
# and is not reported. Keep in sync with the "SPICE divergence" blocks.
INTENTIONAL_DEPS="spice-server usbredir"
INTENTIONAL_ARGS="--enable-spice --enable-usb-redir --target-list"

drift=0

die() { printf '%serror:%s %s\n' "$RED" "$NC" "$*" >&2; exit 2; }

command -v curl >/dev/null || die "curl not found"
[ -f "$OURS" ] || die "formula not found: $OURS"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
core="$workdir/core-qemu.rb"

curl -fsSL "$CORE_URL" -o "$core" || die "could not fetch core qemu formula from $CORE_URL"
[ -s "$core" ] || die "core formula came back empty"

field() { # field <file> <name>
  sed -n "s/^  $2 \"\([^\"]*\)\".*/\1/p" "$1" | head -1
}

printf '%s=== qemu-spice vs homebrew-core qemu ===%s\n' "$BLUE" "$NC"

# --- version -----------------------------------------------------------------
core_url="$(field "$core" url)"
our_url="$(field "$OURS" url)"
core_ver="$(printf '%s' "$core_url" | sed -n 's/.*qemu-\(.*\)\.tar\.xz/\1/p')"
our_ver="$(printf '%s' "$our_url"  | sed -n 's/.*qemu-\(.*\)\.tar\.xz/\1/p')"

if [ -n "$core_ver" ] && [ "$core_ver" = "$our_ver" ]; then
  printf '  %s✓%s version   %s (in sync)\n' "$GREEN" "$NC" "$our_ver"
else
  printf '  %s✗%s version   ours=%s core=%s\n' "$RED" "$NC" "${our_ver:-?}" "${core_ver:-?}"
  printf '      update url + sha256 in Formula/qemu-spice.rb:\n'
  printf '        url    "%s"\n' "$core_url"
  printf '        sha256 "%s"\n' "$(field "$core" sha256)"
  drift=1
fi

# --- sha256 (only meaningful when versions match) ----------------------------
if [ "$core_ver" = "$our_ver" ]; then
  if [ "$(field "$core" sha256)" = "$(field "$OURS" sha256)" ]; then
    printf '  %s✓%s sha256    matches\n' "$GREEN" "$NC"
  else
    printf '  %s✗%s sha256    MISMATCH at the same version — investigate\n' "$RED" "$NC"
    drift=1
  fi
fi

# is "$1" one of the space-separated tokens in "$2", as a "quoted" or prefix match?
is_intentional_dep() {
  for d in $2; do
    case "$1" in *"\"$d\""*) return 0 ;; esac
  done
  return 1
}
is_intentional_arg() {
  for a in $2; do
    case "$1" in "$a"*) return 0 ;; esac
  done
  return 1
}

# --- dependencies ------------------------------------------------------------
extract_deps() {
  grep -E '^[[:space:]]+(depends_on|uses_from_macos) ' "$1" \
    | sed 's/#.*//' | sed 's/[[:space:]]*$//' | sort
}
extract_deps "$core" > "$workdir/deps.core"
extract_deps "$OURS" > "$workdir/deps.ours"

comm -23 "$workdir/deps.core" "$workdir/deps.ours" > "$workdir/deps.onlycore"
comm -13 "$workdir/deps.core" "$workdir/deps.ours" > "$workdir/deps.onlyours.raw"

: > "$workdir/deps.onlyours"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  is_intentional_dep "$line" "$INTENTIONAL_DEPS" || printf '%s\n' "$line" >> "$workdir/deps.onlyours"
done < "$workdir/deps.onlyours.raw"

if [ ! -s "$workdir/deps.onlycore" ] && [ ! -s "$workdir/deps.onlyours" ]; then
  printf '  %s✓%s deps      in sync (plus %s)\n' "$GREEN" "$NC" "$INTENTIONAL_DEPS"
else
  printf '  %s✗%s deps      drift\n' "$RED" "$NC"
  while IFS= read -r l; do [ -n "$l" ] && printf '      %score only:%s %s\n' "$YELLOW" "$NC" "$l"; done < "$workdir/deps.onlycore"
  while IFS= read -r l; do [ -n "$l" ] && printf '      %sours only:%s %s\n' "$YELLOW" "$NC" "$l"; done < "$workdir/deps.onlyours"
  drift=1
fi

# --- configure args ----------------------------------------------------------
extract_args() {
  sed -n '/args = %W\[/,/^[[:space:]]*\]/p' "$1" \
    | grep -oE '\-\-[a-z0-9][a-z0-9=#{}/_.-]*' | sed 's/=.*//' | sort -u
}
extract_args "$core" > "$workdir/args.core"
extract_args "$OURS" > "$workdir/args.ours"

comm -23 "$workdir/args.core" "$workdir/args.ours" > "$workdir/args.onlycore"
comm -13 "$workdir/args.core" "$workdir/args.ours" > "$workdir/args.onlyours.raw"

: > "$workdir/args.onlyours"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  is_intentional_arg "$line" "$INTENTIONAL_ARGS" || printf '%s\n' "$line" >> "$workdir/args.onlyours"
done < "$workdir/args.onlyours.raw"

if [ ! -s "$workdir/args.onlycore" ] && [ ! -s "$workdir/args.onlyours" ]; then
  printf '  %s✓%s args      in sync\n' "$GREEN" "$NC"
else
  printf '  %s✗%s args      drift\n' "$RED" "$NC"
  while IFS= read -r l; do [ -n "$l" ] && printf '      %score only:%s %s\n' "$YELLOW" "$NC" "$l"; done < "$workdir/args.onlycore"
  while IFS= read -r l; do [ -n "$l" ] && printf '      %sours only:%s %s\n' "$YELLOW" "$NC" "$l"; done < "$workdir/args.onlyours"
  drift=1
fi

# --- upstream sanity: is SPICE still absent from core? -----------------------
if grep -q 'depends_on "spice-server"' "$core"; then
  printf '\n  %s!!%s homebrew-core qemu now depends on spice-server.\n' "$GREEN" "$NC"
  printf '      This tap may no longer be necessary — verify with:\n'
  printf '        brew install qemu && qemu-system-aarch64 -spice help\n'
  printf '      If that works, deprecate this tap and use core qemu.\n'
  drift=1
fi

printf '\n'
if [ "$drift" -ne 0 ]; then
  printf '%sDrift detected. Update Formula/qemu-spice.rb to match core, keeping the SPICE divergence blocks.%s\n' "$YELLOW" "$NC"
  exit 1
fi
printf '%sNo drift. Formula tracks homebrew-core.%s\n' "$GREEN" "$NC"
exit 0
