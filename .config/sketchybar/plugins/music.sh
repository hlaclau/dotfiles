#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

get_music_info() {
    if command -v nowplaying-cli > /dev/null 2>&1; then
        PLAYING_STATE=$(nowplaying-cli get playbackRate 2>/dev/null || echo "0")
        if [ "$PLAYING_STATE" != "0" ] && [ "$PLAYING_STATE" != "" ]; then
            TITLE=$(nowplaying-cli get title 2>/dev/null)
            ARTIST=$(nowplaying-cli get artist 2>/dev/null)
            if [ "$TITLE" != "" ] && [ "$ARTIST" != "" ] && [ "$TITLE" != "null" ] && [ "$ARTIST" != "null" ]; then
                echo "$ARTIST - $TITLE" | head -c 40
                return
            fi
        fi
    fi

    if pgrep -x "Music" > /dev/null; then
        MUSIC_STATE=$(osascript -e 'tell application "Music" to player state as string' 2>/dev/null)
        if [ "$MUSIC_STATE" = "playing" ]; then
            TITLE=$(osascript -e 'tell application "Music" to name of current track' 2>/dev/null)
            ARTIST=$(osascript -e 'tell application "Music" to artist of current track' 2>/dev/null)
            if [ "$TITLE" != "" ] && [ "$ARTIST" != "" ] && [ "$TITLE" != "null" ] && [ "$ARTIST" != "null" ]; then
                echo "$ARTIST - $TITLE" | head -c 40
                return
            fi
        fi
    fi

    if pgrep -x "Spotify" > /dev/null; then
        SPOTIFY_STATE=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null)
        if [ "$SPOTIFY_STATE" = "playing" ]; then
            TITLE=$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null)
            ARTIST=$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null)
            if [ "$TITLE" != "" ] && [ "$ARTIST" != "" ] && [ "$TITLE" != "null" ] && [ "$ARTIST" != "null" ]; then
                echo "$ARTIST - $TITLE" | head -c 40
                return
            fi
        fi
    fi

    echo ""
}

MUSIC_INFO=$(get_music_info)

if [ "$MUSIC_INFO" = "" ]; then
    sketchybar --set music drawing=off
else
    sketchybar --set music drawing=on \
                    label="$MUSIC_INFO" \
                    icon=$MUSIC_PLAY_ICON \
                    icon.color=$WHITE
fi
