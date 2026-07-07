import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.Toolbar
Item {
    required property var guidedValueSlider
    id:     control
    width:  parent.width
    height: ScreenTools.toolbarHeight
    property var  _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property var  _guidedController:  globals.guidedControllerFlyView
    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator()
    }
    property bool   _connected:   _activeVehicle !== null && _activeVehicle !== undefined
    property string _vehicleName: _connected ? _activeVehicle.vehicleName : "NO VEHICLE"
    property bool   _armed:       _connected ? _activeVehicle.armed   : false
    property bool   _flying:      _connected ? _activeVehicle.flying  : false
    property bool   _gpsOk:       _connected && _activeVehicle.gps.lock.value >= 3
    property string _gpsText:     _gpsOk ? "3D FIX" : (_connected ? "NO FIX" : "NO GPS")
    property int    _satCount:    _connected && _activeVehicle.gps.count.value !== undefined ? _activeVehicle.gps.count.value : 0
    property int    _msgCount:    _connected ? _activeVehicle.messageCount : 0
    property bool   _msgWarning:  _connected ? _activeVehicle.messageTypeWarning : false
    property bool   _msgError:    _connected ? _activeVehicle.messageTypeError   : false
    property string _missionName: {
        var ctrl = globals.planMasterControllerFlyView
        if (ctrl && ctrl.currentPlanFile && ctrl.currentPlanFile !== "") {
            var parts = ctrl.currentPlanFile.toString().split("/")
            var fname = parts[parts.length - 1]
            return fname.replace(".plan", "").toUpperCase()
        }
        return "NO PLAN"
    }
    readonly property color cBg:      "#0A0C0E"
    readonly property color cPanel:   "#111518"
    readonly property color cBorder:  "#1E2830"
    readonly property color cBorderHi:"#2E4050"
    readonly property color cNeon:    "#00FF88"
    readonly property color cWhite:   "#DDE5EA"
    readonly property color cGrey:    "#4A6070"
    readonly property color cGreyDim: "#2A3840"
    readonly property color cRed:     "#FF2244"
    readonly property color cOrange:  "#FF6600"
    readonly property real _u: ScreenTools.defaultFontPixelWidth * 1.35
    property string _utcTime: "00:00:00"
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            var d = new Date()
            _utcTime =
                d.getUTCHours()  .toString().padStart(2,"0") + ":" +
                d.getUTCMinutes().toString().padStart(2,"0") + ":" +
                d.getUTCSeconds().toString().padStart(2,"0")
        }
    }
    property int _hov: -1
    QGCPalette { id: qgcPal }
    Rectangle { anchors.fill: parent; color: control.cBg }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 1; color: control.cBorderHi
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        // 1. LOGO
        Rectangle {
            Layout.preferredWidth: control._u * 13.5; Layout.fillHeight: true
            color: control.cPanel
            Rectangle {
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 1; color: control.cBorder
            }
            Column {
                anchors.centerIn: parent; spacing: control._u * 0.15
                Text { text:"TTS GROUP"; font.pixelSize: control._u * 1.5; font.bold:true; font.letterSpacing: control._u * 0.15; color:control.cWhite; horizontalAlignment: Text.AlignHCenter }
                Text { text:"GCS v2.0";  font.pixelSize: control._u * 1.05; font.letterSpacing: control._u * 0.08; font.family:"monospace"; color:control.cNeon; horizontalAlignment: Text.AlignHCenter }
            }
        }
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // 3. CONNECTION
        Item {
            Layout.preferredWidth: control._u * 13.8; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: control._u * 1.4
                spacing: control._u * 0.3
                Text { text:"CONNECTION"; font.pixelSize: control._u * 1.1; font.letterSpacing: control._u * 0.18; font.family:"monospace"; color:control.cWhite }
                Row {
                    spacing: control._u * 0.6
                    Rectangle {
                        width: control._u * 0.8; height: control._u * 0.8; radius: control._u * 0.4
                        color: control._communicationLost ? control.cOrange
                             : control._connected ? control.cNeon : control.cRed
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: control._connected && !control._communicationLost
                            loops: Animation.Infinite
                            NumberAnimation { from:1.0; to:0.3; duration:1200 }
                            NumberAnimation { from:0.3; to:1.0; duration:1200 }
                        }
                    }
                    Text {
                        text: control._communicationLost ? "COMM LOST"
                            : control._connected ? "CONNECTED" : "DISCONNECTED"
                        font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"
                        color: control._communicationLost ? control.cOrange
                             : control._connected ? control.cNeon : control.cRed
                    }
                }
            }
        }
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // ── ACTIONS ──
        Item {
            id: actionsButton
            Layout.preferredWidth: control._u * 16; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: control._u * 1.4
                spacing: control._u * 0.3
                Text { text:"ACTIONS"; font.pixelSize: control._u * 1.1; font.letterSpacing: control._u * 0.18; font.family:"monospace"; color:control.cWhite }
                Row {
                    spacing: control._u * 0.5
                    Rectangle {
                        width: control._u * 0.8; height: control._u * 0.8; radius: width/2
                        anchors.verticalCenter: parent.verticalCenter
                        color: control._armed ? control.cNeon : control.cGrey
                    }
                    Text {
                        text: control._armed ? qsTr("ARMED") : qsTr("DISARMED")
                        font.pixelSize: control._u * 1.1; font.bold: true; font.family: "monospace"
                        color: control._armed ? control.cNeon : control.cGrey
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: mainStatusIndicator.dropMainStatusIndicator()
            }
        }
        /* ── معطّل مؤقتًا: قسم VEHICLE ──
        Item {
            Layout.preferredWidth: control._u * 12; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: control._u * 1.4
                spacing: control._u * 0.3
                Text { text:"VEHICLE"; font.pixelSize: control._u * 0.7; font.letterSpacing: control._u * 0.18; font.family:"monospace"; color:control.cGrey }
                Text {
                    text: control._vehicleName
                    font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite
                    elide: Text.ElideRight
                }
            }
        }
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // ── معطّل مؤقتًا: قسم MISSION ──
        Item {
            Layout.preferredWidth: control._u * 13; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: control._u * 1.4
                spacing: control._u * 0.3
                Text { text:"MISSION"; font.pixelSize: control._u * 0.7; font.letterSpacing: control._u * 0.18; font.family:"monospace"; color:control.cGrey }
                Text {
                    text: control._missionName
                    font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite
                    elide: Text.ElideRight
                }
            }
        }
        */
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // ── FLIGHT MODE ──
        Item {
            id: flightModeSection
            Layout.preferredWidth: control._u * 17; Layout.fillHeight: true
            clip: false
            property bool _showFmPopup: false
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: control._u * 1.4
                spacing: control._u * 0.3
                Text { text:"FLIGHT MODE"; font.pixelSize: control._u * 1.1; font.letterSpacing: control._u * 0.18; font.family:"monospace"; color:control.cWhite }
                Text {
                    text: control._connected && control._activeVehicle.flightMode ? control._activeVehicle.flightMode : qsTr("N/A")
                    font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"
                    color: control._connected ? control.cNeon : control.cGrey
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: flightModeSection._showFmPopup = !flightModeSection._showFmPopup
            }
            // ── Flight Mode Popup ──
            Rectangle {
                visible: flightModeSection._showFmPopup && control._connected
                z: 999
                width: control._u * 20
                height: fmPopupCol.implicitHeight + control._u * 2.4
                anchors.top: flightModeSection.bottom
                anchors.topMargin: control._u * 0.4
                anchors.left: flightModeSection.left
                color: control.cPanel
                border.color: control.cBorderHi
                border.width: 1
                radius: control._u * 0.4
                Column {
                    id: fmPopupCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: control._u * 1.2
                    spacing: 0
                    Text {
                        text: "Flight Modes"
                        font.pixelSize: control._u * 1.2; font.bold: true; font.family: "monospace"
                        color: control.cWhite
                        bottomPadding: control._u * 0.8
                    }
                    Rectangle { width: parent.width; height: 1; color: control.cBorder }
                    Repeater {
                        model: control._connected ? control._activeVehicle.flightModes : []
                        Item {
                            width: fmPopupCol.width; height: control._u * 3
                            Rectangle {
                                anchors.fill: parent
                                color: fmItemMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: control._u * 0.6
                                text: modelData
                                font.pixelSize: control._u * 1.1; font.family: "monospace"
                                font.bold: modelData === control._activeVehicle.flightMode
                                color: modelData === control._activeVehicle.flightMode ? control.cNeon : control.cWhite
                            }
                            MouseArea {
                                id: fmItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    control._activeVehicle.flightMode = modelData
                                    flightModeSection._showFmPopup = false
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: 1
                                color: control.cBorder
                                visible: index < (control._activeVehicle.flightModes.length - 1)
                            }
                        }
                    }
                }
            }
        }
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // ── 6. GPS (مع popup بنفس بيانات GPSIndicatorPage.qml الأصلي) ──
        Item {
            id: gpsSection
            Layout.preferredWidth: control._u * 14.8; Layout.fillHeight: true
            property bool _showGpsPopup: false
            function gpsErrorText() {
                if (!control._activeVehicle) return ""
                var v = control._activeVehicle.gps.systemErrors.value
                if (v <= 0) return ""
                switch (v) {
                    case 1:  return "Incoming correction"
                    case 2:  return "Configuration"
                    case 4:  return "Software"
                    case 8:  return "Antenna"
                    case 16: return "Event congestion"
                    case 32: return "CPU overload"
                    case 64: return "Output congestion"
                    default: return "Multiple errors"
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: control._u * 1.4
                spacing: control._u * 0.3
                Text { text:"GPS"; font.pixelSize: control._u * 1.1; font.letterSpacing: control._u * 0.18; font.family:"monospace"; color:control.cWhite }
                Row {
                    spacing: control._u * 0.6
                    Canvas {
                        width: control._u * 1.4; height: control._u * 1.4; anchors.verticalCenter: parent.verticalCenter
                        property bool ok: control._gpsOk
                        onOkChanged: requestPaint()
                        onPaint: {
                            var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
                            var col=control._gpsOk ? control.cNeon : control.cOrange
                            var cx = width/2, cy = height*0.93
                            ctx.strokeStyle=col; ctx.lineWidth=1.5; ctx.lineCap="round"
                            ctx.beginPath(); ctx.arc(cx,cy,width*0.21,-Math.PI*0.85,-Math.PI*0.15); ctx.stroke()
                            ctx.beginPath(); ctx.arc(cx,cy,width*0.43,-Math.PI*0.85,-Math.PI*0.15); ctx.stroke()
                            ctx.beginPath(); ctx.arc(cx,cy,width*0.64,-Math.PI*0.85,-Math.PI*0.15); ctx.stroke()
                            ctx.fillStyle=col; ctx.beginPath(); ctx.arc(cx,cy,width*0.1,0,Math.PI*2); ctx.fill()
                        }
                    }
                    Text {
                        text: control._gpsText + "  " + control._satCount + " SAT"
                        font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"
                        color: control._gpsOk ? control.cNeon : control.cOrange
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: gpsSection._showGpsPopup = !gpsSection._showGpsPopup
            }
            // ── Vehicle GPS Status Popup ──
            Rectangle {
                id: gpsPopup
                visible: gpsSection._showGpsPopup
                z: 999
                width: control._u * 28
                height: gpsPopupCol.implicitHeight + control._u * 2.4
                anchors.top: gpsSection.bottom
                anchors.topMargin: control._u * 0.4
                anchors.horizontalCenter: gpsSection.horizontalCenter
                color: control.cPanel
                border.color: control.cBorderHi
                border.width: 1
                radius: control._u * 0.4
                property string _na: "\u2013.\u2013\u2013"
                Column {
                    id: gpsPopupCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: control._u * 1.2
                    spacing: 0
                    Text {
                        text: "Vehicle GPS Status"
                        font.pixelSize: control._u * 1.2; font.bold: true; font.family: "monospace"
                        color: control.cWhite
                        bottomPadding: control._u * 0.8
                    }
                    Rectangle { width: parent.width; height: 1; color: control.cBorder }
                    Item {
                        width: parent.width; height: control._u * 2.8
                        Text { text: "Satellites"; font.pixelSize: control._u * 1.1; font.family:"monospace"; color:control.cGrey; anchors.verticalCenter:parent.verticalCenter }
                        Text { text: control._connected ? control._activeVehicle.gps.count.valueString : "--"; font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right }
                    }
                    Rectangle { width: parent.width; height: 1; color: control.cBorder }
                    Item {
                        width: parent.width; height: control._u * 2.8
                        Text { text: "GPS Lock"; font.pixelSize: control._u * 1.1; font.family:"monospace"; color:control.cGrey; anchors.verticalCenter:parent.verticalCenter }
                        Text { text: control._connected ? control._activeVehicle.gps.lock.enumStringValue : "--"; font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right }
                    }
                    Rectangle { width: parent.width; height: 1; color: control.cBorder }
                    Item {
                        width: parent.width; height: control._u * 2.8
                        Text { text: "HDOP"; font.pixelSize: control._u * 1.1; font.family:"monospace"; color:control.cGrey; anchors.verticalCenter:parent.verticalCenter }
                        Text { text: control._connected ? control._activeVehicle.gps.hdop.valueString : gpsPopup._na; font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right }
                    }
                    Rectangle { width: parent.width; height: 1; color: control.cBorder }
                    Item {
                        width: parent.width; height: control._u * 2.8
                        Text { text: "VDOP"; font.pixelSize: control._u * 1.1; font.family:"monospace"; color:control.cGrey; anchors.verticalCenter:parent.verticalCenter }
                        Text { text: control._connected ? control._activeVehicle.gps.vdop.valueString : gpsPopup._na; font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right }
                    }
                    Rectangle { width: parent.width; height: 1; color: control.cBorder }
                    Item {
                        width: parent.width; height: control._u * 2.8
                        Text { text: "Course Over Ground"; font.pixelSize: control._u * 1.1; font.family:"monospace"; color:control.cGrey; anchors.verticalCenter:parent.verticalCenter }
                        Text { text: control._connected ? control._activeVehicle.gps.courseOverGround.valueString : gpsPopup._na; font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right }
                    }
                    Rectangle {
                        width: parent.width; height: 1; color: control.cBorder
                        visible: control._connected && control._activeVehicle.gps.systemErrors.value > 0
                    }
                    Item {
                        width: parent.width; height: control._u * 2.8
                        visible: control._connected && control._activeVehicle.gps.systemErrors.value > 0
                        Text { text: "GPS Error"; font.pixelSize: control._u * 1.1; font.family:"monospace"; color:control.cRed; anchors.verticalCenter:parent.verticalCenter }
                        Text { text: gpsSection.gpsErrorText(); font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cRed; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right }
                    }
                }
            }
        }
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // 7. UTC TIME
        Item {
            Layout.preferredWidth: control._u * 11.8; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: control._u * 1.4
                spacing: control._u * 0.3
                Text { text:"TIME (UTC)"; font.pixelSize: control._u * 1.1; font.letterSpacing: control._u * 0.18; font.family:"monospace"; color:control.cWhite }
                Text { text:control._utcTime; font.pixelSize: control._u * 1.1; font.bold:true; font.family:"monospace"; color:control.cWhite }
            }
        }
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // 8. QGC INDICATORS
        Item {
            Layout.preferredWidth: flyViewIndicators.implicitWidth + control._u * 2
            Layout.fillHeight:     true
            FlyViewToolBarIndicators {
                id:              flyViewIndicators
                height:          parent.height
                anchors.centerIn: parent
            }
        }
        // CENTER SPACER + GuidedActionConfirm
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            GuidedActionConfirm {
                id:                       guidedActionConfirm
                height:                   parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                guidedController:         control._guidedController
                guidedValueSlider:        control.guidedValueSlider
                messageDisplay:           guidedActionMessageDisplay
            }
        }
        // 9. FLIGHT STATUS
        Rectangle {
            Layout.fillHeight:     true
            Layout.preferredWidth: mainStatusIndicator.implicitWidth + control._u * 2.4
            color: {
                if (!control._connected)          return "#1a1a2e"
                if (control._communicationLost)   return Qt.rgba(1,0,0,0.15)
                if (control._armed)               return Qt.rgba(0,1,0.53,0.12)
                return Qt.rgba(0,1,0.53,0.06)
            }
            Behavior on color { ColorAnimation { duration: 300 } }
            border.color: {
                if (!control._connected)          return control.cBorder
                if (control._communicationLost)   return control.cRed
                if (control._armed)               return control.cNeon
                return control.cBorder
            }
            border.width: 1
            MainStatusIndicator {
                id:               mainStatusIndicator
                objectName:       "toolbar_mainStatusIndicator"
                anchors.centerIn: parent
                height:           parent.height
            }
        }
        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin: control._u * 1; Layout.bottomMargin: control._u * 1; color:control.cBorder }
        // 10. DISCONNECT
        Rectangle {
            Layout.preferredWidth: control._communicationLost && control._connected ? control._u * 11 : 0
            Layout.fillHeight:     true
            visible:               control._communicationLost && control._connected
            color:                 "transparent"
            Text {
                anchors.centerIn:  parent
                text:              "DISCONNECT"
                font.pixelSize:    control._u * 1; font.bold: true; font.family: "monospace"
                font.letterSpacing: control._u * 0.1; color: control.cOrange
            }
            MouseArea {
                anchors.fill: parent
                onClicked: if (control._activeVehicle) control._activeVehicle.closeVehicle()
            }
        }
        // 11. ACTION ICONS (Notifications, Settings, Hamburger)
        Row {
            spacing: 0; Layout.fillHeight: true
            // Notifications
            Rectangle {
                width: control._u * 4; height: control.height
                color: control._hov===1 ? Qt.rgba(1,1,1,0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    width: control._u * 1.8; height: control._u * 1.8; anchors.centerIn:parent
                    property bool h: control._hov===1
                    onHChanged: requestPaint()
                    onPaint: {
                        var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
                        ctx.strokeStyle=control._hov===1 ? control.cWhite : control.cGrey
                        ctx.lineWidth=1.5; ctx.lineCap="round"; ctx.lineJoin="round"
                        var s = width/18
                        ctx.beginPath()
                        ctx.moveTo(3*s,12*s); ctx.bezierCurveTo(3*s,7*s,6*s,4*s,9*s,4*s)
                        ctx.bezierCurveTo(12*s,4*s,15*s,7*s,15*s,12*s)
                        ctx.lineTo(15*s,13*s); ctx.lineTo(3*s,13*s); ctx.closePath(); ctx.stroke()
                        ctx.beginPath(); ctx.arc(9*s,14.5*s,1.5*s,0,Math.PI*2); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(9*s,2*s); ctx.lineTo(9*s,4*s); ctx.stroke()
                    }
                }
                Rectangle {
                    visible: control._msgCount > 0
                    width:   Math.max(control._u * 1.4, msgNum.implicitWidth + control._u * 0.4)
                    height:  control._u * 1.4; radius: height/2
                    color:   control._msgError ? control.cRed : control._msgWarning ? control.cOrange : control.cNeon
                    anchors { top:parent.top; right:parent.right; topMargin: control._u * 0.5; rightMargin: control._u * 0.4 }
                    Text {
                        id: msgNum; anchors.centerIn: parent
                        text:  control._msgCount > 99 ? "99+" : control._msgCount.toString()
                        font.pixelSize: control._u * 0.7; font.bold:true; color:"#000000"
                    }
                }
                MouseArea {
                    anchors.fill:parent; hoverEnabled:true
                    onEntered: control._hov=1; onExited: control._hov=-1
                    onClicked: mainStatusIndicator.dropMainStatusIndicator()
                }
            }
            Rectangle { width:1; height:parent.height; color:control.cBorder }
            // Settings
            Rectangle {
                width: control._u * 4; height: control.height
                color: control._hov===2 ? Qt.rgba(1,1,1,0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    width: control._u * 1.8; height: control._u * 1.8; anchors.centerIn:parent
                    property bool h: control._hov===2
                    onHChanged: requestPaint()
                    onPaint: {
                        var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
                        var col=control._hov===2 ? control.cWhite : control.cGrey
                        ctx.strokeStyle=col; ctx.lineWidth=1.5
                        var cx = width/2, cy = height/2
                        ctx.beginPath(); ctx.arc(cx,cy,width*0.17,0,Math.PI*2); ctx.stroke()
                        ctx.beginPath(); ctx.arc(cx,cy,width*0.36,0,Math.PI*2); ctx.stroke()
                        for (var i=0; i<8; i++) {
                            var a=(Math.PI/4)*i
                            ctx.beginPath()
                            ctx.moveTo(cx+(width*0.25)*Math.cos(a),cy+(height*0.25)*Math.sin(a))
                            ctx.lineTo(cx+(width*0.36)*Math.cos(a),cy+(height*0.36)*Math.sin(a))
                            ctx.stroke()
                        }
                    }
                }
                MouseArea {
                    anchors.fill:parent; hoverEnabled:true
                    onEntered: control._hov=2; onExited: control._hov=-1
                    onClicked: mainWindow.showSettingsTool()
                }
            }
            Rectangle { width:1; height:parent.height; color:control.cBorder }
            // HAMBURGER
            Rectangle {
                width: control._u * 4; height: control.height
                color: control._hov===0 ? Qt.rgba(1,1,1,0.05) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Column {
                    anchors.centerIn: parent; spacing: control._u * 0.4
                    Repeater {
                        model: 3
                        Rectangle {
                            width: control._u * 1.6; height: 1.5; radius: 1
                            color: control._hov===0 ? control.cWhite : control.cGrey
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: control._hov=0; onExited: control._hov=-1
                    onClicked: mainWindow.showToolSelectDialog()
                }
            }
        }
    }
    Rectangle {
        id:            guidedActionMessageDisplay
        anchors.top:   control.bottom; anchors.topMargin: control._u * 0.4
        x:             guidedActionConfirm.x + (guidedActionConfirm.width - width) / 2
        width:         msgLabel.contentWidth + control._u * 2.4
        height:        msgLabel.contentHeight + control._u * 1.6
        color:         qgcPal.windowTransparent
        radius:        control._u * 0.4
        visible:       guidedActionConfirm.visible
        QGCLabel {
            id: msgLabel; x: control._u * 1.2; y: control._u * 0.8
            width:    ScreenTools.defaultFontPixelWidth * 30
            wrapMode: Text.WordWrap
            text:     guidedActionConfirm.message
        }
        PropertyAnimation { id:msgFade; target:guidedActionMessageDisplay; property:"opacity"; from:1; to:0; duration:500 }
        Timer { interval:4000; onTriggered: msgFade.start() }
    }
    ParameterDownloadProgress { anchors.fill: parent }
}