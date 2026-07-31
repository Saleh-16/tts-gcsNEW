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
/// to that distance range.
///
/// The vertical (altitude) axis auto-fits to whatever altitudes fall inside
/// the selected horizontal span. That fit is computed inside TerrainStatus
/// (autoFitY) from the plotted series data itself, so this window only has to
/// drive the X range and leave the Y range unset. Reset Zoom restores the
/// full mission view.
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

    /* Y range is no longer driven from here — TerrainStatus.autoFitY computes
       it from the visible slice of the series data. Kept commented rather than
       deleted in case an explicit vertical range is ever needed again.
    property real _viewMinY: 0
    property real _viewMaxY: 100
    */

    /// Minimum drag length, in pixels, that counts as a zoom rather than a
    /// stray click.
    readonly property real _minDragPixels: 10

    /// Smallest distance span the view may be zoomed to. Expressed as a
    /// fraction of the full mission length rather than a fixed number, because
    /// a floor that is sensible on a 400 m mission is meaningless on a 40 km
    /// one: zooming to a couple of metres there lands between terrain samples
    /// and shows two flat lines with no detail at all.
    readonly property real _minZoomSpan: Math.max(1, (_fullMaxX - _fullMinX) * 0.002)

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

                // Let TerrainStatus derive the altitude range from the data
                // inside the visible distance span. Leaving the explicit
                // overrides at NaN is what enables that path.
                autoFitY:     true
                externalMinY: NaN
                externalMaxY: NaN

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

                /// The chart's actual plot area, expressed in this MouseArea's
                /// coordinates. Needed because the plot does not start at x=0:
                /// the Y axis labels and the rotated "Height AMSL" title take up
                /// space on the left, and GraphsView adds a right margin. Mapping
                /// drag pixels against the full item width instead would shift
                /// every zoom to the right by that margin.
                readonly property rect plotRect: {
                    if (!terrainStatus.chart) {
                        return Qt.rect(0, 0, 0, 0)
                    }
                    var pa = terrainStatus.chart.plotArea
                    var tl = dragZoomArea.mapFromItem(terrainStatus.chart, pa.x, pa.y)
                    return Qt.rect(tl.x, tl.y, pa.width, pa.height)
                }

                /// Drag bounds clamped to the plot area, so a drag that starts or
                /// ends over the axis labels still selects a valid range.
                readonly property real clampedLo: Math.max(plotRect.x,
                                                    Math.min(startX, currentX))
                readonly property real clampedHi: Math.min(plotRect.x + plotRect.width,
                                                    Math.max(startX, currentX))

                onPressed: (mouse) => {
                    dragging = true
                    startX   = mouse.x
                    currentX = mouse.x
                }

                onPositionChanged: (mouse) => {
                    if (dragging) currentX = mouse.x
                }

                onReleased: (mouse) => {
                    if (!dragging) return
                    dragging = false

                    if (plotRect.width <= 0) return
                    if (clampedHi - clampedLo < elevationWindow._minDragPixels) return

                    var spanX      = elevationWindow._viewMaxX - elevationWindow._viewMinX
                    var fractionLo = (clampedLo - plotRect.x) / plotRect.width
                    var fractionHi = (clampedHi - plotRect.x) / plotRect.width

                    elevationWindow._zoomToRange(
                        elevationWindow._viewMinX + fractionLo * spanX,
                        elevationWindow._viewMinX + fractionHi * spanX)
                }

                Rectangle {
                    visible: dragZoomArea.dragging &&
                             (dragZoomArea.clampedHi - dragZoomArea.clampedLo) >= elevationWindow._minDragPixels
                    x:      dragZoomArea.clampedLo
                    y:      dragZoomArea.plotRect.y
                    width:  Math.max(0, dragZoomArea.clampedHi - dragZoomArea.clampedLo)
                    height: dragZoomArea.plotRect.height
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

        // TerrainStatus falls back to a 0..100 placeholder altitude range until
        // real terrain data arrives; capturing then would lock in bogus bounds.
        var looksLikePlaceholder = (newFullMinY === 0 && newFullMaxY === 100) || (axisMaxX <= 0)
        if (looksLikePlaceholder) return

        _fullMinX = 0
        _fullMaxX = axisMaxX
        _fullMinY = newFullMinY
        _fullMaxY = newFullMaxY

        _viewMinX = _fullMinX
        _viewMaxX = _fullMaxX

        _boundsCaptured = true
    }

    function _zoomToRange(newMinX, newMaxX) {
        if (newMaxX - newMinX < _minZoomSpan) return
        _viewMinX = newMinX
        _viewMaxX = newMaxX
    }

    function _resetZoom() {
        _viewMinX = _fullMinX
        _viewMaxX = _fullMaxX
    }

    onVisibleChanged: {
        if (visible && !_boundsCaptured) _captureFullBounds()
    }
}