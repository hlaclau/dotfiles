#!/bin/bash

sketchybar --add item sound right \
           --set sound \
                icon.font="SF Pro:Regular:16.0" \
                icon.color=$WHITE \
                label.color=$GREY \
                label.font="$FONT:Medium:12.0" \
                background.drawing=off \
                script="$PLUGIN_DIR/sound.sh" \
           --subscribe sound volume_change
