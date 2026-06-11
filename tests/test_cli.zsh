# tests/test_cli.zsh — lcars10k CLI dispatch.

# Build a throwaway _LCARS_ROOT with a stub uninstall.sh.
_cli_tmp="$(mktemp -d)"
mkdir -p "$_cli_tmp/scripts"
cat > "$_cli_tmp/scripts/uninstall.sh" <<'STUB'
#!/usr/bin/env bash
echo "STUB-UNINSTALL args=$*"
STUB
chmod +x "$_cli_tmp/scripts/uninstall.sh"

_LCARS_ROOT="$_cli_tmp"
source "${0:A:h}/../lib/lcars-cli.zsh"

# uninstall dispatches to scripts/uninstall.sh and forwards args
out="$(lcars10k uninstall --dry-run 2>&1)"
lcars_assert_eq "STUB-UNINSTALL args=--dry-run" "$out" "uninstall dispatches and forwards --dry-run"

# unknown subcommand still errors
lcars10k bogus-cmd >/dev/null 2>&1
lcars_assert_eq "2" "$?" "unknown subcommand returns exit 2"

# help lists the uninstall command
help_out="$(lcars10k help 2>&1)"
lcars_assert_match "*uninstall*" "$help_out" "help text mentions uninstall"

rm -rf "$_cli_tmp"
unset _cli_tmp _LCARS_ROOT
