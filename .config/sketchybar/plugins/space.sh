#!/bin/bash

source "$CONFIG_DIR/colors.sh"

FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused)

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --animate sin 10 --set $NAME \
               icon.highlight=true \
               icon.color=$WHITE
else
    sketchybar --animate sin 10 --set $NAME \
               icon.highlight=false \
               icon.color=$DARK_GREY
fi
