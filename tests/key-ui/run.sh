#!/usr/bin/env sh
# Runs the key UI against a fake Roblox environment.
#
#   sh tests/key-ui/run.sh
#
# Needs `luau` on PATH (or LUAU=/path/to/luau). Each case is the shim, an
# optional per-case setup, the UI itself, and the case's assertions
# concatenated into one chunk — the UI is executed unmodified.
set -e

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UI="$DIR/../../voidhub-key-ui.luau"
LUAU=${LUAU:-luau}

if ! command -v "$LUAU" >/dev/null 2>&1; then
	echo "luau not found; set LUAU=/path/to/luau" >&2
	exit 127
fi

status=0
for case_dir in "$DIR"/cases/*/; do
	name=$(basename "$case_dir")
	chunk=$(mktemp)
	cat "$DIR/shim.luau" >"$chunk"
	if [ -f "$case_dir/setup.luau" ]; then
		cat "$case_dir/setup.luau" >>"$chunk"
	fi
	cat "$UI" "$DIR/bridge.luau" "$case_dir/check.luau" >>"$chunk"

	printf '\n=== %s ===\n' "$name"
	if ! "$LUAU" "$chunk"; then
		status=1
	fi
	rm -f "$chunk"
done

exit $status
