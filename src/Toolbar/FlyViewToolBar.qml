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
            Layout.preferredWidth: 108; Layout.fillHeight: true
            color: control.cPanel
            Rectangle {
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 1; color: control.cBorder
            }
            Row {
                anchors.centerIn: parent; spacing: 7
                Canvas {
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0,0,width,height)
                        var pts = []
                        for (var i=0; i<6; i++) {
                            var a = (Math.PI/180)*(60*i-90)
                            pts.push({x:width/2+10*Math.cos(a), y:height/2+10*Math.sin(a)})
                        }
                        ctx.beginPath(); ctx.moveTo(pts[0].x,pts[0].y)
                        for (var j=1; j<6; j++) ctx.lineTo(pts[j].x,pts[j].y)
                        ctx.closePath()
                        ctx.fillStyle="#0D1F2D"; ctx.fill()
                        ctx.strokeStyle=control.cNeon; ctx.lineWidth=1.5; ctx.stroke()
                        ctx.strokeStyle=control.cNeon; ctx.lineWidth=1.2
                        ctx.beginPath()
                        ctx.moveTo(width/2-5,height/2); ctx.lineTo(width/2+5,height/2)
                        ctx.moveTo(width/2,height/2-4); ctx.lineTo(width/2,height/2+4)
                        ctx.stroke()
                        ctx.fillStyle=control.cNeon
                        var d=[{x:width/2-5,y:height/2-4},{x:width/2+5,y:height/2-4},
                               {x:width/2-5,y:height/2+4},{x:width/2+5,y:height/2+4}]
                        for (var k=0; k<d.length; k++) {
                            ctx.beginPath(); ctx.arc(d[k].x,d[k].y,1.2,0,Math.PI*2); ctx.fill()
                        }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 0
                    Text { text:"TTS GROUP"; font.pixelSize:11; font.bold:true; font.letterSpacing:1.5; color:control.cWhite }
                    Text { text:"GCS v2.0";  font.pixelSize:8;  font.letterSpacing:0.8; font.family:"monospace"; color:control.cNeon }
                }
            }
        }

        // 2. HAMBURGER
        Rectangle {
            Layout.preferredWidth: 40; Layout.fillHeight: true
            color: control._hov===0 ? Qt.rgba(1,1,1,0.05) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            Column {
                anchors.centerIn: parent; spacing: 4
                Repeater {
                    model: 3
                    Rectangle {
                        width: 16; height: 1.5; radius: 1
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

        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin:10; Layout.bottomMargin:10; color:control.cBorder }

        // 3. CONNECTION
        Item {
            Layout.preferredWidth: 138; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 14
                spacing: 3
                Text { text:"CONNECTION"; font.pixelSize:7; font.letterSpacing:1.8; font.family:"monospace"; color:control.cGrey }
                Row {
                    spacing: 6
                    Rectangle {
                        width:8; height:8; radius:4
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
                        font.pixelSize:11; font.bold:true; font.family:"monospace"
                        color: control._communicationLost ? control.cOrange
                             : control._connected ? control.cNeon : control.cRed
                    }
                }
            }
        }

        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin:10; Layout.bottomMargin:10; color:control.cBorder }

        // 4. VEHICLE
        Item {
            Layout.preferredWidth: 120; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 14
                spacing: 3
                Text { text:"VEHICLE"; font.pixelSize:7; font.letterSpacing:1.8; font.family:"monospace"; color:control.cGrey }
                Text {
                    text: control._vehicleName
                    font.pixelSize:11; font.bold:true; font.family:"monospace"; color:control.cWhite
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin:10; Layout.bottomMargin:10; color:control.cBorder }

        // 5. MISSION
        Item {
            Layout.preferredWidth: 130; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 14
                spacing: 3
                Text { text:"MISSION"; font.pixelSize:7; font.letterSpacing:1.8; font.family:"monospace"; color:control.cGrey }
                Text {
                    text: control._missionName
                    font.pixelSize:11; font.bold:true; font.family:"monospace"; color:control.cWhite
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin:10; Layout.bottomMargin:10; color:control.cBorder }

        // 6. GPS
        Item {
            Layout.preferredWidth: 148; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 14
                spacing: 3
                Text { text:"GPS"; font.pixelSize:7; font.letterSpacing:1.8; font.family:"monospace"; color:control.cGrey }
                Row {
                    spacing: 6
                    Canvas {
                        width:14; height:14; anchors.verticalCenter: parent.verticalCenter
                        property bool ok: control._gpsOk
                        onOkChanged: requestPaint()
                        onPaint: {
                            var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
                            var col=control._gpsOk ? control.cNeon : control.cOrange
                            ctx.strokeStyle=col; ctx.lineWidth=1.5; ctx.lineCap="round"
                            ctx.beginPath(); ctx.arc(7,13,3,-Math.PI*0.85,-Math.PI*0.15); ctx.stroke()
                            ctx.beginPath(); ctx.arc(7,13,6,-Math.PI*0.85,-Math.PI*0.15); ctx.stroke()
                            ctx.beginPath(); ctx.arc(7,13,9,-Math.PI*0.85,-Math.PI*0.15); ctx.stroke()
                            ctx.fillStyle=col; ctx.beginPath(); ctx.arc(7,13,1.5,0,Math.PI*2); ctx.fill()
                        }
                    }
                    Text {
                        text: control._gpsText + "  " + control._satCount + " SAT"
                        font.pixelSize:11; font.bold:true; font.family:"monospace"
                        color: control._gpsOk ? control.cNeon : control.cOrange
                    }
                }
            }
        }

        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin:10; Layout.bottomMargin:10; color:control.cBorder }

        // 7. UTC TIME
        Item {
            Layout.preferredWidth: 118; Layout.fillHeight: true
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 14
                spacing: 3
                Text { text:"TIME (UTC)"; font.pixelSize:7; font.letterSpacing:1.8; font.family:"monospace"; color:control.cGrey }
                Text { text:control._utcTime; font.pixelSize:12; font.bold:true; font.family:"monospace"; color:control.cWhite }
            }
        }

        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin:10; Layout.bottomMargin:10; color:control.cBorder }

        // 8. QGC INDICATORS (Battery, Link, RTK, etc.)
        Item {
            Layout.preferredWidth: flyViewIndicators.implicitWidth + 20
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
            Layout.preferredWidth: mainStatusIndicator.implicitWidth + 24
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

        Rectangle { Layout.preferredWidth:1; Layout.fillHeight:true; Layout.topMargin:10; Layout.bottomMargin:10; color:control.cBorder }

        // 10. DISCONNECT (comm lost only)
        Rectangle {
            Layout.preferredWidth: control._communicationLost && control._connected ? 110 : 0
            Layout.fillHeight:     true
            visible:               control._communicationLost && control._connected
            color:                 "transparent"
            Text {
                anchors.centerIn:  parent
                text:              "DISCONNECT"
                font.pixelSize:    10; font.bold: true; font.family: "monospace"
                font.letterSpacing: 1; color: control.cOrange
            }
            MouseArea {
                anchors.fill: parent
                onClicked: if (control._activeVehicle) control._activeVehicle.closeVehicle()
            }
        }

        // 11. ACTION ICONS
        Row {
            spacing: 0; Layout.fillHeight: true

            // Notifications
            Rectangle {
                width:40; height:control.height
                color: control._hov===1 ? Qt.rgba(1,1,1,0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    width:18; height:18; anchors.centerIn:parent
                    property bool h: control._hov===1
                    onHChanged: requestPaint()
                    onPaint: {
                        var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
                        ctx.strokeStyle=control._hov===1 ? control.cWhite : control.cGrey
                        ctx.lineWidth=1.5; ctx.lineCap="round"; ctx.lineJoin="round"
                        ctx.beginPath()
                        ctx.moveTo(3,12); ctx.bezierCurveTo(3,7,6,4,9,4)
                        ctx.bezierCurveTo(12,4,15,7,15,12)
                        ctx.lineTo(15,13); ctx.lineTo(3,13); ctx.closePath(); ctx.stroke()
                        ctx.beginPath(); ctx.arc(9,14.5,1.5,0,Math.PI*2); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(9,2); ctx.lineTo(9,4); ctx.stroke()
                    }
                }
                Rectangle {
                    visible: control._msgCount > 0
                    width:   Math.max(14, msgNum.implicitWidth + 4)
                    height:  14; radius: 7
                    color:   control._msgError ? control.cRed : control._msgWarning ? control.cOrange : control.cNeon
                    anchors { top:parent.top; right:parent.right; topMargin:5; rightMargin:4 }
                    Text {
                        id: msgNum; anchors.centerIn: parent
                        text:  control._msgCount > 99 ? "99+" : control._msgCount.toString()
                        font.pixelSize:7; font.bold:true; color:"#000000"
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
                width:40; height:control.height
                color: control._hov===2 ? Qt.rgba(1,1,1,0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    width:18; height:18; anchors.centerIn:parent
                    property bool h: control._hov===2
                    onHChanged: requestPaint()
                    onPaint: {
                        var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
                        var col=control._hov===2 ? control.cWhite : control.cGrey
                        ctx.strokeStyle=col; ctx.lineWidth=1.5
                        ctx.beginPath(); ctx.arc(9,9,3,0,Math.PI*2); ctx.stroke()
                        ctx.beginPath(); ctx.arc(9,9,6.5,0,Math.PI*2); ctx.stroke()
                        for (var i=0; i<8; i++) {
                            var a=(Math.PI/4)*i
                            ctx.beginPath()
                            ctx.moveTo(9+4.5*Math.cos(a),9+4.5*Math.sin(a))
                            ctx.lineTo(9+6.5*Math.cos(a),9+6.5*Math.sin(a))
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

            // Fullscreen
            Rectangle {
                width:40; height:control.height
                color: control._hov===3 ? Qt.rgba(1,1,1,0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Canvas {
                    width:16; height:16; anchors.centerIn:parent
                    property bool h: control._hov===3
                    onHChanged: requestPaint()
                    onPaint: {
                        var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
                        var col=control._hov===3 ? control.cWhite : control.cGrey
                        ctx.strokeStyle=col; ctx.lineWidth=1.5; ctx.lineCap="square"
                        var s=4
                        ctx.beginPath(); ctx.moveTo(s,0); ctx.lineTo(0,0); ctx.lineTo(0,s); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(16-s,0); ctx.lineTo(16,0); ctx.lineTo(16,s); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(0,16-s); ctx.lineTo(0,16); ctx.lineTo(s,16); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(16-s,16); ctx.lineTo(16,16); ctx.lineTo(16,16-s); ctx.stroke()
                    }
                }
                MouseArea {
                    anchors.fill:parent; hoverEnabled:true
                    onEntered: control._hov=3; onExited: control._hov=-1
                }
            }
        }
    }

    Rectangle {
        id:            guidedActionMessageDisplay
        anchors.top:   control.bottom; anchors.topMargin: 4
        x:             guidedActionConfirm.x + (guidedActionConfirm.width - width) / 2
        width:         msgLabel.contentWidth + 24
        height:        msgLabel.contentHeight + 16
        color:         qgcPal.windowTransparent
        radius:        4
        visible:       guidedActionConfirm.visible
        QGCLabel {
            id: msgLabel; x:12; y:8
            width:    ScreenTools.defaultFontPixelWidth * 30
            wrapMode: Text.WordWrap
            text:     guidedActionConfirm.message
        }
        PropertyAnimation { id:msgFade; target:guidedActionMessageDisplay; property:"opacity"; from:1; to:0; duration:500 }
        Timer { interval:4000; onTriggered: msgFade.start() }
    }

    ParameterDownloadProgress { anchors.fill: parent }
}