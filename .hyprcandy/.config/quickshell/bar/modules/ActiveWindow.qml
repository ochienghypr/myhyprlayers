import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."
// Active window — icon + truncated title of the focused window.
// Icon resolution:
//   1. DesktopEntries.heuristicLookup(class) → icon name from .desktop file
//   2. Quickshell.iconPath(name, fallback) → theme icon path (covers most apps)
//   3. tray-icon-resolve.py fallback for edge cases
//
// Uses Connections to track HyprlandFocusedClient changes instead of readonly
// property bindings, which avoids the "not defined" warning at init time.
Item {
    id: root
    Layout.alignment: Qt.AlignVCenter
    implicitWidth:  Math.max(Config.activeWindowMinWidth,
                             row.implicitWidth + Config.modPadH * 2)
    implicitHeight: Config.moduleHeight
    visible: true

    // ── Focused client state (updated via Connections to avoid init-time errors)
    property string winTitle:    ""
    property string winClass:    ""
    property string initialClass:""
    property string winAddress:  ""
    readonly property bool _noWindow: winAddress === ""

    // Sync on startup
    Component.onCompleted: _syncClient()

    function _syncClient() {
        const c = HyprlandFocusedClient
        winTitle     = c.title        ?? ""
        winClass     = c.class        ?? ""
        initialClass = c.initialClass ?? ""
        winAddress   = c.address      ?? ""
    }

    Connections {
        target: HyprlandFocusedClient
        function onTitleChanged()        { root.winTitle     = HyprlandFocusedClient.title        ?? "" }
        function onClassChanged()        { root.winClass     = HyprlandFocusedClient.class        ?? "" }
        function onInitialClassChanged() { root.initialClass = HyprlandFocusedClient.initialClass ?? "" }
        function onAddressChanged()      { root.winAddress   = HyprlandFocusedClient.address      ?? "" }
    }

    // ── Icon resolution ───────────────────────────────────────────────────
    // Use DesktopEntries.heuristicLookup with the window class, then
    // Quickshell.iconPath for theme lookup.  Falls back to tray-icon-resolve.py.
    readonly property var _entry: DesktopEntries.heuristicLookup(
        winClass !== "" ? winClass : initialClass)

    // Primary icon path
    readonly property string _primaryIcon: {
        if (_noWindow) return ""
        const name = _entry?.icon ?? (winClass !== "" ? winClass : initialClass)
        if (!name || name === "") return ""
        if (name.startsWith("/"))        return "file://" + name
        if (name.startsWith("file://"))  return name
        if (name.startsWith("image://")) return name
        return Quickshell.iconPath(name, "image-missing")
    }

    // Resolved path from tray-icon-resolve.py (fills in when primary misses)
    property string resolvedIcon: ""

    // Final icon source: primary > resolved fallback > empty
    readonly property string iconSource: {
        if (_noWindow) return ""
        if (resolvedIcon !== "") return "file://" + resolvedIcon
        return _primaryIcon  // Image.Error will trigger the resolver if this fails
    }

    // Best candidate name for the fallback resolver
    readonly property string _lookupKey: {
        const name = _entry?.icon ?? (winClass !== "" ? winClass : initialClass)
        return (name || "").trim()
    }

    property bool _needsResolve: false

    // Fallback resolver — argv[1] mode, same script as SystemTray uses
    Process {
        id: iconResolverProc
        command: ["python3",
                  Quickshell.env("HOME") + "/.config/quickshell/bar/tray-icon-resolve.py",
                  root._lookupKey]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                const p = line.trim()
                if (p) root.resolvedIcon = p
            }
        }
    }

    function _tryResolve() {
        resolvedIcon = ""
        if (!_noWindow && _lookupKey !== "" && _needsResolve)
            iconResolverProc.running = true
    }

    on_LookupKeyChanged: { _needsResolve = false; resolvedIcon = "" }

    // ── Layout ────────────────────────────────────────────────────────────
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Config.iconTextGap

        Image {
            id: appIcon
            source: root.iconSource
            width: Config.glyphSize + 2; height: Config.glyphSize + 2
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            anchors.verticalCenter: parent.verticalCenter
            visible: !root._noWindow && source !== "" && status !== Image.Error

            // If primary icon failed to load, fire the python resolver
            onStatusChanged: {
                if (status === Image.Error && root.resolvedIcon === "" && root._lookupKey !== "") {
                    root._needsResolve = true
                    root._tryResolve()
                }
            }
        }

        // Placeholder glyph when no window / icon unavailable
        Text {
            visible: root._noWindow ||
                     root.iconSource === "" ||
                     appIcon.status === Image.Error
            text:           "󱑙"   // nf-md-circle_off_outline
            color:          Theme.cOnSurfVar
            font.family:    Config.fontFamily
            font.pixelSize: Config.glyphSize
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.winTitle !== ""
            text: root.winTitle.length > 32
                ? root.winTitle.substring(0, 31) + "…"
                : root.winTitle
            color:          Config.windowTextColor
            font.family:    Config.labelFont
            font.pixelSize: Config.labelFontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
