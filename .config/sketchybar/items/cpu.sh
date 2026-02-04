#!/bin/bash

sketchybar --add item cpu right \
           --set cpu \
                update_freq=2 \
                icon=$CPU_ICON \
                icon.font="SF Pro:Regular:14.0" \
                icon.color=$WHITE \
                label.color=$GREY \
                label.font="$FONT:Medium:12.0" \
                background.drawing=off \
                script="$PLUGIN_DIR/cpu.sh"
