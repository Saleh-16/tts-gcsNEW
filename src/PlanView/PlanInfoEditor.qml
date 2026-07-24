import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
Rectangle {
    id: _root
    required property var planMasterController
    required property var missionController
    required property var editorMap
    property var _controllerVehicle: planMasterController.controllerVehicle
    property var _visualItems: missionController.visualItems
    property bool _noMissionItemsAdded: _visualItems ? _visualItems.count <= 1 : true
    property var _settingsItem: _visualItems && _visualItems.count > 0 ? _visualItems.get(0) : null
    property bool _multipleFirmware: !QGroundControl.singleFirmwareSupport
    property bool _multipleVehicleTypes: !QGroundControl.singleVehicleSupport
    property bool _allowFWVehicleTypeSelection: _noMissionItemsAdded && !globals.activeVehicle
    property bool _waypointsOnlyMode: QGroundControl.corePlugin.options.missionWaypointsOnly
    property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 16
    // ── Auto-set Home from GCS position (GPS) ──
    property var _gcsPos: QGroundControl.qgcPositionManger.gcsPosition
    Component.onCompleted: _tryAutoSetHome()
    on_GcsPosChanged: _tryAutoSetHome()
    function _tryAutoSetHome() {
        if (_settingsItem && !missionController.homePositionSet && _gcsPos && _gcsPos.isValid) {
            _settingsItem.coordinate = _gcsPos
            console.log("Home auto-set from GCS position: " + _gcsPos.latitude.toFixed(6) + ", " + _gcsPos.longitude.toFixed(6))
        }
    }
    width:  parent ? parent.width : 0
    height: mainColumn.height + ScreenTools.defaultFontPixelHeight
    color:  qgcPal.windowShadeDark
    QGCPalette { id: qgcPal; colorGroupEnabled: _root.enabled }
    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.25
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            QGCLabel {
                text: qsTr("Plan File")
            }
            QGCTextField {
                id: planNameField
                placeholderText: qsTr("Untitled")
                Layout.fillWidth: true
                Component.onCompleted: text = _root.planMasterController.currentPlanFileName
                Connections {
                    target: _root.planMasterController
                    function onCurrentPlanFileNameChanged() {
                        if (!planNameField.activeFocus) {
                            planNameField.text = _root.planMasterController.currentPlanFileName
                        }
                    }
                }
                onEditingFinished: _root.planMasterController.currentPlanFileName = text
            }
        }
        // ── Vehicle Info ──
        SectionHeader {
            id: vehicleInfoSectionHeader
            Layout.fillWidth: true
            text: qsTr("Vehicle Info")
            visible: !_root._waypointsOnlyMode && (_root._multipleFirmware || _root._multipleVehicleTypes)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth
            visible: vehicleInfoSectionHeader.visible && vehicleInfoSectionHeader.checked
            FactComboBox {
                objectName: "planInfo_firmwareCombo"
                fact: QGroundControl.settingsManager.appSettings.offlineEditingFirmwareClass
                indexModel: false
                Layout.fillWidth: true
                visible: _root._multipleFirmware && _root._allowFWVehicleTypeSelection
            }
            QGCLabel {
                objectName: "planInfo_firmwareLabel"
                text: _root._controllerVehicle ? _root._controllerVehicle.firmwareTypeString : ""
                Layout.fillWidth: true
                visible: _root._multipleFirmware && !_root._allowFWVehicleTypeSelection
            }
            FactComboBox {
                objectName: "planInfo_vehicleTypeCombo"
                fact: QGroundControl.settingsManager.appSettings.offlineEditingVehicleClass
                indexModel: false
                Layout.fillWidth: true
                visible: _root._multipleVehicleTypes && _root._allowFWVehicleTypeSelection
            }
            QGCLabel {
                objectName: "planInfo_vehicleTypeLabel"
                text: _root._controllerVehicle ? _root._controllerVehicle.vehicleTypeString : ""
                Layout.fillWidth: true
                visible: _root._multipleVehicleTypes && !_root._allowFWVehicleTypeSelection
            }
        }
        // ── Expected Home Position ──
        SectionHeader {
            id: plannedHomePositionSection
            Layout.fillWidth: true
            text: qsTr("Expected Home Position")
        }
        // Prompt to click map to set/move home position
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: ScreenTools.defaultFontPixelWidth / 2
            spacing: ScreenTools.defaultFontPixelWidth / 2
            visible: plannedHomePositionSection.checked && _root.planMasterController.showCreateFromTemplate
            Image {
                source: "qrc:///qmlimages/MapHome.svg"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2
                Layout.preferredHeight: Layout.preferredWidth
                fillMode: Image.PreserveAspectFit
            }
            QGCLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Click in map to set position")
                visible: !_root.missionController.homePositionSet
            }
            QGCLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Drag to move home position. Click to set new position.")
                visible: _root.missionController.homePositionSet
            }
        }
        // Normal home position controls (shown only when home is set)
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: ScreenTools.defaultFontPixelWidth
            columns: 2
            visible: plannedHomePositionSection.checked && _root.missionController.homePositionSet
            // ── TTS: Latitude/Longitude قابلة للتعديل يدوياً — Q_PROPERTY مؤكدة
            //    عبر grep بتاريخ 24 يوليو 2026 من VisualMissionItem.h:
            //    Q_PROPERTY(QGeoCoordinate coordinate READ coordinate WRITE setCoordinate NOTIFY coordinateChanged)
            QGCLabel {
                text: qsTr("Latitude")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCTextField {
                id: homeLatField
                Layout.fillWidth: true
                font.pointSize: ScreenTools.smallFontPointSize
                text: _root._settingsItem && _root._settingsItem.coordinate.isValid
                      ? _root._settingsItem.coordinate.latitude.toFixed(7) : ""
                Connections {
                    target: _root._settingsItem
                    function onCoordinateChanged() {
                        if (!homeLatField.activeFocus && _root._settingsItem.coordinate.isValid) {
                            homeLatField.text = _root._settingsItem.coordinate.latitude.toFixed(7)
                        }
                    }
                }
                onEditingFinished: {
                    if (!_root._settingsItem) return
                    var v = parseFloat(text)
                    if (!isNaN(v)) {
                        var c = _root._settingsItem.coordinate
                        _root._settingsItem.coordinate = QtPositioning.coordinate(v, c.longitude, c.altitude)
                    }
                }
            }
            QGCLabel {
                text: qsTr("Longitude")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCTextField {
                id: homeLonField
                Layout.fillWidth: true
                font.pointSize: ScreenTools.smallFontPointSize
                text: _root._settingsItem && _root._settingsItem.coordinate.isValid
                      ? _root._settingsItem.coordinate.longitude.toFixed(7) : ""
                Connections {
                    target: _root._settingsItem
                    function onCoordinateChanged() {
                        if (!homeLonField.activeFocus && _root._settingsItem.coordinate.isValid) {
                            homeLonField.text = _root._settingsItem.coordinate.longitude.toFixed(7)
                        }
                    }
                }
                onEditingFinished: {
                    if (!_root._settingsItem) return
                    var v = parseFloat(text)
                    if (!isNaN(v)) {
                        var c = _root._settingsItem.coordinate
                        _root._settingsItem.coordinate = QtPositioning.coordinate(c.latitude, v, c.altitude)
                    }
                }
            }
            // ── END TTS Lat/Lon ─────────────────────────────────────────
            QGCLabel {
                text: qsTr("Altitude (AMSL)")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            // TTS (24 يوليو 2026): FactTextField هنا كان يعاني نفس مشكلة
            // جدول Waypoints — يتبع Fact.value/.units المكسورة (إعداد Horizontal
            // بدل Vertical). استبدلناه بنفس التحويل اليدوي المؤكد (rawValue +
            // QGroundControl.unitsConversion)، عشان الاثنين يتطابقوا بدون تعارض.
            // الكود القديم معلّق:
            // FactTextField {
            //     fact: _root._settingsItem ? _root._settingsItem.plannedHomePositionAltitude : null
            //     Layout.fillWidth: true
            //     font.pointSize: ScreenTools.smallFontPointSize
            //     visible: _root._settingsItem !== null
            // }
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                visible: _root._settingsItem !== null
                QGCTextField {
                    id: homeAltField
                    Layout.fillWidth: true
                    font.pointSize: ScreenTools.smallFontPointSize
                    text: (_root._settingsItem && _root._settingsItem.plannedHomePositionAltitude)
                          ? QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(_root._settingsItem.plannedHomePositionAltitude.rawValue).toFixed(1)
                          : ""
                    Connections {
                        target: _root._settingsItem ? _root._settingsItem.plannedHomePositionAltitude : null
                        function onRawValueChanged() {
                            if (!homeAltField.activeFocus && _root._settingsItem && _root._settingsItem.plannedHomePositionAltitude) {
                                homeAltField.text = QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(_root._settingsItem.plannedHomePositionAltitude.rawValue).toFixed(1)
                            }
                        }
                    }
                    onEditingFinished: {
                        if (_root._settingsItem && _root._settingsItem.plannedHomePositionAltitude) {
                            var v = parseFloat(text)
                            if (!isNaN(v)) {
                                _root._settingsItem.plannedHomePositionAltitude.rawValue = QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsToMeters(v)
                            }
                        }
                    }
                }
                QGCLabel {
                    text: QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }
        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
            text: qsTr("Actual position/alt set by vehicle at flight time.")
            horizontalAlignment: Text.AlignHCenter
            visible: plannedHomePositionSection.checked && _root.missionController.homePositionSet
        }
        // ── Plan Templates ── (TTS: مخفي بطلب صريح، الكود القديم معلّق)
        // SectionHeader {
        //     id: planTemplateSectionHeader
        //     objectName: "planInfo_templatesSection"
        //     Layout.fillWidth: true
        //     text: qsTr("Plan Templates")
        //     visible: _root.planMasterController.showCreateFromTemplate
        // }
        // ColumnLayout {
        //     objectName: "planInfo_templatesColumn"
        //     Layout.fillWidth: true
        //     spacing: ScreenTools.defaultFontPixelHeight / 2
        //     visible: planTemplateSectionHeader.visible && planTemplateSectionHeader.checked
        //     enabled: _root.missionController.homePositionSet
        //     opacity: enabled ? 1.0 : 0.5
        //     Repeater {
        //         model: _root.planMasterController.planCreators
        //         QGCButton {
        //             objectName: "planCreator_" + object.name
        //             Layout.fillWidth: true
        //             text: object.name
        //             onClicked: {
        //                 if (object.blankPlan) {
        //                     _root.planMasterController.userSelectedManualCreation = true
        //                 } else {
        //                     object.createPlan(_root.editorMap.center)
        //                 }
        //             }
        //         }
        //     }
        // }
    }
}