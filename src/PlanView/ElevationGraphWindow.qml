// src/PlanView/ElevationGraphWindow.qml
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

/// Standalone, resizable window showing the mission elevation profile.
/// Reuses TerrainStatus.qml (the same chart embedded in PlanView) so the
/// graph is always in sync with the active mission — no duplicated logic.
/// Intended to be dragged onto a second monitor.
///
/// Mission-Planner-style drag-to-zoom: left mouse button drag draws a
/// horizontal selection band across the chart. On release, the view zooms
/// to that distance range. The vertical (altitude) axis keeps the full
/// mission's altitude range — TerrainProfile doesn't expose a way to query
/// altitude for an arbitrary sub-range, so true vertical auto-fit isn't
/// currently possible without a C++ change; horizontal zoom still works
/// fully on its own. Reset Zoom restores the full mission view.
Window {
    id: elevationWindow

    property var missionController: null

    title:  qsTr("Elevation Graph")
    width:  ScreenTools.defaultFontPixelWidth * 100
    height: ScreenTools.defaultFontPixelHeight * 25
    minimumWidth:  ScreenTools.defaultFontPixelWidth * 40
    minimumHeight: ScreenTools.defaultFontPixelHeight * 12
    color:  "#0A0C0E"

    flags: Qt.Window

    property real _fullMinX: 0
    property real _fullMaxX: 100
    property real _fullMinY: 0
    property real _fullMaxY: 100
    property bool _boundsCaptured: false

    property real _viewMinX: 0
    property real _viewMaxX: 100
    property real _viewMinY: 0
    property real _viewMaxY: 100

    readonly property real _minDragPixels: 10

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing:         ScreenTools.defaultFontPixelHeight * 0.5

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Drag to select a distance range to zoom")
                opacity: 0.7
                font.pointSize: ScreenTools.smallFontPointSize
            }

            QGCButton {
                text: qsTr("Reset Zoom")
                onClicked: elevationWindow._resetZoom()
            }
        }

        Item {
            id: chartHost
            Layout.fillWidth:  true
            Layout.fillHeight: true

            TerrainStatus {
                id:                 terrainStatus
                anchors.fill:       parent
                missionController:  elevationWindow.missionController

                externalMinX: elevationWindow._boundsCaptured ? elevationWindow._viewMinX : NaN
                externalMaxX: elevationWindow._boundsCaptured ? elevationWindow._viewMaxX : NaN
                externalMinY: elevationWindow._boundsCaptured ? elevationWindow._viewMinY : NaN
                externalMaxY: elevationWindow._boundsCaptured ? elevationWindow._viewMaxY : NaN

                onSetCurrentSeqNum: {
                    if (elevationWindow.missionController)
                        elevationWindow.missionController.setCurrentPlanViewSeqNum(seqNum, true)
                }
            }

            MouseArea {
                id: dragZoomArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                property bool dragging: false
                property real startX: 0
                property real currentX: 0

                onPressed: (mouse) => {
                    dragging = true
                    startX = mouse.x
                    currentX = mouse.x
                }

                onPositionChanged: (mouse) => {
                    if (dragging) currentX = mouse.x
                }

                onReleased: (mouse) => {
                    if (!dragging) return
                    dragging = false

                    var pixelWidth = Math.abs(currentX - startX)
                    if (pixelWidth < elevationWindow._minDragPixels) {
                        return
                    }

                    var loX = Math.min(startX, currentX)
                    var hiX = Math.max(startX, currentX)

                    var spanX = elevationWindow._viewMaxX - elevationWindow._viewMinX
                    var fractionLo = loX / chartHost.width
                    var fractionHi = hiX / chartHost.width

                    var newMinX = elevationWindow._viewMinX + fractionLo * spanX
                    var newMaxX = elevationWindow._viewMinX + fractionHi * spanX

                    elevationWindow._zoomToRange(newMinX, newMaxX)
                }

                Rectangle {
                    visible: dragZoomArea.dragging &&
                             Math.abs(dragZoomArea.currentX - dragZoomArea.startX) >= elevationWindow._minDragPixels
                    x:      Math.min(dragZoomArea.startX, dragZoomArea.currentX)
                    y:      0
                    width:  Math.abs(dragZoomArea.currentX - dragZoomArea.startX)
                    height: parent.height
                    color:  "#4000FF88"
                    border.color: "#00FF88"
                    border.width: 1
                }
            }

            Timer {
                interval: 300
                running:  !elevationWindow._boundsCaptured
                repeat:   true
                triggeredOnStart: true
                onTriggered: elevationWindow._captureFullBounds()
            }
        }
    }

    function _captureFullBounds() {
        if (!terrainStatus.chart) return

        var axisMaxX = terrainStatus.chart.axisX.max
        var axisMinY = terrainStatus.chart.axisY.min
        var axisMaxY = terrainStatus.chart.axisY.max

        var newFullMinY = isNaN(axisMinY) ? 0 : axisMinY
        var newFullMaxY = isNaN(axisMaxY) || axisMaxY <= newFullMinY ? newFullMinY + 100 : axisMaxY

        var looksLikePlaceholder = (newFullMinY === 0 && newFullMaxY === 100) || (axisMaxX <= 0)
        if (looksLikePlaceholder) return

        _fullMinX = 0
        _fullMaxX = axisMaxX
        _fullMinY = newFullMinY
        _fullMaxY = newFullMaxY

        _viewMinX = _fullMinX
        _viewMaxX = _fullMaxX
        _viewMinY = _fullMinY
        _viewMaxY = _fullMaxY

        _boundsCaptured = true
    }

    function _zoomToRange(newMinX, newMaxX) {
        if (newMaxX - newMinX < 1) return

        _viewMinX = newMinX
        _viewMaxX = newMaxX
        _viewMinY = _fullMinY
        _viewMaxY = _fullMaxY
    }

    function _resetZoom() {
        _viewMinX = _fullMinX
        _viewMaxX = _fullMaxX
        _viewMinY = _fullMinY
        _viewMaxY = _fullMaxY
    }

    onVisibleChanged: {
        if (visible && !_boundsCaptured) _captureFullBounds()
    }
}