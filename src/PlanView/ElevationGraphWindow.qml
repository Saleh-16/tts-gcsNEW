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
    /// Window chrome and chart background. Lighter than the original near-black
    /// (#0A0C0E), which made the thin plot lines read as harsh bright strokes
    /// on a void. The chart sits one step lighter than the surround so its
    /// panel edge still reads.
    readonly property color _windowBackground: "#141A1F"
    readonly property color _plotBackground:   "#1B2329"

    /// Marker line colours. Dimmed well below the text colour so a long
    /// mission's dozen vertical lines read as a faint scale behind the data
    /// rather than a picket fence in front of it.
    readonly property color _markerLine:      "#5A6B78"
    readonly property color _markerHighlight:  "#C8505F"

    color:  _windowBackground

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

    /// How much one wheel notch changes the visible span. 1.25 means each
    /// notch shows 80% of what it did before (or 125% when scrolling out).
    readonly property real _wheelZoomStep: 1.25

    /// How far past the mission's own length the view may be zoomed out. At 5
    /// the whole profile occupies a fifth of the width, with empty margin all
    /// round - far enough to see it in context (and to bring sea level and
    /// below onto the altitude axis) without letting it shrink to a dot that
    /// only Reset Zoom can recover from.
    readonly property real _maxZoomOutFactor: 5

    /// Drives TerrainStatus.autoFitYExpansion: 1 while the view is inside the
    /// mission, then growing in step with the horizontal span once it is zoomed
    /// out past it, so both axes open up together.
    readonly property real _zoomOutExpansion: {
        var fullSpan = _fullMaxX - _fullMinX
        var viewSpan = _viewMaxX - _viewMinX
        return (fullSpan > 0 && viewSpan > fullSpan) ? viewSpan / fullSpan : 1
    }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing:         ScreenTools.defaultFontPixelHeight * 0.5

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel {
                text: qsTr("Scroll to zoom, or drag to select a distance range")
                opacity: 0.7
                font.pointSize: ScreenTools.smallFontPointSize
            }

            Item { Layout.fillWidth: true }

            // Legend. Colours are the LineSeries colours declared in
            // TerrainStatus.qml - keep the two in step if a series colour ever
            // changes there. "No terrain data" is the one worth calling out:
            // that line is not an altitude reading at all, it marks a stretch
            // where QGC has no terrain tiles, so the altitudes shown around it
            // can't be trusted.
            Repeater {
                model: [
                    { swatch: "orange", label: qsTr("Flight path") },
                    { swatch: "green",  label: qsTr("Terrain") },
                    { swatch: "red",    label: qsTr("Terrain collision") },
                    { swatch: "yellow", label: qsTr("No terrain data") }
                ]

                RowLayout {
                    Layout.rightMargin: ScreenTools.defaultFontPixelWidth
                    spacing:            ScreenTools.defaultFontPixelWidth * 0.4

                    Rectangle {
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 1.6
                        Layout.preferredHeight: Math.max(2, ScreenTools.defaultFontPixelHeight * 0.16)
                        Layout.alignment:       Qt.AlignVCenter
                        color:                  modelData.swatch
                    }

                    QGCLabel {
                        text:           modelData.label
                        opacity:        0.7
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
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

                // Opens the altitude scale up in step with the horizontal one
                // once the view is zoomed out past the mission itself.
                autoFitYExpansion: elevationWindow._zoomOutExpansion

                // Draw the WP3 marker as a red dashed line so it stands out
                // against the plain white marker lines of the other waypoints.
                // Change this number to highlight a different waypoint, or set
                // it to -1 to turn the highlight off.
                // WP3 is drawn as a solid coloured line; every other waypoint
                // marker is dashed and muted, so the dozen ordinary markers on
                // a long mission read as a faint scale behind the data instead
                // of a picket fence in front of it. Set highlightSeqNum to -1
                // to turn the highlight off.
                highlightSeqNum:      3
                highlightMarkerColor: elevationWindow._markerHighlight
                markerLineColor:      elevationWindow._markerLine
                dashOrdinaryMarkers:  true

                // A step up from the near-black window colour. Lines read more
                // softly against it, and the panel edge stays distinguishable
                // from the surrounding window.
                plotBackgroundColor: elevationWindow._plotBackground

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

                /// Wheel zoom, anchored on the cursor: the distance under the
                /// pointer stays put while the range grows or shrinks around
                /// it, so you can point at a feature and scroll into it rather
                /// than zooming to the middle and then hunting for it again.
                onWheel: (wheel) => {
                    if (plotRect.width <= 0) return

                    var delta = wheel.angleDelta.y
                    if (delta === 0) return

                    // One notch is 120 units; trackpads send smaller steps, so
                    // scale the factor by the actual delta instead of treating
                    // every event as a full notch.
                    var notches = delta / 120
                    var factor  = Math.pow(1 / elevationWindow._wheelZoomStep, notches)

                    var fraction = (wheel.x - plotRect.x) / plotRect.width
                    fraction = Math.max(0, Math.min(1, fraction))

                    elevationWindow._zoomAtFraction(fraction, factor)
                    wheel.accepted = true
                }

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

    /// Scales the visible span by 'factor' while keeping the distance that sits
    /// at 'fraction' across the plot (0 = left edge, 1 = right edge) pinned in
    /// place.
    ///
    /// Zooming in is clamped to _minZoomSpan. Zooming out is allowed to run
    /// past the mission's own extent, up to _maxZoomOutFactor times its length;
    /// beyond the mission the range is left exactly where the anchor puts it,
    /// so the X axis is free to show 0 and negative distances as empty margin
    /// around the profile. Inside the mission the old behaviour still applies:
    /// the range is pushed back within bounds rather than drifting off the end.
    function _zoomAtFraction(fraction, factor) {
        var span = _viewMaxX - _viewMinX
        if (!(span > 0)) return

        var fullSpan = _fullMaxX - _fullMinX
        var maxSpan  = fullSpan > 0 ? fullSpan * _maxZoomOutFactor : span
        var newSpan  = Math.max(_minZoomSpan, Math.min(maxSpan, span * factor))
        if (newSpan === span) return

        var anchorValue = _viewMinX + fraction * span
        var newMin      = anchorValue - fraction * newSpan

        if (newSpan <= fullSpan) {
            if (newMin < _fullMinX) {
                newMin = _fullMinX
            } else if (newMin + newSpan > _fullMaxX) {
                newMin = _fullMaxX - newSpan
            }
        }

        _viewMinX = newMin
        _viewMaxX = newMin + newSpan
    }

    function _resetZoom() {
        _viewMinX = _fullMinX
        _viewMaxX = _fullMaxX
    }

    onVisibleChanged: {
        if (visible && !_boundsCaptured) _captureFullBounds()
    }
}