import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView
Rectangle {
    id: _root
    required property var missionController
    required property var planMasterController
    property var editorMap: null
    property var _controllerVehicle: planMasterController.controllerVehicle
    property var _visualItems: missionController.visualItems
    property bool _noMissionItemsAdded: _visualItems ? _visualItems.count <= 1 : true
    property var _settingsItem: _visualItems && _visualItems.count > 0 ? _visualItems.get(0) : null
    property bool _flightSpeedSpecified: _settingsItem ? _settingsItem.speedSection.specifyFlightSpeed : false
    property bool _showCruiseSpeed: _controllerVehicle ? !_controllerVehicle.multiRotor : false
    property bool _showHoverSpeed: _controllerVehicle ? (_controllerVehicle.multiRotor || _controllerVehicle.vtol) : false
    property bool _showAscentDescentSpeed: _controllerVehicle ? (_controllerVehicle.multiRotor || _controllerVehicle.vtol) : false
    property bool _isVtol: _controllerVehicle ? _controllerVehicle.vtol : false
    width:  parent ? parent.width : 0
    height: mainColumn.height + ScreenTools.defaultFontPixelHeight
    color:  qgcPal.windowShadeDark
    QGCPalette { id: qgcPal; colorGroupEnabled: _root.enabled }
    Connections {
        target: _root._controllerVehicle
        function onFirmwareTypeChanged() {
            if (!_root._controllerVehicle.supports.terrainFrame
                    && _root.missionController.globalAltitudeFrame === QGroundControl.AltitudeFrameTerrain) {
                _root.missionController.globalAltitudeFrame = QGroundControl.AltitudeFrameCalcAboveTerrain
            }
        }
    }
    Component.onCompleted: {
        _root.missionController.globalAltitudeFrame = QGroundControl.AltitudeFrameAMSL
        for (var i = 1; i < _root._visualItems.count; i++) {
            var item = _root._visualItems.get(i)
            if (item && item.altitudeFrame !== undefined) {
                item.altitudeFrame = QGroundControl.AltitudeFrameAMSL
            }
        }
    }
    property int  _applyDone:    0
    property int  _applySkipped: 0
    property bool _applyRan:     false
    readonly property bool _skipTakeoff: false

    // ── TTS: ETA state ────────────────────────────────────────────────────
    property string _etaResult:   "--:--:--"
    property string _etaDistance: "–"
    property bool   _etaReady:    false
    // TTS: السرعة الخام (m/s) — تُقرأ من PlanView عبر rightPanel لتمريرها للـ WaypointTable
    property real  missionSpeedMS: 0

    // تحديث تلقائي عند تغير المسافة الكلية (إضافة/حذف نقطة)
    Connections {
        target: _root.missionController
        function onMissionTotalDistanceChanged() {
            if (_root._etaReady) {
                _root._calculateETA()
            }
        }
    }

    function _commitAltField() { return wpAltField.commit() }

    function _applyAltToAll() {
        _applyDone = 0; _applySkipped = 0; _applyRan = true
        if (!_root._visualItems) return
        var defAlt = QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude.rawValue
        for (var i = 1; i < _root._visualItems.count; i++) {
            var item = _root._visualItems.get(i)
            if (!item || !item.specifiesAltitude || !item.altitude) continue
            if (_root._skipTakeoff && item.command === 22) { _applySkipped++; continue }
            var terr = item.terrainAltitude
            if (isNaN(terr)) { _applySkipped++; continue }
            item.altitudeFrame = QGroundControl.AltitudeFrameAbsolute
            item.altitude.rawValue = terr + defAlt
            _applyDone++
        }
        applyResetTimer.restart()
    }

    function _calculateETA() {
        var v = parseFloat(ttsMissionSpeedField.text)
        if (isNaN(v) || v <= 0) {
            _root._etaResult   = "--:--:--"
            _root._etaDistance = "–"
            _root._etaReady    = false
            return
        }
        // تحويل وحدة العرض → m/s (اسم الدالة مؤكد من QmlUnitsConversion.h:56)
        var speedMS = QGroundControl.unitsConversion.appSettingsSpeedUnitsToMetersSecond(v) * 1.0
        var distM   = _root.missionController.missionTotalDistance
        console.log("TTS ETA DEBUG: v=" + v + " speedMS=" + speedMS + " distM=" + distM)
        if (distM <= 0 || speedMS <= 0) {
            _root._etaResult   = "--:--:--"
            _root._etaDistance = "–"
            _root._etaReady    = false
            return
        }
        // المسافة بوحدة العرض
        var d = QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(distM)
        var u = QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
        _root._etaDistance = d.toFixed(0) + " " + u
        // ETA
        var s   = Math.floor(distM / speedMS)
        var h   = Math.floor(s / 3600)
        var m   = Math.floor((s % 3600) / 60)
        var sec = s % 60
        _root._etaResult = h.toString().padStart(2,"0") + ":" +
                           m.toString().padStart(2,"0") + ":" +
                           sec.toString().padStart(2,"0")
        _root._etaReady = true
        _root.missionSpeedMS = speedMS
        // TTS: حفظ السرعة في AppSettings حتى تقرأها WaypointTable مباشرة
        // offlineEditingCruiseSpeed — Fact جاهز (m/s خام) — مؤكد من AppSettings.h
        QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed.rawValue = speedMS
        // TTS: نحفظ السرعة في offlineEditingCruiseSpeed (m/s خام) حتى تقرأها
        // WaypointTable مباشرة بدون تمرير عبر rightPanel — قاعدة المشروع رقم 5
        QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed.rawValue = speedMS
    }

    Timer { id: applyResetTimer; interval: 3000; onTriggered: _root._applyRan = false }
    Component { id: altFrameDialogComponent; AltFrameDialog { } }
    QGCPopupDialogFactory { id: altFrameDialogFactory; dialogComponent: altFrameDialogComponent }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.5

        // ── Alt Frame ─────────────────────────────────────────────────────
        LabelledButton {
            Layout.fillWidth: true
            label: qsTr("Alt Frame")
            buttonText: QGroundControl.altitudeFrameExtraUnits(_root.missionController.globalAltitudeFrame)
            onClicked: {
                let removeModes = []
                if (!_root._controllerVehicle.supports.terrainFrame)
                    removeModes.push(QGroundControl.AltitudeFrameTerrain)
                let updateFunction = function(altFrame) {
                    _root.missionController.globalAltitudeFrame = altFrame
                    if (altFrame === QGroundControl.AltitudeFrameMixed) return
                    for (var i = 1; i < _root._visualItems.count; i++) {
                        var item = _root._visualItems.get(i)
                        if (!item || item.altitudeFrame === undefined) continue
                        item.altitudeFrame = altFrame
                    }
                }
                altFrameDialogFactory.open({ currentAltFrame: _root.missionController.globalAltitudeFrame,
                                             rgRemoveModes: removeModes, updateAltFrameFn: updateFunction })
            }
        }

        // ── Waypoints Altitude ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            QGCLabel { text: qsTr("Waypoints Altitude") }
            QGCTextField {
                id: wpAltField
                Layout.fillWidth: true
                readonly property var _fact: QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude
                validator: DoubleValidator { bottom: 0.0; decimals: 1; notation: DoubleValidator.StandardNotation }
                function commit() {
                    if (!wpAltField._fact) return false
                    var v = parseFloat(wpAltField.text)
                    if (isNaN(v)) return false
                    wpAltField._fact.rawValue = QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsToMeters(v)
                    return true
                }
                text: _fact ? QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(_fact.rawValue).toFixed(1) : ""
                Connections {
                    target: wpAltField._fact
                    function onRawValueChanged() {
                        if (!wpAltField.activeFocus && wpAltField._fact)
                            wpAltField.text = QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(wpAltField._fact.rawValue).toFixed(1)
                    }
                }
                onEditingFinished: wpAltField.commit()
            }
            QGCLabel { text: QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString }
        }

        // ── زر Apply Altitude ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: ScreenTools.defaultFontPixelHeight * 2.0
            radius: ScreenTools.defaultFontPixelWidth * 0.4
            color: applyMa.pressed ? Qt.rgba(0,1,0.53,0.25) : applyMa.containsMouse ? Qt.rgba(0,1,0.53,0.10) : "transparent"
            border.color: _root._applyRan ? "#00FF88" : qgcPal.colorGreen
            border.width: 1.5
            opacity: (_root._visualItems && _root._visualItems.count > 1) ? 1.0 : 0.35
            Behavior on color { ColorAnimation { duration: 120 } }
            QGCLabel {
                anchors.centerIn: parent
                font.pointSize: ScreenTools.defaultFontPointSize; font.bold: true; color: qgcPal.colorGreen
                text: {
                    if (!_root._applyRan) return qsTr("Apply Altitude to All Waypoints")
                    if (_root._applySkipped > 0) return "\u2713 " + _root._applyDone + qsTr(" updated, ") + _root._applySkipped + qsTr(" skipped")
                    return "\u2713 " + _root._applyDone + qsTr(" waypoints updated")
                }
            }
            MouseArea {
                id: applyMa; anchors.fill: parent; hoverEnabled: true
                enabled: _root._visualItems && _root._visualItems.count > 1 && wpAltField.acceptableInput
                onClicked: { if (_root._commitAltField()) _root._applyAltToAll() }
            }
        }

        // ── Coordinate Format ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            QGCLabel { text: qsTr("Coordinate Format") }
            QGCComboBox {
                Layout.fillWidth: true
                model: [ qsTr("Geographic"), qsTr("UTM"), qsTr("MGRS") ]
                readonly property var _fmtFact: QGroundControl.settingsManager.appSettings.coordinateFormat
                currentIndex: _fmtFact ? _fmtFact.rawValue : 0
                onActivated: (index) => { if (_fmtFact) _fmtFact.rawValue = index }
            }
        }

        // ── TTS: Mission Speed ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            QGCLabel { text: qsTr("Mission Speed") }
            QGCTextField {
                id: ttsMissionSpeedField
                Layout.fillWidth: true
                text: {
                    var spd = QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed.rawValue * 1.0
                    if (spd <= 0) return "40"
                    return (QGroundControl.unitsConversion.metersSecondToAppSettingsSpeedUnits(spd) * 1.0).toFixed(1)
                }
                validator: DoubleValidator { bottom: 0.1; decimals: 1; notation: DoubleValidator.StandardNotation }
            }
            QGCLabel { text: QGroundControl.unitsConversion.appSettingsSpeedUnitsString }
        }

        // ── زر Calculate ETA ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: ScreenTools.defaultFontPixelHeight * 2.0
            radius: ScreenTools.defaultFontPixelWidth * 0.4
            color: etaMa.pressed ? Qt.rgba(0,1,0.53,0.25) : etaMa.containsMouse ? Qt.rgba(0,1,0.53,0.10) : "transparent"
            border.color: qgcPal.colorGreen
            border.width: 1.5
            Behavior on color { ColorAnimation { duration: 120 } }
            QGCLabel {
                anchors.centerIn: parent
                font.pointSize: ScreenTools.defaultFontPointSize; font.bold: true; color: qgcPal.colorGreen
                text: qsTr("Calculate ETA")
            }
            MouseArea {
                id: etaMa; anchors.fill: parent; hoverEnabled: true
                onClicked: _root._calculateETA()
            }
        }

        // ── نتيجة ETA (تظهر تحت الزر بعد الحساب) ─────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: ScreenTools.defaultFontPixelHeight * 2.2
            radius: ScreenTools.defaultFontPixelWidth * 0.4
            color: Qt.rgba(0, 0, 0, 0.3)
            border.color: _root._etaReady ? "#00FF88" : qgcPal.colorGrey
            border.width: 1
            visible: true
            Row {
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 2
                QGCLabel {
                    text: _root._etaDistance
                    font.pointSize: ScreenTools.defaultFontPointSize
                    font.bold: true
                    color: _root._etaReady ? "#00FF88" : qgcPal.colorGrey
                    anchors.verticalCenter: parent.verticalCenter
                }
                QGCLabel {
                    text: "\u23F1  " + _root._etaResult
                    font.pointSize: ScreenTools.defaultFontPointSize
                    font.bold: true
                    color: _root._etaReady ? "#00FF88" : qgcPal.colorGrey
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        // ── END TTS Mission Speed + ETA ────────────────────────────────────
    }
}