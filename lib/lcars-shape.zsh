# lib/lcars-shape.zsh — Powerline separator glyphs (round pill ends) + UPPERCASE.
# Requires a Nerd Font with Powerline Extra Symbols (MesloLGS NF recommended).

# Round (pill) terminators
POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=$''        #  (round right end)
POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=$''   #  (round left cap)
POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=$''      # round right cap

POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=$''       #  (round left end)
POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=$''
POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=$''

# Subsegment separator (when two segments share a background)
POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=' · '
POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=' · '

# UPPERCASE the directory segment via content expansion
POWERLEVEL9K_DIR_CONTENT_EXPANSION='${(U)P9K_CONTENT}'

# UPPERCASE the context segment (user@host)
POWERLEVEL9K_CONTEXT_TEMPLATE='${(U)%n@%m}'
POWERLEVEL9K_CONTEXT_DEFAULT_TEMPLATE='${(U)%n@%m}'

# VCS segment uppercase + LCARS-flavored prefix
POWERLEVEL9K_VCS_CONTENT_EXPANSION='${(U)P9K_CONTENT}'

# Segment padding feels chunkier with a wider blank column on each side
POWERLEVEL9K_LEFT_SEGMENT_END_TRUNC_SUFFIX=''
POWERLEVEL9K_RIGHT_SEGMENT_START_TRUNC_SUFFIX=''
