// ============================================================================
//  TTS GROUP — Mission Review System
//  MissionReviewEngine.js
//
//  Single file containing all 6 subsystems:
//    [1] Mission Interpretation
//    [2] Geometry Engine
//    [3] Relationship Analysis
//    [4] Validation Engine
//    [5] Quality Assessment
//    [6] Engineering Report
//
//  Data flows ONE DIRECTION only: 1 → 2 → 3 → 4 → 5 → 6
//  No subsystem ever calls back to a subsystem above it.
// ============================================================================
.pragma library

var DEG_TO_RAD = Math.PI / 180.0
var RAD_TO_DEG = 180.0 / Math.PI
var EARTH_RADIUS = 6371000.0  // meters
var GRAVITY = 9.80665         // m/s²

// ═══════════════════════════════════════════════════════════════════════════
//  [1] MISSION INTERPRETATION
//  Reads QGC visualItems and builds a clean internal model.
//  The ONLY section that knows about QGC data structures.
// ═══════════════════════════════════════════════════════════════════════════

function interpretMission(visualItems, homePosition) {
    var points = []
    var segments = []
    var structure = {
        totalItems:       0,
        navigationPoints: 0,
        hasHome:          false,
        hasTakeoff:       false,
        hasLanding:       false,
        hasRTL:           false,
        invalidPoints:    [],
        homeAltMSL:       0,
        homeCoordinate:   null
    }

    if (!visualItems || visualItems.count === 0) {
        return { points: points, segments: segments, structure: structure }
    }

    structure.totalItems = visualItems.count

    // ── Parse home position ──
    if (homePosition && homePosition.isValid) {
        structure.hasHome = true
        structure.homeAltMSL = homePosition.altitude || 0
        structure.homeCoordinate = {
            lat: homePosition.latitude,
            lon: homePosition.longitude
        }
    }

    // ── Parse all items ──
    for (var i = 0; i < visualItems.count; i++) {
        var item = visualItems.get(i)
        if (!item) continue

        var point = _parseVisualItem(item, i, structure.homeAltMSL)
        points.push(point)

        // Track structure
        if (point.type === "HOME")     structure.hasHome = true
        if (point.type === "TAKEOFF")  structure.hasTakeoff = true
        if (point.type === "LAND")     structure.hasLanding = true
        if (point.type === "RTL")      structure.hasRTL = true
        if (point.isNavigation)        structure.navigationPoints++
        if (!point.isValid)            structure.invalidPoints.push(point.displayIndex)
    }

    // ── Build segments between consecutive navigation points ──
    var navPoints = []
    for (var n = 0; n < points.length; n++) {
        if (points[n].isNavigation && points[n].isValid) {
            navPoints.push(points[n])
        }
    }

    for (var s = 0; s < navPoints.length - 1; s++) {
        segments.push({
            fromIndex:  navPoints[s].displayIndex,
            toIndex:    navPoints[s + 1].displayIndex,
            fromPoint:  navPoints[s],
            toPoint:    navPoints[s + 1]
        })
    }

    // ── If RTL, add return segment to home ──
    if (structure.hasRTL && navPoints.length > 0 && structure.hasHome) {
        var lastNav = navPoints[navPoints.length - 1]
        if (lastNav.type === "RTL" && navPoints.length >= 2) {
            // RTL itself has no coords — use the nav point before it
            lastNav = navPoints[navPoints.length - 2]
        }

        var homePoint = null
        for (var h = 0; h < points.length; h++) {
            if (points[h].type === "HOME") { homePoint = points[h]; break }
        }

        if (homePoint && lastNav) {
            segments.push({
                fromIndex:  lastNav.displayIndex,
                toIndex:    "H",
                fromPoint:  lastNav,
                toPoint:    homePoint,
                isReturn:   true
            })
        }
    }

    return { points: points, segments: segments, structure: structure }
}

// ── Parse a single QGC visual item into a MissionPoint ──
function _parseVisualItem(item, rawIndex, homeAltMSL) {
    var type = _classifyCommand(item)
    var isNav = _isNavigationItem(type)
    var lat = 0, lon = 0, altMSL = 0, altRel = 0
    var isValid = true

    // Display index: Home = "H", others = rawIndex (matches QGC map)
    var displayIndex = (rawIndex === 0) ? "H" : rawIndex

    // ── Extract coordinates ──
    if (item.coordinate !== undefined) {
        lat = item.coordinate.latitude || 0
        lon = item.coordinate.longitude || 0
    }

    // ── Check for Null Island (0,0) ──
    if (isNav && Math.abs(lat) < 0.0001 && Math.abs(lon) < 0.0001 && type !== "HOME") {
        isValid = false
    }

    // ── Extract and normalize altitude to AMSL ──
    if (item.altitude !== undefined && item.altitude.value !== undefined) {
        var altValue = item.altitude.value
        var altFrame = item.altitudeFrame

        // QGC AltitudeFrame enum: 0 = Relative, 1 = AMSL, 2 = AboveTerrain
        if (altFrame === 1) {
            // Already AMSL
            altMSL = altValue
            altRel = altValue - homeAltMSL
        } else {
            // Relative to home (default)
            altRel = altValue
            altMSL = homeAltMSL + altValue
        }
    }

    // ── Home special case ──
    if (rawIndex === 0) {
        type = "HOME"
        altMSL = homeAltMSL
        altRel = 0
        if (item.coordinate) {
            lat = item.coordinate.latitude || 0
            lon = item.coordinate.longitude || 0
        }
        isValid = true // Home is always valid
    }

    return {
        rawIndex:      rawIndex,
        displayIndex:  displayIndex,
        type:          type,
        lat:           lat,
        lon:           lon,
        altMSL:        altMSL,
        altRel:        altRel,
        isNavigation:  isNav,
        isValid:       isValid,
        command:       item.command || 0
    }
}

function _classifyCommand(item) {
    if (!item) return "UNKNOWN"

    // QGC provides isTakeoffItem, isLandCommand etc.
    if (item.isTakeoffItem) return "TAKEOFF"

    var cmd = item.command || 0
    switch (cmd) {
        case 16:  return "WAYPOINT"       // MAV_CMD_NAV_WAYPOINT
        case 17:  return "LOITER_UNLIM"   // MAV_CMD_NAV_LOITER_UNLIM
        case 18:  return "LOITER_TURNS"   // MAV_CMD_NAV_LOITER_TURNS
        case 19:  return "LOITER_TIME"    // MAV_CMD_NAV_LOITER_TIME
        case 20:  return "RTL"            // MAV_CMD_NAV_RETURN_TO_LAUNCH
        case 21:  return "LAND"           // MAV_CMD_NAV_LAND
        case 22:  return "TAKEOFF"        // MAV_CMD_NAV_TAKEOFF
        case 82:  return "SPLINE_WP"      // MAV_CMD_NAV_SPLINE_WAYPOINT
        case 85:  return "VTOL_LAND"      // MAV_CMD_NAV_VTOL_LAND
        case 84:  return "VTOL_TAKEOFF"   // MAV_CMD_NAV_VTOL_TAKEOFF
        case 93:  return "DELAY"          // MAV_CMD_NAV_DELAY
        case 112: return "CONDITION_DELAY"
        case 177: return "DO_JUMP"        // MAV_CMD_DO_JUMP
        case 178: return "DO_CHANGE_SPEED"
        case 200: return "DO_SET_CAM"
        case 203: return "DO_DIGICAM"
        case 206: return "DO_SET_CAM_TRIGG"
        default:
            if (cmd >= 16 && cmd <= 95) return "NAV_OTHER"
            if (cmd >= 112 && cmd <= 159) return "CONDITION"
            if (cmd >= 176 && cmd <= 252) return "DO_COMMAND"
            return "UNKNOWN"
    }
}

function _isNavigationItem(type) {
    switch (type) {
        case "HOME":
        case "TAKEOFF":
        case "WAYPOINT":
        case "SPLINE_WP":
        case "LOITER_UNLIM":
        case "LOITER_TURNS":
        case "LOITER_TIME":
        case "LAND":
        case "RTL":
        case "VTOL_LAND":
        case "VTOL_TAKEOFF":
        case "NAV_OTHER":
            return true
        default:
            return false
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  [2] GEOMETRY ENGINE
//  Pure mathematics. No knowledge of aircraft or limits.
// ═══════════════════════════════════════════════════════════════════════════

function calculateGeometry(segments, points) {
    var segResults = []
    var turnResults = []
    var summary = {
        totalDistance:       0,
        maxAltitude:        -Infinity,
        minAltitude:        Infinity,
        totalClimb:         0,
        totalDescent:       0,
        maxDistanceFromHome: 0,
        returnDistance:      0
    }

    // ── Home coordinates for range calculation ──
    var homeLat = 0, homeLon = 0
    for (var p = 0; p < points.length; p++) {
        if (points[p].type === "HOME") {
            homeLat = points[p].lat
            homeLon = points[p].lon
            break
        }
    }

    // ── Calculate per-segment geometry ──
    for (var i = 0; i < segments.length; i++) {
        var seg = segments[i]
        var from = seg.fromPoint
        var to = seg.toPoint

        var dist = _haversineDistance(from.lat, from.lon, to.lat, to.lon)
        var bear = _bearing(from.lat, from.lon, to.lat, to.lon)
        var altChange = to.altMSL - from.altMSL
        var groundDist = Math.sqrt(dist * dist + altChange * altChange)
        var gradient = (dist > 0) ? Math.atan2(Math.abs(altChange), dist) * RAD_TO_DEG : 0

        segResults.push({
            fromIndex:      seg.fromIndex,
            toIndex:        seg.toIndex,
            distance:       dist,
            bearing:        bear,
            altitudeChange: altChange,
            groundDistance: groundDist,
            climbGradient:  (altChange >= 0) ? gradient : -gradient,
            isReturn:       seg.isReturn || false
        })

        summary.totalDistance += dist
        if (altChange > 0) summary.totalClimb += altChange
        if (altChange < 0) summary.totalDescent += Math.abs(altChange)

        if (seg.isReturn) {
            summary.returnDistance = dist
        }
    }

    // ── Calculate per-point stats ──
    for (var j = 0; j < points.length; j++) {
        if (!points[j].isNavigation || !points[j].isValid) continue
        if (points[j].altMSL > summary.maxAltitude) summary.maxAltitude = points[j].altMSL
        if (points[j].altMSL < summary.minAltitude) summary.minAltitude = points[j].altMSL

        var distHome = _haversineDistance(homeLat, homeLon, points[j].lat, points[j].lon)
        if (distHome > summary.maxDistanceFromHome) summary.maxDistanceFromHome = distHome
    }

    // ── Calculate turns (3 consecutive nav points) ──
    for (var t = 1; t < segResults.length; t++) {
        var prev = segResults[t - 1]
        var curr = segResults[t]

        var inBearing = prev.bearing
        var outBearing = curr.bearing
        var hdgChange = _headingChange(inBearing, outBearing)
        var turnDir = _turnDirection(inBearing, outBearing)

        turnResults.push({
            waypointIndex:   curr.fromIndex,
            inboundBearing:  inBearing,
            outboundBearing: outBearing,
            headingChange:   hdgChange,
            turnDirection:   turnDir
        })
    }

    // Fix summary edge cases
    if (summary.maxAltitude === -Infinity) summary.maxAltitude = 0
    if (summary.minAltitude === Infinity)  summary.minAltitude = 0

    return {
        segments: segResults,
        turns:    turnResults,
        summary:  summary
    }
}

// ── Haversine distance (meters) ──
function _haversineDistance(lat1, lon1, lat2, lon2) {
    var dLat = (lat2 - lat1) * DEG_TO_RAD
    var dLon = (lon2 - lon1) * DEG_TO_RAD
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * DEG_TO_RAD) * Math.cos(lat2 * DEG_TO_RAD) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2)
    return EARTH_RADIUS * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

// ── Bearing from point A to point B (degrees, 0-360) ──
function _bearing(lat1, lon1, lat2, lon2) {
    var dLon = (lon2 - lon1) * DEG_TO_RAD
    var y = Math.sin(dLon) * Math.cos(lat2 * DEG_TO_RAD)
    var x = Math.cos(lat1 * DEG_TO_RAD) * Math.sin(lat2 * DEG_TO_RAD) -
            Math.sin(lat1 * DEG_TO_RAD) * Math.cos(lat2 * DEG_TO_RAD) * Math.cos(dLon)
    return (Math.atan2(y, x) * RAD_TO_DEG + 360) % 360
}

// ── Heading change between two bearings (0-180) ──
function _headingChange(bearing1, bearing2) {
    var diff = Math.abs(bearing2 - bearing1)
    if (diff > 180) diff = 360 - diff
    return diff
}

// ── Turn direction ──
function _turnDirection(bearing1, bearing2) {
    var diff = bearing2 - bearing1
    if (diff < 0) diff += 360
    return diff <= 180 ? "RIGHT" : "LEFT"
}

// ═══════════════════════════════════════════════════════════════════════════
//  [3] RELATIONSHIP ANALYSIS
//  Transforms raw geometry + effective limits into engineering relationships.
//  Computes ALL scenarios upfront so the Validation Engine never needs to
//  call back.
// ═══════════════════════════════════════════════════════════════════════════

function analyzeRelationships(geometryResult, effectiveLimits) {
    var turns = []
    var climbs = []
    var spacings = []
    var altitudes = []
    var lim = effectiveLimits

    // ── Turn analysis ──
    for (var t = 0; t < geometryResult.turns.length; t++) {
        var turn = geometryResult.turns[t]
        turns.push(_analyzeTurn(turn, geometryResult.segments, lim))
    }

    // ── Climb/Descent analysis ──
    for (var c = 0; c < geometryResult.segments.length; c++) {
        var seg = geometryResult.segments[c]
        if (Math.abs(seg.altitudeChange) > 0.5) {
            climbs.push(_analyzeClimb(seg, lim))
        }
    }

    // ── Spacing analysis ──
    for (var s = 0; s < geometryResult.segments.length; s++) {
        spacings.push(_analyzeSpacing(geometryResult.segments[s], lim))
    }

    // ── Path analysis ──
    var path = _analyzePathPattern(geometryResult)

    return {
        turns:    turns,
        climbs:   climbs,
        spacings: spacings,
        path:     path
    }
}

function _analyzeTurn(turn, segments, lim) {
    var hdg = turn.headingChange

    // Classification
    var classification
    if (hdg < 15)       classification = "STRAIGHT"
    else if (hdg < 45)  classification = "GENTLE"
    else if (hdg < 90)  classification = "MODERATE"
    else if (hdg < 135) classification = "SHARP"
    else                classification = "REVERSAL"

    // Turn radius at cruise speed: R = V² / (g × tan(bankAngle))
    var bankRad = lim.maxBankAngle * DEG_TO_RAD
    var tanBank = Math.tan(bankRad)
    var radiusAtCruise = (tanBank > 0) ? (lim.cruiseSpeed * lim.cruiseSpeed) / (GRAVITY * tanBank) : Infinity
    var radiusAtMinSpd = (tanBank > 0 && lim.minSpeed > 0) ? (lim.minSpeed * lim.minSpeed) / (GRAVITY * tanBank) : Infinity

    // Available distance: shortest adjacent segment
    var availDist = Infinity
    for (var i = 0; i < segments.length; i++) {
        if (segments[i].fromIndex === turn.waypointIndex || segments[i].toIndex === turn.waypointIndex) {
            if (segments[i].distance < availDist) {
                availDist = segments[i].distance
            }
        }
    }

    // Required distance for the turn (approximation: 2 × radius for 90° turn, scales with angle)
    var turnFraction = hdg / 180.0
    var requiredAtCruise = 2 * radiusAtCruise * turnFraction
    var requiredAtMin = 2 * radiusAtMinSpd * turnFraction

    var feasibleAtCruise = (availDist >= requiredAtCruise)
    var feasibleAtMinSpd = (availDist >= requiredAtMin)

    // Min safe speed for this turn (solve for V: V = sqrt(R × g × tan(bank)), where R = availDist / (2 × fraction))
    var availRadius = availDist / (2 * turnFraction)
    var minSafeSpeed = (turnFraction > 0 && tanBank > 0) ? Math.sqrt(availRadius * GRAVITY * tanBank) : 0
    if (minSafeSpeed < lim.minSpeed) minSafeSpeed = lim.minSpeed

    return {
        waypointIndex:          turn.waypointIndex,
        headingChange:          hdg,
        turnDirection:          turn.turnDirection,
        classification:         classification,
        turnRadiusAtCruise:     radiusAtCruise,
        turnRadiusAtMinSpeed:   radiusAtMinSpd,
        requiredDistanceAtCruise: requiredAtCruise,
        requiredDistanceAtMin:  requiredAtMin,
        availableDistance:      availDist,
        feasibleAtCruise:       feasibleAtCruise,
        feasibleAtMinSpeed:     feasibleAtMinSpd,
        minSafeSpeed:           minSafeSpeed,
        bankAngleUsed:          lim.maxBankAngle,
        bankAngleSource:        lim.sources.maxBankAngle || ""
    }
}

function _analyzeClimb(seg, lim) {
    var altChange = seg.altitudeChange
    var direction = altChange > 0 ? "CLIMB" : "DESCENT"
    var absChange = Math.abs(altChange)
    var gradient = Math.abs(seg.climbGradient)

    var classification
    if (gradient < 3)       classification = "SHALLOW"
    else if (gradient < 8)  classification = "MODERATE"
    else if (gradient < 15) classification = "STEEP"
    else                    classification = "EXTREME"

    // Required rate at cruise speed
    var requiredRate = (seg.distance > 0 && lim.cruiseSpeed > 0) ?
        absChange / (seg.distance / lim.cruiseSpeed) : Infinity

    var rateLimit = direction === "CLIMB" ? lim.maxClimbRate : lim.maxDescentRate
    var feasibleAtCruise = (requiredRate <= rateLimit)

    // Max feasible speed: V_max = (rateLimit × distance) / absChange
    var maxFeasibleSpeed = (absChange > 0) ? (rateLimit * seg.distance) / absChange : Infinity
    if (maxFeasibleSpeed > lim.maxSpeed) maxFeasibleSpeed = lim.maxSpeed

    // Min required horizontal distance at limit rate
    var minRequiredDist = (rateLimit > 0 && lim.cruiseSpeed > 0) ?
        (absChange / rateLimit) * lim.cruiseSpeed : Infinity

    return {
        fromIndex:              seg.fromIndex,
        toIndex:                seg.toIndex,
        altitudeChange:         altChange,
        gradient:               gradient,
        direction:              direction,
        classification:         classification,
        requiredRate:           requiredRate,
        rateLimit:              rateLimit,
        feasibleAtCruise:       feasibleAtCruise,
        maxFeasibleSpeed:       maxFeasibleSpeed,
        minRequiredDistance:     minRequiredDist,
        rateLimitSource:        direction === "CLIMB" ?
            (lim.sources.maxClimbRate || "") : (lim.sources.maxDescentRate || "")
    }
}

function _analyzeSpacing(seg, lim) {
    var dist = seg.distance

    var classification
    if (dist < lim.minWaypointSpacing)          classification = "TOO_SHORT"
    else if (dist < lim.minWaypointSpacing * 2) classification = "SHORT"
    else if (dist > 5000)                       classification = "LONG"
    else                                        classification = "ADEQUATE"

    var gpsAccuracy = 3.0 // typical GPS accuracy in meters
    var errorRatio = (dist > 0) ? (gpsAccuracy / dist) * 100 : 100

    var overlap = (dist < lim.wpAcceptanceRadius * 2)

    return {
        fromIndex:          seg.fromIndex,
        toIndex:            seg.toIndex,
        distance:           dist,
        classification:     classification,
        minSpacing:         lim.minWaypointSpacing,
        gpsAccuracy:        gpsAccuracy,
        errorRatio:         errorRatio,
        wpAcceptanceRadius: lim.wpAcceptanceRadius,
        overlapWithNext:    overlap
    }
}

function _analyzePathPattern(geometryResult) {
    var segs = geometryResult.segments
    var turns = geometryResult.turns

    // ── Zig-zag detection ──
    var zigZagSegments = []
    for (var z = 0; z < turns.length - 1; z++) {
        var t1 = turns[z]
        var t2 = turns[z + 1]
        if (t1.headingChange > 120 && t2.headingChange > 120 &&
            t1.turnDirection !== t2.turnDirection) {
            zigZagSegments.push([t1.waypointIndex, t2.waypointIndex])
        }
    }

    // ── Spacing variance ──
    var distances = segs.map(function(s) { return s.distance })
    var shortest = distances.length > 0 ? Math.min.apply(null, distances) : 0
    var longest = distances.length > 0 ? Math.max.apply(null, distances) : 0
    var ratio = (shortest > 0) ? longest / shortest : 0
    var spacingVariance
    if (ratio < 3)       spacingVariance = "LOW"
    else if (ratio < 10) spacingVariance = "MEDIUM"
    else                 spacingVariance = "HIGH"

    // ── Return efficiency ──
    var summary = geometryResult.summary
    var returnRatio = (summary.totalDistance > 0 && summary.returnDistance > 0) ?
        (summary.returnDistance / summary.totalDistance) * 100 : 0

    return {
        hasZigZag:          zigZagSegments.length > 0,
        zigZagSegments:     zigZagSegments,
        spacingVariance:    spacingVariance,
        shortestSegment:    shortest,
        longestSegment:     longest,
        ratio:              ratio,
        returnDistance:      summary.returnDistance,
        missionDistance:     summary.totalDistance,
        returnRatio:        returnRatio
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  [4] VALIDATION ENGINE
//  Reads relationships and issues findings. Never calculates.
// ═══════════════════════════════════════════════════════════════════════════

function validate(relationships, structure, limits, points) {
    var findings = []
    _validateClimbAngle(relationships.climbs, findings)
    _validateWP3Distance(points, structure, findings)
    return findings
}

// ── RULE 1: Climb/Descent Angle ──
// > 5°  = CRITICAL
// > 2.5° and <= 5° = WARNING
// <= 2.5° = PASS
function _validateClimbAngle(climbs, findings) {
    var failCount = 0
    for (var i = 0; i < climbs.length; i++) {
        var c = climbs[i]
        var angle = c.gradient  // absolute angle in degrees

        if (angle > 5.0) {
            failCount++
            findings.push(_finding("CRITICAL", "GEOMETRY",
                c.direction + " angle " + angle.toFixed(1) + "° exceeds 5° limit: WP " + c.fromIndex + " → " + c.toIndex,
                [c.fromIndex, c.toIndex],
                angle.toFixed(1) + "° " + c.direction.toLowerCase() + " angle. Maximum allowed: 5.0°. " +
                "Altitude change: " + Math.abs(c.altitudeChange).toFixed(0) + "m.",
                "Aircraft cannot safely " + c.direction.toLowerCase() + " at this angle. Mission will fail.",
                "Increase horizontal distance between waypoints or reduce altitude change",
                "Mission requirement: angle <= 5.0°"))
        } else if (angle > 2.5) {
            failCount++
            findings.push(_finding("WARNING", "GEOMETRY",
                c.direction + " angle " + angle.toFixed(1) + "° exceeds 2.5° ideal: WP " + c.fromIndex + " → " + c.toIndex,
                [c.fromIndex, c.toIndex],
                angle.toFixed(1) + "° " + c.direction.toLowerCase() + " angle. Recommended maximum: 2.5°. " +
                "Altitude change: " + Math.abs(c.altitudeChange).toFixed(0) + "m.",
                "Steep angle may cause energy management issues.",
                "Increase horizontal distance or reduce altitude change to bring angle below 2.5°",
                "Mission recommendation: angle <= 2.5°"))
        }
    }
    if (failCount === 0) {
        if (climbs.length > 0) {
            var maxAngle = 0
            for (var j = 0; j < climbs.length; j++) {
                if (climbs[j].gradient > maxAngle) maxAngle = climbs[j].gradient
            }
            findings.push(_finding("NOTICE", "GEOMETRY",
                "All climb/descent angles within limits (max: " + maxAngle.toFixed(1) + "°)",
                [], "All segment angles are below 2.5°. No steep climbs or descents.",
                "No impact — all angles are safe.",
                "No action required", ""))
        } else {
            findings.push(_finding("NOTICE", "GEOMETRY",
                "Level flight — no altitude changes",
                [], "All waypoints are at the same altitude.",
                "No impact — flat mission.",
                "No action required", ""))
        }
    }
}

// ── RULE 2: WP3 minimum 5 km from Home ──
function _validateWP3Distance(points, structure, findings) {
    if (!structure.hasHome || !structure.homeCoordinate) return

    var wp3Point = null
    for (var k = 0; k < points.length; k++) {
        if (points[k].displayIndex === 3) {
            wp3Point = points[k]
            break
        }
    }
    if (wp3Point && wp3Point.isValid) {
        var distWP3 = _haversineDistance(
            structure.homeCoordinate.lat, structure.homeCoordinate.lon,
            wp3Point.lat, wp3Point.lon
        )
        if (distWP3 < 5000) {
            findings.push(_finding("CRITICAL", "CONSISTENCY",
                "WP3 too close to Home: " + (distWP3 / 1000).toFixed(1) + " km",
                [3],
                "WP3 is " + (distWP3 / 1000).toFixed(1) + " km from Home. Minimum required: 5 km.",
                "Mission does not meet minimum standoff distance for WP3.",
                "Move WP3 at least 5 km from Home position",
                "Mission requirement: WP3 >= 5 km"))
        } else {
            findings.push(_finding("NOTICE", "CONSISTENCY",
                "WP3 distance OK: " + (distWP3 / 1000).toFixed(1) + " km from Home",
                [3],
                "WP3 is " + (distWP3 / 1000).toFixed(1) + " km from Home. Minimum required: 5 km. Passed.",
                "No impact — standoff distance requirement met.",
                "No action required",
                "Mission requirement: WP3 >= 5 km"))
        }
    }
}

function _validateStructure(structure, findings) {
    if (!structure.hasHome) {
        findings.push(_finding("CRITICAL", "STRUCTURE", "No Home Position",
            ["H"], "Home Position is not set",
            "RTL will have no destination. Distance calculations will be invalid.",
            "Set Home Position before planning", "QGC Mission Protocol"))
    } else {
        findings.push(_finding("NOTICE", "STRUCTURE", "Home Position set",
            ["H"], "Home Position is defined with valid coordinates.",
            "No impact — Home is set correctly.", "No action required", ""))
    }
    if (!structure.hasTakeoff) {
        findings.push(_finding("CRITICAL", "STRUCTURE", "No Takeoff command",
            [], "Mission has no explicit Takeoff item",
            "Aircraft may not arm or may takeoff with undefined behavior.",
            "Add a Takeoff item as the first mission command", "ArduPilot Mission Protocol"))
    } else {
        findings.push(_finding("NOTICE", "STRUCTURE", "Takeoff command present",
            [], "Mission includes an explicit Takeoff item.",
            "No impact — Takeoff is defined.", "No action required", ""))
    }
    if (!structure.hasRTL && !structure.hasLanding) {
        findings.push(_finding("CRITICAL", "STRUCTURE", "No terminal action",
            [], "Mission has no RTL or Land command at the end",
            "Aircraft will hold at last waypoint until battery runs out.",
            "Add RTL or Land as the last mission item", "ArduPilot Mission Protocol"))
    } else {
        var termType = structure.hasRTL ? "RTL" : "Land"
        findings.push(_finding("NOTICE", "STRUCTURE", "Terminal action present (" + termType + ")",
            [], "Mission ends with " + termType + " command.",
            "No impact — mission has a defined ending.", "No action required", ""))
    }
    if (structure.invalidPoints.length > 0) {
        findings.push(_finding("CRITICAL", "STRUCTURE", "Invalid coordinates",
            structure.invalidPoints, "Waypoints at coordinates (0,0) — Null Island",
            "Navigation to invalid coordinates will cause unpredictable flight.",
            "Verify or remove waypoints with (0,0) coordinates", "GPS Navigation"))
    }
    if (structure.navigationPoints === 0) {
        findings.push(_finding("CRITICAL", "STRUCTURE", "Empty mission",
            [], "Mission has no navigation waypoints",
            "No flight path defined.", "Add waypoints to define the flight path", ""))
    } else {
        findings.push(_finding("NOTICE", "STRUCTURE", structure.navigationPoints + " navigation waypoints defined",
            [], "Mission contains " + structure.navigationPoints + " valid navigation points.",
            "No impact — flight path is defined.", "No action required", ""))
    }
}

function _validateTurns(turns, limits, findings) {
    var failCount = 0
    for (var i = 0; i < turns.length; i++) {
        var t = turns[i]
        if (t.classification === "STRAIGHT" || t.classification === "GENTLE") continue

        if (!t.feasibleAtMinSpeed) {
            failCount++
            findings.push(_finding("CRITICAL", "GEOMETRY",
                "Turn impossible at WP " + t.waypointIndex,
                [t.waypointIndex],
                t.headingChange.toFixed(0) + "° turn requires " + t.requiredDistanceAtMin.toFixed(0) +
                "m but only " + t.availableDistance.toFixed(0) + "m available. Infeasible at any speed.",
                "Aircraft cannot complete this turn and will deviate from planned path.",
                "Add intermediate waypoints to smooth the turn or increase spacing",
                t.bankAngleSource + " = " + t.bankAngleUsed.toFixed(0) + "°"))
        } else if (t.classification === "REVERSAL") {
            failCount++
            findings.push(_finding("CRITICAL", "GEOMETRY",
                "Path overshoot: " + t.headingChange.toFixed(0) + "° reversal at WP " + t.waypointIndex,
                [t.waypointIndex],
                t.headingChange.toFixed(0) + "° " + t.turnDirection.toLowerCase() +
                " reversal. Aircraft will overshoot the planned path significantly. " +
                "Turn radius: " + t.turnRadiusAtCruise.toFixed(0) + "m at cruise speed.",
                "Actual flight path will deviate from planned path. L1 navigation controller cannot track this turn accurately.",
                "Split into multiple waypoints with turns below 90° each",
                t.bankAngleSource + " = " + t.bankAngleUsed.toFixed(0) + "°"))
        } else if (t.classification === "SHARP") {
            failCount++
            findings.push(_finding("CRITICAL", "GEOMETRY",
                "Path overshoot: " + t.headingChange.toFixed(0) + "° sharp turn at WP " + t.waypointIndex,
                [t.waypointIndex],
                t.headingChange.toFixed(0) + "° " + t.turnDirection.toLowerCase() +
                " turn. Aircraft will overshoot the waypoint and deviate from planned path. " +
                "Turn radius: " + t.turnRadiusAtCruise.toFixed(0) + "m at cruise speed.",
                "Actual flight path will not match planned path. Mission accuracy compromised.",
                "Add intermediate waypoints to reduce turn angle below 90°",
                t.bankAngleSource + " = " + t.bankAngleUsed.toFixed(0) + "°"))
        } else if (t.classification === "MODERATE") {
            failCount++
            findings.push(_finding("WARNING", "GEOMETRY",
                "Moderate turn (" + t.headingChange.toFixed(0) + "°) at WP " + t.waypointIndex,
                [t.waypointIndex],
                t.headingChange.toFixed(0) + "° " + t.turnDirection.toLowerCase() +
                " turn. Minor path deviation expected. " +
                "Turn radius: " + t.turnRadiusAtCruise.toFixed(0) + "m at cruise speed.",
                "Small overshoot possible — actual path may differ slightly from planned.",
                "Consider adding intermediate waypoints to smooth the turn",
                t.bankAngleSource + " = " + t.bankAngleUsed.toFixed(0) + "°"))
        } else if (!t.feasibleAtCruise) {
            failCount++
            findings.push(_finding("WARNING", "GEOMETRY",
                "Turn requires speed reduction at WP " + t.waypointIndex,
                [t.waypointIndex],
                t.headingChange.toFixed(0) + "° turn infeasible at cruise speed (" +
                limits.cruiseSpeed.toFixed(0) + " m/s). Minimum safe speed: " +
                t.minSafeSpeed.toFixed(1) + " m/s.",
                "Aircraft must slow down significantly to complete this turn.",
                "Add intermediate waypoints or increase segment spacing",
                t.bankAngleSource + " = " + t.bankAngleUsed.toFixed(0) + "°"))
        }
    }
    if (failCount === 0) {
        findings.push(_finding("NOTICE", "GEOMETRY",
            "All turns within limits — no path overshoot",
            [], "All turn angles are below 45° — no significant path deviation expected.",
            "No impact — flight path will closely match planned path.",
            "No action required", ""))
    }
}

function _validateClimbs(climbs, findings) {
    var failCount = 0
    for (var i = 0; i < climbs.length; i++) {
        var c = climbs[i]

        if (c.requiredRate > c.rateLimit * 2) {
            failCount++
            findings.push(_finding("CRITICAL", "GEOMETRY",
                c.direction + " impossible: WP " + c.fromIndex + " → " + c.toIndex,
                [c.fromIndex, c.toIndex],
                Math.abs(c.altitudeChange).toFixed(0) + "m " + c.direction.toLowerCase() +
                " requires " + c.requiredRate.toFixed(1) + " m/s but limit is " +
                c.rateLimit.toFixed(1) + " m/s (" + (c.requiredRate / c.rateLimit).toFixed(0) + "× exceeded).",
                "Aircraft physically cannot achieve this " + c.direction.toLowerCase() + " rate.",
                "Increase horizontal distance or reduce altitude change",
                c.rateLimitSource + " = " + c.rateLimit.toFixed(1) + " m/s"))
        } else if (!c.feasibleAtCruise) {
            failCount++
            findings.push(_finding("WARNING", "GEOMETRY",
                c.direction + " steep: WP " + c.fromIndex + " → " + c.toIndex,
                [c.fromIndex, c.toIndex],
                c.gradient.toFixed(1) + "° gradient requires " + c.requiredRate.toFixed(1) +
                " m/s " + c.direction.toLowerCase() + " rate. Limit: " + c.rateLimit.toFixed(1) + " m/s.",
                "Aircraft must reduce speed to " + c.maxFeasibleSpeed.toFixed(1) + " m/s.",
                "Increase horizontal distance between these waypoints",
                c.rateLimitSource + " = " + c.rateLimit.toFixed(1) + " m/s"))
        }
    }
    if (failCount === 0) {
        findings.push(_finding("NOTICE", "GEOMETRY",
            "All climb/descent rates within limits",
            [], "All altitude changes are achievable at cruise speed.",
            "No impact — all gradients are within aircraft capability.",
            "No action required", ""))
    }
}

function _validateSpacing(spacings, findings) {
    var failCount = 0
    for (var i = 0; i < spacings.length; i++) {
        var s = spacings[i]

        if (s.classification === "TOO_SHORT") {
            failCount++
            findings.push(_finding("WARNING", "GEOMETRY",
                "Waypoints too close: WP " + s.fromIndex + " → " + s.toIndex,
                [s.fromIndex, s.toIndex],
                s.distance.toFixed(0) + "m spacing is below minimum (" + s.minSpacing.toFixed(0) +
                "m). GPS error ratio: " + s.errorRatio.toFixed(0) + "%.",
                "Navigation oscillation likely. GPS accuracy (" + s.gpsAccuracy.toFixed(0) +
                "m) is significant relative to segment length.",
                "Increase spacing or merge nearby waypoints", "Aircraft config: minSpacing = " + s.minSpacing + "m"))
        }

        if (s.overlapWithNext) {
            failCount++
            findings.push(_finding("WARNING", "ARDUPILOT",
                "Acceptance radius overlap: WP " + s.fromIndex + " → " + s.toIndex,
                [s.fromIndex, s.toIndex],
                "Distance " + s.distance.toFixed(0) + "m is less than 2× WP_RADIUS (" +
                s.wpAcceptanceRadius.toFixed(0) + "m). Acceptance circles overlap.",
                "Aircraft may skip waypoint " + s.toIndex + " entirely.",
                "Increase spacing to at least " + (s.wpAcceptanceRadius * 2).toFixed(0) + "m",
                "WP_RADIUS = " + s.wpAcceptanceRadius.toFixed(0) + "m"))
        }
    }
    if (failCount === 0 && spacings.length > 0) {
        findings.push(_finding("NOTICE", "GEOMETRY",
            "Waypoint spacing adequate",
            [], "All segments meet minimum spacing requirements. No acceptance radius overlaps.",
            "No impact — waypoint spacing is sufficient for GPS navigation.",
            "No action required", ""))
    }
}

function _validateAltitudes(points, limits, findings) {
    var failCount = 0
    for (var i = 0; i < points.length; i++) {
        var p = points[i]
        if (!p.isNavigation || !p.isValid || p.type === "HOME" || p.type === "RTL") continue

        if (limits.maxAltitude > 0 && p.altRel > limits.maxAltitude) {
            failCount++
            findings.push(_finding("CRITICAL", "AIRCRAFT",
                "Altitude exceeds ceiling at WP " + p.displayIndex,
                [p.displayIndex],
                p.altRel.toFixed(0) + "m AGL exceeds maximum " + limits.maxAltitude.toFixed(0) + "m.",
                "Will trigger Geofence failsafe — aircraft will RTL or Land automatically.",
                "Reduce altitude to below " + limits.maxAltitude.toFixed(0) + "m",
                (limits.sources.maxAltitude || "ALT_MAX") + " = " + limits.maxAltitude.toFixed(0) + "m"))
        }
    }
    if (failCount === 0) {
        var ceilText = (limits.maxAltitude > 0) ? " (ceiling: " + limits.maxAltitude.toFixed(0) + "m)" : ""
        findings.push(_finding("NOTICE", "AIRCRAFT",
            "All altitudes within ceiling" + ceilText,
            [], "No waypoint exceeds the maximum altitude limit.",
            "No impact — all altitudes are safe.",
            "No action required", ""))
    }
}

function _validateConsistency(points, structure, findings) {
    // RULE-C01: Takeoff is not first navigation item
    var firstNav = null
    for (var i = 0; i < points.length; i++) {
        if (points[i].isNavigation && points[i].type !== "HOME") {
            firstNav = points[i]
            break
        }
    }
    if (firstNav && firstNav.type !== "TAKEOFF") {
        findings.push(_finding("WARNING", "CONSISTENCY",
            "Takeoff is not the first command",
            [firstNav.displayIndex],
            "First navigation item is " + firstNav.type + " instead of TAKEOFF.",
            "Aircraft may not launch correctly.",
            "Move Takeoff to be the first item after Home", "ArduPilot Mission Protocol"))
    } else if (firstNav && firstNav.type === "TAKEOFF") {
        findings.push(_finding("NOTICE", "CONSISTENCY",
            "Takeoff is first command",
            [firstNav.displayIndex],
            "Takeoff is correctly placed as the first navigation item after Home.",
            "No impact — launch sequence is correct.",
            "No action required", "ArduPilot Mission Protocol"))
    }

    // RULE-C02: Commands after RTL
    var rtlFound = false
    var cmdsAfterRTL = false
    for (var j = 0; j < points.length; j++) {
        if (points[j].type === "RTL") rtlFound = true
        else if (rtlFound && points[j].isNavigation) {
            cmdsAfterRTL = true
            findings.push(_finding("WARNING", "CONSISTENCY",
                "Commands after RTL will not execute",
                [points[j].displayIndex],
                "WP " + points[j].displayIndex + " is placed after RTL and will never be reached.",
                "These waypoints are unreachable.", "Remove items after RTL or move RTL to the end",
                "ArduPilot Mission Protocol"))
            break
        }
    }
    if (rtlFound && !cmdsAfterRTL) {
        findings.push(_finding("NOTICE", "CONSISTENCY",
            "No unreachable commands after RTL",
            [], "RTL is the last action — no navigation items are placed after it.",
            "No impact — all waypoints are reachable.",
            "No action required", "ArduPilot Mission Protocol"))
    }

    // RULE-C03: WP3 minimum 5 km from Home
    if (structure.hasHome && structure.homeCoordinate) {
        var wp3Point = null
        for (var k = 0; k < points.length; k++) {
            if (points[k].displayIndex === 3) {
                wp3Point = points[k]
                break
            }
        }
        if (wp3Point && wp3Point.isValid) {
            var distWP3 = _haversineDistance(
                structure.homeCoordinate.lat, structure.homeCoordinate.lon,
                wp3Point.lat, wp3Point.lon
            )
            if (distWP3 < 5000) {
                findings.push(_finding("CRITICAL", "CONSISTENCY",
                    "WP3 too close to Home: " + distWP3.toFixed(0) + "m",
                    [3],
                    "WP3 is " + distWP3.toFixed(0) + "m from Home. Minimum required: 5000m.",
                    "Mission does not meet minimum standoff distance for WP3.",
                    "Move WP3 at least 5 km from Home position",
                    "Mission requirement: WP3 ≥ 5 km"))
            } else {
                var distKm = (distWP3 / 1000).toFixed(1)
                findings.push(_finding("NOTICE", "CONSISTENCY",
                    "WP3 distance OK: " + distKm + " km from Home",
                    [3],
                    "WP3 is " + distKm + " km from Home. Minimum required: 5 km. ✓ Passed.",
                    "No impact — standoff distance requirement met.",
                    "No action required",
                    "Mission requirement: WP3 ≥ 5 km"))
            }
        }
    }
}

function _finding(severity, category, problem, waypoints, explanation, impact, recommendation, source) {
    return {
        severity:           severity,
        category:           category,
        problem:            problem,
        affectedWaypoints:  waypoints,
        explanation:        explanation,
        flightImpact:       impact,
        recommendation:     recommendation,
        constraintSource:   source
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  [5] QUALITY ASSESSMENT
//  Recommendations only — never CRITICAL or WARNING. Only NOTICE.
// ═══════════════════════════════════════════════════════════════════════════

function assessQuality(relationships, geometrySummary) {
    var assessments = []
    var path = relationships.path

    // ── Zig-zag pattern ──
    if (path.hasZigZag) {
        assessments.push({
            category:       "PATH",
            issue:          "ZIG_ZAG_PATTERN",
            description:    "Zig-zag pattern detected in waypoint sequence",
            affectedPoints: path.zigZagSegments.flat ? path.zigZagSegments.reduce(function(a,b){return a.concat(b)}, []) : [],
            recommendation: "Reorder waypoints for a sequential path instead of back-and-forth"
        })
    }

    // ── Irregular spacing ──
    if (path.spacingVariance === "HIGH" && path.ratio > 20) {
        assessments.push({
            category:       "SPACING",
            issue:          "IRREGULAR_SPACING",
            description:    "Shortest segment " + path.shortestSegment.toFixed(0) + "m, longest " +
                            path.longestSegment.toFixed(0) + "m (ratio " + path.ratio.toFixed(0) + ":1)",
            affectedPoints: [],
            recommendation: "Distribute waypoints more evenly for consistent flight behavior"
        })
    }

    // ── Long return leg ──
    if (path.returnRatio > 30) {
        assessments.push({
            category:       "EFFICIENCY",
            issue:          "LONG_RETURN_LEG",
            description:    "Return leg is " + path.returnDistance.toFixed(0) + "m (" +
                            path.returnRatio.toFixed(0) + "% of total mission distance)",
            affectedPoints: [],
            recommendation: "Plan the path so the last waypoint is closer to Home"
        })
    }

    // ── Excessive altitude changes ──
    if (geometrySummary.totalClimb + geometrySummary.totalDescent > geometrySummary.totalDistance * 0.3) {
        assessments.push({
            category:       "ALTITUDE",
            issue:          "EXCESSIVE_ALT_CHANGES",
            description:    "Total climb " + geometrySummary.totalClimb.toFixed(0) + "m + descent " +
                            geometrySummary.totalDescent.toFixed(0) + "m relative to " +
                            geometrySummary.totalDistance.toFixed(0) + "m distance",
            affectedPoints: [],
            recommendation: "Maintain consistent altitude where possible to conserve energy"
        })
    }

    return assessments
}

// ═══════════════════════════════════════════════════════════════════════════
//  [6] ENGINEERING REPORT
//  Assembles everything into a structured report for the UI.
// ═══════════════════════════════════════════════════════════════════════════

function generateReport(findings, assessments, geometrySummary, structure, limits) {
    // ── Count by severity ──
    var counts = { critical: 0, warning: 0, notice: 0 }
    for (var i = 0; i < findings.length; i++) {
        switch (findings[i].severity) {
            case "CRITICAL": counts.critical++; break
            case "WARNING":  counts.warning++;  break
            case "NOTICE":   counts.notice++;   break
        }
    }
    counts.notice += assessments.length

    // ── Determine readiness ──
    var status
    if (!structure.hasTakeoff || (!structure.hasRTL && !structure.hasLanding) || structure.invalidPoints.length > 0) {
        status = "INCOMPLETE"
    } else if (counts.critical > 0) {
        status = "REVIEW_REQUIRED"
    } else if (counts.warning > 0) {
        status = "READY_WITH_ADVISORIES"
    } else {
        status = "READY"
    }

    // ── Sort findings: CRITICAL first, then WARNING, then NOTICE ──
    var severityOrder = { "CRITICAL": 0, "WARNING": 1, "NOTICE": 2 }
    var sortedFindings = findings.slice().sort(function(a, b) {
        return (severityOrder[a.severity] || 3) - (severityOrder[b.severity] || 3)
    })

    // ── Mission statistics ──
    var cruiseSpeed = limits.cruiseSpeed || 15
    var estimatedTime = (cruiseSpeed > 0) ? geometrySummary.totalDistance / cruiseSpeed : 0

    var stats = {
        totalDistance:       geometrySummary.totalDistance,
        estimatedTime:      estimatedTime,
        maxAltitude:        geometrySummary.maxAltitude,
        maxRange:           geometrySummary.maxDistanceFromHome,
        totalClimb:         geometrySummary.totalClimb,
        totalDescent:       geometrySummary.totalDescent,
        waypointCount:      structure.navigationPoints,
        returnDistance:      geometrySummary.returnDistance
    }

    // ── Responsibility acknowledgment ──
    var requiresAcknowledgment = (counts.critical > 0 || counts.warning > 0)

    return {
        status:                 status,
        counts:                 counts,
        findings:               sortedFindings,
        assessments:            assessments,
        stats:                  stats,
        requiresAcknowledgment: requiresAcknowledgment,
        timestamp:              new Date().toISOString()
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN ENTRY POINT
//  Runs the complete review pipeline: 1 → 2 → 3 → 4 → 5 → 6
// ═══════════════════════════════════════════════════════════════════════════

function reviewMission(visualItems, homePosition, effectiveLimits) {
    // [1] Interpret mission
    var mission = interpretMission(visualItems, homePosition)

    // If empty, return minimal report
    if (mission.points.length === 0) {
        return generateReport([], [], { totalDistance: 0, maxAltitude: 0, minAltitude: 0,
            totalClimb: 0, totalDescent: 0, maxDistanceFromHome: 0, returnDistance: 0 },
            mission.structure, effectiveLimits)
    }

    // [2] Calculate geometry
    var geometry = calculateGeometry(mission.segments, mission.points)

    // [3] Analyze relationships
    var relationships = analyzeRelationships(geometry, effectiveLimits)

    // [4] Validate
    var findings = validate(relationships, mission.structure, effectiveLimits, mission.points)

    // [5] Assess quality
    var assessments = assessQuality(relationships, geometry.summary)

    // [6] Generate report
    return generateReport(findings, assessments, geometry.summary, mission.structure, effectiveLimits)
}