pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// ═══════════════════════════════════════════════════════════════════════════
//  Control Center — hyprcandy quickshell edition.
//
//  Layout:
//    • Anchored like startmenu/notifications — same gap from bar edge,
//      horizontally centered, tracks top/bottom bar position.
//    • Left sidebar (vertical nav) → Right content pane
//    • Sidebar: user icon (click → wallpaper picker) + tab buttons
//    • Content: Bar sub-tabs + Hyprland / Themes / Dock / Menus / SDDM
//
//  Slider style matches startmenu SliderBg exactly:
//    trough = 14 px tall, innerH = 8 px, gradient fill (inversePrimary→onPrimary), dot-glyph thumb.
//
//  Wallpaper picker:
//    • Clicking the user icon circle opens a wallpaper-picker-like overlay
//      rendered ABOVE the control center (higher layer order).
//    • Right-clicking a wallpaper thumbnail shows a small tray-style popover
//      with "Set as user icon" option (converts via imagemagick).
//
//  Layer: Top layer, surround only the panel (not full-screen).
//  Backdrop: full-screen blur rectangle anchored to the PanelWindow fill.
// ═══════════════════════════════════════════════════════════════════════════
PanelWindow {
    id: ccWin

    // ── Bar state (read from qs_bar_state.json, same as startmenu) ───────
    property bool   _barAtBottom: Config.barPosition === "bottom"
    property real   _barGap:      Config.outerMarginTop + Config.barHeight + 6
    property real   _barGapBot:   Config.outerMarginBottom + Config.barHeight + 6
    property real   _sideMargin:  Config.outerMarginSide

    // Anchor to bar edge (top or bottom), left+right for centering
    anchors {
        top:    !_barAtBottom
        bottom:  _barAtBottom
        left:   true
        right:  true
    }
    margins {
        top:    _barAtBottom ? 0 : _barGap
        bottom: _barAtBottom ? _barGapBot : 0
        left:   0
        right:  0
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"
    visible: ControlCenterState.visible

    // ── Full-screen backdrop blur ─────────────────────────────────────────
    // Positioned relative to the PanelWindow (which spans the available strip),
    // this dims the background. We also extend it beyond bounds via a negative
    // margin trick to simulate full-screen dimming while keeping the shell layer.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.48)
        // Allow click-away on the backdrop only (not the panel)
        MouseArea {
            anchors.fill: parent
            onClicked: ControlCenterState.close()
            z: -1
        }
    }

    // ── The panel itself ───────────────────────────────────────────────────
    Rectangle {
        id: panel
        // Centered horizontally; height fills most of the available strip
        width:  Math.min(920, Math.max(600, parent.width * 0.66))
        height: Math.min(parent.height - 16, Math.max(500, parent.height * 0.92))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4

        radius: 20
        color:  Qt.rgba(Theme.cOnSecondary.r, Theme.cOnSecondary.g,
                        Theme.cOnSecondary.b, 0.94)
        border.width: 1
        border.color: Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g,
                              Theme.cOutVar.b, 0.38)
        clip: true

        // Scale-in animation from bar direction
        scale: ControlCenterState.visible ? 1.0 : 0.94
        transformOrigin: _barAtBottom ? Item.Bottom : Item.Top
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        opacity: ControlCenterState.visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Keys.onEscapePressed: ControlCenterState.close()
        focus: true

        Connections {
            target: ControlCenterState
            function onVisibleChanged() {
                if (ControlCenterState.visible) panel.forceActiveFocus()
            }
        }

        Row {
            anchors.fill: parent
            spacing: 0

            // ═══════════════════════════════════════════════════════════════
            //  LEFT SIDEBAR
            // ═══════════════════════════════════════════════════════════════
            Rectangle {
                id: sidebar
                width: 190
                height: parent.height
                color: Qt.rgba(Theme.cOnSecondary.r, Theme.cOnSecondary.g,
                               Theme.cOnSecondary.b, 0.55)
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g, Theme.cOutVar.b, 0.22)
                }

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 5

                    // ── User info card ─────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: 110
                        radius: 16
                        color: Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                       Theme.cInversePrimary.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                              Theme.cPrimary.b, 0.18)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            // User icon circle — click opens wallpaper picker overlay
                            Rectangle {
                                id: userIconCircle
                                Layout.alignment: Qt.AlignHCenter
                                width: 58; height: 58; radius: 29
                                color: Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                               Theme.cInversePrimary.b, 0.32)
                                border.width: 2
                                border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                                      Theme.cPrimary.b, 0.55)
                                clip: true

                                Image {
                                    id: userImg
                                    anchors.fill: parent
                                    source: "file://" + Config.home + "/.config/hyprcandy/user-icon.png"
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: userImg.status !== Image.Ready
                                    text: "󰀄"
                                    font.family: Config.fontFamily
                                    font.pixelSize: 28
                                    color: Theme.cPrimary
                                }

                                // Hover edit overlay
                                Rectangle {
                                    anchors.fill: parent; radius: parent.radius
                                    color: Qt.rgba(0, 0, 0, 0.38)
                                    visible: iconHoverArea.containsMouse
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰄀"
                                        font.family: Config.fontFamily
                                        font.pixelSize: 18
                                        color: "white"
                                    }
                                }
                                MouseArea {
                                    id: iconHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wpPickerOverlay.open()
                                }
                            }

                            Text {
                                id: userNameText
                                Layout.alignment: Qt.AlignHCenter
                                text: "—"
                                color: Theme.cPrimary
                                font.family: Config.labelFont
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // ── Nav buttons ───────────────────────────────────────
                    Repeater {
                        model: [
                            { icon: "󱟛", label: "Bar",       idx: 0 },
                            { icon: " ", label: "Hyprland",  idx: 1 },
                            { icon: "󰔎", label: "Themes",    idx: 2 },
                            { icon: "󰞒", label: "Dock",      idx: 3 },
                            { icon: "󰮫", label: "Menus",     idx: 4 },
                            { icon: "󰍂", label: "SDDM",      idx: 5 }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 38; radius: 11
                            color: mainStack.currentIndex === modelData.idx
                                ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                          Theme.cInversePrimary.b, 0.62)
                                : (navHover.containsMouse
                                    ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                              Theme.cInversePrimary.b, 0.22)
                                    : "transparent")
                            border.width: mainStack.currentIndex === modelData.idx ? 1 : 0
                            border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                                  Theme.cPrimary.b, 0.38)

                            Row {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter
                                          leftMargin: 14 }
                                spacing: 10
                                Text {
                                    text: modelData.icon
                                    font.family: Config.fontFamily; font.pixelSize: 15
                                    color: Theme.cPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.label
                                    font.family: Config.labelFont; font.pixelSize: 13
                                    font.weight: mainStack.currentIndex === modelData.idx
                                        ? Font.SemiBold : Font.Normal
                                    color: Theme.cPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            // Active indicator pill on right
                            Rectangle {
                                anchors { right: parent.right; rightMargin: 4
                                          verticalCenter: parent.verticalCenter }
                                width: 3; height: 20; radius: 2
                                color: Theme.cPrimary
                                visible: mainStack.currentIndex === modelData.idx
                            }

                            MouseArea {
                                id: navHover
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    mainStack.currentIndex = modelData.idx
                                    barSubStack.currentIndex = 0
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Version / close row
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "hyprcandy"
                            color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                           Theme.cPrimary.b, 0.35)
                            font.family: Config.labelFont; font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: closeHov.containsMouse
                                ? Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                          Theme.cPrimary.b, 0.15)
                                : Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                          Theme.cPrimary.b, 0.06)
                            Text {
                                anchors.centerIn: parent; text: "󰅙"
                                font.family: Config.fontFamily; font.pixelSize: 14
                                color: Theme.cPrimary
                            }
                            MouseArea {
                                id: closeHov; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ControlCenterState.close()
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════════
            //  RIGHT CONTENT PANE
            // ═══════════════════════════════════════════════════════════════
            Item {
                width: panel.width - sidebar.width
                height: panel.height

                StackLayout {
                    id: mainStack
                    anchors.fill: parent
                    currentIndex: 0

                    // ── TAB 0: Bar ──────────────────────────────────────────
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            // Bar sub-tab header row
                            Row {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: ["General","Icons","Workspaces","Media","Cava","Background","Visibility"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        required property int index
                                        height: 30
                                        implicitWidth: _stLabel.implicitWidth + 18
                                        radius: 9
                                        color: barSubStack.currentIndex === index
                                            ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                                      Theme.cInversePrimary.b, 0.72)
                                            : Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                                      Theme.cInversePrimary.b, 0.16)
                                        border.width: barSubStack.currentIndex === index ? 1 : 0
                                        border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                                              Theme.cPrimary.b, 0.42)
                                        Text {
                                            id: _stLabel; anchors.centerIn: parent
                                            text: modelData; color: Theme.cPrimary
                                            font.family: Config.labelFont; font.pixelSize: 12
                                            font.weight: barSubStack.currentIndex === index
                                                ? Font.SemiBold : Font.Normal
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: barSubStack.currentIndex = index
                                        }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }
                            }

                            // Separator
                            Rectangle {
                                Layout.fillWidth: true; height: 1
                                color: Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g, Theme.cOutVar.b, 0.22)
                            }

                            // Bar sub-tab content
                            StackLayout {
                                id: barSubStack
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                currentIndex: 0

                                // ── General ────────────────────────────────
                                CCScrollPane {
                                    ColumnLayout {
                                        width: parent.width; spacing: 5

                                        CCSection { text: "Mode & Position" }
                                        CCSegmented {
                                            label: "Bar Mode"
                                            options: ["bar", "island", "tri"]
                                            current: Config.barMode
                                            onPicked: function(v) { Config.barMode = v }
                                        }
                                        CCSegmented {
                                            label: "Position"
                                            options: ["top","bottom","left","right"]
                                            current: Config.barPosition
                                            onPicked: function(v) { Config.barPosition = v }
                                        }

                                        CCSection { text: "Dimensions" }
                                        CCSlider { label:"Bar Height";    from:20;to:80;  value:Config.barHeight;    onMoved:function(v){Config.barHeight=v} }
                                        CCSlider { label:"Module Height";  from:12;to:70;  value:Config.moduleHeight;  onMoved:function(v){Config.moduleHeight=v} }

                                        CCSection { text: "Screen Margins" }
                                        CCSlider { label:"Top Margin";    from:0;to:30; value:Config.outerMarginTop;    onMoved:function(v){Config.outerMarginTop=v} }
                                        CCSlider { label:"Bottom Margin"; from:0;to:30; value:Config.outerMarginBottom; onMoved:function(v){Config.outerMarginBottom=v} }
                                        CCSlider { label:"Side Margin";   from:0;to:80; value:Config.outerMarginSide;   onMoved:function(v){Config.outerMarginSide=v} }
                                        CCSlider { label:"Edge Pad Left"; from:0;to:30; value:Config.barEdgePaddingLeft; onMoved:function(v){Config.barEdgePaddingLeft=v} }
                                        CCSlider { label:"Edge Pad Right";from:0;to:30; value:Config.barEdgePaddingRight;onMoved:function(v){Config.barEdgePaddingRight=v} }

                                        CCSection { text: "Shape" }
                                        CCSlider { label:"Bar Radius";    from:0;to:40; value:Config.barRadius;    onMoved:function(v){Config.barRadius=v} }
                                        CCSlider { label:"Island Radius"; from:0;to:40; value:Config.islandRadius; onMoved:function(v){Config.islandRadius=v} }

                                        CCSection { text: "Borders" }
                                        CCSlider { label:"Bar Border";        from:0;to:8; value:Config.barBorderWidth;    onMoved:function(v){Config.barBorderWidth=v} }
                                        CCSlider { label:"Bar Border Alpha";  from:0;to:1;stepSize:0.05;decimals:2; value:Config.barBorderAlpha;    onMoved:function(v){Config.barBorderAlpha=v} }
                                        CCSlider { label:"Island Border";     from:0;to:8; value:Config.islandBorder;      onMoved:function(v){Config.islandBorder=v} }
                                        CCSlider { label:"Island Border α";   from:0;to:1;stepSize:0.05;decimals:2; value:Config.islandBorderAlpha;  onMoved:function(v){Config.islandBorderAlpha=v} }

                                        CCSection { text: "Spacing & Padding" }
                                        CCSlider { label:"Island Spacing";  from:0;to:24; value:Config.islandSpacing;  onMoved:function(v){Config.islandSpacing=v} }
                                        CCSlider { label:"Grouped Spacing"; from:0;to:12; value:Config.groupedSpacing; onMoved:function(v){Config.groupedSpacing=v} }
                                        CCSlider { label:"Module Pad H";    from:0;to:20; value:Config.modPadH;        onMoved:function(v){Config.modPadH=v} }
                                        CCSlider { label:"Module Pad V";    from:0;to:12; value:Config.modPadV;        onMoved:function(v){Config.modPadV=v} }

                                        CCSection { text: "Opacity" }
                                        CCSlider { label:"Module BG";  from:0;to:1;stepSize:0.05;decimals:2; value:Config.moduleBgOpacity;      onMoved:function(v){Config.moduleBgOpacity=v} }
                                        CCSlider { label:"Island BG";  from:0;to:1;stepSize:0.05;decimals:2; value:Config.islandBgOpacityIsland;onMoved:function(v){Config.islandBgOpacityIsland=v} }

                                        Item { height: 10 }
                                    }
                                }

                                // ── Icons ──────────────────────────────────
                                CCScrollPane {
                                    ColumnLayout {
                                        width: parent.width; spacing: 5

                                        CCSection { text: "Glyph Sizes" }
                                        CCSlider { label:"Glyph Size";  from:8;to:24; value:Config.glyphSize;     onMoved:function(v){Config.glyphSize=v} }
                                        CCSlider { label:"Info Glyph";  from:8;to:24; value:Config.infoGlyphSize;  onMoved:function(v){Config.infoGlyphSize=v} }
                                        CCSlider { label:"Media Glyph"; from:8;to:24; value:Config.mediaGlyphSize; onMoved:function(v){Config.mediaGlyphSize=v} }

                                        CCSection { text: "Text Sizes" }
                                        CCSlider { label:"Info Text";  from:8;to:20; value:Config.infoFontSize;     onMoved:function(v){Config.infoFontSize=v} }
                                        CCSlider { label:"Label Text"; from:8;to:20; value:Config.labelFontSize;    onMoved:function(v){Config.labelFontSize=v} }
                                        CCSlider { label:"Media Text"; from:8;to:20; value:Config.mediaInfoFontSize;onMoved:function(v){Config.mediaInfoFontSize=v} }

                                        CCSection { text: "Workspace Icon Glyphs" }
                                        CCIconEntry { label:"Active Dot";     value:Config.wsDotActive;     onApplied:function(v){Config.wsDotActive=v} }
                                        CCIconEntry { label:"Persistent Dot"; value:Config.wsDotPersistent; onApplied:function(v){Config.wsDotPersistent=v} }
                                        CCIconEntry { label:"Empty Dot";      value:Config.wsDotEmpty;      onApplied:function(v){Config.wsDotEmpty=v} }
                                        CCIconEntry { label:"WS Separator";   value:Config.wsSeparatorGlyph;onApplied:function(v){Config.wsSeparatorGlyph=v} }

                                        CCSection { text: "Control Center & Power" }
                                        CCIconEntry { label:"CC Glyph";    value:Config.ccGlyph;    onApplied:function(v){Config.ccGlyph=v} }
                                        CCIconEntry { label:"Power Glyph"; value:Config.powerGlyph; onApplied:function(v){Config.powerGlyph=v} }

                                        CCSection { text: "Battery" }
                                        CCToggle { label:"Radial Visible"; value:Config.batteryRadialVisible; onToggled:function(v){Config.batteryRadialVisible=v} }
                                        CCSlider { label:"Radial Size";  from:8;to:32; value:Config.batteryRadialSize;  onMoved:function(v){Config.batteryRadialSize=v} }
                                        CCSlider { label:"Radial Stroke";from:1;to:6;  value:Config.batteryRadialWidth; onMoved:function(v){Config.batteryRadialWidth=v} }

                                        CCSection { text: "Tray" }
                                        CCSlider { label:"Icon Size";    from:10;to:32; value:Config.trayIconSz;     onMoved:function(v){Config.trayIconSz=v} }
                                        CCSlider { label:"Item Pad H";   from:0;to:8;   value:Config.trayItemPadH;   onMoved:function(v){Config.trayItemPadH=v} }
                                        CCSlider { label:"Item Spacing"; from:0;to:10;  value:Config.trayItemSpacing; onMoved:function(v){Config.trayItemSpacing=v} }

                                        Item { height: 10 }
                                    }
                                }

                                // ── Workspaces ─────────────────────────────
                                CCScrollPane {
                                    ColumnLayout {
                                        width: parent.width; spacing: 5

                                        CCSection { text: "Display Mode" }
                                        // "dot" mode removed as requested — only number & icon
                                        CCSegmented {
                                            label: "Icon Mode"
                                            options: ["number","icon"]
                                            current: Config.wsIconMode === "dot" ? "number" : Config.wsIconMode
                                            onPicked: function(v) { Config.wsIconMode = v }
                                        }

                                        CCSection { text: "Sizing" }
                                        CCSlider { label:"Glyph Size"; from:8;to:24; value:Config.wsGlyphSize; onMoved:function(v){Config.wsGlyphSize=v} }

                                        CCSection { text: "Spacing (0 = true zero)" }
                                        CCSlider { label:"WS Spacing";   from:0;to:20; value:Config.wsSpacing;   onMoved:function(v){Config.wsSpacing=v} }
                                        CCSlider { label:"Margin Left";  from:0;to:20; value:Config.wsMarginLeft; onMoved:function(v){Config.wsMarginLeft=v} }
                                        CCSlider { label:"Margin Right"; from:0;to:20; value:Config.wsMarginRight;onMoved:function(v){Config.wsMarginRight=v} }

                                        CCSection { text: "Button Padding" }
                                        CCSlider { label:"Pad Left";   from:0;to:16; value:Config.wsPadLeft;   onMoved:function(v){Config.wsPadLeft=v} }
                                        CCSlider { label:"Pad Right";  from:0;to:16; value:Config.wsPadRight;  onMoved:function(v){Config.wsPadRight=v} }
                                        CCSlider { label:"Pad Top";    from:0;to:10; value:Config.wsPadTop;    onMoved:function(v){Config.wsPadTop=v} }
                                        CCSlider { label:"Pad Bottom"; from:0;to:10; value:Config.wsPadBottom; onMoved:function(v){Config.wsPadBottom=v} }

                                        CCSection { text: "Separators" }
                                        CCToggle { label:"Show Separators"; value:Config.wsSeparators; onToggled:function(v){Config.wsSeparators=v} }
                                        CCSlider { label:"Sep Size";  from:6;to:20; value:Config.wsSeparatorSize;     onMoved:function(v){Config.wsSeparatorSize=v} }
                                        CCSlider { label:"Sep Pad L"; from:0;to:10; value:Config.wsSeparatorPadLeft;  onMoved:function(v){Config.wsSeparatorPadLeft=v} }
                                        CCSlider { label:"Sep Pad R"; from:0;to:10; value:Config.wsSeparatorPadRight; onMoved:function(v){Config.wsSeparatorPadRight=v} }

                                        Item { height: 10 }
                                    }
                                }

                                // ── Media ──────────────────────────────────
                                CCScrollPane {
                                    ColumnLayout {
                                        width: parent.width; spacing: 5

                                        CCSection { text: "Thumbnail" }
                                        CCSlider { label:"Thumb Size";      from:10;to:40; value:Config.mediaThumbSize;    onMoved:function(v){Config.mediaThumbSize=v} }

                                        CCSection { text: "Controls" }
                                        CCSlider { label:"Play/Pause Size"; from:4;to:20;  value:Config.mediaPlayPauseSize; onMoved:function(v){Config.mediaPlayPauseSize=v} }

                                        CCSection { text: "Text" }
                                        CCSlider { label:"Info Text";       from:8;to:18;  value:Config.mediaInfoFontSize;  onMoved:function(v){Config.mediaInfoFontSize=v} }

                                        CCSection { text: "Padding (0 = true zero)" }
                                        CCSlider { label:"Pad Left";   from:0;to:16; value:Config.mediaPadLeft;   onMoved:function(v){Config.mediaPadLeft=v} }
                                        CCSlider { label:"Pad Right";  from:0;to:16; value:Config.mediaPadRight;  onMoved:function(v){Config.mediaPadRight=v} }
                                        CCSlider { label:"Pad Top";    from:0;to:10; value:Config.mediaPadTop;    onMoved:function(v){Config.mediaPadTop=v} }
                                        CCSlider { label:"Pad Bottom"; from:0;to:10; value:Config.mediaPadBottom; onMoved:function(v){Config.mediaPadBottom=v} }

                                        Item { height: 10 }
                                    }
                                }

                                // ── Cava ───────────────────────────────────
                                CCScrollPane {
                                    ColumnLayout {
                                        width: parent.width; spacing: 5

                                        CCSection { text: "ASCII Style" }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 5
                                            Repeater {
                                                model: Object.keys(Config.cavaStyleMap)
                                                delegate: Rectangle {
                                                    required property string modelData
                                                    implicitWidth: _csLbl.implicitWidth + 22; height: 30; radius: 9
                                                    color: Config.cavaStyle === modelData
                                                        ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                                                  Theme.cInversePrimary.b, 0.72)
                                                        : Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                                                  Theme.cInversePrimary.b, 0.16)
                                                    border.width: Config.cavaStyle === modelData ? 1 : 0
                                                    border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                                                          Theme.cPrimary.b, 0.5)
                                                    Row {
                                                        anchors.centerIn: parent; spacing: 5
                                                        Text {
                                                            text: Config.cavaStyleMap[modelData] || ""
                                                            font.family: Config.fontFamily
                                                            font.pixelSize: 10; color: Theme.cPrimary
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        Text {
                                                            id: _csLbl
                                                            text: modelData; color: Theme.cPrimary
                                                            font.family: Config.labelFont; font.pixelSize: 12
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: Config.cavaStyle = modelData
                                                    }
                                                    Behavior on color { ColorAnimation { duration: 120 } }
                                                }
                                            }
                                        }

                                        CCSection { text: "Width & Behavior" }
                                        CCSlider { label:"Cava Width";         from:5;to:60;  value:Config.cavaWidth; onMoved:function(v){Config.cavaWidth=v} }
                                        CCToggle { label:"Transparent Inactive"; value:Config.cavaTransparentWhenInactive; onToggled:function(v){Config.cavaTransparentWhenInactive=v} }
                                        CCSlider { label:"Active Opacity";  from:0;to:1;stepSize:0.05;decimals:2; value:Config.cavaActiveOpacity;  onMoved:function(v){Config.cavaActiveOpacity=v} }
                                        CCSlider { label:"Inactive Opacity";from:0;to:1;stepSize:0.05;decimals:2; value:Config.cavaInactiveOpacity;onMoved:function(v){Config.cavaInactiveOpacity=v} }

                                        CCSection { text: "Color" }
                                        CCToggle { label:"Gradient"; value:Config.cavaGradientEnabled; onToggled:function(v){Config.cavaGradientEnabled=v} }
                                        CCColorPicker { label:"Color A"; currentColor:Config.cavaGradientEnabled ? Config.cavaGradientStartColor : Config.cavaGlyphColor }
                                        CCColorPicker { label:"Color B (gradient)"; currentColor:Config.cavaGradientEndColor; enabled:Config.cavaGradientEnabled }

                                        Item { height: 10 }
                                    }
                                }

                                // ── Background ─────────────────────────────
                                CCScrollPane {
                                    ColumnLayout {
                                        width: parent.width; spacing: 5

                                        CCSection { text: "Per-Group Background Opacity" }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "−1 = use global module BG opacity"
                                            color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                                           Theme.cPrimary.b, 0.48)
                                            font.family: Config.labelFont; font.pixelSize: 11
                                            wrapMode: Text.Wrap
                                        }

                                        CCSlider { label:"Workspaces";    from:-1;to:1;stepSize:0.05;decimals:2; value:Config.wsBgOpacity;          onMoved:function(v){Config.wsBgOpacity=v} }
                                        CCSlider { label:"Grouped";       from:-1;to:1;stepSize:0.05;decimals:2; value:Config.groupedBgOpacity;      onMoved:function(v){Config.groupedBgOpacity=v} }
                                        CCSlider { label:"Ungrouped";     from:-1;to:1;stepSize:0.05;decimals:2; value:Config.ungroupedBgOpacity;    onMoved:function(v){Config.ungroupedBgOpacity=v} }
                                        CCSlider { label:"Media";         from:-1;to:1;stepSize:0.05;decimals:2; value:Config.mediaBgOpacity;        onMoved:function(v){Config.mediaBgOpacity=v} }
                                        CCSlider { label:"Cava";          from:-1;to:1;stepSize:0.05;decimals:2; value:Config.cavaBgOpacity;         onMoved:function(v){Config.cavaBgOpacity=v} }
                                        CCSlider { label:"Active Window"; from:-1;to:1;stepSize:0.05;decimals:2; value:Config.activeWindowBgOpacity; onMoved:function(v){Config.activeWindowBgOpacity=v} }

                                        CCSection { text: "Active Window" }
                                        CCSlider { label:"Min Width"; from:0;to:80; value:Config.activeWindowMinWidth; onMoved:function(v){Config.activeWindowMinWidth=v} }

                                        Item { height: 10 }
                                    }
                                }

                                // ── Visibility ─────────────────────────────
                                CCScrollPane {
                                    ColumnLayout {
                                        width: parent.width; spacing: 5

                                        CCSection { text: "Show / Hide Modules" }
                                        CCToggle { label:"Cava";           value:Config.showCava;           onToggled:function(v){Config.showCava=v} }
                                        CCToggle { label:"Weather";        value:Config.showWeather;        onToggled:function(v){Config.showWeather=v} }
                                        CCToggle { label:"Battery";        value:Config.showBattery;        onToggled:function(v){Config.showBattery=v} }
                                        CCToggle { label:"Media Player";   value:Config.showMediaPlayer;    onToggled:function(v){Config.showMediaPlayer=v} }
                                        CCToggle { label:"Idle Inhibitor"; value:Config.showIdleInhibitor;  onToggled:function(v){Config.showIdleInhibitor=v} }
                                        CCToggle { label:"Rofi";           value:Config.showRofi;           onToggled:function(v){Config.showRofi=v} }
                                        CCToggle { label:"Updates";        value:Config.showUpdates;        onToggled:function(v){Config.showUpdates=v} }
                                        CCToggle { label:"Power Profiles"; value:Config.showPowerProfiles;  onToggled:function(v){Config.showPowerProfiles=v} }
                                        CCToggle { label:"Overview";       value:Config.showOverview;       onToggled:function(v){Config.showOverview=v} }
                                        CCToggle { label:"Notifications";  value:Config.showNotifications;  onToggled:function(v){Config.showNotifications=v} }
                                        CCToggle { label:"Wallpaper Btn";  value:Config.showWallpaper;      onToggled:function(v){Config.showWallpaper=v} }
                                        CCToggle { label:"System Tray";    value:Config.showTray;           onToggled:function(v){Config.showTray=v} }
                                        CCToggle { label:"Active Window";  value:Config.showWindow;         onToggled:function(v){Config.showWindow=v} }
                                        CCToggle { label:"Distro Icon";    value:Config.showDistro;         onToggled:function(v){Config.showDistro=v} }

                                        Item { height: 10 }
                                    }
                                }
                            }
                        }
                    }

                    // ── TAB 1: Hyprland ─────────────────────────────────────
                    CCScrollPane {
                        ColumnLayout {
                            width: parent.width; spacing: 5

                            CCSection { text: " Hyprland" }

                            CCToggle {
                                id: sunsetToggle; label: "Hyprsunset"; value: false
                                onToggled: function(v) {
                                    if (v) _sunsetOn.running = true
                                    else   _sunsetOff.running = true
                                }
                            }
                            Process { id: _sunsetOn;  command: ["bash","-c","hyprsunset &"]; running: false }
                            Process { id: _sunsetOff; command: ["pkill","hyprsunset"];       running: false }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text { text:"Gamma"; color:Theme.cPrimary; font.family:Config.labelFont; font.pixelSize:13; Layout.preferredWidth:100 }
                                CCPillBtn { text:"−10"; onClicked: _gammaDec.running=true }
                                CCPillBtn { text:"+10"; onClicked: _gammaInc.running=true }
                            }
                            Process { id: _gammaDec; command:["hyprctl","hyprsunset","gamma","-10"]; running:false }
                            Process { id: _gammaInc; command:["hyprctl","hyprsunset","gamma","+10"]; running:false }

                            CCPillBtn { text:"󰈊  Hyprpicker"; onClicked:_picker.running=true }
                            Process { id:_picker; command:["hyprpicker"]; running:false }

                            CCToggle { id:xrayToggle; label:"X-Ray"; value:false; onToggled:function(v){_xray.running=true} }
                            Process { id:_xray; command:["bash",Config.hyprScripts+"/xray.sh"]; running:false }

                            CCToggle { id:opacToggle; label:"Opacity"; value:false; onToggled:function(v){_opac.running=true} }
                            Process { id:_opac; command:["bash","-c","$HOME/.config/hypr/scripts/window-opacity.sh"]; running:false }

                            RowLayout { Layout.fillWidth:true; spacing:8
                                Text { text:"Opacity"; color:Theme.cPrimary; font.family:Config.labelFont; font.pixelSize:13; Layout.preferredWidth:100 }
                                CCPillBtn { text:"−"; onClicked:_opacDec.running=true }
                                CCPillBtn { text:"+"; onClicked:_opacInc.running=true }
                            }
                            Process { id:_opacDec; command:["bash","-c","f=\"$HOME/.config/hypr/hyprviz.conf\"; v=$(grep 'active_opacity' \"$f\" | grep -oP '[0-9.]+'); nv=$(echo \"$v - 0.05\" | bc); [ $(echo \"$nv >= 0\" | bc) -eq 1 ] && sed -i \"s/active_opacity = .*/active_opacity = $nv/\" \"$f\" && sed -i \"s/inactive_opacity = .*/inactive_opacity = $nv/\" \"$f\" && hyprctl reload"]; running:false }
                            Process { id:_opacInc; command:["bash","-c","f=\"$HOME/.config/hypr/hyprviz.conf\"; v=$(grep 'active_opacity' \"$f\" | grep -oP '[0-9.]+'); nv=$(echo \"$v + 0.05\" | bc); [ $(echo \"$nv <= 1\" | bc) -eq 1 ] && sed -i \"s/active_opacity = .*/active_opacity = $nv/\" \"$f\" && sed -i \"s/inactive_opacity = .*/inactive_opacity = $nv/\" \"$f\" && hyprctl reload"]; running:false }

                            RowLayout { Layout.fillWidth:true; spacing:8
                                Text { text:"Blur Size"; color:Theme.cPrimary; font.family:Config.labelFont; font.pixelSize:13; Layout.preferredWidth:100 }
                                CCPillBtn { text:"−"; onClicked:_blurSzDec.running=true }
                                CCPillBtn { text:"+"; onClicked:_blurSzInc.running=true }
                            }
                            Process { id:_blurSzDec; command:["bash","-c","f=\"$HOME/.config/hypr/hyprviz.conf\"; v=$(sed -n '/blur {/,/}/{ s/.*size = \\([0-9]*\\).*/\\1/p }' \"$f\"); nv=$((v > 0 ? v - 1 : 0)); sed -i \"/blur {/,/}/{s/size = $v/size = $nv/}\" \"$f\" && hyprctl reload"]; running:false }
                            Process { id:_blurSzInc; command:["bash","-c","f=\"$HOME/.config/hypr/hyprviz.conf\"; v=$(sed -n '/blur {/,/}/{ s/.*size = \\([0-9]*\\).*/\\1/p }' \"$f\"); nv=$((v + 1)); sed -i \"/blur {/,/}/{s/size = $v/size = $nv/}\" \"$f\" && hyprctl reload"]; running:false }

                            RowLayout { Layout.fillWidth:true; spacing:8
                                Text { text:"Blur Passes"; color:Theme.cPrimary; font.family:Config.labelFont; font.pixelSize:13; Layout.preferredWidth:100 }
                                CCPillBtn { text:"−"; onClicked:_blurPDec.running=true }
                                CCPillBtn { text:"+"; onClicked:_blurPInc.running=true }
                            }
                            Process { id:_blurPDec; command:["bash","-c","f=\"$HOME/.config/hypr/hyprviz.conf\"; v=$(grep 'passes = ' \"$f\" | grep -oP '[0-9]+'); nv=$((v > 0 ? v - 1 : 0)); sed -i \"s/passes = $v/passes = $nv/\" \"$f\" && hyprctl reload"]; running:false }
                            Process { id:_blurPInc; command:["bash","-c","f=\"$HOME/.config/hypr/hyprviz.conf\"; v=$(grep 'passes = ' \"$f\" | grep -oP '[0-9]+'); nv=$((v + 1)); sed -i \"s/passes = $v/passes = $nv/\" \"$f\" && hyprctl reload"]; running:false }

                            CCSection { text:"Gap Presets" }
                            Flow { Layout.fillWidth:true; spacing:5
                                Repeater {
                                    model:["minimal","balanced","spacious","zero"]
                                    delegate: CCPillBtn {
                                        required property string modelData
                                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                        onClicked: { _gapProc.command=["bash","-c","$HOME/.config/hyprcandy/hooks/hyprland_gap_presets.sh "+modelData]; _gapProc.running=true }
                                    }
                                }
                            }
                            Process { id:_gapProc; running:false }
                            Item { height:10 }
                        }
                    }

                    // ── TAB 2: Themes ────────────────────────────────────────
                    CCScrollPane {
                        ColumnLayout {
                            width: parent.width; spacing: 5
                            CCSection { text: "󰔎 Matugen Themes" }
                            Flow { Layout.fillWidth: true; spacing: 5
                                Repeater {
                                    model: [
                                        {name:"Fidelity",   scheme:"scheme-fidelity"},
                                        {name:"Monochrome", scheme:"scheme-monochrome"},
                                        {name:"Content",    scheme:"scheme-content"},
                                        {name:"Expressive", scheme:"scheme-expressive"},
                                        {name:"Neutral",    scheme:"scheme-neutral"},
                                        {name:"Rainbow",    scheme:"scheme-rainbow"},
                                        {name:"Tonal-spot", scheme:"scheme-tonal-spot"},
                                        {name:"Fruit",      scheme:"scheme-fruit-salad"},
                                        {name:"Vibrant",    scheme:"scheme-vibrant"}
                                    ]
                                    delegate: CCPillBtn {
                                        required property var modelData
                                        text: modelData.name
                                        onClicked: {
                                            _themeProc.command = ["bash","-c",
                                                "sed -i 's/--type scheme-[^ ]*/--type "+modelData.scheme+"/' \"$HOME/.config/hyprcandy/hooks/wallpaper_integration.sh\" && " +
                                                "bash \"$HOME/.config/hyprcandy/hooks/wallpaper_integration.sh\" && " +
                                                "echo '"+modelData.scheme+"' > \"$HOME/.config/hyprcandy/matugen-state\""]
                                            _themeProc.running = true
                                        }
                                    }
                                }
                            }
                            Process { id:_themeProc; running:false }
                            Item { height:10 }
                        }
                    }

                    // ── TAB 3: Dock ──────────────────────────────────────────
                    CCScrollPane {
                        ColumnLayout {
                            width: parent.width; spacing: 5
                            CCSection { text: "󰞒 Dock" }
                            CCPillBtn { text:"󰶘 Cycle Position"; onClicked:_dockCycle.running=true }
                            Process { id:_dockCycle; command:["bash",Config.candyDir+"/GJS/hyprcandydock/cycle.sh"]; running:false }
                            Repeater {
                                model:[{l:"Spacing",k:"buttonSpacing"},{l:"Padding",k:"innerPadding"},{l:"Border W",k:"borderWidth"},{l:"Border R",k:"borderRadius"}]
                                delegate: CCEntryRow {
                                    required property var modelData
                                    label: modelData.l
                                    onApplied: function(val) {
                                        const n = parseInt(val)
                                        if (!isNaN(n)) {
                                            _dockWrite.command=["bash","-c","f=\"$HOME/.hyprcandy/GJS/hyprcandydock/config.js\"; sed -i 's/"+modelData.k+": [0-9]*/"+modelData.k+": "+n+"/' \"$f\" && pkill -SIGUSR2 -f 'gjs dock-main.js'"]
                                            _dockWrite.running=true
                                        }
                                    }
                                }
                            }
                            Process { id:_dockWrite; running:false }
                            CCEntryRow {
                                label:"Icon Size"
                                onApplied: function(val) {
                                    const n=parseInt(val)
                                    if (!isNaN(n)&&n>=12&&n<=64){
                                        _dockIcon.command=["bash","-c","f=\"$HOME/.hyprcandy/GJS/hyprcandydock/config.js\"; sed -i 's/appIconSize: [0-9]*/appIconSize: "+n+"/' \"$f\" && t=\"$HOME/.hyprcandy/GJS/hyprcandydock/toggle.sh\"; bash \"$t\" && sleep 1 && bash \"$t\""]
                                        _dockIcon.running=true
                                    }
                                }
                            }
                            Process { id:_dockIcon; running:false }
                            Item { height:10 }
                        }
                    }

                    // ── TAB 4: Menus ─────────────────────────────────────────
                    CCScrollPane {
                        ColumnLayout {
                            width: parent.width; spacing: 5
                            CCSection { text: "󰮫 Menus (Rofi)" }
                            CCEntryRow { label:"Border px"; onApplied:function(v){const n=parseInt(v);if(!isNaN(n)){_rofiBorder.command=["bash","-c","sed -i 's/border-width: [0-9]*px/border-width: "+n+"px/' \"$HOME/.config/hyprcandy/settings/rofi-border.rasi\""]; _rofiBorder.running=true}} }
                            Process { id:_rofiBorder; running:false }
                            CCEntryRow { label:"Radius em"; onApplied:function(v){const n=parseFloat(v);if(!isNaN(n)){_rofiRadius.command=["bash","-c","sed -i 's/border-radius: [0-9.]*em/border-radius: "+n.toFixed(1)+"em/' \"$HOME/.config/hyprcandy/settings/rofi-border-radius.rasi\""]; _rofiRadius.running=true}} }
                            Process { id:_rofiRadius; running:false }
                            RowLayout { Layout.fillWidth:true; spacing:8
                                Text { text:"Icon Size"; color:Theme.cPrimary; font.family:Config.labelFont; font.pixelSize:13; Layout.preferredWidth:100 }
                                CCPillBtn { text:"−"; onClicked:_rofiIconDec.running=true }
                                CCPillBtn { text:"+"; onClicked:_rofiIconInc.running=true }
                            }
                            Process { id:_rofiIconDec; command:["bash","-c","f=\"$HOME/.config/rofi/config.rasi\"; v=$(sed -n '/element-icon/,/}/{s/.*size:[[:space:]]*\\([0-9.]*\\)em.*/\\1/p}' \"$f\"); nv=$(echo \"$v - 0.5\" | bc); [ $(echo \"$nv >= 0.5\" | bc) -eq 1 ] && sed -i \"/element-icon/,/}/{s/size:[[:space:]]*[0-9.]*em/size: ${nv}em/}\" \"$f\""]; running:false }
                            Process { id:_rofiIconInc; command:["bash","-c","f=\"$HOME/.config/rofi/config.rasi\"; v=$(sed -n '/element-icon/,/}/{s/.*size:[[:space:]]*\\([0-9.]*\\)em.*/\\1/p}' \"$f\"); nv=$(echo \"$v + 0.5\" | bc); sed -i \"/element-icon/,/}/{s/size:[[:space:]]*[0-9.]*em/size: ${nv}em/}\" \"$f\""]; running:false }
                            Item { height:10 }
                        }
                    }

                    // ── TAB 5: SDDM ──────────────────────────────────────────
                    CCScrollPane {
                        ColumnLayout {
                            width: parent.width; spacing: 5
                            CCSection { text: "󰍂 SDDM" }
                            CCEntryRow { label:"Header"; onApplied:function(v){_sddmHdr.command=["sudo","sed","-i","s|^HeaderText=.*|HeaderText="+v+"|","/usr/share/sddm/themes/sugar-candy/theme.conf"];_sddmHdr.running=true} }
                            Process { id:_sddmHdr; running:false }
                            CCEntryRow { label:"Form Pos"; onApplied:function(v){_sddmForm.command=["sudo","sed","-i","s|^FormPosition=.*|FormPosition="+v+"|","/usr/share/sddm/themes/sugar-candy/theme.conf"];_sddmForm.running=true} }
                            Process { id:_sddmForm; running:false }
                            CCEntryRow { label:"Blur R"; onApplied:function(v){const n=parseInt(v);if(!isNaN(n)){_sddmBlur.command=["sudo","sed","-i","s|^BlurRadius=.*|BlurRadius="+n+"|","/usr/share/sddm/themes/sugar-candy/theme.conf"];_sddmBlur.running=true}} }
                            Process { id:_sddmBlur; running:false }
                            CCPillBtn { text:"󰈈 Preview"; onClicked:_sddmPreview.running=true }
                            Process { id:_sddmPreview; command:["sddm-greeter","--test-mode","--theme","/usr/share/sddm/themes/sugar-candy"]; running:false }
                            Item { height:10 }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Wallpaper Picker Overlay
    //  Opens ABOVE the control center when the user icon is clicked.
    //  Grid of thumbnails; right-click any thumbnail → "Set as user icon" popover.
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: wpPickerOverlay

        // Positioned to cover the control center panel area; sits above it via z-order
        anchors.fill: panel
        z: 10
        visible: false
        radius: 20
        color: Qt.rgba(Theme.cOnSecondary.r, Theme.cOnSecondary.g,
                       Theme.cOnSecondary.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g, Theme.cOutVar.b, 0.40)
        clip: true

        scale: visible ? 1.0 : 0.94
        transformOrigin: Item.Top
        opacity: visible ? 1.0 : 0.0
        Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        function open()  { visible = true; wpScanProc.running = true }
        function close() { visible = false; wpContextMenu.visible = false }

        // State
        property var _wallpapers: []
        property string _contextTarget: ""
        property int    _ctxX: 0
        property int    _ctxY: 0

        // Scan wallpaper directory
        Process {
            id: wpScanProc
            command: ["bash", "-c",
                "find \"${HOME}/Pictures/Wallpapers\" -maxdepth 2 " +
                "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
                "2>/dev/null | sort | head -80"]
            running: false
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: function(l) {
                    if (l.trim()) {
                        const w = wpPickerOverlay._wallpapers
                        w.push(l.trim())
                        wpPickerOverlay._wallpapers = w.slice()
                    }
                }
            }
            onRunningChanged: {
                if (running) wpPickerOverlay._wallpapers = []
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰸉  Select Wallpaper / User Icon"
                    color: Theme.cPrimary
                    font.family: Config.labelFont; font.pixelSize: 15
                    font.weight: Font.SemiBold
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Right-click a wallpaper to set as user icon"
                    color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.5)
                    font.family: Config.labelFont; font.pixelSize: 11
                }
                Item { width: 10 }
                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: wpCloseHov.containsMouse
                        ? Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.15)
                        : Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.07)
                    Text {
                        anchors.centerIn: parent; text: "󰅙"
                        font.family: Config.fontFamily; font.pixelSize: 15
                        color: Theme.cPrimary
                    }
                    MouseArea {
                        id: wpCloseHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wpPickerOverlay.close()
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            // Separator
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g, Theme.cOutVar.b, 0.25) }

            // Thumbnail grid
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: wpGrid.implicitHeight + 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Invisible scrollbar
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 0; radius: 0
                        color: "transparent"
                    }
                    background: Rectangle { color: "transparent" }
                }

                Grid {
                    id: wpGrid
                    width: parent.width
                    columns: Math.max(2, Math.floor(parent.width / 160))
                    spacing: 8
                    anchors { left: parent.left; top: parent.top; topMargin: 6 }

                    Repeater {
                        model: wpPickerOverlay._wallpapers
                        delegate: Item {
                            required property string modelData
                            required property int index
                            width:  (wpGrid.width - wpGrid.spacing * (wpGrid.columns - 1)) / wpGrid.columns
                            height: width * 0.56

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                               Theme.cInversePrimary.b, 0.18)
                                border.width: wpThumbHov.containsMouse ? 2 : 1
                                border.color: wpThumbHov.containsMouse
                                    ? Theme.cPrimary
                                    : Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g, Theme.cOutVar.b, 0.28)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 0
                                    source: "file://" + parent.parent.modelData
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true; mipmap: true; asynchronous: true
                                }

                                // Loading placeholder
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.children[1].status !== Image.Ready
                                    text: "󰋩"
                                    font.family: Config.fontFamily; font.pixelSize: 24
                                    color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.3)
                                }

                                Behavior on border.color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: wpThumbHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        // Apply as wallpaper
                                        _wpApply.command = ["bash", "-c",
                                            "exec \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wallpaper/wallpaper-apply.sh\" \"" +
                                            parent.modelData + "\""]
                                        _wpApply.running = true
                                        wpPickerOverlay.close()
                                    } else {
                                        // Show context menu
                                        wpPickerOverlay._contextTarget = parent.modelData
                                        const mapped = parent.mapToItem(wpPickerOverlay, mouse.x, mouse.y)
                                        wpPickerOverlay._ctxX = mapped.x
                                        wpPickerOverlay._ctxY = mapped.y
                                        wpContextMenu.visible = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Tray-style right-click context menu ──────────────────────────────
        Rectangle {
            id: wpContextMenu
            visible: false
            x: Math.min(wpPickerOverlay._ctxX, wpPickerOverlay.width  - width  - 8)
            y: Math.min(wpPickerOverlay._ctxY, wpPickerOverlay.height - height - 8)
            width: 200; height: ctxCol.implicitHeight + 12
            z: 20
            radius: 14
            color: Qt.rgba(Theme.cOnSecondary.r, Theme.cOnSecondary.g,
                           Theme.cOnSecondary.b, 0.98)
            border.width: 1
            border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                  Theme.cPrimary.b, 0.25)

            // Shadow effect via border glow
            layer.enabled: true

            // Click-away to close
            MouseArea {
                parent: wpPickerOverlay
                anchors.fill: parent
                z: 15
                enabled: wpContextMenu.visible
                onClicked: wpContextMenu.visible = false
            }

            Column {
                id: ctxCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                spacing: 0

                // Context header
                Text {
                    leftPadding: 10; topPadding: 6; bottomPadding: 4
                    text: "Wallpaper"
                    color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.55)
                    font.family: Config.labelFont; font.pixelSize: 11
                }

                // Separator
                Rectangle {
                    width: parent.width - 12; height: 1; x: 6
                    color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.15)
                }

                // "Set as wallpaper" item
                Rectangle {
                    width: parent.width; height: 36; radius: 8
                    color: ctxWpHov.containsMouse
                        ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                  Theme.cInversePrimary.b, 0.35)
                        : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: "󰸉"; font.family: Config.fontFamily; font.pixelSize: 13; color: Theme.cPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Set as wallpaper"; font.family: Config.labelFont; font.pixelSize: 12; color: Theme.cPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: ctxWpHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            _wpApply.command = ["bash", "-c",
                                "exec \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wallpaper/wallpaper-apply.sh\" \"" +
                                wpPickerOverlay._contextTarget + "\""]
                            _wpApply.running = true
                            wpContextMenu.visible = false
                            wpPickerOverlay.close()
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                // "Set as user icon" item
                Rectangle {
                    width: parent.width; height: 36; radius: 8
                    color: ctxIconHov.containsMouse
                        ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                  Theme.cInversePrimary.b, 0.35)
                        : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: "󰀄"; font.family: Config.fontFamily; font.pixelSize: 13; color: Theme.cPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Set as user icon"; font.family: Config.labelFont; font.pixelSize: 12; color: Theme.cPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: ctxIconHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            _wpAsIcon.command = ["bash", "-c",
                                "f=\"" + wpPickerOverlay._contextTarget + "\" && " +
                                "magick \"$f\" -resize 96x96^ -gravity center -extent 96x96 " +
                                "  \\( +clone -alpha extract -fill black -colorize 100 " +
                                "     -fill white -draw 'circle 48,48 48,0' \\) " +
                                "  -alpha off -compose CopyOpacity -composite -strip " +
                                "  \"$HOME/.config/hyprcandy/user-icon.png\""]
                            _wpAsIcon.running = true
                            wpContextMenu.visible = false
                        }
                    }
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Processes
    // ═══════════════════════════════════════════════════════════════════════
    Process {
        id: userNameProc
        command: ["bash", "-c", "id -un"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(l) { if (l.trim()) userNameText.text = l.trim() }
        }
    }

    Process {
        id: userIconPicker
        command: ["bash", "-c",
            "f=$(zenity --file-selection --file-filter='Images | *.png *.jpg *.jpeg *.webp' 2>/dev/null) && " +
            "[ -n \"$f\" ] && " +
            "magick \"$f\" -resize 96x96^ -gravity center -extent 96x96 " +
            "  \\( +clone -alpha extract -fill black -colorize 100 " +
            "     -fill white -draw 'circle 48,48 48,0' \\) " +
            "  -alpha off -compose CopyOpacity -composite -strip " +
            "  \"$HOME/.config/hyprcandy/user-icon.png\""]
        running: false
        onExited: {
            userImg.source = ""
            userImg.source = "file://" + Config.home + "/.config/hyprcandy/user-icon.png?" + Date.now()
        }
    }

    Process {
        id: _wpApply
        running: false
    }

    Process {
        id: _wpAsIcon
        running: false
        onExited: {
            userImg.source = ""
            userImg.source = "file://" + Config.home + "/.config/hyprcandy/user-icon.png?" + Date.now()
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Reusable components
    // ═══════════════════════════════════════════════════════════════════════

    // ── Scrollable pane — invisible scrollbar ────────────────────────────
    component CCScrollPane: Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: _scrollContent.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Invisible scrollbar so it doesn't block slider values
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 0
                color: "transparent"
            }
            background: Rectangle { color: "transparent" }
        }
        default property alias scrollContent: _scrollContent.data
        ColumnLayout {
            id: _scrollContent
            width: parent.width - 10
            anchors { left: parent.left; leftMargin: 4; top: parent.top; topMargin: 10 }
            spacing: 0
        }
    }

    // ── Section heading ──────────────────────────────────────────────────
    component CCSection: RowLayout {
        property alias text: _sh.text
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 4
        Text {
            id: _sh
            color: Theme.cPrimary
            font.family: Config.labelFont
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 0.5
        }
        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.16)
        }
    }

    // ── Slider — exact match to startmenu SliderBg ───────────────────────
    //   Trough: 14px tall, innerH=8px, rounded border outline
    //   Fill:   inversePrimary→onPrimary gradient (horizontal)
    //   Thumb:  󰟃 dot-circle glyph
    component CCSlider: RowLayout {
        id: _ccsl
        property alias label: _lbl.text
        property real  from:      0
        property real  to:        1
        property real  stepSize:  1
        property real  value:     0
        property int   decimals:  0
        signal moved(real v)

        Layout.fillWidth: true
        spacing: 8

        Text {
            id: _lbl
            Layout.preferredWidth: 100
            color: Theme.cPrimary
            font.family: Config.labelFont; font.pixelSize: 13
            elide: Text.ElideRight
        }

        // Trough item — matches startmenu SliderBg exactly
        Item {
            id: _trough
            Layout.fillWidth: true
            height: 22

            readonly property int tH: 14
            readonly property int pad: 3
            readonly property int iH: tH - pad * 2
            readonly property real norm: _ccsl.to > _ccsl.from
                ? Math.max(0, Math.min(1, (_ccsl.value - _ccsl.from) / (_ccsl.to - _ccsl.from)))
                : 0

            Item {
                y: (_trough.height - _trough.tH) / 2
                width: parent.width; height: _trough.tH

                // Trough background
                Rectangle {
                    anchors.fill: parent; radius: _trough.tH / 2
                    color: Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g, Theme.cOutVar.b, 0.28)
                    border.width: 1
                    border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.55)
                }

                // Gradient fill — clip to filled portion
                Item {
                    x: _trough.pad; y: _trough.pad
                    width:  Math.max(0, (parent.width - _trough.pad * 2) * _trough.norm)
                    height: _trough.iH
                    clip: true
                    Rectangle {
                        width:  parent.parent.width - _trough.pad * 2
                        height: _trough.iH
                        radius: _trough.iH / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.cInversePrimary }
                            GradientStop { position: 1.0; color: Theme.cOnPrimary }
                        }
                    }
                }

                // Dot-glyph thumb (󰟃) — matches startmenu
                Text {
                    text: "󰟃"
                    font.family: "Symbols Nerd Font Mono"
                    font.pixelSize: _trough.iH + 2
                    color: Theme.cPrimary
                    style: Text.Outline; styleColor: Qt.rgba(0,0,0,0.25)
                    x: {
                        const tw = parent.width - _trough.pad * 2
                        const cx = _trough.pad + tw * _trough.norm - implicitWidth / 2
                        return Math.max(_trough.pad - implicitWidth/2 + 1,
                               Math.min(parent.width - _trough.pad - implicitWidth/2 - 1, cx))
                    }
                    y: (_trough.tH - implicitHeight) / 2
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function _calc(mx) {
                    const n = Math.max(0, Math.min(1, mx / width))
                    const raw = _ccsl.from + n * (_ccsl.to - _ccsl.from)
                    const stepped = _ccsl.stepSize > 0
                        ? Math.round(raw / _ccsl.stepSize) * _ccsl.stepSize : raw
                    return Math.max(_ccsl.from, Math.min(_ccsl.to, stepped))
                }
                onPressed:         function(m) { const v=_calc(m.x); _ccsl.value=v; _ccsl.moved(v) }
                onPositionChanged: function(m) { if(pressed){const v=_calc(m.x); _ccsl.value=v; _ccsl.moved(v)} }
                onWheel:           function(e) {
                    const dir = e.angleDelta.y > 0 ? 1 : -1
                    const step = _ccsl.stepSize > 0 ? _ccsl.stepSize : (_ccsl.to - _ccsl.from) * 0.02
                    const v = Math.max(_ccsl.from, Math.min(_ccsl.to, _ccsl.value + step * dir))
                    _ccsl.value = v; _ccsl.moved(v)
                }
            }
        }

        // Value readout — fixed width so slider doesn't jump
        Text {
            Layout.preferredWidth: 40
            text: _ccsl.decimals > 0
                ? _ccsl.value.toFixed(_ccsl.decimals)
                : Math.round(_ccsl.value).toString()
            color: Theme.cPrimary
            font.family: Config.labelFont; font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
        }
    }

    // ── Toggle ───────────────────────────────────────────────────────────
    component CCToggle: RowLayout {
        property alias label: _tl.text
        property bool  value: false
        signal toggled(bool v)

        Layout.fillWidth: true; spacing: 8

        Text {
            id: _tl
            Layout.preferredWidth: 130
            color: Theme.cPrimary
            font.family: Config.labelFont; font.pixelSize: 13
            elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        // iOS-style pill toggle
        Rectangle {
            id: _pill
            width: 46; height: 26; radius: 13
            color: value
                ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                          Theme.cInversePrimary.b, 0.9)
                : Qt.rgba(Theme.cOutVar.r, Theme.cOutVar.g, Theme.cOutVar.b, 0.35)
            border.width: 1
            border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                  Theme.cPrimary.b, value ? 0.6 : 0.2)

            Rectangle {
                width: 20; height: 20; radius: 10
                color: value ? Theme.cPrimary : Theme.cOnSurfVar
                anchors.verticalCenter: parent.verticalCenter
                x: value ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { value = !value; toggled(value) }
            }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // ── Segmented control ────────────────────────────────────────────────
    component CCSegmented: RowLayout {
        property alias label: _sgl.text
        property var   options: []
        property string current: ""
        signal picked(string v)

        Layout.fillWidth: true; spacing: 8

        Text {
            id: _sgl
            Layout.preferredWidth: 100
            color: Theme.cPrimary
            font.family: Config.labelFont; font.pixelSize: 13
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.preferredWidth: Math.min(360, options.length * 88)
            height: 28; radius: 9
            color: Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                           Theme.cInversePrimary.b, 0.12)
            border.width: 1
            border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                  Theme.cPrimary.b, 0.18)

            Row {
                anchors.fill: parent; anchors.margins: 2; spacing: 2
                Repeater {
                    model: options
                    delegate: Rectangle {
                        required property string modelData
                        width: (parent.width - (options.length - 1) * 2) / options.length
                        height: parent.height; radius: 7
                        color: current === modelData
                            ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                                      Theme.cInversePrimary.b, 0.82)
                            : "transparent"
                        border.width: current === modelData ? 1 : 0
                        border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                              Theme.cPrimary.b, 0.45)

                        Text {
                            anchors.centerIn: parent
                            text: modelData; color: Theme.cPrimary
                            font.family: Config.labelFont; font.pixelSize: 12
                            font.weight: current === modelData ? Font.SemiBold : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: picked(modelData)
                        }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }
            }
        }
    }

    // ── Pill button ──────────────────────────────────────────────────────
    component CCPillBtn: Rectangle {
        id: _pb
        property alias text: _pbt.text
        property bool  active: false
        signal clicked()

        implicitWidth: _pbt.implicitWidth + 22
        implicitHeight: 30; radius: 9
        color: active
            ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                      Theme.cInversePrimary.b, 0.82)
            : (pbma.containsMouse
                ? Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                          Theme.cInversePrimary.b, 0.38)
                : Qt.rgba(Theme.cInversePrimary.r, Theme.cInversePrimary.g,
                          Theme.cInversePrimary.b, 0.16))
        border.width: 1
        border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                              Theme.cPrimary.b, active ? 0.55 : 0.2)

        Text {
            id: _pbt; anchors.centerIn: parent
            color: Theme.cPrimary
            font.family: Config.labelFont; font.pixelSize: 12
        }
        MouseArea {
            id: pbma; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: _pb.clicked()
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Icon / glyph text entry ──────────────────────────────────────────
    component CCIconEntry: RowLayout {
        property alias label: _iel.text
        property string value: ""
        signal applied(string v)

        Layout.fillWidth: true; spacing: 8

        Text {
            id: _iel
            Layout.preferredWidth: 100
            color: Theme.cPrimary
            font.family: Config.labelFont; font.pixelSize: 13
            elide: Text.ElideRight
        }
        Text {
            text: value !== "" ? value : "—"
            font.family: Config.fontFamily; font.pixelSize: 18
            color: Theme.cPrimary; Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
        }
        Rectangle {
            Layout.preferredWidth: 160; height: 28; radius: 7
            color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.2)
            TextInput {
                anchors { fill: parent; margins: 6 }
                text: value; color: Theme.cPrimary
                font.family: Config.labelFont; font.pixelSize: 12
                verticalAlignment: TextInput.AlignVCenter; clip: true
                onAccepted: applied(text)
                onEditingFinished: applied(text)
            }
        }
    }

    // ── Text entry row ───────────────────────────────────────────────────
    component CCEntryRow: RowLayout {
        property alias label: _erl.text
        signal applied(string val)

        Layout.fillWidth: true; spacing: 8

        Text {
            id: _erl
            Layout.preferredWidth: 100
            color: Theme.cPrimary
            font.family: Config.labelFont; font.pixelSize: 13
            elide: Text.ElideRight
        }
        Rectangle {
            Layout.preferredWidth: 180; height: 28; radius: 7
            color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g, Theme.cPrimary.b, 0.2)
            TextInput {
                anchors { fill: parent; margins: 6 }
                color: Theme.cPrimary
                font.family: Config.labelFont; font.pixelSize: 12
                verticalAlignment: TextInput.AlignVCenter; clip: true
                onAccepted: applied(text)
            }
        }
    }

    // ── Color picker (matugen palette swatches) ──────────────────────────
    component CCColorPicker: ColumnLayout {
        property alias label: _cpl.text
        property color currentColor: Theme.cPrimary
        property bool  enabled: true

        Layout.fillWidth: true; spacing: 4
        opacity: enabled ? 1.0 : 0.4

        RowLayout {
            Layout.fillWidth: true
            Text {
                id: _cpl; Layout.preferredWidth: 100
                color: Theme.cPrimary
                font.family: Config.labelFont; font.pixelSize: 13
            }
            Rectangle {
                width: 24; height: 16; radius: 5
                color: currentColor
                border.width: 1
                border.color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                                      Theme.cPrimary.b, 0.4)
            }
            Text {
                text: currentColor.toString().toUpperCase()
                color: Qt.rgba(Theme.cPrimary.r, Theme.cPrimary.g,
                               Theme.cPrimary.b, 0.55)
                font.family: Config.labelFont; font.pixelSize: 10
            }
        }

        Flow {
            Layout.fillWidth: true; spacing: 5
            Repeater {
                model: [
                    Theme.cPrimary, Theme.cInversePrimary, Theme.cPrimaryContainer,
                    Theme.cSecondary, Theme.cTertiary, Theme.cTertiaryContainer,
                    Theme.cOnPrimary, Theme.cOnSecondary, Theme.cOnSurf,
                    Theme.cSurfLow, Theme.cSurfMid, Theme.cSurfHi,
                    Theme.cErr, Theme.cOutVar, Theme.cScrim
                ]
                delegate: Rectangle {
                    required property color modelData
                    width: 22; height: 22; radius: 5
                    color: modelData
                    border.width: currentColor.toString() === modelData.toString() ? 2 : 0
                    border.color: Theme.cPrimary
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (parent.parent.parent.parent.enabled) currentColor = modelData
                    }
                }
            }
        }
    }
}
