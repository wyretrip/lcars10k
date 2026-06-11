# lib/lcars-cli.zsh — `lcars10k` command dispatcher.
#
# Provides the user-facing `lcars10k` command. Subcommands cover the
# common LCARS workflow (setup, reload, sound toggles, red-alert) and
# print LCARS-branded help. p10k internals stay internal — users
# never see them.

_lcars10k_help() {
    cat <<EOF
lcars10k — Star Trek LCARS-themed Zsh prompt

USAGE
  lcars10k <command> [options]

COMMANDS
  setup            Run the lcars10k installer (wires .zshrc, configs,
                   fonts, sounds, terminal profile). Pass --help to
                   the installer for its own options.
  uninstall        Reverse the installer (unwire .zshrc, remove configs,
                   LCARS fonts, terminal profile). Pass --help / --dry-run
                   / --yes to the uninstaller.
  reload           Reload the prompt config (run after editing
                   config/p10k.zsh or ~/.lcars10krc).
  quiet            Silence sound effects for this session.
  loud             Re-enable sound effects for this session.
  redalert on      Force the red-alert palette on.
  redalert off     Stand down. Restore the normal palette.
  redalert auto    Toggle auto-engage on 3 consecutive failures.
  version          Print version info.
  help             Show this message.

PERSISTENT CONFIG
  ~/.lcars10krc                  Env-var-level options (sounds, thresholds).
  \$LCARS_HOME/config/p10k.zsh    Prompt structure, palette, segments.
EOF
}

_lcars10k_version() {
    print "lcars10k — Star Trek LCARS Zsh prompt (hard fork of powerlevel10k)"
    print "  repo:  ${_LCARS_ROOT:-unknown}"
    print "  fork:  https://github.com/wyretrip/lcars10k"
}

lcars10k() {
    local cmd="${1:-help}"
    [[ $# -gt 0 ]] && shift
    case "$cmd" in
        setup)
            local installer="${_LCARS_ROOT:-$HOME/.lcars10k}/scripts/setup.sh"
            if [[ ! -x "$installer" ]]; then
                print -u2 "lcars10k: installer not found or not executable: $installer"
                return 2
            fi
            "$installer" "$@"
            ;;
        uninstall)
            local uninstaller="${_LCARS_ROOT:-$HOME/.lcars10k}/scripts/uninstall.sh"
            if [[ ! -x "$uninstaller" ]]; then
                print -u2 "lcars10k: uninstaller not found or not executable: $uninstaller"
                return 2
            fi
            "$uninstaller" "$@"
            ;;
        reload)
            # p10k is the engine — invoke it directly but don't expose it
            # in user-facing names.
            p10k reload
            ;;
        quiet)
            lcars-quiet
            ;;
        loud)
            lcars-loud
            ;;
        redalert)
            lcars-redalert "$@"
            ;;
        version|--version|-v)
            _lcars10k_version
            ;;
        help|--help|-h|"")
            _lcars10k_help
            ;;
        *)
            print -u2 "lcars10k: unknown command: $cmd"
            print -u2 ""
            _lcars10k_help >&2
            return 2
            ;;
    esac
}
