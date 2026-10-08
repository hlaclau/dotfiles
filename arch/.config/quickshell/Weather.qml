pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Current weather and a 3-day forecast from wttr.in (location from the IP,
// no API key), refreshed every 30 minutes
Singleton {
    id: root

    property bool ready: false
    property string area: ""
    property int temp: 0
    property int feelsLike: 0
    property int humidity: 0
    property int code: 0
    property string description: ""
    // [{ date, max, min, code }]
    property var days: []

    readonly property string icon: iconFor(code, isNight())

    function isNight() {
        const h = new Date().getHours();
        return h < 7 || h >= 20;
    }

    // wttr.in / WWO weather codes -> Nerd Font weather glyphs
    function iconFor(c, night) {
        if (c === 113) return night ? Icons.nightClear : Icons.daySunny;
        if (c === 116) return night ? Icons.nightCloudy : Icons.dayCloudy;
        if ([119, 122].includes(c)) return Icons.cloudy;
        if ([143, 248, 260].includes(c)) return Icons.fog;
        if ([200, 386, 389, 392, 395].includes(c)) return Icons.thunder;
        if ([176, 263, 266, 293, 296, 353].includes(c)) return Icons.showers;
        if ([299, 302, 305, 308, 311, 314, 356, 359].includes(c)) return Icons.rain;
        return Icons.snow;
    }

    function refresh() {
        fetcher.running = true;
    }

    Process {
        id: fetcher
        command: ["curl", "-sf", "-m", "15", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const now = j.current_condition[0];
                    root.temp = Number(now.temp_C);
                    root.feelsLike = Number(now.FeelsLikeC);
                    root.humidity = Number(now.humidity);
                    root.code = Number(now.weatherCode);
                    root.description = now.weatherDesc[0].value.trim();
                    root.area = j.nearest_area?.[0]?.areaName?.[0]?.value ?? "";
                    // Midday (hourly[4] = 12:00) stands for the whole day
                    root.days = j.weather.map(d => ({
                        date: d.date,
                        max: Number(d.maxtempC),
                        min: Number(d.mintempC),
                        code: Number(d.hourly[4]?.weatherCode ?? 113)
                    }));
                    root.ready = true;
                } catch (e) {
                    // Offline or rate limited: keep the last reading and try again next time
                }
            }
        }
    }

    // First fetch shortly after login (network up), then every 30 minutes
    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 5000
        running: true
        onTriggered: root.refresh()
    }
}
