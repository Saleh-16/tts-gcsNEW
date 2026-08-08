import QtQuick
import QtGraphs

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:         root
    radius:     ScreenTools.defaultFontPixelWidth * 0.5
    color:      root.plotBackgroundColor
    opacity:    0.80
    clip:       true

    /// Background behind the chart. Defaults to the standard QGC window colour
    /// so the embedded PlanView chart is unchanged; the standalone viewer
    /// overrides it with a lighter tone, which is easier on the eyes over a
    /// long session than near-black.
    property color plotBackgroundColor: qgcPal.window

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

    /// Sequence number of the mission item drawn as a solid, coloured vertical
    /// line, while every other marker is drawn dashed and muted - a way to make
    /// one waypoint stand out on the profile. -1 (the default) means no item is
    /// highlighted, which is what the embedded PlanView chart uses.
    property int   highlightSeqNum:         -1
    property color highlightMarkerColor:    "red"

    /// Colour of the ordinary (dashed) vertical waypoint marker lines.
    /// Overridable so a viewer can mute them: on a long mission there can be a
    /// dozen of them, and at full text brightness they dominate the chart more
    /// than the data they are only meant to annotate.
    property color markerLineColor:         qgcPal.text

    /// When false (the default) every marker line is solid, which is how the
    /// embedded PlanView chart has always looked. Viewers that want the
    /// muted-scale treatment turn it on; the highlighted item stays solid
    /// either way.
    property bool  dashOrdinaryMarkers:     false

    /// Length of one dash, and of the gap between dashes, for that marker.
    property real _markerDashLength:        ScreenTools.defaultFontPixelHeight * 0.35

    /// Line widths. Derived from the font metrics rather than hard-coded pixel
    /// counts so they hold up on high-DPI screens, where a 1px line renders as
    /// a hairline. The floors keep them from ever disappearing on very small
    /// displays.
    ///
    /// The two are deliberately different: the terrain and flight lines are
    /// the data, so they are drawn thick enough to follow comfortably, while
    /// the waypoint marker lines are only positional references and stay thin
    /// so they don't compete with the data. The marker multiplier reproduces
    /// the original 1px look on a standard-DPI screen and scales up from there.
    property real _seriesLineWidth:         Math.max(2, ScreenTools.defaultFontPixelWidth * 0.4)
    property real _markerLineWidth:         Math.max(1, ScreenTools.defaultFontPixelWidth * 0.12)

    /// The highlighted marker is drawn thicker than the ordinary ones so it
    /// reads at a glance on a busy profile - colour alone is easy to miss on a
    /// hairline. Still derived from the font metrics so it scales with the
    /// display like everything else.
    property real _highlightLineWidth:      Math.max(2, ScreenTools.defaultFontPixelWidth * 0.32)

    /// Approximate number of X axis tick labels aimed for at any zoom level.
    /// A single knob controlling overall label density on the distance axis.
    property int  _targetTickCount:         8

    /// Same idea for the Y (altitude) axis. Kept lower than the X target
    /// because the chart is much shorter than it is wide, so fewer labels
    /// fit vertically before they start crowding each other.
    property int  _targetTickCountY:        6

    /// Largest "nice" step (1 / 2 / 2.5 / 5 x 10^n) that is no bigger than an
    /// even split of the span into targetCount parts. Used by both axes so that
    /// tick density adapts to zoom: as the visible range shrinks, the step
    /// shrinks with it and more (finer) labels appear, instead of always
    /// showing the same fixed number of ticks stretched across whatever range
    /// happens to be visible. Restricting the step to those multiples keeps
    /// the printed values readable (200, 205, 210...) rather than arbitrary
    /// fractions of the range.
    ///
    /// The step is rounded DOWN to the next nice value, never up. Rounding up
    /// can silently halve the label count - a 450 m span split 8 ways gives
    /// 56.25, which rounds up to 100 and leaves only 5 labels instead of the
    /// 8 asked for. Rounding down guarantees at least targetCount labels.
    ///
    /// 2.5 sits in the ladder because without it the gap from 2 to 5 is wide
    /// enough that one extra requested label can double the actual count: a
    /// 355 m span asks for 44 and drops straight to 20, printing 18 labels
    /// where 15 were wanted. 2.5 gives the in-between step (25) and keeps the
    /// values round.
    function _niceTickStep(span, targetCount) {
        if (!(span > 0) || !(targetCount > 0)) {
            return 1
        }
        var rough = span / targetCount
        var mag   = Math.pow(10, Math.floor(Math.log(rough) / Math.LN10))
        var norm  = rough / mag                     // 1 <= norm < 10
        var nice  = norm < 2 ? 1 : norm < 2.5 ? 2 : norm < 5 ? 2.5 : 5
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

    /// Multiplies the fitted altitude span around its centre. Viewers set this
    /// above 1 when the user zooms out past the mission's own extent, so the
    /// vertical scale opens up in step with the horizontal one instead of
    /// staying pinned to the data while the profile shrinks to a flat streak.
    /// Large values are what bring 0 (sea level) and negative altitudes into
    /// view.
    property real autoFitYExpansion: 1

    /// Computed auto-fit bounds. NaN whenever auto-fit is off, no external X
    /// range is set, or no data falls inside the range - in which case the
    /// axis falls back to its normal full-range behavior.
    property real _autoMinY: NaN
    property real _autoMaxY: NaN

    onAutoFitYChanged:          _updateAutoFitY()
    onExternalMinXChanged:      _updateAutoFitY()
    onExternalMaxXChanged:      _updateAutoFitY()
    onAutoFitYExpansionChanged: _updateAutoFitY()

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

        // Grow symmetrically about the centre of the data, so zooming out
        // reveals altitude headroom on both sides rather than sliding the
        // profile towards one edge.
        var centre   = (acc.min + acc.max) / 2
        var halfSpan = (span / 2 + pad) * Math.max(1, autoFitYExpansion)

        _autoMinY = centre - halfSpan
        _autoMaxY = centre + halfSpan
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
                    plotAreaBackgroundColor:     root.plotBackgroundColor
                    // Grid kept faint: readable as an altitude reference without
                    // competing with the terrain and flight lines drawn on top.
                    // Below roughly 0.2 the lines stop being visible at all on a
                    // dark background, so this is about as light as it can go.
                    grid.mainColor:             applyOpacity(qgcPal.text, 0.28)
                    grid.subColor:              applyOpacity(qgcPal.text, 0.15)
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

                    // Vertical grid lines removed: distance is read off the
                    // labels, and the waypoint marker lines already give the
                    // vertical references that matter. The horizontal grid
                    // (axisY) is kept as an altitude reference.
                    gridVisible:                false
                    subGridVisible:             false

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

                    // Horizontal grid kept on: it is the altitude reference that
                    // makes the chart readable at a glance. Stated explicitly so
                    // it can't be lost if the theme default ever changes.
                    gridVisible:                true

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
                    width:      root._seriesLineWidth
                }

                LineSeries {
                    id:         collisionSeries
                    color:      "red"
                    width:      flightSeries.width * 3
                }

                LineSeries {
                    id:         terrainSeries
                    color:      "green"
                    width:      root._seriesLineWidth
                }

                LineSeries {
                    id:         flightSeries
                    color:      "orange"
                    width:      root._seriesLineWidth
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

                        Item {
                            id:         simpleItem
                            height:     terrainProfile.height
                            width:      _highlighted ? root._highlightLineWidth : root._markerLineWidth
                            x:          root._xForDistance(object.distanceFromStart) - width / 2
                            visible:    (object.isSimpleItem || object.isSingleItem) &&
                                        root._distanceInView(object.distanceFromStart)

                            // Was a plain Rectangle acting as the line itself.
                            // It is now a container so the same marker can be
                            // drawn either solid or as a dashed stack, without
                            // disturbing the label anchored to its bottom.
                            //
                            // The highlighted item gets the SOLID line and the
                            // ordinary ones are dashed: on a long mission the
                            // dozen plain markers should read as a faint scale
                            // behind the data, while the one item worth calling
                            // out stands out by being both solid and coloured.
                            readonly property bool _highlighted: object.sequenceNumber === root.highlightSeqNum
                            readonly property bool _drawDashed:  root.dashOrdinaryMarkers && !_highlighted

                            Rectangle {
                                anchors.fill: parent
                                color:        simpleItem._highlighted ? root.highlightMarkerColor : root.markerLineColor
                                visible:      !simpleItem._drawDashed
                            }

                            // Dashed variant. QML has no dashed-line primitive
                            // for a Rectangle, so the dashes are stacked with a
                            // Column whose spacing forms the gaps.
                            Column {
                                anchors.fill: parent
                                spacing:      root._markerDashLength
                                visible:      simpleItem._drawDashed
                                clip:         true

                                Repeater {
                                    model: Math.max(1, Math.ceil(simpleItem.height / (root._markerDashLength * 2)))

                                    Rectangle {
                                        width:  simpleItem.width
                                        height: root._markerDashLength
                                        color:  root.markerLineColor
                                    }
                                }
                            }

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
                            width:      root._markerLineWidth
                            color:      root.markerLineColor
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
                            width:      root._markerLineWidth
                            color:      root.markerLineColor
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