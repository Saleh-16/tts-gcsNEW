import QtQuick
import QtGraphs

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:         root
    radius:     ScreenTools.defaultFontPixelWidth * 0.5
    color:      qgcPal.window
    opacity:    0.80
    clip:       true

    property var missionController

    signal setCurrentSeqNum(int seqNum)

    /// Exposes the internal chart so external tools (like ElevationGraphWindow)
    /// can read/drive its axes for features like zoom, without duplicating
    /// the chart itself. Also lets them read the computed full-range
    /// axisX.max, needed to know the "reset zoom" bounds.
    property alias chart: chart

    /// Exposes the internal TerrainProfile so external tools can query
    /// altitude data (e.g. for computing a vertical auto-fit range when
    /// zooming into a horizontal distance span).
    property alias terrainProfile: terrainProfile

    /// Optional external override for the X axis visible range, used by
    /// standalone viewers (like ElevationGraphWindow) to implement zoom
    /// without duplicating this chart. When either is NaN (the default),
    /// the axis falls back to its normal full-mission-distance behavior.
    property real externalMinX: NaN
    property real externalMaxX: NaN

    /// Optional external override for the Y axis (altitude) visible range.
    /// Used together with externalMinX/externalMaxX to implement
    /// Mission-Planner-style drag-to-zoom, where the vertical scale
    /// auto-fits to whatever altitude range falls within the selected
    /// horizontal span. NaN falls back to the normal full-range behavior.
    property real externalMinY: NaN
    property real externalMaxY: NaN

    property real _margins:                 ScreenTools.defaultFontPixelWidth / 2
    property var  _visualItems:             missionController.visualItems
    property real _altRange:                _maxAMSLAltitude - _minAMSLAltitude
    property real _indicatorSpacing:        5
    property real _minAMSLAltitude:         isNaN(terrainProfile.minAMSLAlt) ? 0 : terrainProfile.minAMSLAlt
    property real _maxAMSLAltitude:         isNaN(terrainProfile.maxAMSLAlt) ? 100 : terrainProfile.maxAMSLAlt
    property real _missionTotalDistance:    isNaN(missionController.missionTotalDistance) ? 100 : missionController.missionTotalDistance
    property var  _unitsConversion:         QGroundControl.unitsConversion

    /// Approximate number of X axis tick labels aimed for at any zoom level.
    /// A single knob controlling overall label density on the distance axis.
    property int  _targetTickCount:         8

    /// Same idea for the Y (altitude) axis. Kept lower than the X target
    /// because the chart is much shorter than it is wide, so fewer labels
    /// fit vertically before they start crowding each other.
    property int  _targetTickCountY:        5

    /// Smallest "nice" step (1 / 2 / 5 x 10^n) that yields roughly targetCount
    /// labels across the given visible span. Used by both axes so that tick
    /// density adapts to zoom: as the visible range shrinks, the step shrinks
    /// with it and more (finer) labels appear, instead of always showing the
    /// same fixed number of ticks stretched across whatever range happens to
    /// be visible. Restricting the step to 1/2/5 multiples keeps the printed
    /// values readable (200, 205, 210...) rather than arbitrary fractions of
    /// the range.
    function _niceTickStep(span, targetCount) {
        if (!(span > 0) || !(targetCount > 0)) {
            return 1
        }
        var rough = span / targetCount
        var mag   = Math.pow(10, Math.floor(Math.log(rough) / Math.LN10))
        var norm  = rough / mag                     // 1 <= norm < 10
        var nice  = norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10
        return nice * mag
    }

    /// When true, and an external X range is active (i.e. the viewer is
    /// zoomed in), the Y axis shrinks to fit only the altitudes that actually
    /// fall inside that horizontal span, instead of always spanning the whole
    /// mission's altitude range. Combined with the adaptive tick step this is
    /// what makes vertical labels get denser as you zoom: the visible altitude
    /// span shrinks, so the "nice" step shrinks with it.
    /// Off by default so the embedded PlanView chart keeps its original
    /// full-range behavior.
    property bool autoFitY: false

    /// Fraction of the fitted altitude span added above and below, so the
    /// lines don't sit flush against the top and bottom edges of the plot.
    property real _autoFitYPadding: 0.10

    /// Computed auto-fit bounds. NaN whenever auto-fit is off, no external X
    /// range is set, or no data falls inside the range - in which case the
    /// axis falls back to its normal full-range behavior.
    property real _autoMinY: NaN
    property real _autoMaxY: NaN

    onAutoFitYChanged:      _updateAutoFitY()
    onExternalMinXChanged:  _updateAutoFitY()
    onExternalMaxXChanged:  _updateAutoFitY()

    /// Returns the series' points as a plain array, tolerating either the
    /// list-style 'points' property or the indexed at()/count API.
    function _seriesPoints(series) {
        if (!series) {
            return []
        }
        if (series.points !== undefined && series.points !== null) {
            return series.points
        }
        var pts = []
        for (var i = 0; i < series.count; i++) {
            pts.push(series.at(i))
        }
        return pts
    }

    /// Expands acc.min / acc.max to cover every part of 'series' that lies
    /// within the currently visible X range. Works segment by segment and
    /// linearly interpolates where a segment crosses a range boundary, so a
    /// single long segment spanning the whole view is still measured correctly
    /// even when it has no sample point inside the range - which is exactly
    /// the case at high zoom levels.
    function _scanSeriesY(series, lo, hi, acc) {
        var pts = _seriesPoints(series)
        if (pts.length === 0) {
            return
        }

        function include(y) {
            if (y < acc.min) acc.min = y
            if (y > acc.max) acc.max = y
        }

        if (pts.length === 1) {
            if (pts[0].x >= lo && pts[0].x <= hi) {
                include(pts[0].y)
            }
            return
        }

        for (var i = 0; i < pts.length - 1; i++) {
            var p0 = pts[i]
            var p1 = pts[i + 1]
            var x0 = Math.min(p0.x, p1.x)
            var x1 = Math.max(p0.x, p1.x)

            var segLo = Math.max(x0, lo)
            var segHi = Math.min(x1, hi)
            if (segLo > segHi) {
                continue    // segment entirely outside the visible range
            }

            if (p1.x === p0.x) {
                include(p0.y)
                include(p1.y)
                continue
            }

            var slope = (p1.y - p0.y) / (p1.x - p0.x)
            include(p0.y + (segLo - p0.x) * slope)
            include(p0.y + (segHi - p0.x) * slope)
        }
    }

    function _updateAutoFitY() {
        if (!autoFitY || isNaN(externalMinX) || isNaN(externalMaxX) || externalMaxX <= externalMinX) {
            _autoMinY = NaN
            _autoMaxY = NaN
            return
        }

        var acc = { min: Number.POSITIVE_INFINITY, max: Number.NEGATIVE_INFINITY }
        _scanSeriesY(terrainSeries,   externalMinX, externalMaxX, acc)
        _scanSeriesY(flightSeries,    externalMinX, externalMaxX, acc)
        _scanSeriesY(collisionSeries, externalMinX, externalMaxX, acc)
        _scanSeriesY(missingSeries,   externalMinX, externalMaxX, acc)

        if (!isFinite(acc.min) || !isFinite(acc.max)) {
            _autoMinY = NaN
            _autoMaxY = NaN
            return
        }

        var span = acc.max - acc.min
        // Flat sections would collapse to a zero-height axis, so give them a
        // small artificial span centered on the value.
        var pad = span > 0 ? span * _autoFitYPadding : Math.max(1, Math.abs(acc.max) * 0.01)
        _autoMinY = acc.min - pad
        _autoMaxY = acc.max + pad
    }

    /// Maps a mission distance (raw metres, as reported by
    /// VisualMissionItem.distanceFromStart) to an x pixel position inside the
    /// plot area, using the chart's own X axis range.
    ///
    /// The markers used to be positioned with terrainProfile.pixelsPerMeter,
    /// but that is computed in C++ as visibleWidth / missionTotalDistance
    /// (TerrainProfile.cc), i.e. against the WHOLE mission - it knows nothing
    /// about axisX. So while the series honoured a zoomed axis range, the
    /// markers stayed frozen at their full-mission positions and no longer
    /// lined up with the plotted lines.
    ///
    /// The horizontalScale multiply matches what TerrainProfile.cc does when
    /// it builds the series points, so marker x and series x live in the same
    /// unit space even when the user displays distances in feet.
    function _xForDistance(distanceMeters) {
        if (!chart || !chart.axisX) {
            return 0
        }
        var lo = chart.axisX.min
        var hi = chart.axisX.max
        if (!(hi > lo)) {
            return 0
        }
        var scaled = distanceMeters * terrainProfile.horizontalScale
        return chart.plotArea.width * ((scaled - lo) / (hi - lo))
    }

    /// True when the given mission distance falls inside the visible X range,
    /// so markers outside a zoomed view are hidden instead of being clamped
    /// against the edges where they would misrepresent their real position.
    function _distanceInView(distanceMeters) {
        if (!chart || !chart.axisX) {
            return false
        }
        var scaled = distanceMeters * terrainProfile.horizontalScale
        return scaled >= chart.axisX.min && scaled <= chart.axisX.max
    }

    QGCPalette { id: qgcPal }

    QGCLabel {
        id:                     titleLabel
        anchors.top:            parent.bottom
        width:                  parent.height
        font.pointSize:         ScreenTools.smallFontPointSize
        text:                   qsTr("Height AMSL (%1)").arg(_unitsConversion.appSettingsVerticalDistanceUnitsString)
        horizontalAlignment:    Text.AlignHCenter
        rotation:               -90
        transformOrigin:        Item.TopLeft
    }

    QGCFlickable {
        id:                 terrainProfileFlickable
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.leftMargin: titleLabel.contentHeight
        anchors.left:       parent.left
        anchors.right:      parent.right
        clip:               true

        Item {
            height: terrainProfileFlickable.height
            width:  terrainProfileFlickable.width

            GraphsView {
                id:                 chart
                anchors.fill:       parent
                marginTop:          ScreenTools.defaultFontPixelHeight / 2  // Fixes top clipping problem
                marginRight:        ScreenTools.defaultFontPixelWidth * 2   // Prevents clipping last tick mark
                marginBottom:       -ScreenTools.defaultFontPixelHeight / 2 // For some reason you can't get rid of bottom margin by setting to 0
                marginLeft:         0

                theme: GraphsTheme {
                    colorScheme:                qgcPal.globalTheme === QGCPalette.Light ? GraphsTheme.ColorScheme.Light : GraphsTheme.ColorScheme.Dark
                    backgroundColor:            "transparent"
                    backgroundVisible:          false
                    plotAreaBackgroundColor:     qgcPal.window
                    grid.mainColor:             applyOpacity(qgcPal.text, 0.5)
                    grid.subColor:              applyOpacity(qgcPal.text, 0.3)
                    grid.mainWidth:             1
                    labelBackgroundVisible:     false
                    labelTextColor:             qgcPal.text
                    axisXLabelFont.family:      ScreenTools.fixedFontFamily
                    axisXLabelFont.pointSize:   ScreenTools.smallFontPointSize
                    axisYLabelFont.family:      ScreenTools.fixedFontFamily
                    axisYLabelFont.pointSize:   ScreenTools.smallFontPointSize
                }

                axisX: ValueAxis {
                    id:                         axisX
                    min:                        isNaN(root.externalMinX) ? 0 : root.externalMinX
                    max:                        isNaN(root.externalMaxX)
                                                    ? _unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_missionTotalDistance)
                                                    : root.externalMaxX
                    lineVisible:                true

                    // Adaptive tick density: the step is derived from the currently
                    // visible span rather than being a fixed fraction of it, so zooming
                    // in produces more, finer labels instead of the same 5 labels
                    // relabelled. tickAnchor snaps the first tick to a multiple of the
                    // step so values stay round even when min is not zero (i.e. zoomed).
                    tickInterval:               root._niceTickStep(max - min, root._targetTickCount)
                    tickAnchor:                 Math.ceil(min / axisX.tickInterval) * axisX.tickInterval
                    labelDecimals:              axisX.tickInterval >= 10 ? 0 : (axisX.tickInterval >= 1 ? 1 : 2)
                }

                axisY: ValueAxis {
                    id:                         axisY
                    // Priority: explicit external override, then the computed
                    // auto-fit range (when zoomed), then the full mission range.
                    min:                        !isNaN(root.externalMinY)
                                                    ? root.externalMinY
                                                    : !isNaN(root._autoMinY)
                                                        ? root._autoMinY
                                                        : _unitsConversion.metersToAppSettingsVerticalDistanceUnits(_minAMSLAltitude)
                    max:                        !isNaN(root.externalMaxY)
                                                    ? root.externalMaxY
                                                    : !isNaN(root._autoMaxY)
                                                        ? root._autoMaxY
                                                        : _unitsConversion.metersToAppSettingsVerticalDistanceUnits(_maxAMSLAltitude)
                    lineVisible:                true

                    // Same adaptive scheme as the X axis: round altitude steps
                    // that get finer as the visible altitude range shrinks,
                    // with the first tick snapped to a multiple of the step so
                    // labels stay round when min is not zero.
                    tickInterval:               root._niceTickStep(max - min, root._targetTickCountY)
                    tickAnchor:                 Math.ceil(min / axisY.tickInterval) * axisY.tickInterval
                    labelDecimals:              axisY.tickInterval >= 10 ? 0 : (axisY.tickInterval >= 1 ? 1 : 2)
                }

                // The order of the LineSeries is important to work around nasty bugs in QtGraphs where series just don't display. If you put
                // terrain and flight first you end up with cases where flight doesn't display no matter what other sorts of workarounds you try.
                // Putting missing and collision first seems to prevent the problem.
                LineSeries {
                    id:         missingSeries
                    color:      "yellow"
                    width:      2
                }

                LineSeries {
                    id:         collisionSeries
                    color:      "red"
                    width:      flightSeries.width * 3
                }

                LineSeries {
                    id:         terrainSeries
                    color:      "green"
                    width:      2
                }

                LineSeries {
                    id:         flightSeries
                    color:      "orange"
                    width:      2
                }
            }

            TerrainProfile {
                id:                 terrainProfile
                x:                  chart.plotArea.x
                y:                  chart.plotArea.y
                height:             chart.plotArea.height
                visibleWidth:       chart.plotArea.width
                missionController:  root.missionController
                horizontalScale:    _unitsConversion.metersToAppSettingsHorizontalDistanceUnits(1)
                verticalScale:      _unitsConversion.metersToAppSettingsVerticalDistanceUnits(1)
                onProfileChanged:   {
                    terrainProfile.updateSeries(terrainSeries, flightSeries, missingSeries, collisionSeries)
                    // Series points just changed, so any active vertical
                    // auto-fit has to be recomputed against the new data.
                    root._updateAutoFitY()
                }

                Repeater {
                    model: missionController.visualItems

                    Item {
                        id:             topLevelItem
                        anchors.fill:   parent
                        visible:        object.specifiesCoordinate && !object.standaloneCoordinate

                        Rectangle {
                            id:         simpleItem
                            height:     terrainProfile.height
                            width:      1
                            color:      qgcPal.text
                            x:          root._xForDistance(object.distanceFromStart)
                            visible:    (object.isSimpleItem || object.isSingleItem) &&
                                        root._distanceInView(object.distanceFromStart)

                            MissionItemIndexLabel {
                                anchors.horizontalCenter:   parent.horizontalCenter
                                anchors.bottom:             parent.bottom
                                small:                      true
                                checked:                    object.isCurrentItem
                                label:                      object.abbreviation.charAt(0)
                                index:                      object.abbreviation.charAt(0) > 'A' && object.abbreviation.charAt(0) < 'z' ? -1 : object.sequenceNumber
                                onClicked:                  root.setCurrentSeqNum(object.sequenceNumber)
                            }
                        }

                        Rectangle {
                            id:         complexItemEntry
                            height:     terrainProfile.height
                            width:      1
                            color:      qgcPal.text
                            x:          root._xForDistance(object.distanceFromStart)
                            visible:    complexItem.visible &&
                                        root._distanceInView(object.distanceFromStart)

                            MissionItemIndexLabel {
                                anchors.horizontalCenter:   parent.horizontalCenter
                                anchors.bottom:             parent.bottom
                                small:                      true
                                checked:                    object.isCurrentItem
                                index:                      object.sequenceNumber
                                onClicked:                  root.setCurrentSeqNum(object.sequenceNumber)
                            }
                        }

                        Rectangle {
                            id:         complexItemExit
                            height:     terrainProfile.height
                            width:      1
                            color:      qgcPal.text
                            x:          root._xForDistance(object.distanceFromStart + object.complexDistance)
                            visible:    complexItem.visible &&
                                        root._distanceInView(object.distanceFromStart + object.complexDistance)

                            MissionItemIndexLabel {
                                anchors.horizontalCenter:   parent.horizontalCenter
                                anchors.bottom:             parent.bottom
                                small:                      true
                                checked:                    object.isCurrentItem
                                index:                      object.lastSequenceNumber
                                onClicked:                  root.setCurrentSeqNum(object.sequenceNumber)
                            }
                        }

                        Rectangle {
                            id:             complexItem
                            anchors.bottom: parent.bottom
                            x:              root._xForDistance(object.distanceFromStart)
                            width:          complexItem.visible
                                                ? Math.max(0, root._xForDistance(object.distanceFromStart + object.complexDistance)
                                                              - root._xForDistance(object.distanceFromStart))
                                                : 0
                            height:         patternNameLabel.height
                            color:          "green"
                            opacity:        0.5
                            visible:        !object.isSimpleItem && !object.isSingleItem

                            QGCMouseArea {
                                anchors.fill:   parent
                                onClicked:      root.setCurrentSeqNum(object.sequenceNumber)
                            }

                            QGCLabel {
                                id:                         patternNameLabel
                                anchors.horizontalCenter:   parent.horizontalCenter
                                text:                       complexItem.visible ? object.patternName : ""
                            }
                        }
                    }
                }
            }
        }
    }

    function applyOpacity(colorIn, opacity){
        return Qt.rgba(colorIn.r, colorIn.g, colorIn.b, opacity)
    }
}