import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent

    // ── Required QGC properties ───────────────────────────────────────────
    property var parentToolInsets
    property var totalToolInsets: _toolInsets
    property var mapControl

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

    // ── Palette ───────────────────────────────────────────────────────────
    readonly property color cBg:       "#0A0C0E"
    readonly property color cPanel:    "#111518"
    readonly property color cBorder:   "#1E2830"
    readonly property color cBorderHi: "#2E4050"
    readonly property color cNeon:     "#00FF88"
    readonly property color cNeonDim:  "#008844"
    readonly property color cNeonFaint:"#041a0e"
    readonly property color cWhite:    "#DDE5EA"
    readonly property color cGrey:     "#4A6070"
    readonly property color cGreyMid:  "#3A4E5A"
    readonly property color cGreyDark: "#1E2830"
    readonly property color cRed:      "#FF2244"
    readonly property color cOrange:   "#FF6600"
    readonly property color cBlue:     "#3399FF"

    // ── Vehicle data ──────────────────────────────────────────────────────
    property var  _v:      QGroundControl.multiVehicleManager.activeVehicle
    property bool _ok:     _v !== null && _v !== undefined

    property real _roll:   _ok && _v.roll.value   !== undefined ? _v.roll.value   : 0
    property real _pitch:  _ok && _v.pitch.value  !== undefined ? _v.pitch.value  : 0
    property real _hdg:    _ok && _v.heading.value !== undefined ? _v.heading.value : 0
    property real _ias:    _ok && _v.airSpeed.value    !== undefined ? _v.airSpeed.value    : 0
    property real _gs:     _ok && _v.groundSpeed.value !== undefined ? _v.groundSpeed.value : 0
    property real _alt:    _ok && _v.altitudeRelative.value !== undefined ? _v.altitudeRelative.value : 0
    property real _amsl:   _ok && _v.altitudeAMSL.value     !== undefined ? _v.altitudeAMSL.value     : 0
    property real _agl:    _ok && _v.altitudeRelative.value !== undefined ? _v.altitudeRelative.value  : 0
    property real _vs:     _ok && _v.climbRate.value !== undefined ? _v.climbRate.value : 0
    property real _bat:    _ok && _v.battery.percentRemaining.value !== undefined ? _v.battery.percentRemaining.value : 0
    property real _volt:   _ok && _v.battery.voltage.value !== undefined ? _v.battery.voltage.value : 0
    property real _sats:   _ok && _v.gps.count.value !== undefined ? _v.gps.count.value : 0
    property real _hdop:   _ok && _v.gps.hdop.value  !== undefined ? _v.gps.hdop.value  : 0
    property int  _msgCount: _ok ? _v.messageCount : 0

    // ── Layout sizes ──────────────────────────────────────────────────────
    readonly property int _botBarH:  80
    readonly property int _botPanH:  230
    readonly property int _tapeW:    72

    // ════════════════════════════════════════════════════════════════════════
    //  MAIN COLUMN
    // ════════════════════════════════════════════════════════════════════════
    Column {
        anchors.fill: parent
        spacing: 0

        // ── TOP: HUD AREA ─────────────────────────────────────────────────
        Item {
            id: hudArea
            width:  parent.width
            height: parent.height - _botPanH - _botBarH

            // Thin frame
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: root.cBorder
                border.width: 1
            }

            // ── HEADING TAPE ─────────────────────────────────────────────
            Item {
                id: hdgTape
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 48
                clip: true

                Rectangle { anchors.fill: parent; color: Qt.rgba(0.04,0.06,0.08,0.88) }
                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height:1; color: root.cBorder }

                // Scrolling ticks
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -(root._hdg % 10) * 8.5
                    spacing: 0
                    Repeater {
                        model: 80
                        delegate: Item {
                            width: 85; height: 40
                            property int normDeg: (((root._hdg/10|0) - 40 + index) * 10 % 360 + 360) % 360
                            Rectangle {
                                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 5 }
                                width: 1; height: normDeg % 30 === 0 ? 14 : 7
                                color: root.cGreyMid
                            }
                            Text {
                                visible: normDeg % 10 === 0
                                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 5 }
                                text: normDeg===0?"N": normDeg===90?"E": normDeg===180?"S": normDeg===270?"W": normDeg.toString()
                                font.pixelSize: normDeg%90===0 ? 12 : 9
                                font.bold: normDeg%90===0
                                font.family: "monospace"
                                color: normDeg%90===0 ? root.cWhite : root.cGrey
                            }
                        }
                    }
                }

                // Centre box
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                    width: 54; height: 22; color: root.cNeon
                    Text {
                        anchors.centerIn: parent
                        text: root._hdg.toFixed(0).padStart(3,"0")
                        font.pixelSize: 13; font.bold: true; font.family: "monospace"
                        color: root.cBg
                    }
                }

                // Pointer
                Canvas {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                    width: 12; height: 7
                    onPaint: {
                        var c=getContext("2d"); c.clearRect(0,0,width,height)
                        c.fillStyle=root.cNeon
                        c.beginPath(); c.moveTo(0,0); c.lineTo(width,0); c.lineTo(width/2,height); c.closePath(); c.fill()
                    }
                }
            }

            // ── ALTITUDE BOX (top-left) ───────────────────────────────────
            Rectangle {
                anchors { top: hdgTape.bottom; left: parent.left; topMargin: 10; leftMargin: 10 }
                width: 175; height: 88
                color: Qt.rgba(0.04,0.06,0.08,0.88)
                border.color: root.cBorder; border.width: 1

                Column {
                    anchors { fill: parent; margins: 10 }
                    spacing: 4
                    Text { text:"ALTITUDE"; font.pixelSize:9; font.letterSpacing:1.5; color:root.cGrey; font.family:"monospace" }
                    Row {
                        spacing: 5
                        Text { text:root._alt.toFixed(0); font.pixelSize:34; font.bold:true; color:root.cNeon; font.family:"monospace" }
                        Text { text:"m"; font.pixelSize:15; color:root.cNeonDim; anchors.bottom:parent.bottom; anchors.bottomMargin:5 }
                    }
                    Column {
                        spacing: 2
                        Row { spacing:6; Text{text:"AGL"; font.pixelSize:9;color:root.cGrey;font.family:"monospace";width:34} Text{text:root._agl.toFixed(0)+" m"; font.pixelSize:10;color:root.cWhite;font.family:"monospace"} }
                        Row { spacing:6; Text{text:"AMSL";font.pixelSize:9;color:root.cGrey;font.family:"monospace";width:34} Text{text:root._amsl.toFixed(0)+" m";font.pixelSize:10;color:root.cWhite;font.family:"monospace"} }
                    }
                }
            }

            // ── GROUND SPEED BOX (top-right) ─────────────────────────────
            Rectangle {
                anchors { top: hdgTape.bottom; right: parent.right; topMargin: 10; rightMargin: 10 }
                width: 195; height: 88
                color: Qt.rgba(0.04,0.06,0.08,0.88)
                border.color: root.cBorder; border.width: 1

                Column {
                    anchors { fill: parent; margins: 10 }
                    spacing: 4
                    Text { text:"GROUND SPEED"; font.pixelSize:9; font.letterSpacing:1.5; color:root.cGrey; font.family:"monospace" }
                    Row {
                        spacing: 5
                        Text { text:root._gs.toFixed(0); font.pixelSize:34; font.bold:true; color:root.cNeon; font.family:"monospace" }
                        Text { text:"m/s"; font.pixelSize:15; color:root.cNeonDim; anchors.bottom:parent.bottom; anchors.bottomMargin:5 }
                    }
                    Column {
                        spacing: 2
                        Row { spacing:6; Text{text:"MAX";font.pixelSize:9;color:root.cGrey;font.family:"monospace";width:28} Text{text:"80 m/s";font.pixelSize:10;color:root.cWhite;font.family:"monospace"} }
                        Row { spacing:6; Text{text:"MIN";font.pixelSize:9;color:root.cGrey;font.family:"monospace";width:28} Text{text:"0 m/s"; font.pixelSize:10;color:root.cWhite;font.family:"monospace"} }
                    }
                }
            }

            // ── SPEED TAPE (left) ─────────────────────────────────────────
            Item {
                id: spdTape
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter; verticalCenterOffset: 30 }
                width: _tapeW; height: 280

                Rectangle { anchors.fill:parent; color:Qt.rgba(0.03,0.05,0.07,0.88); border.color:root.cBorder; border.width:1 }

                Text {
                    anchors { top:parent.top; horizontalCenter:parent.horizontalCenter; topMargin:6 }
                    text:"SPD\nm/s"; font.pixelSize:8; font.family:"monospace"; color:root.cGrey; horizontalAlignment:Text.AlignHCenter
                }

                Item {
                    anchors { left:parent.left; right:parent.right; top:parent.top; bottom:parent.bottom; topMargin:28; bottomMargin:28 }
                    clip: true
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter:   parent.verticalCenter
                        anchors.verticalCenterOffset: (root._ias % 10) * 4.0
                        spacing: 0
                        Repeater {
                            model: 30
                            delegate: Item {
                                width: _tapeW; height: 40
                                property real spd: ((root._ias/10|0) + 15 - index) * 10
                                Rectangle {
                                    anchors { right:parent.right; verticalCenter:parent.verticalCenter }
                                    width: spd%20===0 ? 14 : 7; height: 1
                                    color: spd%20===0 ? root.cGreyMid : root.cGreyDark
                                }
                                Text {
                                    visible: spd%20===0 && spd>=0
                                    anchors { right:parent.right; rightMargin:18; verticalCenter:parent.verticalCenter }
                                    text: spd.toFixed(0); font.pixelSize:10; font.family:"monospace"; color:root.cGrey
                                }
                            }
                        }
                    }
                }

                // Speed bug
                Rectangle {
                    anchors { verticalCenter:parent.verticalCenter; left:parent.left; right:parent.right }
                    height: 26; color: root.cNeon
                    Row {
                        anchors { right:parent.right; rightMargin:5; verticalCenter:parent.verticalCenter }
                        spacing: 3
                        Text { text:root._ias.toFixed(0); font.pixelSize:15; font.bold:true; color:root.cBg; font.family:"monospace" }
                        Canvas {
                            width:9; height:16; anchors.verticalCenter:parent.verticalCenter
                            onPaint: {
                                var c=getContext("2d"); c.clearRect(0,0,width,height)
                                c.fillStyle=root.cBg
                                c.beginPath(); c.moveTo(0,height/2); c.lineTo(width,0); c.lineTo(width,height); c.closePath(); c.fill()
                            }
                        }
                    }
                }

                // GS / TAS
                Column {
                    anchors { bottom:parent.bottom; left:parent.left; leftMargin:5; bottomMargin:5 }
                    spacing: 2
                    Row { spacing:3; Text{text:"GS"; font.pixelSize:8;color:root.cGrey;font.family:"monospace";width:22} Text{text:root._gs.toFixed(0)+" m/s"; font.pixelSize:9;color:root.cWhite;font.family:"monospace"} }
                    Row { spacing:3; Text{text:"TAS";font.pixelSize:8;color:root.cGrey;font.family:"monospace";width:22} Text{text:(root._ias+1).toFixed(0)+" m/s";font.pixelSize:9;color:root.cWhite;font.family:"monospace"} }
                }
            }

            // ── ALT TAPE (right) ──────────────────────────────────────────
            Item {
                id: altTape
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter; verticalCenterOffset: 30 }
                width: _tapeW; height: 280

                Rectangle { anchors.fill:parent; color:Qt.rgba(0.03,0.05,0.07,0.88); border.color:root.cBorder; border.width:1 }

                Text {
                    anchors { top:parent.top; horizontalCenter:parent.horizontalCenter; topMargin:6 }
                    text:"ALT\nm"; font.pixelSize:8; font.family:"monospace"; color:root.cGrey; horizontalAlignment:Text.AlignHCenter
                }

                Item {
                    anchors { left:parent.left; right:parent.right; top:parent.top; bottom:parent.bottom; topMargin:28; bottomMargin:28 }
                    clip: true
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter:   parent.verticalCenter
                        anchors.verticalCenterOffset: (root._alt % 100) * 0.40
                        spacing: 0
                        Repeater {
                            model: 18
                            delegate: Item {
                                width: _tapeW; height: 40
                                property real a: ((root._alt/100|0) + 9 - index) * 100
                                Rectangle {
                                    anchors { left:parent.left; verticalCenter:parent.verticalCenter }
                                    width: a%500===0 ? 14 : 7; height: 1
                                    color: a%500===0 ? root.cGreyMid : root.cGreyDark
                                }
                                Text {
                                    visible: a%200===0
                                    anchors { left:parent.left; leftMargin:18; verticalCenter:parent.verticalCenter }
                                    text: a.toFixed(0); font.pixelSize:10; font.family:"monospace"; color:root.cGrey
                                }
                            }
                        }
                    }
                }

                // Alt bug
                Rectangle {
                    anchors { verticalCenter:parent.verticalCenter; left:parent.left; right:parent.right }
                    height: 26; color: root.cNeon
                    Row {
                        anchors { left:parent.left; leftMargin:4; verticalCenter:parent.verticalCenter }
                        spacing: 3
                        Canvas {
                            width:9; height:16; anchors.verticalCenter:parent.verticalCenter
                            onPaint: {
                                var c=getContext("2d"); c.clearRect(0,0,width,height)
                                c.fillStyle=root.cBg
                                c.beginPath(); c.moveTo(width,height/2); c.lineTo(0,0); c.lineTo(0,height); c.closePath(); c.fill()
                            }
                        }
                        Text { text:root._alt.toFixed(0); font.pixelSize:15; font.bold:true; color:root.cBg; font.family:"monospace" }
                    }
                }

                // VS / BARO
                Column {
                    anchors { bottom:parent.bottom; left:parent.left; leftMargin:5; bottomMargin:5 }
                    spacing: 2
                    Row { spacing:3; Text{text:"VS";  font.pixelSize:8;color:root.cGrey;font.family:"monospace";width:28} Text{text:root._vs.toFixed(1)+" m/s";font.pixelSize:9;color:root.cWhite;font.family:"monospace"} }
                    Row { spacing:3; Text{text:"BARO";font.pixelSize:8;color:root.cGrey;font.family:"monospace";width:28} Text{text:"1013 hPa";            font.pixelSize:9;color:root.cWhite;font.family:"monospace"} }
                }
            }

            // ── ARTIFICIAL HORIZON ────────────────────────────────────────
            Canvas {
                id: ahCanvas
                anchors {
                    left:  spdTape.right; right: altTape.left
                    top:   hdgTape.bottom; bottom: parent.bottom
                    leftMargin: 8; rightMargin: 8
                }

                property real ahRoll:  root._roll
                property real ahPitch: root._pitch
                onAhRollChanged:  requestPaint()
                onAhPitchChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width/2, cy = height/2
                    var pitchPx = ahPitch * 5.0
                    var rollRad = ahRoll * Math.PI/180

                    ctx.save()
                    ctx.translate(cx, cy)
                    ctx.rotate(-rollRad)

                    // Pitch ladder
                    for (var deg = -30; deg <= 30; deg += 10) {
                        if (deg === 0) continue
                        var py = -deg*5.0 + pitchPx
                        var pLen = 65
                        ctx.strokeStyle = "rgba(255,255,255,0.65)"
                        ctx.lineWidth = 1.5
                        ctx.beginPath(); ctx.moveTo(-pLen, py); ctx.lineTo(pLen, py); ctx.stroke()
                        // End caps
                        var cap = deg > 0 ? 7 : -7
                        ctx.beginPath(); ctx.moveTo(-pLen,py); ctx.lineTo(-pLen,py+cap); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo( pLen,py); ctx.lineTo( pLen,py+cap); ctx.stroke()
                        // Labels
                        ctx.fillStyle = "rgba(255,255,255,0.7)"
                        ctx.font = "11px monospace"
                        ctx.textAlign = "center"; ctx.textBaseline = "middle"
                        ctx.fillText(deg.toString(), -pLen-20, py)
                        ctx.fillText(deg.toString(),  pLen+20, py)
                    }

                    // Horizon line
                    ctx.strokeStyle = "rgba(255,255,255,0.9)"
                    ctx.lineWidth = 2
                    ctx.beginPath(); ctx.moveTo(-130, pitchPx); ctx.lineTo(130, pitchPx); ctx.stroke()

                    // Bank arc
                    ctx.strokeStyle = "rgba(255,255,255,0.25)"
                    ctx.lineWidth = 1
                    ctx.beginPath(); ctx.arc(0,0,115,-Math.PI*0.75,-Math.PI*0.25); ctx.stroke()
                    var bTicks = [-60,-45,-30,-20,-10,0,10,20,30,45,60]
                    for (var bi=0; bi<bTicks.length; bi++) {
                        ctx.save(); ctx.rotate(bTicks[bi]*Math.PI/180)
                        ctx.strokeStyle="rgba(255,255,255,0.4)"; ctx.lineWidth=1
                        ctx.beginPath(); ctx.moveTo(0,-115); ctx.lineTo(0, bTicks[bi]%30===0?-102:-108); ctx.stroke()
                        ctx.restore()
                    }

                    ctx.restore()

                    // Fixed aircraft symbol
                    ctx.strokeStyle = root.cNeon; ctx.lineWidth = 2
                    ctx.beginPath(); ctx.moveTo(cx-52,cy); ctx.lineTo(cx-14,cy); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(cx+14,cy); ctx.lineTo(cx+52,cy); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(cx,cy-14); ctx.lineTo(cx,cy-6);  ctx.stroke()
                    ctx.beginPath(); ctx.arc(cx,cy,6,0,Math.PI*2); ctx.stroke()

                    // Flight path marker
                    var fpmX = cx + (root._gs - root._ias)*1.5
                    var fpmY = cy - root._vs*6
                    ctx.strokeStyle=root.cNeon; ctx.lineWidth=1.5
                    ctx.beginPath(); ctx.arc(fpmX,fpmY,8,0,Math.PI*2); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(fpmX+8,fpmY);  ctx.lineTo(fpmX+18,fpmY);  ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(fpmX-8,fpmY);  ctx.lineTo(fpmX-18,fpmY);  ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(fpmX,fpmY-8);  ctx.lineTo(fpmX,fpmY-14);  ctx.stroke()

                    // Roll pointer
                    ctx.save(); ctx.translate(cx,cy); ctx.rotate(-rollRad)
                    ctx.fillStyle=root.cNeon
                    ctx.beginPath(); ctx.moveTo(-6,113); ctx.lineTo(0,103); ctx.lineTo(6,113); ctx.closePath(); ctx.fill()
                    ctx.restore()
                }
            }
        }

        // ── BOTTOM SPLIT: Map + Mission ───────────────────────────────────
        Item {
            id: bottomSplit
            width:  parent.width
            height: _botPanH

            Rectangle { anchors.top:parent.top; anchors.left:parent.left; anchors.right:parent.right; height:1; color:root.cBorderHi }

            Row {
                anchors.fill: parent

                // ── TACTICAL MAP ──────────────────────────────────────────
                Item {
                    id: mapPanel
                    width: parent.width * 0.50
                    height: parent.height

                    Rectangle { anchors.fill:parent; color:root.cPanel; border.color:root.cBorder; border.width:1 }

                    // Header
                    Rectangle {
                        id: mapHdr
                        anchors { top:parent.top; left:parent.left; right:parent.right }
                        height: 30; color: Qt.rgba(0,0,0,0.6)
                        border.color: root.cBorder; border.width: 1

                        Row {
                            anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:10 }
                            spacing: 8
                            Rectangle { width:8;height:8;radius:4; color:root.cRed; anchors.verticalCenter:parent.verticalCenter }
                            Text { text:"TACTICAL MAP"; font.pixelSize:10; font.bold:true; font.letterSpacing:1.5; font.family:"monospace"; color:root.cWhite; anchors.verticalCenter:parent.verticalCenter }
                        }

                        Row {
                            anchors { verticalCenter:parent.verticalCenter; right:parent.right; rightMargin:8 }
                            spacing: 5
                            Repeater {
                                model: ["≡","⌖","✎","⛶","⌫"]
                                delegate: Rectangle {
                                    width:24; height:24; color:"transparent"; border.color:root.cBorder; border.width:1
                                    Text { anchors.centerIn:parent; text:modelData; font.pixelSize:12; color:root.cGrey }
                                    MouseArea { anchors.fill:parent }
                                }
                            }
                        }
                    }

                    // Map content
                    Item {
                        anchors { top:mapHdr.bottom; left:parent.left; right:parent.right; bottom:parent.bottom }

                        // Grid overlay
                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                var c=getContext("2d"); c.clearRect(0,0,width,height)
                                c.strokeStyle="rgba(0,255,136,0.04)"; c.lineWidth=1
                                for(var x=0;x<width;x+=25){c.beginPath();c.moveTo(x,0);c.lineTo(x,height);c.stroke()}
                                for(var y=0;y<height;y+=25){c.beginPath();c.moveTo(0,y);c.lineTo(width,y);c.stroke()}
                            }
                        }

                        // Left toolbar
                        Column {
                            anchors { top:parent.top; left:parent.left; topMargin:8; leftMargin:8 }
                            spacing: 5
                            Repeater {
                                model: ["+","−","⛶"]
                                delegate: Rectangle {
                                    width:24;height:24; color:Qt.rgba(0.04,0.06,0.08,0.9); border.color:root.cBorder; border.width:1
                                    Text { anchors.centerIn:parent; text:modelData; font.pixelSize:13; color:root.cWhite }
                                    MouseArea { anchors.fill:parent }
                                }
                            }
                            Canvas {
                                width:24; height:28
                                onPaint: {
                                    var c=getContext("2d"); c.clearRect(0,0,width,height)
                                    c.fillStyle=root.cNeon
                                    c.beginPath(); c.moveTo(width/2,2); c.lineTo(width/2+4,12); c.lineTo(width/2-4,12); c.closePath(); c.fill()
                                    c.fillStyle=root.cGreyMid
                                    c.beginPath(); c.moveTo(width/2,26); c.lineTo(width/2+4,16); c.lineTo(width/2-4,16); c.closePath(); c.fill()
                                    c.fillStyle=root.cWhite; c.font="7px monospace"; c.textAlign="center"; c.fillText("N",width/2,10)
                                }
                            }
                        }

                        // Scale bar
                        Row {
                            anchors { bottom:parent.bottom; left:parent.left; bottomMargin:8; leftMargin:40 }
                            spacing: 4
                            Rectangle { width:50;height:2;color:root.cWhite;anchors.verticalCenter:parent.verticalCenter }
                            Text { text:"1 km"; font.pixelSize:9; color:root.cWhite; font.family:"monospace" }
                        }

                        // WPT markers
                        Repeater {
                            model: [
                                {px:0.22,py:0.78,label:"WPT-1",col:"#00ff88",tgt:false},
                                {px:0.52,py:0.90,label:"WPT-3",col:"#00ff88",tgt:false},
                                {px:0.74,py:0.54,label:"WPT-4",col:"#00ff88",tgt:false},
                                {px:0.43,py:0.36,label:"TGT-1",col:"#ff6600",tgt:true},
                                {px:0.57,py:0.46,label:"TGT-2",col:"#ff6600",tgt:true}
                            ]
                            delegate: Item {
                                x: parent.width*modelData.px-14; y: parent.height*modelData.py-14
                                width:28; height:28
                                Rectangle {
                                    anchors.centerIn:parent; width:16;height:16
                                    radius:   modelData.tgt?0:8
                                    rotation: modelData.tgt?45:0
                                    color: Qt.rgba(0,0,0,0.6)
                                    border.color:modelData.col; border.width:1.5
                                }
                                Text {
                                    anchors{top:parent.bottom;horizontalCenter:parent.horizontalCenter;topMargin:2}
                                    text:modelData.label; font.pixelSize:8; color:modelData.col; font.family:"monospace"
                                }
                            }
                        }

                        // UAV
                        Canvas {
                            x:parent.width*0.44-14; y:parent.height*0.60-14
                            width:28; height:28
                            onPaint: {
                                var c=getContext("2d"); c.clearRect(0,0,width,height)
                                c.strokeStyle=root.cWhite; c.lineWidth=2
                                c.save(); c.translate(width/2,height/2); c.rotate(-25*Math.PI/180)
                                c.beginPath(); c.moveTo(0,-11); c.lineTo(4,5); c.lineTo(0,3); c.lineTo(-4,5); c.closePath(); c.stroke()
                                c.restore()
                            }
                        }

                        // Coordinates
                        Text {
                            anchors { bottom:parent.bottom; right:parent.right; margins:5 }
                            text: root._ok && root._v.coordinate.isValid ?
                                  root._v.coordinate.latitude.toFixed(6)+"°  "+root._v.coordinate.longitude.toFixed(6)+"°" :
                                  "–– .––––––°  –– .––––––°"
                            font.pixelSize:8; font.family:"monospace"; color:root.cNeonDim
                        }
                    }
                }

                Rectangle { width:1; height:parent.height; color:root.cBorderHi }

                // ── MISSION / TARGETS ─────────────────────────────────────
                Item {
                    id: missionPanel
                    width: parent.width - mapPanel.width - 1
                    height: parent.height

                    Rectangle { anchors.fill:parent; color:root.cPanel; border.color:root.cBorder; border.width:1 }

                    // Header
                    Rectangle {
                        id: msnHdr
                        anchors { top:parent.top; left:parent.left; right:parent.right }
                        height: 30; color:Qt.rgba(0,0,0,0.6)
                        border.color:root.cBorder; border.width:1

                        Text {
                            anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:14 }
                            text:"MISSION / TARGETS"; font.pixelSize:10; font.bold:true; font.letterSpacing:1.5; font.family:"monospace"; color:root.cWhite
                        }
                        Row {
                            anchors { verticalCenter:parent.verticalCenter; right:parent.right; rightMargin:8 }
                            spacing: 6
                            Repeater {
                                model:[{t:"NEW"},{t:"LOAD"},{t:"SAVE"},{t:"UPLOAD"}]
                                delegate: Rectangle {
                                    height:20; width:msnBtnTxt.implicitWidth+14
                                    color:Qt.rgba(0.08,0.12,0.18,0.9); border.color:root.cBorder; border.width:1
                                    Text { id:msnBtnTxt; anchors.centerIn:parent; text:modelData.t; font.pixelSize:8; font.letterSpacing:1; font.family:"monospace"; color:root.cGrey }
                                    MouseArea { anchors.fill:parent }
                                }
                            }
                        }
                    }

                    // Table
                    Item {
                        anchors { top:msnHdr.bottom; left:parent.left; right:parent.right; bottom:parent.bottom; margins:5 }

                        // Column headers
                        Row {
                            id: tblHdr; width:parent.width; height:20; spacing:0
                            Repeater {
                                model:[{t:"#",w:0.05},{t:"TYPE",w:0.14},{t:"NAME",w:0.11},{t:"COORDINATES",w:0.33},{t:"ALT",w:0.10},{t:"STATUS",w:0.19},{t:"",w:0.08}]
                                delegate: Text { width:parent.width*modelData.w; text:modelData.t; font.pixelSize:8; font.letterSpacing:1.5; font.family:"monospace"; color:root.cGrey }
                            }
                        }
                        Rectangle { anchors.top:tblHdr.bottom; width:parent.width; height:1; color:root.cBorder }

                        // Rows
                        Column {
                            anchors { top:tblHdr.bottom; topMargin:3; left:parent.left; right:parent.right }
                            spacing: 0
                            Repeater {
                                model:[
                                    {n:1,type:"TAKEOFF", icon:"✈",name:"BASE", lat:"24.123456 N",lon:"46.123456 E",alt:"150 m",status:"DONE",   sc:"#00ff88"},
                                    {n:2,type:"WAYPOINT",icon:"◎",name:"WPT-1",lat:"24.124000 N",lon:"46.125000 E",alt:"200 m",status:"DONE",   sc:"#00ff88"},
                                    {n:3,type:"WAYPOINT",icon:"◎",name:"WPT-2",lat:"24.126000 N",lon:"46.127000 E",alt:"250 m",status:"ACTIVE", sc:"#3399ff"},
                                    {n:4,type:"TARGET",  icon:"◈",name:"TGT-1",lat:"24.128500 N",lon:"46.129500 E",alt:"--",  status:"PENDING",sc:"#ff6600"},
                                    {n:5,type:"TARGET",  icon:"◈",name:"TGT-2",lat:"24.130000 N",lon:"46.133000 E",alt:"--",  status:"PENDING",sc:"#ff6600"},
                                    {n:6,type:"WAYPOINT",icon:"◎",name:"WPT-3",lat:"24.132000 N",lon:"46.135000 E",alt:"250 m",status:"PENDING",sc:"#ff6600"},
                                    {n:7,type:"LAND",    icon:"⬇",name:"BASE", lat:"24.123456 N",lon:"46.123456 E",alt:"150 m",status:"PENDING",sc:"#ff6600"}
                                ]
                                delegate: Rectangle {
                                    width:parent.width; height:24
                                    color: modelData.status==="ACTIVE" ? Qt.rgba(0.2,0.6,1,0.07) : index%2===0?"transparent":Qt.rgba(1,1,1,0.02)
                                    border.color: modelData.status==="ACTIVE" ? Qt.rgba(0.2,0.6,1,0.3) : "transparent"
                                    border.width: 1

                                    property color tc: modelData.status==="DONE" ? root.cGrey : root.cWhite

                                    Row {
                                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; right:parent.right }
                                        spacing: 0
                                        Text { width:parent.width*0.05; text:modelData.n;    font.pixelSize:9;font.family:"monospace";color:root.cGrey }
                                        Row {
                                            width:parent.width*0.14; spacing:4
                                            Text { text:modelData.icon; font.pixelSize:10;color:modelData.sc;anchors.verticalCenter:parent.verticalCenter }
                                            Text { text:modelData.type; font.pixelSize:9;font.family:"monospace";color:parent.parent.tc;elide:Text.ElideRight;width:parent.width-20;anchors.verticalCenter:parent.verticalCenter }
                                        }
                                        Text { width:parent.width*0.11; text:modelData.name; font.pixelSize:9;font.family:"monospace";color:parent.tc }
                                        Text { width:parent.width*0.17; text:modelData.lat;  font.pixelSize:9;font.family:"monospace";color:parent.tc }
                                        Text { width:parent.width*0.16; text:modelData.lon;  font.pixelSize:9;font.family:"monospace";color:parent.tc }
                                        Text { width:parent.width*0.10; text:modelData.alt;  font.pixelSize:9;font.family:"monospace";color:parent.tc }
                                        Rectangle {
                                            width:parent.width*0.13; height:16; anchors.verticalCenter:parent.verticalCenter
                                            color:"transparent"; border.color:modelData.sc; border.width:1
                                            Text { anchors.centerIn:parent; text:modelData.status; font.pixelSize:7;font.letterSpacing:0.8;font.family:"monospace";color:modelData.sc }
                                        }
                                        Item {
                                            width:parent.width*0.08; height:24
                                            Text { anchors.centerIn:parent; text:"⋮"; font.pixelSize:14;color:root.cGrey }
                                            MouseArea { anchors.fill:parent }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── BOTTOM STATUS BAR ─────────────────────────────────────────────
        Rectangle {
            id: bottomBar
            width:  parent.width
            height: _botBarH
            color:  root.cPanel
            border.color: root.cBorder; border.width: 1

            Rectangle { anchors.top:parent.top; anchors.left:parent.left; anchors.right:parent.right; height:1; color:root.cBorderHi }

            Row {
                anchors.fill: parent
                spacing: 0

                // BATTERY
                Item {
                    width: parent.width/7; height: parent.height
                    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:root.cBorder }
                    Column {
                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:16 }
                        spacing: 4
                        Text { text:"BATTERY"; font.pixelSize:8;font.letterSpacing:2;color:root.cGrey;font.family:"monospace" }
                        Row {
                            spacing: 10
                            Item {
                                width:36;height:18;anchors.verticalCenter:parent.verticalCenter
                                Rectangle { anchors.fill:parent;radius:3;color:root.cGreyDark;border.color:root.cGreyMid;border.width:1 }
                                Rectangle {
                                    anchors{left:parent.left;top:parent.top;bottom:parent.bottom;margins:2}
                                    width: Math.max(2,(parent.width-4)*root._bat/100); radius:2
                                    color: root._bat>30?root.cNeon:root._bat>15?root.cOrange:root.cRed
                                    Behavior on width { NumberAnimation { duration:500 } }
                                }
                                Rectangle { anchors.right:parent.right; anchors.verticalCenter:parent.verticalCenter; anchors.rightMargin:-4; width:4; height:9; radius:2; color:root.cGreyMid }
                            }
                            Text { text:root._bat.toFixed(0)+"%"; font.pixelSize:20;font.bold:true;color:root._bat>30?root.cNeon:root.cOrange;font.family:"monospace";anchors.verticalCenter:parent.verticalCenter }
                            Column {
                                spacing:2;anchors.verticalCenter:parent.verticalCenter
                                Text { text:root._volt.toFixed(1)+" V";font.pixelSize:10;color:root.cWhite;font.family:"monospace" }
                                Text { text:"23 min";               font.pixelSize:10;color:root.cGrey; font.family:"monospace" }
                            }
                        }
                    }
                }

                // WIND
                Item {
                    width: parent.width/7; height: parent.height
                    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:root.cBorder }
                    Column {
                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:16 }
                        spacing: 4
                        Text { text:"WIND"; font.pixelSize:8;font.letterSpacing:2;color:root.cGrey;font.family:"monospace" }
                        Row {
                            spacing: 10
                            Canvas {
                                width:30;height:30;anchors.verticalCenter:parent.verticalCenter
                                onPaint: {
                                    var c=getContext("2d");c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cGreyMid;c.lineWidth=1
                                    c.beginPath();c.arc(15,15,12,0,Math.PI*2);c.stroke()
                                    c.save();c.translate(15,15);c.rotate(315*Math.PI/180)
                                    c.strokeStyle=root.cNeon;c.lineWidth=2
                                    c.beginPath();c.moveTo(0,-11);c.lineTo(0,11);c.stroke()
                                    c.fillStyle=root.cNeon
                                    c.beginPath();c.moveTo(-4,3);c.lineTo(0,-10);c.lineTo(4,3);c.closePath();c.fill()
                                    c.restore()
                                }
                            }
                            Column {
                                spacing:2;anchors.verticalCenter:parent.verticalCenter
                                Text { text:"12 m/s";  font.pixelSize:20;font.bold:true;color:root.cWhite;font.family:"monospace" }
                                Text { text:"NW 315°"; font.pixelSize:10;color:root.cGrey; font.family:"monospace" }
                            }
                        }
                    }
                }

                // WAYPOINTS
                Item {
                    width: parent.width/7; height: parent.height
                    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:root.cBorder }
                    Column {
                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:16 }
                        spacing: 4
                        Text { text:"WAYPOINTS"; font.pixelSize:8;font.letterSpacing:2;color:root.cGrey;font.family:"monospace" }
                        Row {
                            spacing:8
                            Canvas {
                                width:20;height:20;anchors.verticalCenter:parent.verticalCenter
                                onPaint:{
                                    var c=getContext("2d");c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cNeon;c.lineWidth=2
                                    c.beginPath();c.arc(10,10,8,0,Math.PI*2);c.stroke()
                                    c.fillStyle=root.cNeon;c.beginPath();c.arc(10,10,3,0,Math.PI*2);c.fill()
                                }
                            }
                            Column {
                                spacing:2;anchors.verticalCenter:parent.verticalCenter
                                Text { text:"3 / 7";      font.pixelSize:20;font.bold:true;color:root.cNeon;font.family:"monospace" }
                                Text { text:"NEXT: WPT-2";font.pixelSize:9;color:root.cGrey;font.family:"monospace" }
                            }
                        }
                    }
                }

                // DIST TO NEXT
                Item {
                    width: parent.width/7; height: parent.height
                    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:root.cBorder }
                    Column {
                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:16 }
                        spacing: 4
                        Text { text:"DIST TO NEXT"; font.pixelSize:8;font.letterSpacing:2;color:root.cGrey;font.family:"monospace" }
                        Row {
                            spacing:8
                            Text { text:"→"; font.pixelSize:20;color:root.cNeon;anchors.verticalCenter:parent.verticalCenter }
                            Text { text:"2.4 km"; font.pixelSize:20;font.bold:true;color:root.cWhite;font.family:"monospace";anchors.verticalCenter:parent.verticalCenter }
                        }
                    }
                }

                // ETA
                Item {
                    width: parent.width/7; height: parent.height
                    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:root.cBorder }
                    Column {
                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:16 }
                        spacing: 4
                        Text { text:"ETA"; font.pixelSize:8;font.letterSpacing:2;color:root.cGrey;font.family:"monospace" }
                        Row {
                            spacing:8
                            Text { text:"◷"; font.pixelSize:18;color:root.cNeon;anchors.verticalCenter:parent.verticalCenter }
                            Text { text:"02:15"; font.pixelSize:20;font.bold:true;color:root.cWhite;font.family:"monospace";anchors.verticalCenter:parent.verticalCenter }
                        }
                    }
                }

                // MESSAGES
                Item {
                    width: parent.width/7; height: parent.height
                    Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:root.cBorder }
                    Column {
                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:16 }
                        spacing: 4
                        Text { text:"MESSAGES"; font.pixelSize:8;font.letterSpacing:2;color:root.cGrey;font.family:"monospace" }
                        Row {
                            spacing:8
                            Text { text:"☰"; font.pixelSize:18;color:root.cNeon;anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: root._msgCount > 0 ? root._msgCount+" New" : "0 New"
                                font.pixelSize:20;font.bold:true;color:root.cWhite;font.family:"monospace";anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                }

                // ALERTS
                Item {
                    width: parent.width/7; height: parent.height
                    Column {
                        anchors { verticalCenter:parent.verticalCenter; left:parent.left; leftMargin:16 }
                        spacing: 4
                        Text { text:"ALERTS"; font.pixelSize:8;font.letterSpacing:2;color:root.cGrey;font.family:"monospace" }
                        Row {
                            spacing:10
                            Text {
                                text:"⚠"; font.pixelSize:24;color:root.cOrange
                                SequentialAnimation on opacity {
                                    loops:Animation.Infinite
                                    NumberAnimation{from:1.0;to:0.3;duration:700}
                                    NumberAnimation{from:0.3;to:1.0;duration:700}
                                }
                            }
                            Text { text:"1"; font.pixelSize:24;font.bold:true;color:root.cOrange;font.family:"monospace";anchors.verticalCenter:parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }
}