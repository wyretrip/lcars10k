# vim:ft=zsh ts=2 sw=2 sts=2 et fenc=utf-8
################################################################
# lcars10k — LCARS-themed Zsh prompt, hard-fork of powerlevel10k.
#
# License: MIT (powerlevel10k base) + LCARS-specific code MIT.
# Upstream (fork base): https://github.com/romkatv/powerlevel10k
# This fork: https://github.com/wyretrip/lcars10k
################################################################

# Temporarily change options.
'builtin' 'local' '-a' '__p9k_src_opts'
[[ ! -o 'aliases'         ]] || __p9k_src_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || __p9k_src_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || __p9k_src_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

(( $+__p9k_root_dir )) || typeset -gr __p9k_root_dir=${POWERLEVEL9K_INSTALLATION_DIR:-${${(%):-%x}:A:h}}
(( $+__p9k_intro )) || {
  # Leading spaces before `local` are important. Otherwise Antigen will remove `local` (!!!).
  # __p9k_trapint is to work around bugs in zsh: https://www.zsh.org/mla/workers/2020/msg00612.html.
  # Likewise for `trap ":"` instead of the plain `trap ""`.
  typeset -gr __p9k_intro_base='emulate -L zsh -o no_hist_expand -o extended_glob -o no_prompt_bang -o prompt_percent -o no_prompt_subst -o no_aliases -o no_bg_nice -o typeset_silent -o no_rematch_pcre
  (( $+__p9k_trapped )) || { local -i __p9k_trapped; trap : INT; trap "trap ${(q)__p9k_trapint:--} INT" EXIT }
  local -a match mbegin mend
  local -i MBEGIN MEND OPTIND
  local MATCH OPTARG IFS=$'\'' \t\n\0'\'
  typeset -gr __p9k_intro_locale='[[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]] && _p9k_init_locale && { [[ -n $LC_ALL ]] && local LC_ALL=$__p9k_locale || local LC_CTYPE=$__p9k_locale }'
  typeset -gr __p9k_intro_no_locale="${${__p9k_intro_base/ match / match reply }/ MATCH / MATCH REPLY }"
  typeset -gr __p9k_intro_no_reply="$__p9k_intro_base; $__p9k_intro_locale"
  typeset -gr __p9k_intro="$__p9k_intro_no_locale; $__p9k_intro_locale"
}

zmodload zsh/langinfo

function _p9k_init_locale() {
  if (( ! $+__p9k_locale )); then
    typeset -g __p9k_locale=
    (( $+commands[locale] )) || return
    local -a loc
    loc=(${(@M)$(locale -a 2>/dev/null):#*.(utf|UTF)(-|)8}) || return
    (( $#loc )) || return
    typeset -g __p9k_locale=${loc[(r)(#i)C.UTF(-|)8]:-${loc[(r)(#i)en_US.UTF(-|)8]:-$loc[1]}}
  fi
  [[ -n $__p9k_locale ]]
}

() {
  eval "$__p9k_intro"
  if (( $+__p9k_sourced )); then
    (( $+functions[_p9k_setup] )) && _p9k_setup
    return 0
  fi
  typeset -gr __p9k_dump_file=${XDG_CACHE_HOME:-~/.cache}/p10k-dump-${(%):-%n}.zsh
  if [[ $__p9k_dump_file != $__p9k_instant_prompt_dump_file ]] && (( ! $+functions[_p9k_preinit] )) && source $__p9k_dump_file 2>/dev/null && (( $+functions[_p9k_preinit] )); then
    _p9k_preinit
  fi
  typeset -gr __p9k_sourced=13
  if [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]]; then
    if [[ -w $__p9k_root_dir && -w $__p9k_root_dir/internal && -w $__p9k_root_dir/gitstatus ]]; then
      local f
      for f in $__p9k_root_dir/{powerlevel9k.zsh-theme,lcars10k.zsh-theme,internal/p10k.zsh,internal/icons.zsh,internal/configure.zsh,internal/worker.zsh,internal/parser.zsh,gitstatus/gitstatus.plugin.zsh,gitstatus/install}; do
        [[ $f.zwc -nt $f ]] && continue
        zmodload -F zsh/files b:zf_mv b:zf_rm
        local tmp=$f.tmp.$$.zwc
        {
          # `zf_mv -f src dst` fails on NTFS if `dst` is not writable, hence `zf_rm`.
          zf_rm -f -- $f.zwc && zcompile -R -- $tmp $f && zf_mv -f -- $tmp $f.zwc
        } always {
          (( $? )) && zf_rm -f -- $tmp
        }
      done
    fi
  fi
  builtin source $__p9k_root_dir/internal/p10k.zsh || true
}

(( $+__p9k_instant_prompt_active )) && unsetopt prompt_cr prompt_sp || setopt prompt_cr prompt_sp

(( ${#__p9k_src_opts} )) && setopt ${__p9k_src_opts[@]}

# ============================================================
# LCARS10k overlay (added by hard fork — wyretrip/lcars10k)
# ============================================================
#
# Static prompt configuration (palette, separators, segment layout, vcs
# formatter) lives in config/p10k.zsh, installed as ~/.p10k.zsh by
# scripts/setup.sh. p10k loads that during its own init above, so by the time
# we get here every POWERLEVEL9K_* var is already set.
#
# This block sources the runtime behavior modules:
#   - lcars-segments.zsh: defines prompt_lcars_* segment functions
#   - lcars-palette.zsh:  defines runtime palette-swap helpers for red alert
#   - lcars-quiet.zsh:    lcars-quiet / lcars-loud session toggles
#   - lcars-redalert.zsh: red-alert mode (state machine + palette swap)
#   - lcars-sounds.zsh:   sound hooks (precmd/preexec)

typeset -g _LCARS_ROOT="${${(%):-%x}:A:h}"

# Segments must be defined before the first prompt render
source "$_LCARS_ROOT/lib/lcars-segments.zsh"

# Palette swap helpers (used by red alert)
source "$_LCARS_ROOT/lib/lcars-palette.zsh"

# User config — env-var-level overrides (LCARS_SOUNDS, thresholds, sound paths)
[[ -r "$HOME/.lcars10krc" ]] && source "$HOME/.lcars10krc"

# Behavior modules — these read the env vars set above
source "$_LCARS_ROOT/lib/lcars-quiet.zsh"
source "$_LCARS_ROOT/lib/lcars-redalert.zsh"
source "$_LCARS_ROOT/lib/lcars-sounds.zsh"

# User-facing CLI: lcars10k {setup,reload,quiet,loud,redalert,version,help}
source "$_LCARS_ROOT/lib/lcars-cli.zsh"
'builtin' 'unset' '__p9k_src_opts'
