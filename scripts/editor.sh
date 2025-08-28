#!/bin/sh
# editor.sh

# Notify Neovim (via terminal escape) that it should open a commit buffer.
# We pass the file path ($1).
printf "\033]51;fossil:edit;%s\007" "$1" >&2

marker=/tmp/nvim-fossil.edit
echo "$1" > $marker

# Wait until Neovim writes the message
while [ -f $marker ]; do
    sleep 0.1 2>/dev/null || sleep 1
done

exit 0
