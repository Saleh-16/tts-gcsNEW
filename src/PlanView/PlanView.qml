import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtLocation
import QtPositioning
import QtQuick.Layouts
import QtQuick.Window
import QGroundControl
import QGroundControl.FlightMap
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.Geo
import QGroundControl.Toolbar
import QGroundControl.PlanView
Item {
    id: _root
    readonly property int   _decimalPlaces: 8
    readonly property real  _margin: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real  _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real  _rightPanelWidth: Math.min(width / 3, ScreenTools.defaultFontPixelWidth * 38)
    property var    _planMasterController: planMasterController
    property var    _missionController: _planMasterController.missionController
    property var    _geoFenceController: _planMasterController.geoFenceController
    property var    _rallyPointController: _planMasterController.rallyPointController
    property var    _visualItems: _missionController.visualItems
    property bool   _singleComplexItem: _missionController.complexMissionItems.length === 1
    property int    _editingLayer: _layerMission
    property var    _appSettings: QGroundControl.settingsManager.appSettings
    property var    _planViewSettings: QGroundControl.settingsManager.planViewSettings
    property bool   _promptForPlanUsageShowing: false
    property bool   _addROIOnClick: false
    property bool   _addWaypointOnClick: false
    readonly property int _layerMission: 1
    readonly property int _layerFence: 2
    readonly property int _layerRally: 3
    // ── Mission Review upload/save control ──
    property bool _reviewUploadAllowed: rightPanel.uploadAllowed !== undefined ? rightPanel.uploadAllowed : true
    onVisibleChanged: {
        if(visible) {
            editorMap.zoomLevel = QGroundControl.flightMapZoom
            editorMap.center    = QGroundControl.flightMapPosition
        }
    }
    Connections {
        target: planToolBar
        function onToolbarButtonClicked() {
            _addWaypointOnClick = false
            _addROIOnClick = false
        }
    }
    function mapCenter() {
        var coordinate = editorMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }
    function ttsFormatCoord(coord) {
        if (!coord || !coord.isValid) return ""
        var fmt = QGroundControl.settingsManager.appSettings.coordinateFormat.rawValue
        if (fmt === 1) {
            if (!ttsHoverPos.zone) return "UTM: -.-"
            var z = ttsHoverPos.zone.rawValue
            if (z < 1 || z > 60) return "UTM: -.-"
            return "UTM: " + z + (ttsHoverPos.hemisphere.rawValue ? "S" : "N") +
                   "   " + ttsHoverPos.easting.rawValue.toFixed(0) + "E" +
                   "   " + ttsHoverPos.northing.rawValue.toFixed(0) + "N"
        }
        if (fmt === 2) {
            var s = ttsHoverPos.mgrs ? ttsHoverPos.mgrs.valueString : ""
            return "MGRS: " + (s && s.length > 0 ? s : "-.-")
        }
        return "LAT: " + coord.latitude.toFixed(7) + "   LON: " + coord.longitude.toFixed(7)
    }
    function ttsDistFromHome(coord) {
        if (!coord || !coord.isValid) return ""
        if (!_missionController.homePositionSet) return ""
        var home = _missionController.plannedHomePosition
        if (!home || !home.isValid) return ""
        if (Math.abs(home.latitude) < 0.0001 && Math.abs(home.longitude) < 0.0001) return ""
        var meters = home.distanceTo(coord)
        var disp   = QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(meters)
        return "   DIST From home: " + disp.toFixed(1) + " " +
               QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    }

    // ── TTS LAUNCHER PITCH — Plan View ──────────────────────────────────
    //     Detects armed+stationary aircraft and shows pitch for launcher setup.
    //     Auto-adjust modifies NAV_TAKEOFF param1 in the loaded plan.
    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool _vOk:          _activeVehicle !== null && _activeVehicle !== undefined
    property bool _vArmed:       _vOk ? _activeVehicle.armed   : false
    property bool _vFlying:      _vOk ? _activeVehicle.flying  : false
    property real _vPitch:       _vOk && _activeVehicle.pitch.rawValue !== undefined && !isNaN(_activeVehicle.pitch.rawValue) ? _activeVehicle.pitch.rawValue : 0
    property real _vGndSpd: {
        if (!_vOk) return 0
        var f = _activeVehicle.groundSpeed || (_activeVehicle.vehicle ? _activeVehicle.vehicle.groundSpeed : null)
        return (f && f.rawValue !== undefined && !isNaN(f.rawValue)) ? f.rawValue : 0
    }
    property bool _onLauncher:          _vArmed && !_vFlying && _vGndSpd < 1.0
    property bool _launcherDismissed:   false

    on_VArmedChanged: {
        if (_vArmed) _launcherDismissed = false
    }

    MapFitFunctions {
        id: mapFitFunctions
        map: editorMap
        usePlannedHomePosition: true
        planMasterController: _planMasterController
    }
    PlanMasterController {
        id: planMasterController
        flyView: false
        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }
        onPromptForPlanUsageOnVehicleChange: {
            if (!_promptForPlanUsageShowing) {
                _promptForPlanUsageShowing = true
                promptForPlanUsageOnVehicleChangePopupFactory.open()
            }
        }
        function waitingOnIncompleteDataMessage(save) {
            var saveOrUpload = save ? qsTr("Save") : qsTr("Upload")
            QGroundControl.showMessageDialog(_root, qsTr("Unable to %1").arg(saveOrUpload), qsTr("Plan has incomplete items. Complete all items and %1 again.").arg(saveOrUpload))
        }
        function waitingOnTerrainDataMessage(save) {
            var saveOrUpload = save ? qsTr("Save") : qsTr("Upload")
            QGroundControl.showMessageDialog(_root, qsTr("Unable to %1").arg(saveOrUpload), qsTr("Plan is waiting on terrain data from server for correct altitude values."))
        }
        function checkReadyForSaveUpload(save) {
            if (readyForSaveState() == VisualMissionItem.NotReadyForSaveData) {
                waitingOnIncompleteDataMessage(save)
                return false
            } else if (readyForSaveState() == VisualMissionItem.NotReadyForSaveTerrain) {
                waitingOnTerrainDataMessage(save)
                return false
            }
            return true
        }
        function upload() {
            if (!_root._reviewUploadAllowed) {
                QGroundControl.showMessageDialog(_root,
                    qsTr("Upload Blocked"),
                    qsTr("Mission review has unresolved critical findings. Accept responsibility in the Mission Review panel before uploading."))
                return
            }
            if (!checkReadyForSaveUpload(false)) {
                return
            }
            switch (_missionController.sendToVehiclePreCheck()) {
                case MissionController.SendToVehiclePreCheckStateOk: sendToVehicle()
                    break
                case MissionController.SendToVehiclePreCheckStateActiveMission: QGroundControl.showMessageDialog(_root, qsTr("Send To Vehicle"), qsTr("Current mission must be paused prior to uploading a new Plan"))
                    break
                case MissionController.SendToVehiclePreCheckStateFirwmareVehicleMismatch: QGroundControl.showMessageDialog(_root, qsTr("Plan Upload"),
                                                 qsTr("This Plan was created for a different firmware or vehicle type than the firmware/vehicle type of vehicle you are uploading to. " +
                                                      "This can lead to errors or incorrect behavior. " +
                                                      "It is recommended to recreate the Plan for the correct firmware/vehicle type.\n\n" +
                                                      "Click 'Ok' to upload the Plan anyway."),
                                                 Dialog.Ok | Dialog.Cancel,
                                                 function() { _planMasterController.sendToVehicle() })
                    break
            }
        }
        function loadFromSelectedFile() {
            fileDialog.title =          qsTr("Select Plan File")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.loadNameFilters
            fileDialog.openForLoad()
        }
        function saveToSelectedFile() {
            if (!_root._reviewUploadAllowed) {
                QGroundControl.showMessageDialog(_root,
                    qsTr("Save Blocked"),
                    qsTr("Mission review has unresolved critical findings. Accept responsibility in the Mission Review panel before saving."))
                return
            }
            if (!checkReadyForSaveUpload(true)) {
                return
            }
            fileDialog.title =          qsTr("Save Plan")
            fileDialog.planFiles =      true
            fileDialog.nameFilters =    _planMasterController.saveNameFilters
            fileDialog.openForSave()
        }
        function fitViewportToItems() {
            mapFitFunctions.fitMapViewportToMissionItems()
        }
        function saveKmlToSelectedFile() {
            if (!checkReadyForSaveUpload(true)) {
                return
            }
            fileDialog.title =          qsTr("Save KML")
            fileDialog.planFiles =      false
            fileDialog.nameFilters =    ShapeFileHelper.fileDialogKMLFilters
            fileDialog.openForSave()
        }
    }
    Connections {
        target: _missionController
        function onNewItemsFromVehicle() {
            if (_visualItems && _visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
            }
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }
    }
    function ttsTakeoffAltOffset() {
        var v = QGroundControl.multiVehicleManager.activeVehicle
        if (v && v.parameterManager.parameterExists(-1, "TKOFF_ALT")) {
            var val = v.getParameterFact(-1, "TKOFF_ALT").rawValue
            if (val > 0) return val
        }
        return 150
    }
    function ttsApplyTerrainAltitude(item, coord, overrideOffset) {
        if (item && item.specifiesAltitude && coord && coord.isValid) {
            ttsNewItemTerrainQuery.enqueue(item, coord, (overrideOffset !== undefined) ? overrideOffset : -1)
        }
    }
    function insertSimpleItemAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertSimpleMissionItem(coordinate, nextIndex, true)
        ttsApplyTerrainAltitude(_missionController.currentPlanViewItem, coordinate)
    }
    function insertROIAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertROIMissionItem(coordinate, nextIndex, true)
        ttsApplyTerrainAltitude(_missionController.currentPlanViewItem, coordinate)
    }
    function insertCancelROIAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertCancelROIMissionItem(nextIndex, true)
    }
    function insertComplexItemAfterCurrent(complexItemName) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertComplexMissionItem(complexItemName, mapCenter(), nextIndex, true)
        ttsApplyTerrainAltitude(_missionController.currentPlanViewItem, mapCenter())
    }
    function insertTakeoffItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertTakeoffItem(mapCenter(), nextIndex, true)
        var newItem = _missionController.currentPlanViewItem
        if (newItem) {
            newItem.wizardMode = false
        }
        if (newItem && newItem.specifiesAltitude) {
            var tkCoord = newItem.coordinate && newItem.coordinate.isValid ? newItem.coordinate : mapCenter()
            ttsApplyTerrainAltitude(newItem, tkCoord, ttsTakeoffAltOffset())
        }
    }
    function insertLandItemAfterCurrent() {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertLandItem(mapCenter(), nextIndex, true)
        var newItem = _missionController.currentPlanViewItem
        var coord = mapCenter()
        if (newItem && newItem.specifiesAltitude) {
            ttsLandDelayTimer._item = newItem
            ttsLandDelayTimer._coord = coord
            ttsLandDelayTimer.restart()
        }
    }
    QGCFileDialog {
        id: fileDialog
        folder: _appSettings ? _appSettings.missionSavePath : ""
        property bool planFiles: true
        onAcceptedForSave: (file) => {
            if (planFiles) {
                if (_planMasterController.saveToFile(file)) {
                    close()
                }
            } else {
                _planMasterController.saveToKml(file)
                close()
            }
        }
        onAcceptedForLoad: (file) => {
            _planMasterController.loadFromFile(file)
            _planMasterController.fitViewportToItems()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            close()
        }
    }
    PlanViewToolBar {
        id: planToolBar
        planMasterController: _planMasterController
        showRallyPointsHelp: _editingLayer === _layerRally
    }
    Item {
        id: mainPlanViewArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: planToolBar.bottom
        anchors.bottom: parent.bottom
        FlightMap {
            id: editorMap
            objectName: "planView_map"
            anchors.fill: parent
            mapName: "MissionEditor"
            allowGCSLocationCenter: true
            allowVehicleLocationCenter: true
            planView: true
            zoomLevel: QGroundControl.flightMapZoom
            center: QGroundControl.flightMapPosition
            property rect centerViewport: Qt.rect(_leftToolWidth + _margin,  _margin, editorMap.width - _leftToolWidth - _rightToolWidth - (_margin * 2), (missionStatus.visible ? missionStatus.y : height - _margin) - _margin)
            property real _leftToolWidth: toolStrip.x + toolStrip.width
            property real _rightToolWidth: rightPanel.width + rightPanel.anchors.rightMargin
            property real _nonInteractiveOpacity: 0.5
            Component.onCompleted: {
                editorMap.center = QtPositioning.coordinate(17.5656, 44.2286)
                editorMap.zoomLevel = 6
            }
            onZoomLevelChanged: {
                QGroundControl.flightMapZoom = editorMap.zoomLevel
            }
            onCenterChanged: {
                QGroundControl.flightMapPosition = editorMap.center
            }
            onMapClicked: (mouse) => {
                editorMap.focus = true
                layerSwitcher.expanded = false
                collapseTimer.stop()
                if (!mainWindow.allowViewSwitch()) {
                    return
                }
                var coordinate = editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false)
                coordinate.latitude = coordinate.latitude.toFixed(_decimalPlaces)
                coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
                coordinate.altitude = coordinate.altitude.toFixed(_decimalPlaces)
                switch (_editingLayer) {
                case _layerMission:
                    if (_planMasterController.showCreateFromTemplate) {
                        _missionController.setHomePosition(coordinate)
                    } else if (_addROIOnClick) {
                        _addROIOnClick = false
                        if (_missionController.isROIActive) {
                            var pos = Qt.point(mouse.x, mouse.y)
                            pos = editorMap.mapToItem(globals.parent, pos)
                            var dropPanel = insertOrCancelROIDropPanelComponent.createObject(mainWindow, { mapClickCoord: coordinate, clickRect: Qt.rect(pos.x, pos.y, 0, 0) })
                            dropPanel.open()
                        } else {
                            insertROIAfterCurrent(coordinate)
                        }
                    } else if (_addWaypointOnClick) {
                        insertSimpleItemAfterCurrent(coordinate)
                    }
                    break
                case _layerRally:
                    if (_rallyPointController.supported) {
                        _rallyPointController.addPoint(coordinate)
                    }
                    break
                }
            }
            Repeater {
                model: _missionController.visualItems
                delegate: MissionItemMapVisual {
                    map: editorMap
                    opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
                    interactive: _editingLayer == _layerMission
                    vehicle: _planMasterController.controllerVehicle
                    onClicked: (sequenceNumber) => { _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false) }
                }
            }
            MissionLineView {
                showSpecialVisual: _missionController.isROIBeginCurrentItem
                model: _missionController.simpleFlightPathSegments
                opacity: _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
            }
            MapItemView {
                model: _editingLayer == _layerMission ? _missionController.directionArrows : undefined
                delegate: MapLineArrow {
                    fromCoord: object ? object.coordinate1 : undefined
                    toCoord: object ? object.coordinate2 : undefined
                    arrowPosition: 3
                    z: QGroundControl.zOrderWaypointLines + 1
                }
            }
            MapQuickItem {
                id: splitSegmentItem
                anchorPoint.x: sourceItem.width / 2
                anchorPoint.y: sourceItem.height / 2
                z: QGroundControl.zOrderWaypointLines + 1
                visible: _editingLayer == _layerMission
                sourceItem: SplitIndicator {
                    onClicked: _missionController.insertSimpleMissionItem(splitSegmentItem.coordinate,
                                                                           _missionController.currentPlanViewVIIndex,
                                                                           true)
                }
                function _updateSplitCoord() {
                    if (_missionController.splitSegment) {
                        var distance = _missionController.splitSegment.coordinate1.distanceTo(_missionController.splitSegment.coordinate2)
                        var azimuth = _missionController.splitSegment.coordinate1.azimuthTo(_missionController.splitSegment.coordinate2)
                        splitSegmentItem.coordinate = _missionController.splitSegment.coordinate1.atDistanceAndAzimuth(distance / 2, azimuth)
                    } else {
                        coordinate = QtPositioning.coordinate()
                    }
                }
                Connections {
                    target: _missionController
                    function onSplitSegmentChanged()  { splitSegmentItem._updateSplitCoord() }
                }
                Connections {
                    target: _missionController.splitSegment
                    function onCoordinate1Changed()   { splitSegmentItem._updateSplitCoord() }
                    function onCoordinate2Changed()   { splitSegmentItem._updateSplitCoord() }
                }
            }
            MapItemView {
                model: QGroundControl.multiVehicleManager.vehicles
                delegate: VehicleMapItem {
                    vehicle: object
                    coordinate: object.coordinate
                    map: editorMap
                    size: ScreenTools.defaultFontPixelHeight * 3
                    z: QGroundControl.zOrderMapItems - 1
                }
            }
            GeoFenceMapVisuals {
                map: editorMap
                myGeoFenceController: _geoFenceController
                interactive: _editingLayer == _layerFence
                homePosition: _missionController.plannedHomePosition
                planView: true
                opacity: _editingLayer != _layerFence ? editorMap._nonInteractiveOpacity : 1
            }
            RallyPointMapVisuals {
                map: editorMap
                myRallyPointController: _rallyPointController
                interactive: _editingLayer == _layerRally
                planView: true
                opacity: _editingLayer != _layerRally ? editorMap._nonInteractiveOpacity : 1
            }
        }
        TTSHoverTerrainQuery {
            id: ttsTerrainQuery
            onTerrainAltitudeReceived: (success, altitude) => {
                ttsCoordTracker._hoverAlt = success ? altitude : null
            }
        }
        TTSHoverTerrainQuery {
            id: ttsNewItemTerrainQuery
            property var _queue: []
            property bool _busy: false
            property var _altMap: ({})
            function enqueue(item, coord, offset) {
                _queue.push({ item: item, lat: coord.latitude, lon: coord.longitude, offset: offset })
                if (!_busy) _processNext()
            }
            function _processNext() {
                if (_queue.length === 0) { _busy = false; return }
                _busy = true
                var entry = _queue[0]
                requestAltitude(entry.lat, entry.lon)
            }
            onTerrainAltitudeReceived: (success, altitude) => {
                if (_queue.length > 0) {
                    var entry = _queue.shift()
                    if (success && entry.item && entry.item.specifiesAltitude) {
                        var offset = entry.offset >= 0
                                     ? entry.offset
                                     : QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude.rawValue
                        var finalAlt = altitude + offset
                        entry.item.altitudeFrame = QGroundControl.AltitudeFrameAbsolute
                        entry.item.altitude.rawValue = finalAlt
                        _altMap[entry.item.sequenceNumber] = { alt: finalAlt, frame: QGroundControl.AltitudeFrameAbsolute }
                    }
                }
                _processNext()
            }
        }
        Connections {
            id: ttsAltSaver
            target: _missionController.currentPlanViewItem && _missionController.currentPlanViewItem.altitude
                    ? _missionController.currentPlanViewItem.altitude : null
            function onRawValueChanged() {
                var item = _missionController.currentPlanViewItem
                if (!item || !item.specifiesAltitude) return
                var defAlt = QGroundControl.settingsManager.appSettings.defaultMissionItemAltitude.rawValue
                if (Math.abs(item.altitude.rawValue - defAlt) > 0.1) {
                    ttsNewItemTerrainQuery._altMap[item.sequenceNumber] = { alt: item.altitude.rawValue, frame: item.altitudeFrame }
                }
            }
        }
        Connections {
            id: ttsCommandWatcher
            target: _missionController.currentPlanViewItem ? _missionController.currentPlanViewItem : null
            function onCommandChanged() {
                ttsCommandDelayTimer._retryCount = 0
                ttsCommandDelayTimer.restart()
            }
        }
        Timer {
            id: ttsCommandDelayTimer
            interval: 300
            repeat: false
            property int _retryCount: 0
            onTriggered: {
                var item = _missionController.currentPlanViewItem
                if (!item || !item.specifiesAltitude) { _retryCount = 0; return }
                var saved = ttsNewItemTerrainQuery._altMap[item.sequenceNumber]
                if (saved) {
                    item.altitudeFrame = saved.frame
                    item.altitude.rawValue = saved.alt
                    if (_retryCount < 2) {
                        _retryCount++
                        ttsCommandDelayTimer.restart()
                        return
                    }
                } else if (item.coordinate && item.coordinate.isValid) {
                    var offset = item.isTakeoffItem ? ttsTakeoffAltOffset() : undefined
                    ttsApplyTerrainAltitude(item, item.coordinate, offset)
                }
                _retryCount = 0
            }
        }
        Timer {
            id: ttsLandDelayTimer
            interval: 400
            repeat: false
            property var _item: null
            property var _coord: null
            onTriggered: {
                if (_item && _item.specifiesAltitude && _coord) {
                    ttsApplyTerrainAltitude(_item, _coord)
                }
                _item = null
            }
        }
        Timer {
            id: ttsTerrainDebounce
            interval: 150
            repeat: false
            onTriggered: {
                if (ttsCoordTracker._hoverCoord) {
                    ttsTerrainQuery.requestAltitude(ttsCoordTracker._hoverCoord.latitude,
                                                     ttsCoordTracker._hoverCoord.longitude)
                }
            }
        }
        MouseArea {
            id: ttsCoordTracker
            anchors.fill:    editorMap
            hoverEnabled:    true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            z: QGroundControl.zOrderWidgets + 99
            property var  _hoverCoord: null
            property var  _hoverAlt:   null
            onPositionChanged: (mouse) => {
                ttsCoordTracker._hoverCoord = editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false)
                ttsCoordTracker._hoverAlt = null
                ttsHoverPos.initValues()
                ttsTerrainDebounce.restart()
            }
            onExited: {
                ttsCoordTracker._hoverCoord = null
                ttsCoordTracker._hoverAlt = null
            }
        }
        TransformPositionController {
            id: ttsHoverPos
            coordinate: ttsCoordTracker._hoverCoord ? ttsCoordTracker._hoverCoord : QtPositioning.coordinate()
            onCoordinateChanged: initValues()
            Component.onCompleted: initValues()
        }
        Rectangle {
            id:                   ttsCoordBox
            z:                    QGroundControl.zOrderWidgets + 100
            anchors.top:          editorMap.top
            anchors.horizontalCenter: editorMap.horizontalCenter
            anchors.topMargin:    _toolsMargin
            width:                coordText.implicitWidth + ScreenTools.defaultFontPixelWidth * 2
            height:               coordText.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.6
            radius:               4
            color:                "#FFFFFF"
            border.color:         "#1E2830"
            border.width:         1
            visible:              ttsCoordTracker._hoverCoord !== null
            Text {
                id:              coordText
                anchors.centerIn: parent
                font.family:     "monospace"
                font.pixelSize:  ScreenTools.defaultFontPixelHeight * 0.75
                font.bold:       true
                color:           "#0A0C0E"
                text: ttsCoordTracker._hoverCoord
                      ? _root.ttsFormatCoord(ttsCoordTracker._hoverCoord) +
                        "   ALT: " + (ttsCoordTracker._hoverAlt !== null
                                      ? QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(ttsCoordTracker._hoverAlt).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
                                      : "…") +
                        _root.ttsDistFromHome(ttsCoordTracker._hoverCoord)
                      : ""
            }
        }

        // ── TTS PERMANENT PITCH READOUT ─────────────────────────────────
        //     Always visible when a vehicle is connected.
        //     Shows live IMU pitch so the user can adjust the launcher
        //     angle without needing to ARM first.
        Rectangle {
            id:      pitchReadoutBox
            visible: _root._vOk
            z:       QGroundControl.zOrderWidgets + 100
            anchors.top:          editorMap.top
            anchors.right:        editorMap.right
            anchors.topMargin:    _toolsMargin
            anchors.rightMargin:  editorMap._rightToolWidth + _toolsMargin
            width:   pitchReadoutRow.implicitWidth + ScreenTools.defaultFontPixelWidth * 2
            height:  pitchReadoutRow.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.6
            radius:  4
            color:   "#FFFFFF"
            border.color: "#00FF88"
            border.width: 1.5

            Row {
                id: pitchReadoutRow
                anchors.centerIn: parent
                spacing: ScreenTools.defaultFontPixelWidth * 0.6
                Text {
                    text: qsTr("PITCH")
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                    font.family: "monospace"; font.bold: true; color: "#4A6070"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: {
                        var p = _root._vPitch
                        return (p >= 0 ? "+" : "") + p.toFixed(1) + "°"
                    }
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.2
                    font.bold: true; font.family: "monospace"; color: "#0A0C0E"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // ── TTS LAUNCHER PITCH OVERLAY (Plan View) ───────────────────────
        //     Anchored below the white coord bar (ttsCoordBox).
        //     Shows IMU pitch when aircraft is armed+stationary on launcher.
        //     AUTO-ADJUST sets NAV_TAKEOFF param1 in the loaded plan.
        //     UPLOAD sends the modified plan to the vehicle.
        // ══════════════════════════════════════════════════════════════════
        Rectangle {
            id:      launcherPlanOverlay
            visible: _root._onLauncher && !_root._launcherDismissed
            z:       QGroundControl.zOrderWidgets + 101
            anchors.centerIn:             editorMap
            anchors.verticalCenterOffset: -ScreenTools.defaultFontPixelHeight * 5
            width:   ScreenTools.defaultFontPixelWidth * 48
            height:  ScreenTools.defaultFontPixelHeight * 11
            radius:  4
            color:   "#FFFFFF"
            border.color: "#00FF88"
            border.width: 2

            Column {
                id: launcherPlanCol
                anchors.top: parent.top
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                spacing: ScreenTools.defaultFontPixelHeight * 0.5

                // Title
                Row {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.6
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: "⚙"
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.1
                        color: "#00CC6A"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: qsTr("LAUNCHER PITCH DETECTED")
                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                        font.bold: true; font.letterSpacing: 1.5; font.family: "monospace"
                        color: "#0A0C0E"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Big pitch readout
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ScreenTools.defaultFontPixelWidth * 26
                    height: ScreenTools.defaultFontPixelHeight * 3
                    color: "#F0FFF5"
                    border.color: "#00CC6A"; border.width: 1; radius: 4
                    Row {
                        anchors.centerIn: parent
                        spacing: ScreenTools.defaultFontPixelWidth * 0.8
                        Text {
                            text: qsTr("PITCH")
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.8
                            font.family: "monospace"; font.bold: true; color: "#4A6070"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: {
                                var p = _root._vPitch
                                var sign = p >= 0 ? "+" : "-"
                                var num = Math.abs(p).toFixed(1)
                                while (num.length < 4) num = " " + num
                                return sign + num + "°"
                            }
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 1.8
                            font.bold: true; font.family: "monospace"; color: "#0A0C0E"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Description with live pitch value
                Text {
                    width: parent.width
                    text: {
                        var p = Math.abs(_root._vPitch).toFixed(1)
                        return qsTr("Set Takeoff Angle PITCH to ") + p + "°" + qsTr(" before launch.")
                    }
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.75
                    font.family: "monospace"; font.bold: true; color: "#0A0C0E"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            // DISMISS — anchored to bottom, independent from Column
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.6
                anchors.horizontalCenter: parent.horizontalCenter
                width: ScreenTools.defaultFontPixelWidth * 10
                height: ScreenTools.defaultFontPixelHeight * 2
                color: launcherDismissMA.containsMouse ? "#F0F0F0" : "#FAFAFA"
                border.color: "#4A6070"; border.width: 1; radius: 4
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: qsTr("DISMISS")
                    font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7
                    font.bold: true; font.family: "monospace"; color: "#4A6070"
                }
                MouseArea {
                    id: launcherDismissMA
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: _root._launcherDismissed = true
                }
            }
        }

        Rectangle {
            id:                   ttsPlanZoom
            z:                    QGroundControl.zOrderWidgets
            anchors.right:        editorMap.right
            anchors.bottom:       editorMap.bottom
            anchors.rightMargin:  editorMap._rightToolWidth + _toolsMargin
            anchors.bottomMargin: (wpTable.visible ? wpTable.height + _toolsMargin : _toolsMargin)
            width:  ScreenTools.defaultFontPixelWidth * 4
            height: ScreenTools.defaultFontPixelWidth * 8
            radius: ScreenTools.defaultFontPixelWidth * 0.4
            color:  Qt.rgba(0, 0, 0, 0.55)
            border.color: "#00CC6A"
            border.width: 1
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 1
                height: parent.height / 2 - 1
                color: ttsZoomInMA.pressed      ? "#00CC6A"
                     : ttsZoomInMA.containsMouse ? Qt.rgba(0, 1, 0.53, 0.15)
                     : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: ScreenTools.defaultFontPixelWidth * 2.6; font.bold: true; font.family: "monospace"
                    color: ttsZoomInMA.pressed ? "#0A0C0E" : "#00FF88"
                }
                MouseArea {
                    id: ttsZoomInMA
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: editorMap.zoomLevel = editorMap.zoomLevel + 1
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 1; anchors.rightMargin: 1
                height: 1; color: "#00CC6A"
            }
            Rectangle {
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 1
                height: parent.height / 2 - 1
                color: ttsZoomOutMA.pressed      ? "#00CC6A"
                     : ttsZoomOutMA.containsMouse ? Qt.rgba(0, 1, 0.53, 0.15)
                     : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "\u2212"
                    font.pixelSize: ScreenTools.defaultFontPixelWidth * 2.6; font.bold: true; font.family: "monospace"
                    color: ttsZoomOutMA.pressed ? "#0A0C0E" : "#00FF88"
                }
                MouseArea {
                    id: ttsZoomOutMA
                    anchors.fill: parent; hoverEnabled: true
                    onClicked: editorMap.zoomLevel = editorMap.zoomLevel - 1
                }
            }
        }
        ToolStrip {
            id: toolStrip
            anchors.margins: _toolsMargin
            anchors.left: parent.left
            anchors.top: parent.top
            z: QGroundControl.zOrderWidgets
            maxHeight: parent.height - toolStrip.y
            visible: _editingLayer == _layerMission
            property bool _isMissionLayer: _editingLayer == _layerMission
            Binding {
                target: waypointButton
                property: "checked"
                value: _addWaypointOnClick
            }
            ToolStripActionList {
                id: toolStripActionList
                model: [
                    ToolStripAction {
                        objectName: "planToolStrip_takeoffButton"
                        text: qsTr("Takeoff")
                        iconSource: "/res/takeoff.svg"
                        enabled: _missionController.isInsertTakeoffValid
                        visible: toolStrip._isMissionLayer && !_planMasterController.controllerVehicle.rover
                        onTriggered: {
                            insertTakeoffItemAfterCurrent()
                        }
                    },
                    ToolStripAction {
                        id: waypointButton
                        objectName: "planToolStrip_waypointButton"
                        text: qsTr("Waypoint")
                        iconSource: "/res/waypoint.svg"
                        enabled: _missionController.flyThroughCommandsAllowed
                        visible: toolStrip._isMissionLayer
                        checkable: true
                        onTriggered: { _addWaypointOnClick = !_addWaypointOnClick; if (_addWaypointOnClick) _addROIOnClick = false }
                    },
                    ToolStripAction {
                        text: qsTr("Stats")
                        iconSource: "/res/chevron-double-right.svg"
                        visible: missionStatus.hidden && QGroundControl.corePlugin.options.showMissionStatus
                        onTriggered: missionStatus.showMissionStatus()
                    }
                ]
            }
            model: toolStripActionList.model
        }
        MapScale {
            anchors.margins: _toolsMargin
            anchors.left: toolStrip.right
            anchors.top: parent.top
            mapControl: editorMap
            autoHide: true
        }
        PlanViewRightPanel {
            id: rightPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: _rightPanelWidth
            planMasterController: _planMasterController
            editorMap: editorMap
            onEditingLayerChangeRequested: (layer) => _editingLayer = layer
        }
        Item {
            id:                     layerSwitcher
            anchors.right:          rightPanel.left
            anchors.rightMargin:    _toolsMargin
            anchors.top:            parent.top
            anchors.topMargin:      _toolsMargin
            width:                  layerRow.width
            height:                 _layerButtonSize
            z:                      QGroundControl.zOrderWidgets
            property bool   expanded: false
            property real   _layerButtonSize: ScreenTools.defaultFontPixelHeight * 2.0
            property real   _spacing: ScreenTools.defaultFontPixelHeight * 0.25
            readonly property var _layers: [
                { layer: _layerMission, icon: "/res/waypoint.svg",      nodeType: "missionGroup" },
                { layer: _layerFence,   icon: "/res/GeoFence.svg",      nodeType: "fenceGroup" },
                { layer: _layerRally,   icon: "/res/RallyPoint.svg",    nodeType: "rallyGroup" }
            ]
            Timer {
                id: collapseTimer
                interval: 5000
                onTriggered: layerSwitcher.expanded = false
            }
            function toggle() {
                expanded = !expanded
                if (expanded) {
                    collapseTimer.restart()
                } else {
                    collapseTimer.stop()
                }
            }
            function choose(nodeType) {
                expanded = false
                collapseTimer.stop()
                rightPanel.selectLayer(nodeType)
            }
            Row {
                id:             layerRow
                anchors.right:  parent.right
                spacing:        layerSwitcher._spacing
                layoutDirection: Qt.RightToLeft
                Rectangle {
                    width:  layerSwitcher._layerButtonSize
                    height: width
                    radius: ScreenTools.defaultBorderRadius
                    color:  QGroundControl.globalPalette.buttonHighlight
                    QGCColoredImage {
                        anchors.centerIn:   parent
                        width:              parent.width * 0.6
                        height:             width
                        source:             layerSwitcher._layers.find(l => l.layer === _editingLayer)?.icon ?? "/res/waypoint.svg"
                        color:              QGroundControl.globalPalette.buttonHighlightText
                    }
                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked:    layerSwitcher.toggle()
                    }
                }
                Repeater {
                    model: layerSwitcher._layers.filter(l => l.layer !== _editingLayer)
                    Rectangle {
                        required property var modelData
                        width:   layerSwitcher._layerButtonSize
                        height:  width
                        radius:  ScreenTools.defaultBorderRadius
                        color:   QGroundControl.globalPalette.button
                        visible: opacity > 0
                        opacity: layerSwitcher.expanded ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        QGCColoredImage {
                            anchors.centerIn:   parent
                            width:              parent.width * 0.6
                            height:             width
                            source:             modelData.icon
                            color:              QGroundControl.globalPalette.buttonText
                        }
                        QGCMouseArea {
                            anchors.fill: parent
                            onClicked:    layerSwitcher.choose(modelData.nodeType)
                        }
                    }
                }
            }
        }
        RowLayout {
            id: missionStatus
            anchors.margins: _toolsMargin
            anchors.left: _calcLeftAnchor()
            anchors.right: rightPanel.left
            anchors.bottom: parent.bottom
            spacing: 0
            visible: false
            readonly property bool hidden: _planViewSettings.showMissionItemStatus.rawValue ? false : true
            function showMissionStatus() {
                _planViewSettings.showMissionItemStatus.rawValue = true
            }
            function _calcLeftAnchor() {
                let bottomOfToolStrip = toolStrip.y + toolStrip.height
                let largestStatsHeight = Math.max(terrainStatus.height, missionStats.height)
                if (bottomOfToolStrip + largestStatsHeight > parent.height - missionStatus.anchors.margins) {
                    return toolStrip.right
                }
                return parent.left
            }
            function _toggleMissionStatusVisibility() {
                _planViewSettings.showMissionItemStatus.rawValue = _planViewSettings.showMissionItemStatus.rawValue ? false : true
            }
            ColumnLayout {
                id: missionStatsButtonLayout
                Layout.alignment: Qt.AlignBottom
                spacing: 0
                property real _buttonImplicitWidth: ScreenTools.defaultFontPixelHeight * 1.5
                property real _buttonImageMargins: _buttonImplicitWidth * 0.15
                Rectangle {
                    id: terrainButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    color: checked ? QGroundControl.globalPalette.buttonHighlight : QGroundControl.globalPalette.button
                    property bool checked: true
                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/terrain.svg"
                        color: parent.checked ? QGroundControl.globalPalette.buttonHighlightText : QGroundControl.globalPalette.buttonText
                    }
                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked: {
                            terrainButton.checked = true
                            missionStatsButton.checked = false
                        }
                    }
                }
                Rectangle {
                    id: missionStatsButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    color: checked ? QGroundControl.globalPalette.buttonHighlight : QGroundControl.globalPalette.button
                    property bool checked: false
                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/sliders.svg"
                        color: parent.checked ? QGroundControl.globalPalette.buttonHighlightText : QGroundControl.globalPalette.buttonText
                    }
                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked: {
                            missionStatsButton.checked = true
                            terrainButton.checked = false
                        }
                    }
                }
                Rectangle {
                    id: bottomStatusOpenCloseButton
                    implicitWidth: missionStatsButtonLayout._buttonImplicitWidth
                    implicitHeight: implicitWidth
                    color: QGroundControl.globalPalette.button
                    QGCColoredImage {
                        anchors.margins: missionStatsButtonLayout._buttonImageMargins
                        anchors.fill: parent
                        source: "/res/chevron-double-left.svg"
                        color: QGroundControl.globalPalette.buttonText
                    }
                    QGCMouseArea {
                        anchors.fill: parent
                        onClicked: missionStatus._toggleMissionStatusVisibility()
                    }
                }
            }
            TerrainStatus {
                id: terrainStatus
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                height: ScreenTools.defaultFontPixelHeight * 7
                missionController: _missionController
                visible: terrainButton.checked
                onSetCurrentSeqNum: _missionController.setCurrentPlanViewSeqNum(seqNum, true)
            }
            MissionStats {
                id: missionStats
                Layout.alignment: Qt.AlignBottom
                Layout.fillWidth: true
                visible: missionStatsButton.checked
                planMasterController: _root._planMasterController
            }
        }
        WaypointTable {
            id:                   wpTable
            z:                    QGroundControl.zOrderWidgets + 1
            anchors.left:         parent.left
            anchors.right:        rightPanel.left
            anchors.bottom:       parent.bottom
            height:               parent.height * 0.32
            visible:              _editingLayer == _layerMission
            missionController:    _missionController
            planMasterController: _planMasterController
            map:                  editorMap
        }
    }
    Component {
        id: patternDropPanel
        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            QGCLabel { text: qsTr("Create complex pattern:") }
            Repeater {
                model: _missionController.complexMissionItems
                QGCButton {
                    text: modelData.translatedName
                    Layout.fillWidth: true
                    onClicked: {
                        insertComplexItemAfterCurrent(modelData.canonicalName)
                        dropPanel.hide()
                    }
                }
            }
        }
    }
    QGCPopupDialogFactory {
        id: promptForPlanUsageOnVehicleChangePopupFactory
        dialogComponent: promptForPlanUsageOnVehicleChangePopupComponent
    }
    Component {
        id: promptForPlanUsageOnVehicleChangePopupComponent
        QGCPopupDialog {
            title: _planMasterController.managerVehicle.isOfflineEditingVehicle ? qsTr("Plan View - Vehicle Disconnected") : qsTr("Plan View - Vehicle Changed")
            buttons: Dialog.NoButton
            ColumnLayout {
                QGCLabel {
                    Layout.maximumWidth: parent.width
                    wrapMode: QGCLabel.WordWrap
                    text: _planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                                qsTr("The vehicle associated with the plan in the Plan View is no longer available. What would you like to do with that plan?") : qsTr("The plan being worked on in the Plan View is not from the current vehicle. What would you like to do with that plan?")
                }
                QGCButton {
                    Layout.fillWidth: true
                    text: (_planMasterController.dirtyForSave) ?
                                            (_planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                                 qsTr("Discard Unsaved Changes") : qsTr("Discard Unsaved Changes, Load New Plan From Vehicle")) : qsTr("Load New Plan From Vehicle")
                    onClicked: {
                        _planMasterController.showPlanFromManagerVehicle()
                        _promptForPlanUsageShowing = false
                        close();
                    }
                }
                QGCButton {
                    Layout.fillWidth: true
                    text: _planMasterController.managerVehicle.isOfflineEditingVehicle ?
                                            qsTr("Keep Current Plan") : qsTr("Keep Current Plan, Don't Update From Vehicle")
                    onClicked: {
                        _promptForPlanUsageShowing = false
                        close()
                    }
                }
            }
        }
    }
    Component {
        id: insertOrCancelROIDropPanelComponent
        DropPanel {
            id: insertOrCancelROIDropPanel
            onClosed: destroy()
            property var mapClickCoord
            sourceComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelWidth / 2
                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Insert ROI")
                        onClicked: {
                            insertOrCancelROIDropPanel.close()
                            insertROIAfterCurrent(mapClickCoord)
                        }
                    }
                    QGCButton {
                        Layout.fillWidth: true
                        text: qsTr("Insert Cancel ROI")
                        onClicked: {
                            insertOrCancelROIDropPanel.close()
                            insertCancelROIAfterCurrent()
                        }
                    }
                }
            }
        }
    }
}