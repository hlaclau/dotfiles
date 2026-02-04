#!/bin/bash

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9")

sketchybar --add event aerospace_workspace_change

for i in "${!SPACE_ICONS[@]}"
do
  sid=$(($i+1))
  sketchybar --add item space.$sid left \
             --subscribe space.$sid aerospace_workspace_change \
             --set space.$sid \
                  icon=${SPACE_ICONS[i]} \
                  icon.font="$FONT:Bold:13.0" \
                  icon.color=$DARK_GREY \
                  icon.highlight_color=$WHITE \
                  icon.padding_left=8 \
                  icon.padding_right=8 \
                  label.drawing=off \
                  background.drawing=off \
                  script="$PLUGIN_DIR/space.sh $sid" \
                  click_script="aerospace workspace $sid"
done

# Initialize the correct state on startup
sketchybar --trigger aerospace_workspace_change
