#!/bin/bash

sketchybar --add item front_app left \
           --set front_app \
                label.font="$FONT:Semibold:13.0" \
                label.color=$WHITE \
                icon.drawing=off \
                background.drawing=off \
                script="$PLUGIN_DIR/front_app.sh" \
           --subscribe front_app front_app_switched
