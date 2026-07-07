import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
// ============================================================================
//  TTS GROUP — Custom Fly View overlay (HUD + Tactical Map + Mission + Status)
//  All displayed values come from the real active vehicle. No fake/demo data.
// ============================================================================
Item {
    id: root
    anchors.fill: parent
    // ── Interface hooks required by QGC's FlyView (do not remove) ───────────
    property var parentToolInsets
    property var totalToolInsets: _toolInsets
    property var mapControl
    // ── Tool insets: tells QGC how much screen edge our overlay reserves ─────
    //     All zero here because this overlay draws its own full layout.
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       0
        leftEdgeCenterInset:    0
        leftEdgeBottomInset:    0
        rightEdgeTopInset:      0
        rightEdgeCenterInset:   0
        rightEdgeBottomInset:   0
        topEdgeLeftInset:       0
        topEdgeCenterInset:     0
        topEdgeRightInset:      0
        bottomEdgeLeftInset:    0
        bottomEdgeCenterInset:  0
        bottomEdgeRightInset:   0
    }
    // ── Palette: single source of truth for every colour in this file ───────
    readonly property color cBg:       "#0A0C0E"
    readonly property color cPanel:    "#111518"
    readonly property color cBorder:   "#1E2830"
    readonly property color cBorderHi: "#2E4050"
    readonly property color cNeon:     "#00FF88"
    readonly property color cNeonMid:  "#00CC6A"
    readonly property color cWhite:    "#DDE5EA"
    readonly property color cGrey:     "#4A6070"
    readonly property color cOrange:   "#FF6600"
    readonly property color cRed:      "#FF2244"
    readonly property color cGreyDark: "#1E2830"
    readonly property color cGreyMid:  "#3A4E5A"
    // ── Unit scale: every size below is "_u * factor" instead of a raw pixel,
    //     so the whole UI adapts to any screen size / DPI / user font setting ─
    readonly property real _u: ScreenTools.defaultFontPixelWidth
    // ── Layout heights: use ratios of window height (not _u) because these
    //     split a fixed vertical area; _u-based values could overflow on
    //     short windows ────────────────────────────────────────────────────
    readonly property real botPanH: root.height * 0.42
    readonly property real botBarH: root.height * 0.09
    readonly property int sidebarW: 0
    // ── Active vehicle handle + battery reference ───────────────────────────
    property var  _v:    QGroundControl.multiVehicleManager.activeVehicle
    property bool _ok:   _v !== null && _v !== undefined
    property var  _bat0: _ok && _v.batteries && _v.batteries.count > 0 ? _v.batteries.get(0) : null
    property real _bat:  _bat0 && _bat0.percentRemaining && _bat0.percentRemaining.value !== undefined ? _bat0.percentRemaining.value : 0
    // ── Message / notification counters from the vehicle ────────────────────
    property int  _msgCount: _ok ? _v.messageCount : 0
    property bool _msgWarn:  _ok ? _v.messageTypeWarning : false
    property bool _msgErr:   _ok ? _v.messageTypeError   : false
    // ── FACT ACCESS HELPER ──────────────────────────────────────────────────
    //     Some telemetry facts (groundSpeed / airSpeed / flightTime) do NOT
    //     hang directly off the Vehicle — they live inside the vehicle's
    //     "vehicle" FactGroup (registered in Vehicle.cc as
    //     _addFactGroup(_vehicleFactGroup, _vehicleFactGroupName /* "vehicle" */)).
    //     Other facts (heading, roll, pitch, altitudeAMSL, altitudeRelative)
    //     are reachable directly. This helper returns the real Fact from
    //     wherever it actually is, so the UI works regardless of layout and
    //     nothing breaks if a fact moves between builds.
    function _vf(name) {
        if (!_ok) return null
        var f = _v[name]
        if (f !== undefined && f !== null) return f
        if (_v.vehicle) {
            f = _v.vehicle[name]
            if (f !== undefined && f !== null) return f
        }
        return null
    }
    // Resolved Fact handles (re-resolve automatically when the vehicle changes)
    property var _factAir: _ok ? _vf("airSpeed")    : null
    property var _factGnd: _ok ? _vf("groundSpeed") : null
    property var _factFt:  _ok ? _vf("flightTime")  : null
    // ── RAW telemetry (always SI, never affected by user unit settings) ─────
    //     Used for drawing the HUD (horizon, tapes) so geometry stays stable.
    property real _rawHdg:    _ok && _v.heading.rawValue      !== undefined && !isNaN(_v.heading.rawValue)      ? _v.heading.rawValue      : 0
    property real _rawSpd:    (_factAir && _factAir.rawValue !== undefined && !isNaN(_factAir.rawValue)) ? _factAir.rawValue : 0
    property real _rawAlt:    _ok && _v.altitudeAMSL.rawValue !== undefined && !isNaN(_v.altitudeAMSL.rawValue) ? _v.altitudeAMSL.rawValue : 0
    property real _rawRoll:   _ok && _v.roll.rawValue         !== undefined && !isNaN(_v.roll.rawValue)         ? _v.roll.rawValue         : 0
    property real _rawPitch:  _ok && _v.pitch.rawValue        !== undefined && !isNaN(_v.pitch.rawValue)        ? _v.pitch.rawValue        : 0
    // ── DISPLAY telemetry (follows the user's unit settings) ────────────────
    //     Kept for readouts that should reflect the user's chosen units.
    property real _dispHdg:      _ok && _v.heading.value          !== undefined && !isNaN(_v.heading.value)          ? _v.heading.value          : 0
    property real _dispSpd:      (_factAir && _factAir.value !== undefined && !isNaN(_factAir.value)) ? _factAir.value : 0
    property real _dispAlt:      _ok && _v.altitudeAMSL.value     !== undefined && !isNaN(_v.altitudeAMSL.value)     ? _v.altitudeAMSL.value     : 0
    property real _dispAlt_AGL:  _ok && _v.altitudeRelative.value !== undefined && !isNaN(_v.altitudeRelative.value) ? _v.altitudeRelative.value : 0
    property real _dispGndSpd:   (_factGnd && _factGnd.value !== undefined && !isNaN(_factGnd.value)) ? _factGnd.value : 0
    // ── Raw ground speed in m/s (SI), used only for internal maths (ETA) ────
    //     _dispGndSpd stays for direct display since it follows the user unit.
    property real _rawGndSpd:    (_factGnd && _factGnd.rawValue !== undefined && !isNaN(_factGnd.rawValue)) ? _factGnd.rawValue : 0
    // ── Helper: extract just the number out of a QGC valueString ────────────
    //     valueString example: "42.8 kn" -> returns "42.8".
    function _numOnly(vs) {
        if (!vs) return "0"
        var parts = vs.toString().trim().split(" ")
        return parts.length > 0 ? parts[0] : "0"
    }
    // ── Speed text values, formatted exactly like native QGC ────────────────
    property string _spdText:     _factAir ? _numOnly(_factAir.valueString) : "0"
    property string _gndSpdText:  _factGnd ? _numOnly(_factGnd.valueString) : "0"
    // ── ALTITUDE UNIT FIX (uses QGC's own conversion, tied to VERTICAL) ─────
    //     Altitude (AMSL + AGL) must follow the VERTICAL distance setting, NOT
    //     the horizontal one. Reading altitudeAMSL.value/.units in this build
    //     picked up the HORIZONTAL unit (Nautical Miles), so altitude showed as
    //     "0.3 NM". Fix: use QGC's official QmlUnitsConversion helper — the same
    //     one QGC itself uses for AMSL altitude (see TerrainStatus.qml /
    //     MissionStats.qml). It converts metres straight into the user's chosen
    //     VERTICAL unit and gives the matching unit string, so there is NO manual
    //     maths here and it stays fully dynamic: change "Vertical Distance" in
    //     Settings and it updates live; "Horizontal Distance" no longer affects it.
    readonly property var _uc: QGroundControl.unitsConversion
    // Relative altitude (AGL) raw value — always metres (SI), unit-independent
    property real   _rawAltAGL:  _ok && _v.altitudeRelative.rawValue !== undefined && !isNaN(_v.altitudeRelative.rawValue) ? _v.altitudeRelative.rawValue : 0
    // Unit labels come straight from QGC's vertical-distance unit string ("m"/"ft")
    property string _unitAlt:    _uc ? _uc.appSettingsVerticalDistanceUnitsString : qsTr("m")
    property string _unitAltAGL: _uc ? _uc.appSettingsVerticalDistanceUnitsString : qsTr("m")
    // Values converted by QGC from metres into the user's vertical unit
    property string _altText:    (_ok && _uc) ? _uc.metersToAppSettingsVerticalDistanceUnits(root._rawAlt).toFixed(1)    : "0.0"
    property string _altAglText: (_ok && _uc) ? _uc.metersToAppSettingsVerticalDistanceUnits(root._rawAltAGL).toFixed(1) : "0.0"
    // ── Remaining display-unit labels (speed / wind / voltage) ──────────────
    property string _unitSpd:    _factAir ? _factAir.units : qsTr("m/s")
    property string _unitGndSpd: _factGnd ? _factGnd.units : qsTr("m/s")
    property string _unitVolt:   _bat0 && _bat0.voltage ? _bat0.voltage.units : qsTr("V")
    property string _unitWndSpd: _ok ? _v.wind.speed.units  : qsTr("m/s")
    // ── Ground-speed session MAX / MIN tracker (updated on every change) ────
    property real _spdMax:  0
    property real _spdMin:  0
    property bool _spdInit: false
    on_DispGndSpdChanged: {
        if (_ok) {
            if (!_spdInit) {
                _spdMax  = _dispGndSpd
                _spdMin  = _dispGndSpd
                _spdInit = true
            } else {
                if (_dispGndSpd > _spdMax) _spdMax = _dispGndSpd
                if (_dispGndSpd < _spdMin) _spdMin = _dispGndSpd
            }
        }
    }
    // ── ROOT LAYOUT: video/HUD on top, map+mission in middle, status at bottom
    Column {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.right:      parent.right
            anchors.left:       parent.left
            anchors.leftMargin: root.sidebarW
            spacing: 0
            // ── TOP AREA: background image + full HUD overlay ───────────────
            Item {
                id: videoArea
                width:  parent.width
                height: parent.height - root.botPanH - root.botBarH
                // Background terrain image (behind the whole HUD)
                Image {
                    anchors.fill: parent
                    source:   "qrc:/res/terrain_bg.png"
                    fillMode: Image.PreserveAspectCrop
                }
                // ── MINI HEADING TAPE (reversed "outside observer" heading) ──
                //     Scale is relative to its own size, not _u, so it adapts.
                Item {
                    id: miniHdgTape
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Positioned above the SPD / ALT tapes with a small gap
                    anchors.topMargin: spdTape.y - height - root._u * 3
                    z: 200
                    // Width: 42% of video width, clamped by _u safety bounds
                    // Height: 9% of video height, clamped by _u safety bounds
                    width:  Math.max(root._u * 32, Math.min(root._u * 70, parent.width * 0.42))
                    height: Math.max(root._u *  6, Math.min(root._u * 12, parent.height * 0.09))
                    clip: true
                    // Mini heading scale: everything inside scales with height
                    readonly property real _mhs: height / 45
                    // Dim background strip
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.4)
                    }
                    // Scrolling degree strip (reversed direction)
                    Row {
                        id: miniHdgRow
                        width: miniHdgTape._mhs * 40 * 60
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Reversed scroll offset
                        anchors.horizontalCenterOffset: (safeHdgMini % 10) * miniHdgTape._mhs * 6
                        property real safeHdgMini: Number.isFinite(root._rawHdg) ? root._rawHdg : 0
                        Repeater {
                            model: 40
                            delegate: Item {
                                width: miniHdgTape._mhs * 60; height: miniHdgTape._mhs * 36
                                // Reversed degree mapping
                                property int normDeg: ((Math.floor(miniHdgRow.safeHdgMini / 10) + 20 - index) * 10 % 360 + 360) % 360
                                // Tick mark (N drawn in red)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.topMargin: miniHdgTape._mhs * 4
                                    width: 1; height: normDeg % 30 === 0 ? miniHdgTape._mhs * 14 : miniHdgTape._mhs * 8
                                    color: normDeg === 0 ? root.cRed : root.cNeonMid
                                }
                                // Cardinal / numeric label
                                Text {
                                    visible: normDeg % 10 === 0
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.bold: true
                                    anchors.bottomMargin: miniHdgTape._mhs * 4
                                    text: normDeg===0   ? qsTr("N") :
                                          normDeg===90  ? qsTr("E") :
                                          normDeg===180 ? qsTr("S") :
                                          normDeg===270 ? qsTr("W") : normDeg.toString()
                                    font.pixelSize: normDeg % 30 === 0 ? miniHdgTape._mhs * 14 : miniHdgTape._mhs * 11
                                    font.family: "monospace"
                                    color: normDeg===0 ? root.cRed : (normDeg % 90 === 0 ? root.cWhite : root.cNeonMid)
                                }
                            }
                        }
                    }
                    // Current-heading readout box (bottom centre)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: miniHdgTape._mhs * 2
                        width: miniHdgTape._mhs * 40; height: miniHdgTape._mhs * 16
                        color: "transparent"
                        border.color: root.cNeonMid
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: (Number.isFinite(root._dispHdg) ? root._dispHdg : 0).toFixed(0).padStart(3,"0")
                            font.pixelSize: miniHdgTape._mhs * 9; font.bold: true; font.family: "monospace"; color: root.cNeonMid
                        }
                    }
                    // Centre pointer triangle (top)
                    Canvas {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: miniHdgTape._mhs * 18; height: miniHdgTape._mhs * 11
                        property real hs: miniHdgTape._mhs
                        onHsChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.clearRect(0,0,width,height)
                            c.fillStyle = root.cNeon
                            c.beginPath(); c.moveTo(0,0); c.lineTo(width,0); c.lineTo(width/2,height); c.closePath(); c.fill()
                        }
                    }
                }
                // ── ARTIFICIAL HORIZON ("outside observer" mode, fully scaled)
                //     Everything is drawn against _hs so it grows/shrinks with
                //     the available video area.
                Item {
                    id: ahCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    // Horizon scale: based on smallest dimension, clamped
                    readonly property real _hs: Math.max(0.6, Math.min(2.5, Math.min(width / 700, height / 400)))
                    // Pitch ladder + horizon line + roll indicator (canvas)
                    Canvas {
                        id: ahCanvas
                        anchors.fill: parent
                        property real ahRoll:  root._rawRoll
                        property real ahPitch: root._rawPitch
                        property real hs:      ahCenter._hs
                        onAhRollChanged:  requestPaint()
                        onAhPitchChanged: requestPaint()
                        onHsChanged:      requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width/2, cy = height/2
                            var s  = hs   // horizon scale — every number multiplied by s
                            // Reversed: pitch sign negative, 3.9 px per degree * s
                            var pitchPx = -ahPitch * 3.9 * s
                            var rollRad = ahRoll * Math.PI / 180
                            ctx.save()
                            ctx.translate(cx, cy)
                            ctx.rotate(rollRad)
                            // One pitch-ladder rung with optional side labels
                            function pitchLine(deg, lineWidth, label) {
                                var y = -deg * 3.9 * s + pitchPx
                                ctx.strokeStyle = "rgba(255,255,255,0.9)"
                                ctx.lineWidth = 1.5
                                ctx.beginPath()
                                ctx.moveTo(-lineWidth/2, y); ctx.lineTo(lineWidth/2, y)
                                ctx.stroke()
                                if (label !== "") {
                                    ctx.fillStyle = "rgba(255,255,255,0.9)"
                                    ctx.font = (13 * s) + "px monospace"
                                    ctx.textAlign = "center"; ctx.textBaseline = "middle"
                                    ctx.fillText(label, -lineWidth/2 - 18*s, y)
                                    ctx.fillText(label,  lineWidth/2 + 18*s, y)
                                }
                            }
                            pitchLine(20, 140*s, "20")
                            pitchLine(10, 100*s, "10")
                            pitchLine(-10, 100*s, "-10")
                            pitchLine(-20, 140*s, "-20")
                            // Green horizon line
                            var hy = pitchPx
                            ctx.strokeStyle = root.cNeon
                            ctx.lineWidth = 1.5
                            ctx.beginPath()
                            ctx.moveTo(-140*s, hy); ctx.lineTo(140*s, hy)
                            ctx.stroke()
                            ctx.restore()
                            // Fixed aircraft-reference brackets (no roll)
                            ctx.strokeStyle = root.cWhite; ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(cx-150*s, cy+20*s); ctx.lineTo(cx-110*s, cy+20*s); ctx.lineTo(cx-90*s, cy)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(cx+150*s, cy+20*s); ctx.lineTo(cx+110*s, cy+20*s); ctx.lineTo(cx+90*s, cy)
                            ctx.stroke()
                            // Roll indicator triangle (rotates with roll)
                            ctx.save()
                            ctx.translate(cx, cy)
                            ctx.rotate(rollRad)
                            ctx.fillStyle = root.cNeon
                            ctx.beginPath()
                            ctx.moveTo(-6*s, -100*s); ctx.lineTo(0, -90*s); ctx.lineTo(6*s, -100*s)
                            ctx.closePath(); ctx.fill()
                            ctx.restore()
                        }
                    }
                    // Centre crosshair ring (scaled)
                    Canvas {
                        anchors.centerIn: parent
                        width: 60 * ahCenter._hs; height: 60 * ahCenter._hs
                        property real hs: ahCenter._hs
                        onHsChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.clearRect(0,0,width,height)
                            var cx=width/2, cy=height/2, s=hs
                            c.strokeStyle = root.cNeon; c.lineWidth = 1.5
                            c.beginPath(); c.arc(cx,cy,14*s,0,Math.PI*2); c.stroke()
                            var dirs=[[0,-1],[0,1],[-1,0],[1,0]]
                            for (var i=0;i<4;i++) {
                                c.beginPath()
                                c.moveTo(cx+dirs[i][0]*17*s, cy+dirs[i][1]*17*s)
                                c.lineTo(cx+dirs[i][0]*26*s, cy+dirs[i][1]*26*s)
                                c.stroke()
                            }
                            c.fillStyle = root.cNeon
                            c.beginPath(); c.arc(cx,cy,2*s,0,Math.PI*2); c.fill()
                        }
                    }
                    // Dashed flight-path line under centre (scaled)
                    Canvas {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 14 * ahCenter._hs
                        width: 240 * ahCenter._hs; height: 4
                        property real hs: ahCenter._hs
                        onHsChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.clearRect(0,0,width,height)
                            c.strokeStyle = root.cNeon; c.lineWidth = 1.5
                            c.setLineDash([6*hs, 5*hs])
                            c.beginPath()
                            c.moveTo(0, 2); c.lineTo(width, 2)
                            c.stroke()
                            c.setLineDash([])
                        }
                    }
                    // Small tick-mark row across centre (scaled)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 56 * ahCenter._hs
                        Repeater {
                            model: 6
                            Rectangle {
                                width: 2 * ahCenter._hs; height: 14 * ahCenter._hs
                                color: index === 2 || index === 3 ? "transparent" : root.cNeon
                            }
                        }
                    }
                }
                // ── SPEED TAPE (left of centre) ─────────────────────────────
                //     Height adapts to video area; inner items scale with _ts.
                Item {
                    id: spdTape
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -Math.max(root._u * 15, Math.min(root._u * 50, parent.width * 0.25))
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    height: Math.max(root._u * 18, Math.min(root._u * 32, parent.height * 0.55))
                    width:  height * (7.2 / 28)
                    // Tape scale: all inner lines/positions derive from _ts
                    readonly property real _ts: height / 28
                    // Header label ("SPD" + current speed unit)
                    Text {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("AIR SPD") + "\n" + root._unitSpd
                        font.pixelSize: spdTape._ts * 2; font.bold: true; font.family: "monospace"; color: root.cNeon
                        horizontalAlignment: Text.AlignHCenter
                    }
                    // Scrolling number column (clipped viewport)
                    Item {
                        anchors.top: parent.top
                        anchors.topMargin: spdTape._ts * 5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: spdTape._ts * 16.8
                        clip: true
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: (root._rawSpd % 20) * spdTape._ts * 0.84
                            spacing: spdTape._ts * 2.8
                            Repeater {
                                model: 9
                                delegate: Row {
                                    spacing: spdTape._ts * 0.6
                                    property real val: ((root._rawSpd/20|0) + 4 - index) * 20
                                    Rectangle { width: spdTape._ts * 1.6; height: Math.max(1, spdTape._ts * 0.2); color: root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                                    Text { text: Math.max(0, val).toFixed(0); font.bold:true; font.pixelSize: spdTape._ts * 2; font.family:"monospace"; color: root.cWhite }
                                }
                            }
                        }
                    }
                    // Fixed current-value box (numbers scroll behind it)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: spdTape._ts * 11.7
                        height: spdTape._ts * 3.4
                        color: root.cNeon
                        clip: true
                        Text {
                            anchors.centerIn: parent
                            text: root._spdText
                            font.bold:true; color:root.cBg; font.family:"monospace"
                            width: parent.width - (spdTape._ts * 1.2)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: spdTape._ts * 0.8
                            font.pixelSize: spdTape._ts * 2.2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.AlignRight
                        }
                    }
                }
                // ── ALTITUDE TAPE (right of centre) ─────────────────────────
                //     Reads AMSL; number/unit now driven by _altText/_unitAlt
                //     (vertical-distance setting), fixing the "NM" bug.
                Item {
                    id: altTape
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: Math.max(root._u * 15, Math.min(root._u * 50, parent.width * 0.25))
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    height: Math.max(root._u * 18, Math.min(root._u * 32, parent.height * 0.55))
                    width:  height * (7.6 / 28)
                    // Tape scale
                    readonly property real _ts: height / 28
                    // Header label ("ALT AMSL" + current altitude unit)
                    Text {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("ALT AMSL") + "\n" + root._unitAlt
                        font.pixelSize: altTape._ts * 2; font.bold: true; font.family: "monospace"; color: root.cNeon
                        horizontalAlignment: Text.AlignHCenter
                    }
                    // Scrolling number column (clipped viewport)
                    Item {
                        anchors.top: parent.top
                        anchors.topMargin: altTape._ts * 5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: altTape._ts * 16.8
                        clip: true
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: (root._rawAlt % 100) * altTape._ts * 0.168
                            spacing: altTape._ts * 2.8
                            Repeater {
                                model: 9
                                delegate: Row {
                                    spacing: altTape._ts * 0.6
                                    property real val: ((root._rawAlt/100|0) + 4 - index) * 100
                                    Text { text: val.toFixed(0); font.bold:true; font.pixelSize: altTape._ts * 2; font.family:"monospace"; color: root.cWhite }
                                    Rectangle { width: altTape._ts * 1.6; height: Math.max(1, altTape._ts * 0.2); color: root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                                }
                            }
                        }
                    }
                    // Fixed current-value box (numbers scroll behind it)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: altTape._ts * 11.7
                        height: altTape._ts * 3.4
                        color: root.cNeon
                        clip: true
                        Text {
                            anchors.centerIn: parent
                            text: root._altText
                            font.bold:true; color:root.cBg; font.family:"monospace"
                            width: parent.width - (altTape._ts * 1.2)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: altTape._ts * 0.8
                            font.pixelSize: altTape._ts * 2.2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.AlignRight
                        }
                    }
                }
                // ── ALTITUDE INFO CARD (right) — big AMSL + AGL/AMSL rows ────
                //     All values now use the fixed vertical-unit properties.
                Rectangle {
                    id: altitudeCard
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: Math.max(root._u * 25, Math.min(root._u * 75, parent.width * 0.40))
                    width:  Math.max(root._u * 12, Math.min(root._u * 22, parent.width * 0.14))
                    height: Math.max(root._u *  9, Math.min(root._u * 17, parent.width * 0.11))
                    // Card scale: inner spacing/fonts derive from card width
                    readonly property real _cs: width / 16.8
                    radius: _cs * 1
                    color: Qt.rgba(0.02, 0.03, 0.04, 0.82)
                    border.color: root.cNeon
                    border.width: 1.5
                    z: 100
                    Column {
                        anchors.fill: parent
                        anchors.margins: altitudeCard._cs * 1.2
                        spacing: altitudeCard._cs * 0.4
                        // Card title
                        Text {
                            text: qsTr("ALTITUDE")
                            font.pixelSize: altitudeCard._cs * 1.1; font.bold: true; font.letterSpacing: altitudeCard._cs * 0.15
                            font.family: "monospace"; color: root.cWhite
                        }
                        // Big primary AMSL value + unit
                        Row {
                            spacing: altitudeCard._cs * 0.4
                            Text {
                                text: root._altText
                                font.pixelSize: altitudeCard._cs * 3.4; font.bold: true
                                font.family: "monospace"; color: root.cNeon
                            }
                            Text {
                                text: root._unitAlt
                                font.pixelSize: altitudeCard._cs * 1.4; font.family: "monospace"; color: root.cWhite
                                anchors.bottom: parent.bottom; anchors.bottomMargin: altitudeCard._cs * 0.6
                            }
                        }
                        // Spacer
                        Item { width: 1; height: altitudeCard._cs * 0.4 }
                        // AGL row
                        Row {
                            spacing: altitudeCard._cs * 0.6
                            Text { text: qsTr("AGL");  font.pixelSize: altitudeCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: altitudeCard._cs * 4 }
                            Text { text: root._altAglText + " " + root._unitAltAGL; font.pixelSize: altitudeCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                        // AMSL row
                        Row {
                            spacing: altitudeCard._cs * 0.6
                            Text { text: qsTr("AMSL"); font.pixelSize: altitudeCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: altitudeCard._cs * 4 }
                            Text { text: root._altText + " " + root._unitAlt; font.pixelSize: altitudeCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                    }
                }
                // ── GROUND-SPEED INFO CARD (left) — big value + MAX/MIN rows ─
                Rectangle {
                    id: groundSpeedCard
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -Math.max(root._u * 25, Math.min(root._u * 75, parent.width * 0.40))
                    width:  Math.max(root._u * 12, Math.min(root._u * 22, parent.width * 0.14))
                    height: Math.max(root._u *  9, Math.min(root._u * 17, parent.width * 0.11))
                    // Card scale
                    readonly property real _cs: width / 16.8
                    radius: _cs * 1
                    color: Qt.rgba(0.02, 0.03, 0.04, 0.82)
                    border.color: root.cNeon
                    border.width: 1.5
                    z: 100
                    Column {
                        anchors.fill: parent
                        anchors.margins: groundSpeedCard._cs * 1.2
                        spacing: groundSpeedCard._cs * 0.4
                        // Card title
                        Text {
                            text: qsTr("GROUND SPEED")
                            font.pixelSize: groundSpeedCard._cs * 1.1; font.bold: true; font.letterSpacing: groundSpeedCard._cs * 0.15
                            font.family: "monospace"; color: root.cWhite
                        }
                        // Big primary ground-speed value + unit
                        Row {
                            spacing: groundSpeedCard._cs * 0.4
                            Text {
                                text: root._gndSpdText
                                font.pixelSize: groundSpeedCard._cs * 3.4; font.bold: true
                                font.family: "monospace"; color: root.cNeon
                            }
                            Text {
                                text: root._unitGndSpd
                                font.pixelSize: groundSpeedCard._cs * 1.4; font.family: "monospace"; color: root.cWhite
                                anchors.bottom: parent.bottom; anchors.bottomMargin: groundSpeedCard._cs * 0.6
                            }
                        }
                        // Spacer
                        Item { width: 1; height: groundSpeedCard._cs * 0.4 }
                        // Session MAX row
                        Row {
                            spacing: groundSpeedCard._cs * 0.6
                            Text { text: qsTr("MAX"); font.pixelSize: groundSpeedCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: groundSpeedCard._cs * 3.4 }
                            Text { text: root._spdMax.toFixed(1) + " " + root._unitGndSpd; font.pixelSize: groundSpeedCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                        // Session MIN row
                        Row {
                            spacing: groundSpeedCard._cs * 0.6
                            Text { text: qsTr("MIN"); font.pixelSize: groundSpeedCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: groundSpeedCard._cs * 3.4 }
                            Text { text: root._spdMin.toFixed(1) + " " + root._unitGndSpd; font.pixelSize: groundSpeedCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                    }
                }
            }
            // ── MIDDLE AREA: Tactical Map (left) + Mission table (right) ─────
            Item {
                id: middleArea
                width:  parent.width
                height: root.botPanH
                // Top divider line
                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    height: 1; color: root.cBorderHi
                }
                Row {
                    anchors.fill: parent
                    // ── TACTICAL MAP panel (transparent placeholder for now) ─
                    Rectangle {
                        id: mapPanel
                        width: parent.width * 0.50; height: parent.height
                        color: "transparent"; border.color: root.cBorder; border.width: 1
                        // Panel header bar
                        Rectangle {
                            id: mapHeader
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: root._u * 3; color: Qt.rgba(0, 0, 0, 0.5)
                            border.color: root.cBorder; border.width: 1
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: root._u * 1.4
                                text: qsTr("TACTICAL MAP")
                                font.pixelSize: root._u * 1; font.bold: true; font.letterSpacing: root._u * 0.15
                                font.family: "monospace"; color: root.cWhite
                            }
                        }
                        // Empty content area (real map wiring deferred)
                        Item { anchors.top: mapHeader.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom }
                        // ── MAP ZOOM CONTROL (+/-) ──────────────────────────────
                        //     Floating +/- buttons over the tactical map, pinned to
                        //     the bottom-right corner. mapPanel is transparent and sits
                        //     ON TOP of QGC's real FlyViewMap, so these buttons appear
                        //     over the live map. Each button has its OWN MouseArea, so
                        //     only taps directly on + / - are captured; the rest of the
                        //     map area still passes drag/pinch through to the real map
                        //     underneath.
                        //
                        //     They act on root.mapControl (the FlyViewMap handle passed
                        //     in from FlyView.qml). zoomLevel / minimumZoomLevel /
                        //     maximumZoomLevel are standard QtLocation Map properties.
                        //     The `if (root.mapControl)` guard prevents a crash when no
                        //     map is wired up yet.
                        //
                        //     All sizes use root._u so the control scales with every
                        //     other element in this file.
                        Rectangle {
                            id:                   mapZoom
                            anchors.right:        parent.right
                            anchors.bottom:       parent.bottom
                            anchors.rightMargin:  root._u * 1.4
                            anchors.bottomMargin: root._u * 1.4
                            width:  root._u * 4
                            height: root._u * 8
                            radius: root._u * 0.4
                            color:  Qt.rgba(0, 0, 0, 0.55)
                            border.color: root.cNeonMid
                            border.width: 1
                            z: 300   // above the empty content Item / map layer
                            // ── + (Zoom In) — top half ──────────────────────────
                            Rectangle {
                                id: zoomInBtn
                                anchors.top:     parent.top
                                anchors.left:    parent.left
                                anchors.right:   parent.right
                                anchors.margins: 1
                                height: parent.height / 2 - 1
                                // Hover / press feedback
                                color: zoomInMA.pressed      ? root.cNeonMid
                                     : zoomInMA.containsMouse ? Qt.rgba(0, 1, 0.53, 0.15)
                                     : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.pixelSize: root._u * 2.6; font.bold: true; font.family: "monospace"
                                    color: zoomInMA.pressed ? root.cBg : root.cNeon
                                }
                                MouseArea {
                                    id: zoomInMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        // Step zoom in by 1 level, clamped to the map max
                                        if (root.mapControl)
                                            root.mapControl.zoomLevel = Math.min(
                                                root.mapControl.maximumZoomLevel,
                                                root.mapControl.zoomLevel + 1)
                                    }
                                }
                            }
                            // ── Divider between + and − ─────────────────────────
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left:        parent.left
                                anchors.right:       parent.right
                                anchors.leftMargin:  1
                                anchors.rightMargin: 1
                                height: 1
                                color:  root.cNeonMid
                            }
                            // ── − (Zoom Out) — bottom half ──────────────────────
                            Rectangle {
                                id: zoomOutBtn
                                anchors.bottom:  parent.bottom
                                anchors.left:    parent.left
                                anchors.right:   parent.right
                                anchors.margins: 1
                                height: parent.height / 2 - 1
                                // Hover / press feedback
                                color: zoomOutMA.pressed      ? root.cNeonMid
                                     : zoomOutMA.containsMouse ? Qt.rgba(0, 1, 0.53, 0.15)
                                     : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2212"   // real minus sign (−), not a hyphen
                                    font.pixelSize: root._u * 2.6; font.bold: true; font.family: "monospace"
                                    color: zoomOutMA.pressed ? root.cBg : root.cNeon
                                }
                                MouseArea {
                                    id: zoomOutMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        // Step zoom out by 1 level, clamped to the map min
                                        if (root.mapControl)
                                            root.mapControl.zoomLevel = Math.max(
                                                root.mapControl.minimumZoomLevel,
                                                root.mapControl.zoomLevel - 1)
                                    }
                                }
                            }
                        }
                        // ── END MAP ZOOM CONTROL ────────────────────────────────
                    }
                    // Vertical divider between the two panels
                    Rectangle { width: 1; height:parent.height; color:root.cBorderHi }
                    // ── MISSION / TARGETS panel ──────────────────────────────
                    Rectangle {
                        id: missionPanel
                        width: parent.width - mapPanel.width - 1; height: parent.height
                        color: root.cPanel; border.color: root.cBorder; border.width: 1
                        // Panel header bar
                        Rectangle {
                            id: missionHeader
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: root._u * 3; color: Qt.rgba(0, 0, 0, 0.5)
                            border.color: root.cBorder; border.width: 1
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: root._u * 1.4
                                text: qsTr("MISSION / TARGETS")
                                font.pixelSize: root._u * 1; font.bold: true; font.letterSpacing: root._u * 0.15
                                font.family: "monospace"; color: root.cWhite
                            }
                        }
                        // ── Mission items table (data + header + rows) ───────
                        Item {
                            id: missionTableRoot
                            anchors.top: missionHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            // Prefer the same source as the map (planMasterController);
                            // fall back to the vehicle's own missionManager if empty
                            readonly property var _planItems: {
                                try {
                                    if (typeof globals !== "undefined" && globals.planMasterControllerFlyView
                                        && globals.planMasterControllerFlyView.missionController
                                        && globals.planMasterControllerFlyView.missionController.visualItems) {
                                        return globals.planMasterControllerFlyView.missionController.visualItems
                                    }
                                } catch (e) { }
                                return null
                            }
                            readonly property var _vehicleItems: root._ok && root._v.missionManager && root._v.missionManager.missionItems ? root._v.missionManager.missionItems : null
                            readonly property var _missionItems: (_planItems && _planItems.count > 0) ? _planItems : _vehicleItems
                            readonly property int _itemCount: _missionItems ? _missionItems.count : 0
                            readonly property int _curSeq: root._ok && root._v.missionItemIndex && root._v.missionItemIndex.value !== undefined ? root._v.missionItemIndex.value : -1
                            // Keep only real navigation points (those with an actual
                            // altitude), dropping non-nav commands like camera setup
                            readonly property var _validIndices: {
                                var arr = []
                                if (!_missionItems) return arr
                                for (var i = 0; i < _itemCount; i++) {
                                    var mi = _missionItems.get(i)
                                    if (mi && mi.altitude !== undefined && mi.altitude.value !== undefined) {
                                        arr.push(i)
                                    }
                                }
                                return arr
                            }
                            // Table header row (relative column widths cover full width)
                            Item {
                                id: tableHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: root._u * 3.2
                                readonly property real cSeq:   width * 0.06
                                readonly property real cType:  width * 0.18
                                readonly property real cName:  width * 0.20
                                readonly property real cCoord: width * 0.36
                                readonly property real cStat:  width * 0.20
                                Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.35) }
                                Row {
                                    anchors.fill: parent
                                    Text { width: tableHeader.cSeq;   height: parent.height; verticalAlignment: Text.AlignVCenter; text: "#";              font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey; leftPadding: root._u * 0.6 }
                                    Text { width: tableHeader.cType;  height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("TYPE");     font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                    Text { width: tableHeader.cName;  height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("NAME");     font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                    Text { width: tableHeader.cCoord; height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("COORDINATES"); font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                    Text { width: tableHeader.cStat;  height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("STATUS");   font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                }
                            }
                            // Header underline
                            Rectangle { anchors.top: tableHeader.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.cBorderHi }
                            // Table rows (read from the real vehicle mission).
                            // Fix note: instead of reaching data via parent.parent inside
                            // the delegate (unreliable — ListView inserts an internal
                            // contentItem so the chain returns null), we pass the data as
                            // direct properties on the ListView and read them via
                            // ListView.view.xxx. Also: anchors.fill was removed from inside
                            // Row (illegal), and the delegate is an Item wrapping a Row
                            // rather than being a Row itself.
                            ListView {
                                id: missionListView
                                anchors.top: tableHeader.bottom
                                anchors.topMargin: 1
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                clip: true
                                model: parent._validIndices
                                property var missionItemsRef: parent._missionItems
                                property int curSeqRef:       parent._curSeq
                                property int itemCountRef:    parent._itemCount
                                delegate: Item {
                                    id: rowRoot
                                    width: ListView.view.width
                                    height: root._u * 3.6
                                    // modelData = real index into the original mission array
                                    // (after filtering); index = display row order (used for #)
                                    property int realIndex: modelData
                                    property var _mi: ListView.view.missionItemsRef ? ListView.view.missionItemsRef.get(realIndex) : null
                                    readonly property bool _isCurrent: realIndex === ListView.view.curSeqRef
                                    readonly property bool _isDone: ListView.view.curSeqRef >= 0 && realIndex < ListView.view.curSeqRef
                                    // Alternating row background
                                    Rectangle {
                                        anchors.fill: parent
                                        color: index % 2 === 0 ? Qt.rgba(1,1,1,0.02) : "transparent"
                                    }
                                    // Row cells
                                    Row {
                                        anchors.fill: parent
                                        // # (display order)
                                        Text {
                                            width: tableHeader.cSeq; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: (index + 1).toString()
                                            font.pixelSize: root._u * 1.4; font.family: "monospace"; color: root.cWhite
                                            leftPadding: root._u * 0.6
                                        }
                                        // TYPE (command name, with sensible fallbacks)
                                        Text {
                                            width: tableHeader.cType; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._mi && rowRoot._mi.commandName !== undefined ? rowRoot._mi.commandName
                                                : (realIndex === 0 ? qsTr("TAKEOFF") : (realIndex === ListView.view.itemCountRef - 1 ? qsTr("LAND") : qsTr("WAYPOINT")))
                                            font.pixelSize: root._u * 1.3; font.bold: true; font.family: "monospace"; color: root.cNeon
                                            elide: Text.ElideRight
                                        }
                                        // NAME
                                        Text {
                                            width: tableHeader.cName; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._mi && rowRoot._mi.missionItemName !== undefined ? rowRoot._mi.missionItemName : ("WPT-" + (realIndex + 1))
                                            font.pixelSize: root._u * 1.3; font.family: "monospace"; color: root.cWhite
                                            elide: Text.ElideRight
                                        }
                                        // COORDINATES
                                        Text {
                                            width: tableHeader.cCoord; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._mi && rowRoot._mi.coordinate !== undefined
                                                  ? rowRoot._mi.coordinate.latitude.toFixed(6) + " N  " + rowRoot._mi.coordinate.longitude.toFixed(6) + " E"
                                                  : "--"
                                            font.pixelSize: root._u * 1.2; font.family: "monospace"; color: root.cWhite
                                            elide: Text.ElideRight
                                        }
                                        // STATUS (ACTIVE / DONE / PENDING)
                                        Text {
                                            width: tableHeader.cStat; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._isCurrent ? qsTr("ACTIVE") : (rowRoot._isDone ? qsTr("DONE") : qsTr("PENDING"))
                                            font.pixelSize: root._u * 1.3; font.bold: true; font.family: "monospace"
                                            color: rowRoot._isCurrent ? root.cNeon : (rowRoot._isDone ? "#4ADE80" : root.cOrange)
                                        }
                                    }
                                }
                                // Empty-state message when there is no mission
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.count === 0
                                    text: qsTr("NO MISSION LOADED")
                                    font.pixelSize: root._u * 1; font.family: "monospace"; color: root.cGrey
                                }
                            }
                        }
                    }
                }
            }
            // ── BOTTOM STATUS BAR: 6 equal sections ─────────────────────────
            Rectangle {
                id: statusBar
                width: parent.width; height: root.botBarH
                color: root.cPanel; border.color: root.cBorder; border.width: 1
                // Top divider line
                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.cBorderHi }
                Row {
                    anchors.fill: parent
                    spacing: 0
                    // ── Section 1: WIND (speed + direction + rotating arrow) ─
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        // Section title (pinned top)
                        Text {
                            text: qsTr("WIND"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        // Section content (centred below title)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.5
                            // Wind arrow — rotates to the real wind direction
                            Canvas {
                                id: windArrowCanvas
                                width: root._u * 4.5; height: root._u * 4.5; anchors.verticalCenter:parent.verticalCenter
                                property real windDeg: root._ok && root._v.wind.direction.value !== undefined && !isNaN(root._v.wind.direction.value)
                                                        ? root._v.wind.direction.value : 0
                                onWindDegChanged: requestPaint()
                                onPaint: {
                                    var c=getContext("2d"); c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cGreyMid; c.lineWidth=1
                                    c.beginPath(); c.arc(15,15,12,0,Math.PI*2); c.stroke()
                                    // Arrow points to the wind's from-direction, matching QGC
                                    c.save(); c.translate(15,15); c.rotate(windDeg*Math.PI/180)
                                    c.strokeStyle=root.cNeon; c.lineWidth=2
                                    c.beginPath(); c.moveTo(0,-11); c.lineTo(0,11); c.stroke()
                                    c.fillStyle=root.cNeon
                                    c.beginPath(); c.moveTo(-4,3); c.lineTo(0,-10); c.lineTo(4,3); c.closePath(); c.fill()
                                    c.restore()
                                }
                            }
                            // Wind speed (top) + direction degrees (bottom)
                            Column {
                                spacing: root._u * 0.3; anchors.verticalCenter:parent.verticalCenter
                                Text {
                                    text: root._ok ? root._v.wind.speed.valueString : ("– " + root._unitWndSpd)
                                    font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                }
                                Text {
                                    text: root._ok && root._v.wind.direction.value !== undefined ?
                                          root._v.wind.direction.value.toFixed(0) + "°" : "–°"
                                    font.pixelSize: root._u * 1.5; color:root.cGrey; font.family:"monospace"
                                }
                            }
                        }
                    }
                    // ── Section 2: WAYPOINTS (current / total, filtered) ─────
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        // Section title
                        Text {
                            text: qsTr("WAYPOINTS"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        // Section content
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.2
                            // Waypoint icon
                            Canvas {
                                width: root._u * 3; height: root._u * 3; anchors.verticalCenter:parent.verticalCenter
                                onPaint: {
                                    var c=getContext("2d"); c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cNeon; c.lineWidth=2
                                    c.beginPath(); c.arc(10,10,8,0,Math.PI*2); c.stroke()
                                    c.fillStyle=root.cNeon
                                    c.beginPath(); c.arc(10,10,3,0,Math.PI*2); c.fill()
                                }
                            }
                            // "current / total" using the SAME filtered indices as the table
                            Column {
                                spacing: root._u * 0.3; anchors.verticalCenter:parent.verticalCenter
                                Text {
                                    text: {
                                    if (!root._ok) return "– / –"
                                    var rawCur = root._v.missionItemIndex && root._v.missionItemIndex.value !== undefined ? root._v.missionItemIndex.value : -1
                                    var validArr = missionTableRoot._validIndices
                                    if (!validArr || validArr.length === 0) return "– / –"
                                    var pos = validArr.indexOf(rawCur)
                                    var cur = pos >= 0 ? (pos + 1) : "–"
                                    var tot = validArr.length
                                    return cur + " / " + tot
                                }
                                    font.pixelSize: root._u * 2.7; font.bold:true; color:root.cNeon; font.family:"monospace"
                                }
                                Text { text: qsTr("NEXT:") + " –"; font.pixelSize: root._u * 1.35; color:root.cGrey; font.family:"monospace" }
                            }
                        }
                    }
                    // ── Section 3: DIST TO NEXT (distance only — ETA moved to Section 4) ──
                    Item {
                        id: distToNextBox
                        width: parent.width / 6; height: parent.height
                        clip: true
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        // Section title
                        Text {
                            text: qsTr("DIST TO NEXT"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        // Section content + all distance/ETA computation.
                        // NOTE: this Column carries the id `distCalc` and exposes both
                        // _distText and _etaText. The ETA value is now DISPLAYED in the
                        // separate ETA section (was FLIGHT TIME), but it is still
                        // COMPUTED here so both boxes read from one place.
                        Column {
                            id: distCalc
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 0.45
                            // Real distance from current vehicle position to the next
                            // mission point (a true two-coordinate distance, not to Home)
                            readonly property var _nextItem: {
                                if (!root._ok) return null
                                var seq = root._v.missionItemIndex && root._v.missionItemIndex.value !== undefined ? root._v.missionItemIndex.value : -1
                                if (seq < 0) return null
                                var candidate = null
                                try {
                                    if (typeof globals !== "undefined" && globals.planMasterControllerFlyView
                                        && globals.planMasterControllerFlyView.missionController
                                        && globals.planMasterControllerFlyView.missionController.visualItems
                                        && globals.planMasterControllerFlyView.missionController.visualItems.count > 0) {
                                        var planItems = globals.planMasterControllerFlyView.missionController.visualItems
                                        if (seq < planItems.count) candidate = planItems.get(seq)
                                    }
                                } catch (e) { }
                                if (!candidate && root._v.missionManager && root._v.missionManager.missionItems) {
                                    var items = root._v.missionManager.missionItems
                                    if (seq < items.count) candidate = items.get(seq)
                                }
                                // Ignore fake (0,0 "Null Island") coordinates like RTL,
                                // whose real position is computed at execution time
                                if (candidate && candidate.coordinate !== undefined) {
                                    var lat = candidate.coordinate.latitude
                                    var lon = candidate.coordinate.longitude
                                    if (Math.abs(lat) < 0.0001 && Math.abs(lon) < 0.0001) return null
                                }
                                return candidate
                            }
                            readonly property bool _hasNextCoord: _nextItem !== null && _nextItem.coordinate !== undefined && root._ok && root._v.coordinate !== undefined
                            readonly property real _distValMeters: _hasNextCoord ? root._v.coordinate.distanceTo(_nextItem.coordinate) : -1
                            readonly property real _etaSec: (_distValMeters >= 0 && root._rawGndSpd > 0.3) ? (_distValMeters / root._rawGndSpd) : -1
                            // Distance text uses QGC's official horizontal-distance
                            // conversion + unit string (same helper QGC uses itself), so
                            // it follows the user's Horizontal Distance setting exactly —
                            // Nautical Miles, km, m or ft — with NO manual maths and fully
                            // dynamic when the setting changes.
                            readonly property string _distText: {
                                if (_distValMeters < 0)
                                    return "-- " + (root._uc ? root._uc.appSettingsHorizontalDistanceUnitsString : qsTr("m"))
                                if (!root._uc) return _distValMeters.toFixed(0) + " " + qsTr("m")
                                return root._uc.metersToAppSettingsHorizontalDistanceUnits(_distValMeters).toFixed(1)
                                       + " " + root._uc.appSettingsHorizontalDistanceUnitsString
                            }
                            readonly property string _etaText: {
                                if (_etaSec < 0) return "--:--:--"
                                var s = Math.floor(_etaSec)
                                var h = Math.floor(s / 3600)
                                var m = Math.floor((s % 3600) / 60)
                                var ss = s % 60
                                return String(h).padStart(2,"0") + ":" + String(m).padStart(2,"0") + ":" + String(ss).padStart(2,"0")
                            }
                            // Distance only (ETA now shown in its own ETA box)
                            Column {
                                spacing: root._u * 0.4
                                Row {
                                    spacing: root._u * 0.9
                                    Text { text:"→"; font.pixelSize: root._u * 2.7; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                                    Text {
                                        text: distCalc._distText
                                        font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                        anchors.verticalCenter:parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                    // ── Section 4: ETA (estimated time to next waypoint) ─────
                    //     This box replaces the old FLIGHT TIME section. The ETA
                    //     value is computed in the DIST TO NEXT section (id: distCalc)
                    //     and simply displayed here in its own separate box.
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        // Section title
                        Text {
                            text: qsTr("ETA"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        // Section content — ETA pulled from distCalc._etaText
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.2
                            Text { text:"◷"; font.pixelSize: root._u * 2.7; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: distCalc._etaText
                                font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                    // ── Section 5: MESSAGES (new message count) ──────────────
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        // Section title
                        Text {
                            text: qsTr("MESSAGES"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        // Section content
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.2
                            Text { text:"☰"; font.pixelSize: root._u * 2.7; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: root._msgCount > 0 ? root._msgCount + " " + qsTr("New") : "0 " + qsTr("New")
                                font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                    // ── Section 6: ALERTS (blinking warning/error indicator) ─
                    Item {
                        width: parent.width / 6; height: parent.height
                        // Section title
                        Text {
                            text: qsTr("ALERTS"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        // Section content
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.5
                            // Warning glyph — blinks only when there is a warn/error
                            Text {
                                text: "⚠"
                                font.pixelSize: root._u * 3.6; color:root.cOrange
                                SequentialAnimation on opacity {
                                    running: root._msgErr || root._msgWarn
                                    loops: Animation.Infinite
                                    NumberAnimation { from:1.0; to:0.3; duration:700 }
                                    NumberAnimation { from:0.3; to:1.0; duration:700 }
                                }
                            }
                            // "!" when warn/error, otherwise "0"
                            Text {
                                text: root._msgErr || root._msgWarn ? "!" : "0"
                                font.pixelSize: root._u * 3.6; font.bold:true; font.family:"monospace"
                                color: root._msgErr ? root.cRed : root._msgWarn ? root.cOrange : root.cGrey
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
}