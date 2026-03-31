import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Cava visualizer — runs cava directly with a generated per-side config.
// Bypasses the socket manager for reliability.
// Non-collapse: uses a hidden sizer Text so width is always reserved.
// Auto-hide: when Config.cavaAutoHide is true AND Config.showMediaPlayer is false,
//            the module hides itself when no media is detected and shows again
//            when media plays. If the media player module is visible, cava always
//            stays shown (media info is already providing context).
Item {
    id: root
    property string side: "left"   // "left" or "right"

    Layout.alignment: Qt.AlignVCenter

    //  Auto-hide only applies when the toggle is on AND media module is hidden.
    readonly property bool _autoHideActive: Config.cavaAutoHide && !Config.showMediaPlayer

    //  Non-collapse: always reserve full width when transparent-when-inactive.
    //  _sizer uses a placeholder string of cavaWidth first-bar chars so the
    //  island pre-allocates the correct width before cava outputs anything.
    //  When auto-hide is active and no media is detected, collapse to 0.
    implicitWidth: {
        if (_autoHideActive && !_mediaActive) return 0
        const w = _sizer.advanceWidth + Config.modPadH * 2
        return Config.cavaTransparentWhenInactive ? w : (_active ? w : 0)
    }
    implicitHeight: Config.moduleHeight

    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

    property string _text:   ""
    property bool   _active: false

    // ── Media detection for auto-hide ─────────────────────────────────────────
    //  Watches playerctl status; _mediaActive = true when Playing or Paused.
    //  Only runs when auto-hide is actually in effect.
    property bool _mediaActive: false

    Process {
        id: mediaWatchProc
        command: ["playerctl", "-F", "status"]
        running: root._autoHideActive
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const s = line.trim()
                root._mediaActive = (s === "Playing" || s === "Paused")
            }
        }
        onExited: mediaWatchRestart.restart()
    }
    Timer { id: mediaWatchRestart; interval: 3000; repeat: false
        onTriggered: if (root._autoHideActive && !mediaWatchProc.running) mediaWatchProc.running = true }

    // ── Direct cava invocation ────────────────────────────────────────────────
    //  Writes a temp config file then runs cava with ascii output.
    //  Each output line: semicolon-separated integers 0..N-1 where N = len(bars).
    Process {
        id: cavaProc
        // Build command at binding time so it reacts to Config changes on restart.
        command: {
            const bars    = Config.cavaEffectiveBars
            const maxR    = Math.max(0, bars.length - 1)
            const rev     = root.side === "right" ? 1 : 0
            const cfgPath = "/tmp/qs-cava-" + root.side + ".ini"
            // Pass each line as a separate printf arg so actual newlines are
            // written — JSON.stringify would escape \n in a joined string.
            const lines = [
                "[general]",
                "bars = "             + Config.cavaWidth,
                "framerate = 60",
                "",
                "[output]",
                "method = raw",
                "raw_target = /dev/stdout",
                "data_format = ascii",
                "ascii_max_range = "  + maxR,
                "channels = mono",
                "reverse = "          + rev
            ]
            const quoted   = lines.map(l => JSON.stringify(l)).join(" ")
            const writeCmd = "printf '%s\\n' " + quoted + " > " + cfgPath
            return ["bash", "-c", writeCmd + " && cava -p " + cfgPath]
        }
        Component.onCompleted: running = true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const t = line.trim()
                if (!t || t.startsWith("[")) return   // skip cava header lines
                const vals    = t.split(";")
                const barsStr = Config.cavaEffectiveBars
                let   result  = ""
                let   allZero = true
                for (let i = 0; i < vals.length; i++) {
                    const v = parseInt(vals[i])
                    if (!isNaN(v)) {
                        if (v > 0) allZero = false
                        result += barsStr[Math.min(v, barsStr.length - 1)]
                    }
                }
                root._text   = result
                root._active = !allZero
            }
        }
        onExited: restartTimer.restart()
    }
    Timer { id: restartTimer; interval: 2000; repeat: false
        onTriggered: if (!cavaProc.running) cavaProc.running = true }

    // ── Hidden sizer: reserves correct width before first output ─────────────
    // Uses TextMetrics so the island bg always matches what cavaLabel will render.
    TextMetrics {
        id: _sizer
        font.family:    Config.fontFamily
        font.pixelSize: Config.glyphSize
        font.letterSpacing: Config.cavaBarSpacing
        text: {
            const b  = Config.cavaEffectiveBars
            const ch = b.length > 0 ? b[0] : " "
            return ch.repeat(Config.cavaWidth)
        }
    }

    // ── Visible label ─────────────────────────────────────────────────────────
    Text {
        id: cavaLabel
        anchors.centerIn: parent
        // Clamp width to the sizer measurement so text never escapes the island bg
        width: _sizer.advanceWidth
        clip: true
        text: root._text

        readonly property color _activeColor: Config.cavaGradientEnabled
            ? Config.cavaGradientStartColor
            : Qt.rgba(Config.cavaGlyphColor.r, Config.cavaGlyphColor.g,
                      Config.cavaGlyphColor.b, Config.cavaActiveOpacity)

        readonly property color _inactiveColor: Config.cavaGradientEnabled
            ? Qt.rgba(Config.cavaGradientEndColor.r, Config.cavaGradientEndColor.g,
                      Config.cavaGradientEndColor.b, Config.cavaInactiveOpacity)
            : Qt.rgba(Config.cavaGlyphColor.r, Config.cavaGlyphColor.g,
                      Config.cavaGlyphColor.b, Config.cavaInactiveOpacity)

        color: root._active ? _activeColor : _inactiveColor
        font.family:        Config.fontFamily
        font.pixelSize:     Config.glyphSize
        font.letterSpacing: Config.cavaBarSpacing
        Behavior on color { ColorAnimation { duration: 300 } }
    }
}
