#!/bin/bash

sketchybar --add item time right \
           --set time \
                update_freq=10 \
                icon.drawing=off \
                label.font="$FONT:Medium:13.0" \
                label.color=$WHITE \
                background.drawing=off \
                script="$PLUGIN_DIR/time.sh"
