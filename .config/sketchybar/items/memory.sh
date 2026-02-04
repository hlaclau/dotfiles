#!/bin/bash

sketchybar --add item memory right \
           --set memory \
                update_freq=5 \
                icon=$MEMORY_ICON \
                icon.font="SF Pro:Regular:14.0" \
                icon.color=$WHITE \
                label.color=$GREY \
                label.font="$FONT:Medium:12.0" \
                background.drawing=off \
                script="$PLUGIN_DIR/memory.sh"
