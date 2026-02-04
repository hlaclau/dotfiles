#!/bin/bash

sketchybar --add item battery right \
           --set battery \
                update_freq=120 \
                icon.font="SF Pro:Regular:16.0" \
                icon.color=$WHITE \
                label.color=$GREY \
                label.font="$FONT:Medium:12.0" \
                background.drawing=off \
                script="$PLUGIN_DIR/battery.sh" \
           --subscribe battery system_woke power_source_change
