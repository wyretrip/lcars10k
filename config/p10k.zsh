# config/p10k.zsh — LCARS-tuned powerlevel10k configuration.
#
# Installed as ~/.p10k.zsh by scripts/setup.sh (the original is backed up to
# ~/.p10k.zsh.pre-lcars10k). lcars10k is opinionated: this file is the single
# source of truth for the LCARS prompt's structure, palette, and segment
# styling. To customize, edit ~/.lcars10krc for env-var-level knobs, or edit
# this file directly to change the layout / colors.

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
    emulate -L zsh -o extended_glob

    # Wipe any prior POWERLEVEL9K_* settings so this file is authoritative.
    unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

    # ============================================================
    # LCARS palette — muted "70859" set (per reference). Less neon-Okuda,
    # more modern-Trek. Coffee replaces red as the alert color since the
    # reference has no true red; alert segments use cream fg for legibility.
    # ============================================================
    local pumpkin='#F5B86E'   # amber       — primary / host / context
    local peach='#D8C4DE'     # lavender    — secondary / dir
    local tan='#A07A6E'       # terracotta  — warm accent / time
    local lilac='#7C74A2'     # plum        — alt / vcs clean
    local sky='#A2A8F0'       # periwinkle  — info / cmd duration / date
    local alert='#60463E'     # coffee      — error / red-alert (dark; use cream fg)
    local rose='#86667A'      # rose        — held in reserve
    local black='#000000'     # text on light segment
    local cream='#FFE6D5'     # text on dark (coffee) segment

    # ============================================================
    # Prompt structure — one line, no leading blank, no transient.
    # ============================================================
    typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
        lcars_hostid
        lcars_dirid
        context
        dir
        vcs
        newline       # break to a second line for the actual prompt char
        prompt_char   # the > where you type
    )
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
        command_execution_time
        lcars_date
        lcars_err
    )

    # Honour LCARS_NUMERIC_IDS=0 (set in ~/.lcars10krc)
    if (( ${LCARS_NUMERIC_IDS:-1} != 1 )); then
        POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=("${(@)POWERLEVEL9K_LEFT_PROMPT_ELEMENTS:#lcars_(hostid|dirid)}")
    fi

    # Two-line prompt: pills on line 1, input cursor on line 2.
    typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false  # we use the `newline` segment instead
    typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false  # right prompt stays beside the pills
    typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true   # blank line above each new prompt
    # Transient prompt: collapse prior prompts to just the input line when a
    # command runs. Pills only show on the *current* prompt.
    typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
    typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

    # Mode (vi/etc) indicator: hide
    typeset -g POWERLEVEL9K_MODE=nerdfont-complete
    typeset -g POWERLEVEL9K_ICON_PADDING=none

    # ============================================================
    # Round-pill separators (Powerline Extra Symbols U+E0B4 / U+E0B6).
    # Requires MesloLGS NF or similar Nerd Font in the terminal.
    # ============================================================
    # Round-pill caps. U+E0B4 = right half-circle (right pill end).
    # U+E0B6 = left half-circle (left pill end). Both live in the Powerline
    # Extra Symbols block — MesloLGS NF has them.
    typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=$''
    typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=$''
    typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=$''
    typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=$''
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=$''
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=$''

    typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' '
    typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=' '

    # ============================================================
    # Custom segments (LCARS-specific)
    # ============================================================

    # --- lcars_hostid (the "LCARS-XX-XXX-X" pill — matches the dominant
    # periwinkle header from the reference palette) ---
    typeset -g POWERLEVEL9K_LCARS_HOSTID_BACKGROUND=$sky
    typeset -g POWERLEVEL9K_LCARS_HOSTID_FOREGROUND=$black

    # --- lcars_dirid ---
    typeset -g POWERLEVEL9K_LCARS_DIRID_BACKGROUND=$peach
    typeset -g POWERLEVEL9K_LCARS_DIRID_FOREGROUND=$black

    # --- lcars_date ---
    typeset -g POWERLEVEL9K_LCARS_DATE_BACKGROUND=$pumpkin
    typeset -g POWERLEVEL9K_LCARS_DATE_FOREGROUND=$black

    # --- lcars_err ---
    typeset -g POWERLEVEL9K_LCARS_ERR_BACKGROUND=$alert
    typeset -g POWERLEVEL9K_LCARS_ERR_FOREGROUND=$cream

    # --- prompt_char (line-2 input indicator, no pill around it) ---
    typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$sky
    typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$pumpkin
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION='❯'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_CONTENT_EXPANSION='❮'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIVIS_CONTENT_EXPANSION='V'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIOWR_CONTENT_EXPANSION='▶'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION='❯'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD_CONTENT_EXPANSION='❮'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIVIS_CONTENT_EXPANSION='V'
    typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIOWR_CONTENT_EXPANSION='▶'
    # No pill caps around prompt_char (it's bare on line 2)
    typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=
    typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
    typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_LEFT_WHITESPACE=
    typeset -g POWERLEVEL9K_PROMPT_CHAR_RIGHT_LEFT_WHITESPACE=

    # ============================================================
    # Standard segments (re-styled for LCARS)
    # ============================================================

    # --- context (username) ---
    typeset -g POWERLEVEL9K_ALWAYS_SHOW_USER=true
    typeset -g POWERLEVEL9K_ALWAYS_SHOW_CONTEXT=true
    # Templates use p10k's prompt-style expansion (%n = username, %m = host).
    # CONTENT_EXPANSION applies the (%) flag BEFORE (U) — so if P9K_CONTENT
    # arrives unexpanded (containing literal %n), prompt-expand it first, then
    # uppercase. Otherwise (U) would convert %n → %N and the result would be
    # re-interpreted as the function-name sequence.
    typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n'
    typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_TEMPLATE='%n'
    typeset -g POWERLEVEL9K_CONTEXT_SUDO_TEMPLATE='%n'
    typeset -g POWERLEVEL9K_CONTEXT_REMOTE_TEMPLATE='%n@%m'
    typeset -g POWERLEVEL9K_CONTEXT_REMOTE_SUDO_TEMPLATE='%n@%m'
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_TEMPLATE='%n'

    typeset -g POWERLEVEL9K_CONTEXT_CONTENT_EXPANSION='${(U)${(%)P9K_CONTENT}}'
    typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_CONTENT_EXPANSION='${(U)${(%)P9K_CONTENT}}'
    typeset -g POWERLEVEL9K_CONTEXT_SUDO_CONTENT_EXPANSION='${(U)${(%)P9K_CONTENT}}'
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_CONTENT_EXPANSION='${(U)${(%)P9K_CONTENT}}'
    typeset -g POWERLEVEL9K_CONTEXT_REMOTE_CONTENT_EXPANSION='${(U)${(%)P9K_CONTENT}}'
    typeset -g POWERLEVEL9K_CONTEXT_REMOTE_SUDO_CONTENT_EXPANSION='${(U)${(%)P9K_CONTENT}}'

    typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND=$lilac
    typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND=$black
    typeset -g POWERLEVEL9K_CONTEXT_SUDO_BACKGROUND=$lilac
    typeset -g POWERLEVEL9K_CONTEXT_SUDO_FOREGROUND=$black
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_BACKGROUND=$alert
    typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=$black
    typeset -g POWERLEVEL9K_CONTEXT_REMOTE_BACKGROUND=$lilac
    typeset -g POWERLEVEL9K_CONTEXT_REMOTE_FOREGROUND=$black

    typeset -g POWERLEVEL9K_CONTEXT_PREFIX=''

    # --- dir ---
    typeset -g POWERLEVEL9K_DIR_BACKGROUND=$rose
    typeset -g POWERLEVEL9K_DIR_FOREGROUND=$black
    # Dir is NOT uppercased — paths read better in their natural case.
    # (No (U) wrapping; that interacts badly with very short content and
    # produces extra cap glyphs flanking the `~`.)
    typeset -g POWERLEVEL9K_DIR_CONTENT_EXPANSION='${P9K_CONTENT}'
    typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false
    typeset -g POWERLEVEL9K_DIR_PREFIX=''
    typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
    typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
    typeset -g POWERLEVEL9K_DIR_MAX_LENGTH_PERCENT=0
    typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
    # No dir icons
    typeset -g POWERLEVEL9K_DIR_HOME_ICON=''
    typeset -g POWERLEVEL9K_DIR_HOME_SUBFOLDER_ICON=''
    typeset -g POWERLEVEL9K_DIR_DEFAULT_ICON=''
    typeset -g POWERLEVEL9K_DIR_ETC_ICON=''
    typeset -g POWERLEVEL9K_DIR_FOLDER_ICON=''
    typeset -g POWERLEVEL9K_DIR_NOT_WRITABLE_ICON=''
    typeset -g POWERLEVEL9K_DIR_PUBLIC_FOLDER_ICON=''
    typeset -g POWERLEVEL9K_HOME_ICON=''
    typeset -g POWERLEVEL9K_HOME_SUB_ICON=''
    typeset -g POWERLEVEL9K_FOLDER_ICON=''
    typeset -g POWERLEVEL9K_LOCK_ICON=''

    # --- vcs ---
    typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
    typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=$lilac
    typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=$black
    typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=$tan
    typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=$black
    typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=$lilac
    typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=$black
    typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=$peach
    typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=$black
    typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=$alert
    typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=$cream
    typeset -g POWERLEVEL9K_VCS_PREFIX=''
    typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1

    # LCARS VCS content formatter: UPPERCASE branch + ahead/behind/dirty counters.
    function _lcars_vcs_format() {
        emulate -L zsh
        local res=""
        if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
            res+="${(U)VCS_STATUS_LOCAL_BRANCH}"
        elif [[ -n $VCS_STATUS_TAG ]]; then
            res+="#${(U)VCS_STATUS_TAG}"
        elif [[ -n $VCS_STATUS_COMMIT ]]; then
            res+="@${VCS_STATUS_COMMIT[1,8]}"
        fi
        (( VCS_STATUS_COMMITS_AHEAD ))  && res+=" ↑${VCS_STATUS_COMMITS_AHEAD}"
        (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ↓${VCS_STATUS_COMMITS_BEHIND}"
        (( VCS_STATUS_NUM_STAGED ))     && res+=" +${VCS_STATUS_NUM_STAGED}"
        (( VCS_STATUS_NUM_UNSTAGED ))   && res+=" !${VCS_STATUS_NUM_UNSTAGED}"
        (( VCS_STATUS_NUM_UNTRACKED ))  && res+=" ?${VCS_STATUS_NUM_UNTRACKED}"
        (( VCS_STATUS_STASHES ))        && res+=" *${VCS_STATUS_STASHES}"
        [[ -n $VCS_STATUS_ACTION ]]     && res+=" (${(U)VCS_STATUS_ACTION})"
        typeset -g _lcars_vcs_content="$res"
    }
    functions -M _lcars_vcs_format 2>/dev/null
    typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((_lcars_vcs_format()))+${_lcars_vcs_content}}'
    typeset -g POWERLEVEL9K_VCS_LOADING_CONTENT_EXPANSION='…'

    # Drop all VCS icons
    typeset -g POWERLEVEL9K_VCS_GIT_ICON=''
    typeset -g POWERLEVEL9K_VCS_GIT_GITHUB_ICON=''
    typeset -g POWERLEVEL9K_VCS_GIT_BITBUCKET_ICON=''
    typeset -g POWERLEVEL9K_VCS_GIT_GITLAB_ICON=''
    typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=''
    typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON=''
    typeset -g POWERLEVEL9K_VCS_UNSTAGED_ICON=''
    typeset -g POWERLEVEL9K_VCS_STAGED_ICON=''
    typeset -g POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON=''
    typeset -g POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON=''
    typeset -g POWERLEVEL9K_VCS_STASH_ICON=''
    typeset -g POWERLEVEL9K_VCS_TAG_ICON=''
    typeset -g POWERLEVEL9K_VCS_COMMIT_ICON=''
    typeset -g POWERLEVEL9K_VCS_REMOTE_BRANCH_ICON=''
    typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_EXPANSION=''
    typeset -g POWERLEVEL9K_VCS_LOADING_VISUAL_IDENTIFIER_EXPANSION=''

    # --- command_execution_time ---
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=$sky
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=$black
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=${LCARS_LONGCMD_THRESHOLD:-5}
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=1
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='H:M:S'
    # Drop the default stopwatch icon — wasn't disabled before and was
    # rendering as ? in a box.
    typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_VISUAL_IDENTIFIER_EXPANSION=''

    # ============================================================
    # Gitstatus tuning
    # ============================================================
    typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1
    # Don't disable VCS in any directory
    typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN=''

    # ============================================================
    # Disable everything we don't use (kubectl, gcloud, asdf, etc.)
    # ============================================================
    # No instant-prompt warnings; we just want a clean prompt
    typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
}

# Restore options
'builtin' 'setopt' "${p10k_config_opts[@]}"
'builtin' 'unset' 'p10k_config_opts'
