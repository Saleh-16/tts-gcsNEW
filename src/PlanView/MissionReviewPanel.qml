import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import "ConstraintResolver.js" as Constraints
import "MissionReviewEngine.js" as ReviewEngine
Item {
    id: root
    width: parent.width
    height: contentCol.height
    required property var planMasterController
    required property int sectionIndex
    property var  _missionController:   planMasterController.missionController
    property var  _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property var  _visualItems:         _missionController ? _missionController.visualItems : null
    property int  _itemCount:           _visualItems ? _visualItems.count : 0
    property var    _report:            null
    property bool   _reviewing:         false
    property bool   _hasResults:        false
    property bool   _stale:             false
    property bool   _accepted:          false
    property real   _progress:          0
    // ── Upload/Save control ──
    property bool uploadAllowed: {
        if (!_hasResults) return true
        if (!_report) return true
        if (!_report.requiresAcknowledgment) return true
        return _accepted
    }
    signal riskAccepted(string reportText)
    property bool _hasHome:     _itemCount > 0
    property bool _hasTakeoff:  _checkForCommand("TAKEOFF")
    property bool _hasTerminal: _checkForCommand("RTL") || _checkForCommand("LAND")
    property int  _navCount:    _countNavItems()
    on_ItemCountChanged: {
        if (_hasResults) _stale = true
    }
    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    // fileWriter is a global context property (registered in QGCCorePlugin.cc)
    function _checkForCommand(cmdType) {
        if (!_visualItems) return false
        for (var i = 0; i < _visualItems.count; i++) {
            var item = _visualItems.get(i)
            if (!item) continue
            if (cmdType === "TAKEOFF" && item.isTakeoffItem) return true
            if (cmdType === "RTL" && item.command === 20) return true
            if (cmdType === "LAND" && item.command === 21) return true
        }
        return false
    }
    function _countNavItems() {
        if (!_visualItems) return 0
        var count = 0
        for (var i = 1; i < _visualItems.count; i++) {
            var item = _visualItems.get(i)
            if (item && item.specifiesCoordinate) count++
        }
        return count
    }
    function _runReview() {
        _reviewing = true
        _progress = 0
        _accepted = false
        progressTimer.start()
    }
    Timer {
        id: progressTimer
        interval: 40
        repeat: true
        onTriggered: {
            _progress += Math.random() * 0.12 + 0.04
            if (_progress >= 1.0) {
                _progress = 1.0
                progressTimer.stop()
                _executeReview()
            }
        }
    }
    function _executeReview() {
        var limits
        if (root.parent && root.parent.parent && root.parent.parent.parent
            && root.parent.parent.parent.getEffectiveLimits) {
            limits = root.parent.parent.parent.getEffectiveLimits()
        } else {
            limits = Constraints.resolveFromVehicle(_activeVehicle)
        }
        var homePos = _missionController ? _missionController.plannedHomePosition : null
        _report = ReviewEngine.reviewMission(_visualItems, homePos, limits)
        _reviewing = false
        _hasResults = true
        _stale = false
    }
    function _fmtDist(meters) {
        if (meters >= 1000) return (meters / 1000).toFixed(1) + " km"
        return meters.toFixed(0) + " m"
    }
    function _fmtTime(seconds) {
        if (seconds <= 0) return "--"
        var m = Math.floor(seconds / 60)
        if (m >= 60) return Math.floor(m / 60) + "h " + (m % 60) + "m"
        return "~" + m + " min"
    }
    function _filterFindings(category) {
        if (!_report) return []
        var result = []
        for (var i = 0; i < _report.findings.length; i++) {
            if (_report.findings[i].category === category) result.push(_report.findings[i])
        }
        return result
    }
    function _generateRiskReport() {
        if (!_report) return ""
        var d = new Date()
        var timestamp = d.getFullYear() + "-" +
            (d.getMonth()+1).toString().padStart(2,"0") + "-" +
            d.getDate().toString().padStart(2,"0") + " " +
            d.getHours().toString().padStart(2,"0") + ":" +
            d.getMinutes().toString().padStart(2,"0") + ":" +
            d.getSeconds().toString().padStart(2,"0")
        var lines = []
        lines.push("===================================================")
        lines.push("  TTS GROUP - MISSION RISK ACCEPTANCE REPORT")
        lines.push("===================================================")
        lines.push("")
        lines.push("Date/Time:      " + timestamp)
        lines.push("Status:         " + _report.status)
        lines.push("Total Distance: " + _fmtDist(_report.stats.totalDistance))
        lines.push("Max Altitude:   " + _report.stats.maxAltitude.toFixed(0) + "m")
        lines.push("Max Range:      " + _fmtDist(_report.stats.maxRange))
        lines.push("Waypoints:      " + _report.stats.waypointCount)
        lines.push("")
        lines.push("---------------------------------------------------")
        lines.push("  FINDINGS:  " + _report.counts.critical + " CRITICAL  " +
                    _report.counts.warning + " WARNING  " +
                    _report.counts.notice + " PASS")
        lines.push("---------------------------------------------------")
        lines.push("")
        for (var i = 0; i < _report.findings.length; i++) {
            var f = _report.findings[i]
            var icon = f.severity === "CRITICAL" ? "[FAIL]" : f.severity === "WARNING" ? "[WARN]" : "[PASS]"
            lines.push(icon + " " + f.problem)
            lines.push("  Category:       " + f.category)
            if (f.affectedWaypoints && f.affectedWaypoints.length > 0)
                lines.push("  Waypoints:      " + f.affectedWaypoints.join(", "))
            lines.push("  Detail:         " + f.explanation)
            lines.push("  Flight Impact:  " + f.flightImpact)
            if (f.recommendation)
                lines.push("  Recommendation: " + f.recommendation)
            if (f.constraintSource)
                lines.push("  Source:         " + f.constraintSource)
            lines.push("")
        }
        lines.push("---------------------------------------------------")
        lines.push("  OPERATOR ACKNOWLEDGMENT")
        lines.push("---------------------------------------------------")
        lines.push("")
        lines.push("The operator has reviewed all findings above and")
        lines.push("accepts full responsibility for uploading and")
        lines.push("executing this mission with known risks.")
        lines.push("")
        lines.push("Accepted at: " + timestamp)
        lines.push("")
        lines.push("===================================================")
        return lines.join("\n")
    }
    function _structureOk() { return _filterFindings("STRUCTURE").length === 0 }
    function _engFindings() {
        return _filterFindings("GEOMETRY").concat(_filterFindings("AIRCRAFT")).concat(_filterFindings("ARDUPILOT"))
    }
    function _badgeText(findingsList) {
        if (findingsList.length === 0) return qsTr("✓ Pass")
        var c = 0, w = 0
        for (var i = 0; i < findingsList.length; i++) {
            if (findingsList[i].severity === "CRITICAL") c++
            if (findingsList[i].severity === "WARNING") w++
        }
        var parts = []
        if (c > 0) parts.push(c + " ✗")
        if (w > 0) parts.push(w + " ⚠")
        return parts.join("  ")
    }
    function _badgeColor(findingsList) {
        for (var i = 0; i < findingsList.length; i++) {
            if (findingsList[i].severity === "CRITICAL") return qgcPal.colorRed
        }
        for (var j = 0; j < findingsList.length; j++) {
            if (findingsList[j].severity === "WARNING") return qgcPal.colorOrange
        }
        return qgcPal.colorGreen
    }
    function _readinessText() {
        if (!_report) return ""
        switch (_report.status) {
            case "READY":                 return qsTr("READY")
            case "READY_WITH_ADVISORIES": return qsTr("READY WITH ADVISORIES")
            case "REVIEW_REQUIRED":       return qsTr("REVIEW REQUIRED")
            case "INCOMPLETE":            return qsTr("INCOMPLETE")
            default: return ""
        }
    }
    function _countsText() {
        if (!_report) return ""
        var parts = []
        if (_report.counts.critical > 0) parts.push(_report.counts.critical + " critical")
        if (_report.counts.warning > 0)  parts.push(_report.counts.warning + " warnings")
        if (_report.counts.notice > 0)   parts.push(_report.counts.notice + " notices")
        if (parts.length === 0) return qsTr("No engineering concerns")
        return parts.join(" - ")
    }
    // UI
    Column {
        id: contentCol
        width: parent.width
        spacing: 0
        Rectangle {
            width: parent.width
            height: ScreenTools.implicitComboBoxHeight + ScreenTools.defaultFontPixelWidth
            color: qgcPal.windowShade
            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.0
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: reviewBody.visible ? qgcPal.colorGreen : qgcPal.windowShadeDark
                    Text {
                        anchors.centerIn: parent
                        text: root.sectionIndex.toString()
                        font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                        font.bold: true
                        font.family: "monospace"
                        color: reviewBody.visible ? "#0A0C0E" : qgcPal.colorGrey
                    }
                }
                QGCColoredImage {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.75
                    Layout.preferredHeight: Layout.preferredWidth
                    source: "/InstrumentValueIcons/cheveron-right.svg"
                    color: qgcPal.colorGreen
                    rotation: reviewBody.visible ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 150 } }
                }
                QGCLabel {
                    Layout.alignment: Qt.AlignBaseline
                    text: qsTr("Mission Review")
                    font.bold: true
                    color: qgcPal.colorGreen
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.5
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: {
                        if (_reviewing)              return "transparent"
                        if (_stale || !_hasResults)  return qgcPal.colorGrey
                        if (_report.status === "READY") return qgcPal.colorGreen
                        if (_report.status === "READY_WITH_ADVISORIES") return qgcPal.colorYellow
                        return qgcPal.colorRed
                    }
                    border.width: _reviewing ? 2 : 0
                    border.color: qgcPal.colorGreen
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: reviewBody.visible = !reviewBody.visible
            }
        }
        Column {
            id: reviewBody
            width: parent.width
            visible: true
            Rectangle {
                width: parent.width
                height: bodyContent.height + ScreenTools.defaultFontPixelHeight
                color: qgcPal.window
                Column {
                    id: bodyContent
                    width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
                    spacing: ScreenTools.defaultFontPixelHeight * 0.4
                    Rectangle {
                        width: parent.width
                        height: staleLabel.height + ScreenTools.defaultFontPixelHeight * 0.6
                        color: Qt.rgba(0.3, 0.3, 0.3, 0.2)
                        border.color: qgcPal.colorGrey
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelWidth * 0.3
                        visible: _stale && _hasResults
                        QGCLabel {
                            id: staleLabel
                            anchors.centerIn: parent
                            text: qsTr("Mission changed - review again")
                            color: qgcPal.colorGrey
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: ScreenTools.defaultFontPixelHeight * 2.2
                        radius: ScreenTools.defaultFontPixelWidth * 0.4
                        color: "transparent"
                        border.color: _reviewing ? qgcPal.colorGrey : qgcPal.colorGreen
                        border.width: 1.5
                        opacity: _reviewing ? 0.5 : 1.0
                        QGCLabel {
                            anchors.centerIn: parent
                            text: _reviewing ? qsTr("Analyzing...") : _hasResults ? qsTr("Review Again") : qsTr("Review Mission")
                            font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                            font.bold: true
                            color: _reviewing ? qgcPal.colorGrey : qgcPal.colorGreen
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !_reviewing && _itemCount > 1
                            onClicked: _runReview()
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: ScreenTools.defaultFontPixelHeight * 0.2
                        color: qgcPal.windowShadeDark
                        radius: height / 2
                        visible: _reviewing
                        Rectangle {
                            width: parent.width * _progress
                            height: parent.height
                            color: qgcPal.colorGreen
                            radius: height / 2
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: ScreenTools.defaultFontPixelHeight * 0.3
                        visible: _hasResults && !_reviewing
                        Repeater {
                            model: _hasResults ? _buildGroupModel() : []
                            Column {
                                width: parent.width
                                spacing: 0
                                property var groupData: modelData
                                Rectangle {
                                    width: parent.width
                                    height: ScreenTools.defaultFontPixelHeight * 1.8
                                    color: qgcPal.windowShadeDark
                                    radius: ScreenTools.defaultFontPixelWidth * 0.3
                                    property bool expanded: groupData.findings.length > 0
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                        QGCColoredImage {
                                            Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.5
                                            Layout.preferredHeight: Layout.preferredWidth
                                            source: "/InstrumentValueIcons/cheveron-right.svg"
                                            color: qgcPal.text
                                            rotation: parent.parent.expanded ? 90 : 0
                                        }
                                        QGCLabel {
                                            text: groupData.title
                                            font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        Rectangle {
                                            Layout.preferredWidth:  grpBadge.width + ScreenTools.defaultFontPixelWidth * 1.5
                                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.0
                                            radius: ScreenTools.defaultFontPixelWidth * 0.3
                                            color: Qt.rgba(groupData.badgeColor.r, groupData.badgeColor.g, groupData.badgeColor.b, 0.2)
                                            border.width: 1
                                            border.color: Qt.rgba(groupData.badgeColor.r, groupData.badgeColor.g, groupData.badgeColor.b, 0.4)
                                            QGCLabel {
                                                id: grpBadge
                                                anchors.centerIn: parent
                                                text: groupData.badge
                                                font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                                                font.bold: true
                                                color: groupData.badgeColor
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: parent.expanded = !parent.expanded
                                    }
                                }
                                Column {
                                    width: parent.width
                                    visible: parent.children[0].expanded
                                    Repeater {
                                        model: groupData.findings
                                        Rectangle {
                                            width: parent.width
                                            height: fCol.height + ScreenTools.defaultFontPixelHeight * 0.5
                                            color: "transparent"
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                width: parent.width; height: 1
                                                color: qgcPal.groupBorder
                                            }
                                            Column {
                                                id: fCol
                                                width: parent.width - ScreenTools.defaultFontPixelWidth
                                                anchors.left: parent.left
                                                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                                                anchors.top: parent.top
                                                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.25
                                                spacing: ScreenTools.defaultFontPixelHeight * 0.1
                                                Row {
                                                    spacing: ScreenTools.defaultFontPixelWidth * 0.3
                                                    QGCLabel {
                                                        text: modelData.severity === "CRITICAL" ? "✗" : modelData.severity === "WARNING" ? "⚠" : "✓"
                                                        font.pointSize: ScreenTools.defaultFontPointSize * 0.95
                                                        color: modelData.severity === "CRITICAL" ? qgcPal.colorRed : modelData.severity === "WARNING" ? qgcPal.colorOrange : qgcPal.colorGreen
                                                    }
                                                    QGCLabel {
                                                        text: modelData.problem || modelData.issue || ""
                                                        font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                                                        font.bold: true
                                                    }
                                                }
                                                QGCLabel {
                                                    width: parent.width
                                                    text: modelData.explanation || modelData.description || ""
                                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                                                    color: qgcPal.colorGrey
                                                    wrapMode: Text.WordWrap
                                                    leftPadding: ScreenTools.defaultFontPixelWidth * 1.2
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: rdCol.height + ScreenTools.defaultFontPixelHeight * 0.8
                            radius: ScreenTools.defaultFontPixelWidth * 0.4
                            border.width: 1
                            visible: _hasResults
                            color: {
                                if (!_report) return "transparent"
                                if (_report.status === "READY")                 return Qt.rgba(0, 1, 0.53, 0.04)
                                if (_report.status === "READY_WITH_ADVISORIES") return Qt.rgba(1, 0.72, 0, 0.04)
                                return Qt.rgba(1, 0.13, 0.27, 0.04)
                            }
                            border.color: {
                                if (!_report) return qgcPal.colorGrey
                                if (_report.status === "READY")                 return Qt.rgba(0, 1, 0.53, 0.25)
                                if (_report.status === "READY_WITH_ADVISORIES") return Qt.rgba(1, 0.72, 0, 0.25)
                                return Qt.rgba(1, 0.13, 0.27, 0.25)
                            }
                            Column {
                                id: rdCol
                                width: parent.width - ScreenTools.defaultFontPixelWidth * 1.5
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelHeight * 0.25
                                QGCLabel {
                                    text: _readinessText()
                                    font.pointSize: ScreenTools.defaultFontPointSize * 1.05
                                    font.bold: true
                                    color: {
                                        if (!_report) return qgcPal.text
                                        if (_report.status === "READY")                 return qgcPal.colorGreen
                                        if (_report.status === "READY_WITH_ADVISORIES") return qgcPal.colorYellow
                                        return qgcPal.colorRed
                                    }
                                }
                                QGCLabel {
                                    text: _countsText()
                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                                    color: qgcPal.colorGrey
                                }
                                Grid {
                                    columns: 2
                                    columnSpacing: ScreenTools.defaultFontPixelWidth * 2
                                    rowSpacing: ScreenTools.defaultFontPixelHeight * 0.15
                                    visible: _report !== null
                                    Row { spacing: ScreenTools.defaultFontPixelWidth * 0.3
                                        QGCLabel { text: _report ? _fmtDist(_report.stats.totalDistance) : ""; font.pointSize: ScreenTools.defaultFontPointSize * 0.95; font.bold: true }
                                        QGCLabel { text: qsTr("distance");  font.pointSize: ScreenTools.defaultFontPointSize * 0.75; color: qgcPal.colorGrey }
                                    }
                                    Row { spacing: ScreenTools.defaultFontPixelWidth * 0.3
                                        QGCLabel { text: _report ? _report.stats.maxAltitude.toFixed(0) + "m" : ""; font.pointSize: ScreenTools.defaultFontPointSize * 0.95; font.bold: true }
                                        QGCLabel { text: qsTr("max alt");   font.pointSize: ScreenTools.defaultFontPointSize * 0.75; color: qgcPal.colorGrey }
                                    }
                                    Row { spacing: ScreenTools.defaultFontPixelWidth * 0.3
                                        QGCLabel { text: _report ? _fmtDist(_report.stats.maxRange) : ""; font.pointSize: ScreenTools.defaultFontPointSize * 0.95; font.bold: true }
                                        QGCLabel { text: qsTr("max range"); font.pointSize: ScreenTools.defaultFontPointSize * 0.75; color: qgcPal.colorGrey }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: respContent.height + ScreenTools.defaultFontPixelHeight * 0.8
                            radius: ScreenTools.defaultFontPixelWidth * 0.4
                            visible: _report !== null && _report.requiresAcknowledgment
                            color: Qt.rgba(1, 0.4, 0, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 0.4, 0, 0.3)
                            Column {
                                id: respContent
                                width: parent.width - ScreenTools.defaultFontPixelWidth * 1.5
                                anchors.centerIn: parent
                                spacing: ScreenTools.defaultFontPixelHeight * 0.3
                                QGCLabel {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("PROCEED AT YOUR OWN RISK")
                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.9
                                    font.bold: true
                                    color: qgcPal.colorOrange
                                }
                                QGCLabel {
                                    width: parent.width
                                    text: qsTr("Uploading this mission is the operator's full responsibility.")
                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                                    color: qgcPal.colorGrey
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Rectangle {
                                    width: parent.width
                                    height: ScreenTools.defaultFontPixelHeight * 2
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    radius: ScreenTools.defaultFontPixelWidth * 0.3
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                        Rectangle {
                                            width: ScreenTools.defaultFontPixelHeight * 0.9
                                            height: width
                                            radius: ScreenTools.defaultFontPixelWidth * 0.2
                                            border.width: 1.5
                                            border.color: _accepted ? qgcPal.colorOrange : qgcPal.colorGrey
                                            color: _accepted ? qgcPal.colorOrange : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓"
                                                font.bold: true
                                                font.pointSize: ScreenTools.defaultFontPointSize * 0.75
                                                color: "#0A0C0E"
                                                visible: _accepted
                                            }
                                        }
                                        QGCLabel {
                                            text: qsTr("I accept full responsibility")
                                            font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            _accepted = !_accepted
                                            if (_accepted && _report) {
                                                var reportText = _generateRiskReport()
                                                riskAccepted(reportText)
                                                var d = new Date()
                                                var fname = "RiskReport_" +
                                                    d.getFullYear() +
                                                    (d.getMonth()+1).toString().padStart(2,"0") +
                                                    d.getDate().toString().padStart(2,"0") + "_" +
                                                    d.getHours().toString().padStart(2,"0") +
                                                    d.getMinutes().toString().padStart(2,"0") +
                                                    d.getSeconds().toString().padStart(2,"0") + ".txt"
                                                var savePath = QGroundControl.settingsManager.appSettings.missionSavePath.toString() + "/" + fname
                                                if (fileWriter.save(savePath, reportText)) {
                                                    console.log("Risk report saved: " + savePath + " (" + reportText.length + " chars)")
                                                } else {
                                                    console.warn("FAILED to save risk report: " + savePath)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: blockedLabel.height + ScreenTools.defaultFontPixelHeight * 0.6
                            radius: ScreenTools.defaultFontPixelWidth * 0.3
                            visible: _report !== null && _report.requiresAcknowledgment && !_accepted
                            color: Qt.rgba(1, 0, 0, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(1, 0, 0, 0.2)
                            QGCLabel {
                                id: blockedLabel
                                width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                                anchors.centerIn: parent
                                text: qsTr("Upload & Save BLOCKED - accept responsibility first")
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                                font.bold: true
                                color: qgcPal.colorRed
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: allowedLabel.height + ScreenTools.defaultFontPixelHeight * 0.6
                            radius: ScreenTools.defaultFontPixelWidth * 0.3
                            visible: _report !== null && _report.requiresAcknowledgment && _accepted
                            color: Qt.rgba(0, 1, 0.53, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(0, 1, 0.53, 0.2)
                            QGCLabel {
                                id: allowedLabel
                                width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                                anchors.centerIn: parent
                                text: qsTr("Upload & Save UNLOCKED - risk report saved")
                                font.pointSize: ScreenTools.defaultFontPointSize * 0.82
                                font.bold: true
                                color: qgcPal.colorGreen
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
    function _smartBadge(findings) {
        var c = 0, w = 0
        for (var i = 0; i < findings.length; i++) {
            if (findings[i].severity === "CRITICAL") c++
            else if (findings[i].severity === "WARNING") w++
        }
        var parts = []
        if (c > 0) parts.push(c + " ✗")
        if (w > 0) parts.push(w + " ⚠")
        if (parts.length > 0) return parts.join("  ")
        return qsTr("✓ Pass")
    }
    function _smartBadgeColor(findings) {
        for (var i = 0; i < findings.length; i++) {
            if (findings[i].severity === "CRITICAL") return qgcPal.colorRed
        }
        for (var j = 0; j < findings.length; j++) {
            if (findings[j].severity === "WARNING") return qgcPal.colorOrange
        }
        return qgcPal.colorGreen
    }
    function _buildGroupModel() {
        if (!_report) return []
        var angleFindings = _filterFindings("GEOMETRY")
        var wp3Findings = _filterFindings("CONSISTENCY")
        return [
            { title: qsTr("Climb / Descent Angle"), badge: _smartBadge(angleFindings), badgeColor: _smartBadgeColor(angleFindings), findings: angleFindings },
            { title: qsTr("WP3 Distance from Home"), badge: _smartBadge(wp3Findings), badgeColor: _smartBadgeColor(wp3Findings), findings: wp3Findings }
        ]
    }
}