#!/bin/bash

sketchybar --add event music_changed \
           --add item music right \
           --set music \
                update_freq=3 \
                icon=$MUSIC_ICON \
                icon.font="SF Pro:Regular:14.0" \
                icon.color=$WHITE \
                label.color=$GREY \
                label.font="$FONT:Medium:11.0" \
                label.max_chars=30 \
                background.drawing=off \
                script="$PLUGIN_DIR/music.sh" \
           --subscribe music music_changed
