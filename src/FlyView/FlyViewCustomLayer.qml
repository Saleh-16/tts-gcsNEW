import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    anchors.fill: parent

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
    readonly property color cWhite:    "#DDE5EA"
    readonly property color cGrey:     "#4A6070"
    readonly property color cOrange:   "#FF6600"
    readonly property color cRed:      "#FF2244"
    readonly property color cGreyDark: "#1E2830"
    readonly property color cGreyMid:  "#3A4E5A"

    // ── Layout ────────────────────────────────────────────────────────────
    readonly property int botPanH:  300
    readonly property int botBarH:  90
    readonly property int sidebarW: 0

    // ── Vehicle data ──────────────────────────────────────────────────────
    property var  _v:    QGroundControl.multiVehicleManager.activeVehicle
    property bool _ok:   _v !== null && _v !== undefined

    property real _bat:  _ok && _v.battery.percentRemaining.value !== undefined ? _v.battery.percentRemaining.value : 0
    property real _volt: _ok && _v.battery.voltage.value !== undefined ? _v.battery.voltage.value : 0
    property int  _msgCount: _ok ? _v.messageCount : 0
    property bool _msgWarn:  _ok ? _v.messageTypeWarning : false
    property bool _msgErr:   _ok ? _v.messageTypeError   : false

    // ─────────────────────────────────────────────────────────────────────
    Column {
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.right:      parent.right
        anchors.left:       parent.left
        anchors.leftMargin: root.sidebarW
        spacing: 0

        // ── TOP: صورة خلفية ───────────────────────────────────────────────
        Item {
            id: videoArea
            width:  parent.width
            height: parent.height - root.botPanH - root.botBarH
            Image {
                anchors.fill: parent
                source:   "file:///home/saleh/qgroundcontrol/resources/terrain_bg.png"
                fillMode: Image.PreserveAspectCrop
            }
        }

        // ── MIDDLE: TACTICAL MAP + MISSION ────────────────────────────────
        Item {
            id: middleArea
            width:  parent.width
            height: root.botPanH

            Rectangle {
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height: 1
                color:  root.cBorderHi
            }

            Row {
                anchors.fill: parent

                // TACTICAL MAP
                Rectangle {
                    id:     mapPanel
                    width:  parent.width * 0.50
                    height: parent.height
                    color:  "transparent"
                    border.color: root.cBorder
                    border.width: 1

                    Rectangle {
                        id: mapHeader
                        anchors.top:   parent.top
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        height: 30
                        color:  Qt.rgba(0, 0, 0, 0.5)
                        border.color: root.cBorder
                        border.width: 1
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:           parent.left
                            anchors.leftMargin:     14
                            text:               "TACTICAL MAP"
                            font.pixelSize:     10
                            font.bold:          true
                            font.letterSpacing: 1.5
                            font.family:        "monospace"
                            color:              root.cWhite
                        }
                    }
                    Item {
                        anchors.top:    mapHeader.bottom
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                    }
                }

                Rectangle { width:1; height:parent.height; color:root.cBorderHi }

                // MISSION / TARGETS
                Rectangle {
                    id:     missionPanel
                    width:  parent.width - mapPanel.width - 1
                    height: parent.height
                    color:  root.cPanel
                    border.color: root.cBorder
                    border.width: 1

                    Rectangle {
                        id: missionHeader
                        anchors.top:   parent.top
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        height: 30
                        color:  Qt.rgba(0, 0, 0, 0.5)
                        border.color: root.cBorder
                        border.width: 1
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:           parent.left
                            anchors.leftMargin:     14
                            text:               "MISSION / TARGETS"
                            font.pixelSize:     10
                            font.bold:          true
                            font.letterSpacing: 1.5
                            font.family:        "monospace"
                            color:              root.cWhite
                        }
                    }
                    Item {
                        anchors.top:    missionHeader.bottom
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                    }
                }
            }
        }

        // ── BOTTOM: STATUS BAR ────────────────────────────────────────────
        Rectangle {
            id:     statusBar
            width:  parent.width
            height: root.botBarH
            color:  root.cPanel
            border.color: root.cBorder
            border.width: 1

            Rectangle {
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height: 1
                color:  root.cBorderHi
            }

            Row {
                anchors.fill: parent
                spacing: 0

                // ── 1. BATTERY ────────────────────────────────────────────
                Item {
                    width:  parent.width / 7
                    height: parent.height
                    Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width:1; color:root.cBorder }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     16
                        spacing: 5
                        Text { text:"BATTERY"; font.pixelSize:8; font.letterSpacing:2; color:root.cGrey; font.family:"monospace" }
                        Row {
                            spacing: 10
                            // Battery icon
                            Item {
                                width:36; height:18; anchors.verticalCenter:parent.verticalCenter
                                Rectangle { anchors.fill:parent; radius:3; color:root.cGreyDark; border.color:root.cGreyMid; border.width:1 }
                                Rectangle {
                                    anchors { left:parent.left; top:parent.top; bottom:parent.bottom; margins:2 }
                                    width: Math.max(2, (parent.width-4)*root._bat/100)
                                    radius: 2
                                    color: root._bat>30 ? root.cNeon : root._bat>15 ? root.cOrange : root.cRed
                                    Behavior on width { NumberAnimation { duration:500 } }
                                }
                                Rectangle { anchors { right:parent.right; verticalCenter:parent.verticalCenter; rightMargin:-4 }
                                    width:4; height:9; radius:2; color:root.cGreyMid }
                            }
                            Text {
                                text: root._bat.toFixed(0) + "%"
                                font.pixelSize:20; font.bold:true; font.family:"monospace"
                                color: root._bat>30 ? root.cNeon : root.cOrange
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Column {
                                spacing:2; anchors.verticalCenter:parent.verticalCenter
                                Text { text:root._volt.toFixed(1)+" V"; font.pixelSize:10; color:root.cWhite; font.family:"monospace" }
                                Text { text:"– min";                    font.pixelSize:10; color:root.cGrey;  font.family:"monospace" }
                            }
                        }
                    }
                }

                // ── 2. WIND ───────────────────────────────────────────────
                Item {
                    width:  parent.width / 7
                    height: parent.height
                    Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width:1; color:root.cBorder }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     16
                        spacing: 5
                        Text { text:"WIND"; font.pixelSize:8; font.letterSpacing:2; color:root.cGrey; font.family:"monospace" }
                        Row {
                            spacing: 10
                            Canvas {
                                width:30; height:30; anchors.verticalCenter:parent.verticalCenter
                                onPaint: {
                                    var c=getContext("2d"); c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cGreyMid; c.lineWidth=1
                                    c.beginPath(); c.arc(15,15,12,0,Math.PI*2); c.stroke()
                                    c.save(); c.translate(15,15); c.rotate(315*Math.PI/180)
                                    c.strokeStyle=root.cNeon; c.lineWidth=2
                                    c.beginPath(); c.moveTo(0,-11); c.lineTo(0,11); c.stroke()
                                    c.fillStyle=root.cNeon
                                    c.beginPath(); c.moveTo(-4,3); c.lineTo(0,-10); c.lineTo(4,3); c.closePath(); c.fill()
                                    c.restore()
                                }
                            }
                            Column {
                                spacing:2; anchors.verticalCenter:parent.verticalCenter
                                Text {
                                    text: root._ok && root._v.wind.speed.value !== undefined ?
                                          root._v.wind.speed.value.toFixed(1)+" m/s" : "– m/s"
                                    font.pixelSize:18; font.bold:true; color:root.cWhite; font.family:"monospace"
                                }
                                Text {
                                    text: root._ok && root._v.wind.direction.value !== undefined ?
                                          root._v.wind.direction.value.toFixed(0)+"°" : "–°"
                                    font.pixelSize:10; color:root.cGrey; font.family:"monospace"
                                }
                            }
                        }
                    }
                }

                // ── 3. WAYPOINTS ──────────────────────────────────────────
                Item {
                    width:  parent.width / 7
                    height: parent.height
                    Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width:1; color:root.cBorder }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     16
                        spacing: 5
                        Text { text:"WAYPOINTS"; font.pixelSize:8; font.letterSpacing:2; color:root.cGrey; font.family:"monospace" }
                        Row {
                            spacing: 8
                            Canvas {
                                width:20; height:20; anchors.verticalCenter:parent.verticalCenter
                                onPaint: {
                                    var c=getContext("2d"); c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cNeon; c.lineWidth=2
                                    c.beginPath(); c.arc(10,10,8,0,Math.PI*2); c.stroke()
                                    c.fillStyle=root.cNeon
                                    c.beginPath(); c.arc(10,10,3,0,Math.PI*2); c.fill()
                                }
                            }
                            Column {
                                spacing:2; anchors.verticalCenter:parent.verticalCenter
                                Text {
                                    text: root._ok && root._v.missionManager ? root._v.currentMissionIndex + " / " + root._v.missionManager.missionItems.count : "– / –"
                                    font.pixelSize:18; font.bold:true; color:root.cNeon; font.family:"monospace"
                                }
                                Text { text:"NEXT: –"; font.pixelSize:9; color:root.cGrey; font.family:"monospace" }
                            }
                        }
                    }
                }

                // ── 4. DIST TO NEXT ───────────────────────────────────────
                Item {
                    width:  parent.width / 7
                    height: parent.height
                    Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width:1; color:root.cBorder }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     16
                        spacing: 5
                        Text { text:"DIST TO NEXT"; font.pixelSize:8; font.letterSpacing:2; color:root.cGrey; font.family:"monospace" }
                        Row {
                            spacing: 8
                            Text { text:"→"; font.pixelSize:20; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: root._ok && root._v.distanceToHome.value !== undefined ?
                                      root._v.distanceToHome.value < 1000 ?
                                      root._v.distanceToHome.value.toFixed(0)+" m" :
                                      (root._v.distanceToHome.value/1000).toFixed(2)+" km" : "– m"
                                font.pixelSize:18; font.bold:true; color:root.cWhite; font.family:"monospace"
                                anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                }

                // ── 5. ETA ────────────────────────────────────────────────
                Item {
                    width:  parent.width / 7
                    height: parent.height
                    Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width:1; color:root.cBorder }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     16
                        spacing: 5
                        Text { text:"FLIGHT TIME"; font.pixelSize:8; font.letterSpacing:2; color:root.cGrey; font.family:"monospace" }
                        Row {
                            spacing: 8
                            Text { text:"◷"; font.pixelSize:18; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: root._ok && root._v.flightTime !== undefined ? root._v.flightTime : "00:00:00"
                                font.pixelSize:18; font.bold:true; color:root.cWhite; font.family:"monospace"
                                anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                }

                // ── 6. MESSAGES ───────────────────────────────────────────
                Item {
                    width:  parent.width / 7
                    height: parent.height
                    Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width:1; color:root.cBorder }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     16
                        spacing: 5
                        Text { text:"MESSAGES"; font.pixelSize:8; font.letterSpacing:2; color:root.cGrey; font.family:"monospace" }
                        Row {
                            spacing: 8
                            Text { text:"☰"; font.pixelSize:18; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: root._msgCount > 0 ? root._msgCount + " New" : "0 New"
                                font.pixelSize:18; font.bold:true; color:root.cWhite; font.family:"monospace"
                                anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                }

                // ── 7. ALERTS ─────────────────────────────────────────────
                Item {
                    width:  parent.width / 7
                    height: parent.height
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.leftMargin:     16
                        spacing: 5
                        Text { text:"ALERTS"; font.pixelSize:8; font.letterSpacing:2; color:root.cGrey; font.family:"monospace" }
                        Row {
                            spacing: 10
                            Text {
                                text: "⚠"
                                font.pixelSize:24; color:root.cOrange
                                SequentialAnimation on opacity {
                                    running: root._msgErr || root._msgWarn
                                    loops: Animation.Infinite
                                    NumberAnimation { from:1.0; to:0.3; duration:700 }
                                    NumberAnimation { from:0.3; to:1.0; duration:700 }
                                }
                            }
                            Text {
                                text: root._msgErr || root._msgWarn ? "!" : "0"
                                font.pixelSize:24; font.bold:true; font.family:"monospace"
                                color: root._msgErr ? root.cRed : root._msgWarn ? root.cOrange : root.cGrey
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

            }
        }
    }
}