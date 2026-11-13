#!/bin/zsh
# Restore the watch's stock emoji table (removes the Chinese reading support).
# See load.sh for the requirements. This undoes load.sh and nothing else.
exec "$(dirname "$0")/load.sh" "$(dirname "$0")/original/ExtData/006-D8168-00.fnt"
