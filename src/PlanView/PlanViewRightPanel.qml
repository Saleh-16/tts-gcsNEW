import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import "ConstraintResolver.js" as Constraints

Item {
    required property var editorMap
    required property var planMasterController
    signal editingLayerChangeRequested(int layer)
    id: root

    property var  _missionController: planMasterController.missionController
    property real _toolsMargin:       ScreenTools.defaultFontPixelWidth * 0.75
    property var  _appSettings:       QGroundControl.settingsManager.appSettings
    property var  _vehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property bool _connected:         _vehicle !== null && _vehicle !== undefined

    property string _paramFileContent: ""
    property string _paramFileName:    ""
    property bool   _paramsLoaded:     false
    property bool   _panelExpanded:    true
    property var    _missingParams:    []
    property var    _uploadedParams:   []
    property bool   _uploaded:         false

    // Create controller ONLY when vehicle is connected
    Loader {
        id: paramControllerLoader
        active: root._connected
        sourceComponent: Component {
            ParameterEditorController { }
        }
    }
    property var paramController: paramControllerLoader.item

    Connections {
        target: root.paramController
        enabled: root.paramController !== null
        function onMissingParamsFromFile(missingParams) {
            root._missingParams = missingParams
        }
    }

    function _parseParamFile(text) {
        var fileParams = {}
        if (!text) return fileParams
        var lines = text.split('\n')
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === '' || line.charAt(0) === '#') continue
            var comma = line.indexOf(',')
            if (comma < 0) continue
            var name = line.substring(0, comma).trim()
            var val = parseFloat(line.substring(comma + 1).trim())
            if (!isNaN(val)) fileParams[name] = val
        }
        return fileParams
    }

    function selectNextNotReady() {
        for (var i = 0; i < _missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    function getEffectiveLimits() {
        if (root._paramsLoaded) return Constraints.resolveFromParamText(root._paramFileContent)
        return Constraints.resolveFromVehicle(root._vehicle)
    }

    QGCPalette { id: qgcPal }
    Rectangle { id: rightPanelBackground; anchors.fill: parent; color: qgcPal.window; opacity: 0.85 }

    QGCFileDialog {
        id: paramFileDialog
        title: qsTr("Load Parameters")
        folder: _appSettings ? _appSettings.parameterSavePath : ""
        nameFilters: [qsTr("Parameter Files (*.%1)").arg(_appSettings.parameterFileExtension), qsTr("Mission Planner Files (*.param)"), qsTr("All Files (*)")]
        onAcceptedForLoad: (file) => {
            close()
            // Save for ConstraintResolver
            try {
                var url = file.toString()
                if (!url.startsWith("file://")) url = "file://" + url
                var xhr = new XMLHttpRequest()
                xhr.open("GET", url, false)
                xhr.send()
                if (xhr.responseText) root._paramFileContent = xhr.responseText
            } catch(e) {}

            var parts = file.toString().split("/")
            root._paramFileName = parts[parts.length - 1]
            root._paramsLoaded = true
            root._missingParams = []
            paramHeader.expanded = true

            // Use QGC's popup — it works correctly
            if (root.paramController && root.paramController.buildDiffFromFile(file)) {
                // Save diff data (changed params)
                var diffNames = {}
                var saved = []
                for (var i = 0; i < root.paramController.diffList.count; i++) {
                    var obj = root.paramController.diffList.get(i)
                    saved.push({ name: obj.name, fileValue: obj.fileValue, vehicleValue: obj.vehicleValue, units: obj.units, status: "changed" })
                    diffNames[obj.name] = true
                }

                // Parse file to find params that are SAME (not in diff, not missing)
                var fileParams = root._parseParamFile(root._paramFileContent)
                var missingSet = {}
                for (var m = 0; m < root._missingParams.length; m++) missingSet[root._missingParams[m]] = true

                var allNames = Object.keys(fileParams)
                for (var j = 0; j < allNames.length; j++) {
                    var pName = allNames[j]
                    if (!diffNames[pName] && !missingSet[pName]) {
                        saved.push({ name: pName, fileValue: String(fileParams[pName]), vehicleValue: String(fileParams[pName]), units: "", status: "same" })
                    }
                }

                root._uploadedParams = saved

                if (root.paramController.diffList.count > 0) {
                    // Has differences — show popup for OK/Cancel
                    root._uploaded = false
                    parameterDiffDialogFactory.open()
                } else {
                    // No differences — show report directly (no popup needed)
                    root._uploaded = true
                    root.paramController.clearDiff()
                }
            }
        }
    }

    QGCPopupDialogFactory {
        id: parameterDiffDialogFactory
        dialogComponent: Component {
            ParameterDiffDialog {
                paramController: root.paramController
                onAccepted: {
                    root._uploaded = true
                    // Wait for writes to complete, then verify
                    verifyTimer.start()
                }
            }
        }
    }

    Timer {
        id: verifyTimer
        interval: 2000
        onTriggered: {
            // Re-check each changed param to see if write succeeded
            var vehicle = QGroundControl.multiVehicleManager.activeVehicle
            if (!vehicle) return
            var verified = []
            for (var i = 0; i < root._uploadedParams.length; i++) {
                var p = root._uploadedParams[i]
                if (p.status === "same") {
                    verified.push(p)
                    continue
                }
                // Try to read current value and compare with file value
                try {
                    var fact = vehicle.parameterManager.getParameterFact(-1, p.name)
                    var currentVal = fact.rawValue
                    var fileVal = parseFloat(p.fileValue)
                    if (Math.abs(currentVal - fileVal) < 0.01) {
                        verified.push({ name: p.name, fileValue: p.fileValue, vehicleValue: p.vehicleValue, units: p.units, status: "changed" })
                    } else {
                        verified.push({ name: p.name, fileValue: p.fileValue, vehicleValue: String(currentVal), units: p.units, status: "error" })
                    }
                } catch(e) {
                    verified.push({ name: p.name, fileValue: p.fileValue, vehicleValue: p.vehicleValue, units: p.units, status: "error" })
                }
            }
            root._uploadedParams = verified
        }
    }

    Item {
        anchors.fill: rightPanelBackground
        DeadMouseArea { anchors.fill: parent }

        Item {
            id: pymHeader
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: ScreenTools.defaultFontPixelHeight * 2.6
            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 1, 0.53, 0.04) }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: qgcPal.windowShadeLight }
            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth; anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                anchors.verticalCenter: parent.verticalCenter; spacing: ScreenTools.defaultFontPixelWidth * 0.5
                QGCColoredImage { Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.75; Layout.preferredHeight: Layout.preferredWidth; source: "/InstrumentValueIcons/cheveron-right.svg"; color: qgcPal.colorGreen; rotation: root._panelExpanded ? 90 : 0; Behavior on rotation { NumberAnimation { duration: 150 } } }
                Column { Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                    QGCLabel { text: "PLAN YOUR MISSION"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7; font.bold: true; font.letterSpacing: ScreenTools.defaultFontPixelWidth * 0.1; color: qgcPal.colorGreen }
                    QGCLabel { text: qsTr("Build your mission, then review before flight"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55; color: qgcPal.text }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root._panelExpanded = !root._panelExpanded }
        }

        Flickable {
            anchors.top: pymHeader.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            visible: root._panelExpanded; contentHeight: contentColumn.height; flickableDirection: Flickable.VerticalFlick; clip: true

            Column {
                id: contentColumn; width: parent.width

                PlanTreeView {
                    id: planTreeView; width: parent.width; height: contentHeight
                    editorMap: root.editorMap; planMasterController: root.planMasterController; interactive: false
                    onEditingLayerChangeRequested: (layer) => root.editingLayerChangeRequested(layer)
                }

                Rectangle { width: parent.width; height: 1; color: qgcPal.windowShadeLight }

                // ═══════════════════════════════════
                // ⑦ UPLOAD PARAMETERS
                // ═══════════════════════════════════
                Column {
                    width: parent.width; spacing: 0

                    Rectangle {
                        id: paramHeader; width: parent.width
                        height: ScreenTools.implicitComboBoxHeight + ScreenTools.defaultFontPixelWidth
                        color: qgcPal.windowShade; property bool expanded: false
                        RowLayout {
                            anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5; spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            Rectangle { Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.0; Layout.preferredHeight: Layout.preferredWidth; radius: width/2; color: paramHeader.expanded ? qgcPal.colorGreen : qgcPal.windowShadeDark; Text { anchors.centerIn: parent; text: "7"; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; font.bold: true; font.family: "monospace"; color: paramHeader.expanded ? "#0A0C0E" : qgcPal.colorGrey } }
                            QGCColoredImage { Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.75; Layout.preferredHeight: Layout.preferredWidth; source: "/InstrumentValueIcons/cheveron-right.svg"; color: qgcPal.text; rotation: paramHeader.expanded ? 90 : 0; Behavior on rotation { NumberAnimation { duration: 150 } } }
                            QGCLabel { Layout.alignment: Qt.AlignBaseline; text: qsTr("Upload Parameters"); font.bold: true }
                            QGCLabel { Layout.alignment: Qt.AlignBaseline; Layout.fillWidth: true; text: root._paramsLoaded ? root._paramFileName : ""; elide: Text.ElideRight; font.pointSize: ScreenTools.smallFontPointSize; color: root._paramsLoaded ? qgcPal.colorGreen : qgcPal.colorGrey }
                        }
                        MouseArea { anchors.fill: parent; onClicked: paramHeader.expanded = !paramHeader.expanded }
                    }

                    Column {
                        width: parent.width; visible: paramHeader.expanded
                        Rectangle {
                            width: parent.width; height: pBody.height + ScreenTools.defaultFontPixelHeight; color: qgcPal.window
                            Column {
                                id: pBody; width: parent.width - ScreenTools.defaultFontPixelWidth * 2; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5; spacing: ScreenTools.defaultFontPixelHeight * 0.4

                                // ── Load button ──
                                Rectangle {
                                    width: parent.width; height: ScreenTools.defaultFontPixelHeight * 2.2; radius: ScreenTools.defaultFontPixelWidth * 0.4
                                    color: "transparent"; border.color: root._connected ? qgcPal.colorGreen : qgcPal.colorGrey; border.width: 1.5; opacity: root._connected ? 1.0 : 0.35
                                    QGCLabel { anchors.centerIn: parent; text: root._connected ? (root._paramsLoaded ? qsTr("Load Another .param") : qsTr("Load .param File")) : qsTr("Connect vehicle first"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.7; font.bold: true; color: root._connected ? qgcPal.colorGreen : qgcPal.colorGrey }
                                    MouseArea { anchors.fill: parent; enabled: root._connected; onClicked: { if(root.paramController) root.paramController.clearDiff(); paramFileDialog.openForLoad() } }
                                }

                                QGCLabel { visible: root._paramsLoaded; text: "✓ " + root._paramFileName; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.6; color: qgcPal.colorGreen }

                                // ── Uploaded Parameters (after OK) ──
                                Column {
                                    width: parent.width; spacing: 0
                                    visible: root._uploaded && root._uploadedParams.length > 0

                                    QGCLabel {
                                        text: root._uploadedParams.length + qsTr(" parameters processed:")
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        font.bold: true; color: qgcPal.colorGreen
                                        bottomPadding: ScreenTools.defaultFontPixelHeight * 0.2
                                    }

                                    Rectangle {
                                        width: parent.width; height: ScreenTools.defaultFontPixelHeight * 1.3; color: qgcPal.windowShadeDark
                                        Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; spacing: 0
                                            QGCLabel { width: ScreenTools.defaultFontPixelWidth * 1.5; text: "" }
                                            QGCLabel { width: ScreenTools.defaultFontPixelWidth * 12; text: qsTr("Name"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; font.bold: true; color: qgcPal.colorGrey; leftPadding: ScreenTools.defaultFontPixelWidth * 0.3 }
                                            QGCLabel { width: ScreenTools.defaultFontPixelWidth * 7; text: qsTr("Before"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; font.bold: true; color: qgcPal.colorGrey; horizontalAlignment: Text.AlignRight }
                                            QGCLabel { width: ScreenTools.defaultFontPixelWidth * 7; text: qsTr("After"); font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; font.bold: true; color: qgcPal.colorGrey; horizontalAlignment: Text.AlignRight }
                                        }
                                    }

                                    Repeater {
                                        model: root._uploadedParams
                                        Rectangle {
                                            width: parent.width; height: ScreenTools.defaultFontPixelHeight * 1.4
                                            color: index % 2 === 0 ? Qt.rgba(1,1,1,0.02) : "transparent"
                                            Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; spacing: 0
                                                QGCLabel { width: ScreenTools.defaultFontPixelWidth * 1.5; text: modelData.status === "changed" ? "✓" : modelData.status === "error" ? "✗" : "="; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; color: modelData.status === "changed" ? qgcPal.colorGreen : modelData.status === "error" ? qgcPal.colorRed : qgcPal.colorGrey }
                                                QGCLabel { width: ScreenTools.defaultFontPixelWidth * 12; text: modelData.name; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; elide: Text.ElideRight; leftPadding: ScreenTools.defaultFontPixelWidth * 0.3; color: modelData.status === "error" ? qgcPal.colorRed : qgcPal.text }
                                                QGCLabel { width: ScreenTools.defaultFontPixelWidth * 7; text: modelData.vehicleValue + " " + modelData.units; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; color: qgcPal.colorGrey; horizontalAlignment: Text.AlignRight }
                                                QGCLabel { width: ScreenTools.defaultFontPixelWidth * 7; text: modelData.fileValue + " " + modelData.units; font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5; font.bold: modelData.status === "changed"; color: modelData.status === "changed" ? qgcPal.colorGreen : modelData.status === "error" ? qgcPal.colorRed : qgcPal.text; horizontalAlignment: Text.AlignRight }
                                            }
                                        }
                                    }
                                }

                                // ── Missing Parameters ──
                                Column {
                                    width: parent.width; spacing: ScreenTools.defaultFontPixelHeight * 0.15
                                    visible: root._missingParams.length > 0

                                    QGCLabel {
                                        text: root._missingParams.length + qsTr(" missing on vehicle:")
                                        font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.55
                                        font.bold: true; color: qgcPal.colorOrange
                                    }

                                    Repeater {
                                        model: root._missingParams
                                        QGCLabel {
                                            text: "✗ " + modelData
                                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                                            color: qgcPal.colorGrey
                                            leftPadding: ScreenTools.defaultFontPixelWidth * 0.5
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: qgcPal.windowShadeLight }

                MissionReviewPanel {
                    id: reviewPanel; width: parent.width
                    planMasterController: root.planMasterController
                }
            }
        }
    }

    function selectLayer(nodeType) {
        if (!root._panelExpanded) root._panelExpanded = true
        planTreeView.selectLayer(nodeType)
    }
}