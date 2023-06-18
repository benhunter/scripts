#!/bin/zsh

while fswatch -e close_write "$1"; do
    python "$1"
done | tee /dev/tty

#!/bin/sh
#
# while inotifywait -e modify "$1"; do
#     python "$1"
# done
