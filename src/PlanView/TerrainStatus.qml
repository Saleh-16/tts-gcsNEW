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

    /// The full mission span on the X axis, in display units - exactly what
    /// axisX uses when no external override is active.
    ///
    /// Exposed because a viewer that drives externalMinX/externalMaxX freezes
    /// axisX at whatever it sets. If such a viewer captured the full range once
    /// at startup, it would never notice the mission getting longer, and its
    /// "reset zoom" would restore a stale range that clips the new waypoints
    /// with no way to recover short of reopening the window. Binding to this
    /// instead keeps the viewer's idea of "full range" live.
    readonly property real fullRangeMaxX:
        _unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_missionTotalDistance)

    /// Series colours, published so a viewer can build a legend that cannot
    /// drift out of step with what is actually plotted.
    readonly property color seriesTerrainColor:   terrainSeries.color
    readonly property color seriesFlightColor:    flightSeries.color
    readonly property color seriesCollisionColor: collisionSeries.color
    readonly property color seriesMissingColor:   missingSeries.color

    /// True when a confirmed terrain collision falls inside the visible X range.
    ///
    /// Kept as an explicit flag because the red line alone is not a reliable
    /// signal once zoomed: it is drawn at flight altitude, so a viewer that
    /// auto-fits the Y axis can still clip it, and it carries no label of its
    /// own. A viewer can surface this as a badge.
    readonly property bool collisionInView:
        _rangeHasSegmentIn(collisionSeries, chart.axisX.min, chart.axisX.max)

    /// True when a stretch with no terrain data falls inside the visible X
    /// range.
    ///
    /// This one genuinely does vanish when zoomed. TerrainProfile.cc draws the
    /// missing-data line as a flat bar along the bottom of the plot at the
    /// WHOLE mission's minimum altitude (_addMissingPoints), not at any real
    /// altitude, so as soon as the Y axis fits a zoomed-in span that bar falls
    /// outside it. Losing it silently is worse than losing the collision line,
    /// because it marks the stretch where every altitude shown cannot be
    /// trusted at all.
    readonly property bool missingDataInView:
        _rangeHasSegmentIn(missingSeries, chart.axisX.min, chart.axisX.max)

    /// Height of the strip along the bottom of this control that the waypoint
    /// index labels occupy.
    ///
    /// They are anchored to the bottom of the marker lines, which end at the
    /// bottom of the plot area - so the strip starts wherever marginBottom
    /// puts that edge, plus room for the label itself. Published because a
    /// viewer that lays a MouseArea over this control has to leave that strip
    /// uncovered, or the labels stop being clickable. Deriving it here means
    /// the two cannot drift apart when the margin changes.
    readonly property real markerLabelZoneHeight:
        chart.marginBottom + ScreenTools.defaultFontPixelHeight * 1.6

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

    /// Floor on the altitude tick step, in display units.
    ///
    /// Without it, zooming far enough drives the step below 1 and the labels
    /// gain a second decimal - which is false precision on an AMSL scale (no
    /// aircraft holds a quarter of a metre) and costs a character in every
    /// label, on the axis that has the least room for one.
    property real _minTickStepY:            1

    /// The widest label each axis will print at the current range. Measured
    /// with real font metrics rather than counted in characters, because
    /// character width varies with the font the platform actually resolves.
    readonly property string _widestAxisYLabel: {
        var d = axisY.labelDecimals
        var a = axisY.min.toFixed(d)
        var b = axisY.max.toFixed(d)
        return a.length >= b.length ? a : b
    }

    readonly property string _widestAxisXLabel: {
        var d = axisX.labelDecimals
        var a = axisX.min.toFixed(d)
        var b = axisX.max.toFixed(d)
        return a.length >= b.length ? a : b
    }

    TextMetrics {
        id:             axisYLabelMetrics
        font.family:    ScreenTools.fixedFontFamily
        font.pointSize: ScreenTools.smallFontPointSize
        text:           root._widestAxisYLabel
    }

    TextMetrics {
        id:             axisXLabelMetrics
        font.family:    ScreenTools.fixedFontFamily
        font.pointSize: ScreenTools.smallFontPointSize
        text:           root._widestAxisXLabel
    }

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
    ///
    /// minStep is optional and clamps the result from below, for axes where a
    /// finer step would be meaningless precision rather than useful detail.
    function _niceTickStep(span, targetCount, minStep) {
        if (!(span > 0) || !(targetCount > 0)) {
            return 1
        }
        var rough = span / targetCount
        var mag   = Math.pow(10, Math.floor(Math.log(rough) / Math.LN10))
        var norm  = rough / mag                     // 1 <= norm < 10
        var nice  = norm < 2 ? 1 : norm < 2.5 ? 2 : norm < 5 ? 2.5 : 5
        var step  = nice * mag
        return (minStep !== undefined && step < minStep) ? minStep : step
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

    /// Cached point arrays for the three series that carry real altitude data.
    /// Rebuilt only when the profile changes, never while zooming: reading a
    /// series back point-by-point through at() is O(n), and on a long mission
    /// n runs into the thousands. A single wheel notch changes three properties
    /// that all feed the fit, and a trackpad sends those events continuously,
    /// so recomputing the arrays per event is what makes zooming stutter.
    property var _cachedFitPoints: null

    /// Coalesces fit requests into one pass per event loop turn. A zoom
    /// changes externalMinX, externalMaxX and autoFitYExpansion together;
    /// without this the fit would run up to three times per notch, and the
    /// first two runs would be against a half-updated range (new min, old max)
    /// whose result is thrown away a moment later - visible as a flicker on
    /// the altitude axis.
    property bool _autoFitPending: false

    onAutoFitYChanged:          _scheduleAutoFitY()
    onExternalMinXChanged:      _scheduleAutoFitY()
    onExternalMaxXChanged:      _scheduleAutoFitY()
    onAutoFitYExpansionChanged: _scheduleAutoFitY()

    function _scheduleAutoFitY() {
        if (_autoFitPending) {
            return
        }
        _autoFitPending = true
        Qt.callLater(function() {
            root._autoFitPending = false
            root._updateAutoFitY()
        })
    }

    /// Returns the series' points as a plain array.
    ///
    /// QtGraphs' QXYSeries exposes count as a property and at() as
    /// Q_INVOKABLE, but its points() accessor is plain C++ and is NOT visible
    /// from QML (unlike the old QtCharts, where points was a property). The
    /// property branch below therefore never runs on current Qt; it is kept
    /// only so this still works if a future Qt publishes it.
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

    /// True if any drawn part of 'series' crosses [lo, hi].
    ///
    /// Tests SEGMENTS, not vertices. A collision or missing-data run is emitted
    /// as just two points, one at each end, so a vertex test reports nothing
    /// the moment you zoom into the middle of such a run - the line spans the
    /// whole screen while both of its endpoints sit outside the range. Same
    /// long-segment case _scanPointsY already handles for the axis fit.
    function _rangeHasSegmentIn(series, lo, hi) {
        if (!series || !(hi > lo)) {
            return false
        }
        var n = series.count
        if (n === 0) {
            return false
        }
        if (n === 1) {
            var only = series.at(0)
            return !isNaN(only.x) && only.x >= lo && only.x <= hi
        }
        var prev = null
        for (var i = 0; i < n; i++) {
            var p = series.at(i)
            var ok = !isNaN(p.x) && !isNaN(p.y)     // NaN separates disjoint runs
            if (ok && prev) {
                var x0 = Math.min(prev.x, p.x)
                var x1 = Math.max(prev.x, p.x)
                if (x0 <= hi && x1 >= lo) {
                    return true
                }
            }
            prev = ok ? p : null
        }
        return false
    }

    /// Expands acc.min / acc.max to cover every part of 'pts' that lies
    /// within the currently visible X range. Works segment by segment and
    /// linearly interpolates where a segment crosses a range boundary, so a
    /// single long segment spanning the whole view is still measured correctly
    /// even when it has no sample point inside the range - which is exactly
    /// the case at high zoom levels.
    function _scanPointsY(pts, lo, hi, acc) {
        if (!pts || pts.length === 0) {
            return
        }

        function include(y) {
            if (y < acc.min) acc.min = y
            if (y > acc.max) acc.max = y
        }

        if (pts.length === 1) {
            if (!isNaN(pts[0].x) && !isNaN(pts[0].y) && pts[0].x >= lo && pts[0].x <= hi) {
                include(pts[0].y)
            }
            return
        }

        for (var i = 0; i < pts.length - 1; i++) {
            var p0 = pts[i]
            var p1 = pts[i + 1]

            // TerrainProfile.cc separates disjoint runs with NaN points. Skip
            // any segment touching one: there is no line drawn across a break,
            // so there is nothing to measure. Checked explicitly rather than
            // relying on NaN comparisons quietly failing every test below,
            // which is correct today but would flip silently if the range
            // check were ever rewritten.
            if (isNaN(p0.x) || isNaN(p0.y) || isNaN(p1.x) || isNaN(p1.y)) {
                continue
            }

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

        // missingSeries is deliberately NOT part of the fit. Its points are not
        // altitudes: TerrainProfile.cc::_addMissingPoints draws them as a flat
        // bar along the bottom of the plot at the whole mission's minimum
        // altitude, purely as a marker. Feeding that into the fit would pin the
        // lower bound to the full-mission minimum and flatten the zoom to
        // nothing over any stretch with no terrain data. The warning is kept
        // instead through missingDataInView, which a viewer shows as a badge.
        //
        // collisionSeries IS included: _addCollisionPoints uses the segment's
        // real coord1/coord2 AMSL altitudes, so it is genuine data drawn thick
        // over the flight path, not a marker.
        if (_cachedFitPoints === null) {
            _cachedFitPoints = [
                _seriesPoints(terrainSeries),
                _seriesPoints(flightSeries),
                _seriesPoints(collisionSeries)
            ]
        }

        var acc = { min: Number.POSITIVE_INFINITY, max: Number.NEGATIVE_INFINITY }
        for (var i = 0; i < _cachedFitPoints.length; i++) {
            _scanPointsY(_cachedFitPoints[i], externalMinX, externalMaxX, acc)
        }

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
    /// The metres-to-display-units conversion is read from unitsConversion
    /// rather than from terrainProfile.horizontalScale, even though the two
    /// always hold the same number. horizontalScale is declared MEMBER with no
    /// NOTIFY (TerrainProfile.h), so a binding on it is never re-evaluated:
    /// switching the distance unit would move axisX (which reads
    /// unitsConversion directly) while leaving every marker at its old-unit
    /// position, and Qt would log a non-notifiable-property warning for the
    /// dependency.
    function _xForDistance(distanceMeters) {
        if (!chart || !chart.axisX) {
            return 0
        }
        var lo = chart.axisX.min
        var hi = chart.axisX.max
        if (!(hi > lo)) {
            return 0
        }
        var scaled = _unitsConversion.metersToAppSettingsHorizontalDistanceUnits(distanceMeters)
        return chart.plotArea.width * ((scaled - lo) / (hi - lo))
    }

    /// True when the given mission distance falls inside the visible X range,
    /// so markers outside a zoomed view are hidden instead of being clamped
    /// against the edges where they would misrepresent their real position.
    function _distanceInView(distanceMeters) {
        if (!chart || !chart.axisX) {
            return false
        }
        var scaled = _unitsConversion.metersToAppSettingsHorizontalDistanceUnits(distanceMeters)
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

                // Every margin that carries axis labels is sized from measured
                // text, not from a fixed guess.
                //
                // The left margin used to be 0, which let QtGraphs draw the
                // altitude labels outside the item, where the Flickable's clip
                // cut them off. It held only as long as the labels stayed six
                // characters: zoom in far enough, the tick step drops below a
                // metre, a second decimal appears, and 1170.00 renders as
                // 170.00 - a silent thousand-metre error on an altitude axis.
                //
                // The bottom margin was negative for the same "just make it go
                // away" reason, and cost the bottom of every distance label.
                // The right margin was a fixed two-character guess that fails
                // once the last label is longer than that.
                marginTop:    ScreenTools.defaultFontPixelHeight / 2   // Fixes top clipping problem
                marginLeft:   axisYLabelMetrics.width  + ScreenTools.defaultFontPixelWidth * 0.6
                marginBottom: axisXLabelMetrics.height + ScreenTools.defaultFontPixelHeight * 0.2
                marginRight:  axisXLabelMetrics.width / 2 + ScreenTools.defaultFontPixelWidth * 0.6

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
                    max:                        isNaN(root.externalMaxX) ? root.fullRangeMaxX : root.externalMaxX
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
                    tickInterval:               root._niceTickStep(max - min, root._targetTickCountY, root._minTickStepY)
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
                    // Series points just changed, so the cached arrays are
                    // stale and any active vertical auto-fit has to be
                    // recomputed against the new data. Order matters: drop the
                    // cache first, then request the fit.
                    root._cachedFitPoints = null
                    root._scheduleAutoFitY()
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

                        // Complex-pattern entry/exit markers are centred on
                        // their distance the same way the simple markers are.
                        // Without the half-width shift they sit a fraction of a
                        // line to the right of the position they mark, which is
                        // invisible at 1px but obvious once the marker width
                        // scales up on a high-DPI display.
                        Rectangle {
                            id:         complexItemEntry
                            height:     terrainProfile.height
                            width:      root._markerLineWidth
                            color:      root.markerLineColor
                            x:          root._xForDistance(object.distanceFromStart) - width / 2
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
                            x:          root._xForDistance(object.distanceFromStart + object.complexDistance) - width / 2
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