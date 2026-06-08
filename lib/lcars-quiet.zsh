# lib/lcars-quiet.zsh — per-session sound toggle.

lcars-quiet() {
    export LCARS_SOUNDS=0
    print -P "%F{208}LCARS%f sounds %F{red}disabled%f for this session."
}

lcars-loud() {
    export LCARS_SOUNDS=1
    print -P "%F{208}LCARS%f sounds %F{green}enabled%f for this session."
}
