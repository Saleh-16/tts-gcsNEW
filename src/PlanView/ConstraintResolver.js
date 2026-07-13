.pragma library
// ============================================================================
//  TTS GROUP — Mission Review System
//  ConstraintResolver.js
//
//  Purpose:  Merge aircraft performance limits with ArduPilot parameters
//            into a single EffectiveLimits object.
//            Most restrictive limit always wins.
//
//  Called:   Once before any analysis begins.
//  Output:   Used by RelationshipAnalysis and ValidationEngine.
//
//  This file is SEPARATE from MissionReviewEngine.js by design decision.
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────────
//  DEFAULT AIRCRAFT CONFIG
//  Fixed for this aircraft type. NOT entered every mission.
//  Change these values once when the aircraft changes.
// ─────────────────────────────────────────────────────────────────────────────
var _defaultAircraftConfig = {
    cruiseSpeed:        15.0,   // m/s
    stallSpeed:         10.0,   // m/s
    maxSpeed:           25.0,   // m/s
    maxBankAngle:       45.0,   // degrees
    maxClimbRate:        5.0,   // m/s
    maxDescentRate:      4.0,   // m/s
    maxAltitude:       500.0,   // meters (above home)
    minWaypointSpacing: 20.0    // meters
}

// ─────────────────────────────────────────────────────────────────────────────
//  ArduPilot PARAMETER MAP
//  Maps ArduPilot parameter names to their meaning and unit conversion.
//  CM values (like TRIM_ARSPD_CM) are converted to m/s by dividing by 100.
// ─────────────────────────────────────────────────────────────────────────────
var _parameterMap = {
    "TRIM_ARSPD_CM":    { field: "cruiseSpeed",     divisor: 100.0 },
    "ARSPD_FBW_MIN":    { field: "minSpeed",         divisor: 1.0   },
    "ARSPD_FBW_MAX":    { field: "maxSpeed",         divisor: 1.0   },
    "ROLL_LIMIT_DEG":   { field: "maxBankAngle",     divisor: 1.0   },
    "TECS_CLMB_MAX":    { field: "maxClimbRate",     divisor: 1.0   },
    "TECS_SINK_MAX":    { field: "maxDescentRate",    divisor: 1.0   },
    "ALT_MAX":          { field: "maxAltitude",       divisor: 1.0   },
    "WP_RADIUS":        { field: "wpAcceptanceRadius", divisor: 1.0  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  readArduPilotParams(vehicle)
//  Reads relevant parameters from the connected vehicle.
//  Returns an object with converted values, or empty object if not connected.
// ─────────────────────────────────────────────────────────────────────────────
function readArduPilotParams(vehicle) {
    var params = {}

    if (!vehicle || !vehicle.parameterManager) {
        return params
    }

    var paramNames = Object.keys(_parameterMap)
    for (var i = 0; i < paramNames.length; i++) {
        var paramName = paramNames[i]
        var mapping = _parameterMap[paramName]

        try {
            var fact = vehicle.parameterManager.getParameter(-1, paramName)
            if (fact && fact.rawValue !== undefined && !isNaN(fact.rawValue)) {
                params[mapping.field] = fact.rawValue / mapping.divisor
                params[mapping.field + "_source"] = paramName
                params[mapping.field + "_raw"] = fact.rawValue
            }
        } catch (e) {
            // Parameter not available — skip silently
        }
    }

    return params
}

// ─────────────────────────────────────────────────────────────────────────────
//  parseParamText(text)
//  Parses a .param file content (format: "PARAM_NAME,VALUE" per line)
//  Returns an object with converted values matching the field names
//  used by resolve().
// ─────────────────────────────────────────────────────────────────────────────
function parseParamText(text) {
    var params = {}
    if (!text) return params

    var lines = text.split('\n')
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === '' || line.charAt(0) === '#') continue

        var comma = line.indexOf(',')
        if (comma < 0) continue

        var paramName = line.substring(0, comma).trim()
        var paramValue = parseFloat(line.substring(comma + 1).trim())
        if (isNaN(paramValue)) continue

        // Map to internal field names
        var mapping = _parameterMap[paramName]
        if (mapping) {
            params[mapping.field] = paramValue / mapping.divisor
            params[mapping.field + "_source"] = paramName
            params[mapping.field + "_raw"] = paramValue
        }

        // Store ALL params for display (not just mapped ones)
        params["_raw_" + paramName] = paramValue
    }

    return params
}

// ─────────────────────────────────────────────────────────────────────────────
//  resolveFromParamText(paramText)
//  Convenience: parse .param file text and resolve against aircraft config.
//  Used when no vehicle is connected (offline planning with a .param file).
// ─────────────────────────────────────────────────────────────────────────────
function resolveFromParamText(paramText) {
    var ap = parseParamText(paramText)
    return resolve(_defaultAircraftConfig, ap)
}

// ─────────────────────────────────────────────────────────────────────────────
//  getParamStatus(parsedParams, vehicle)
//  Returns before/after comparison.
//  "Before" = current vehicle value (or default if not connected).
//  "After"  = value from .param file (or default if not in file).
// ─────────────────────────────────────────────────────────────────────────────
function getParamStatus(parsedParams, vehicle) {
    var critical = [
        { param: "TRIM_ARSPD_CM",  field: "cruiseSpeed",    label: "Cruise Speed",      unit: "m/s",  defaultVal: _defaultAircraftConfig.cruiseSpeed,    divisor: 100 },
        { param: "ARSPD_FBW_MIN",  field: "minSpeed",       label: "Min Speed",         unit: "m/s",  defaultVal: _defaultAircraftConfig.stallSpeed,     divisor: 1 },
        { param: "ARSPD_FBW_MAX",  field: "maxSpeed",       label: "Max Speed",         unit: "m/s",  defaultVal: _defaultAircraftConfig.maxSpeed,       divisor: 1 },
        { param: "ROLL_LIMIT_DEG", field: "maxBankAngle",   label: "Max Bank Angle",    unit: "°",    defaultVal: _defaultAircraftConfig.maxBankAngle,   divisor: 1 },
        { param: "TECS_CLMB_MAX",  field: "maxClimbRate",   label: "Max Climb Rate",    unit: "m/s",  defaultVal: _defaultAircraftConfig.maxClimbRate,   divisor: 1 },
        { param: "TECS_SINK_MAX",  field: "maxDescentRate",  label: "Max Descent Rate",  unit: "m/s",  defaultVal: _defaultAircraftConfig.maxDescentRate, divisor: 1 },
        { param: "ALT_MAX",        field: "maxAltitude",     label: "Max Altitude",      unit: "m",    defaultVal: _defaultAircraftConfig.maxAltitude,    divisor: 1 },
        { param: "WP_RADIUS",      field: "wpAcceptanceRadius", label: "WP Radius",      unit: "m",    defaultVal: 30,                                   divisor: 1 }
    ]

    var result = []
    for (var i = 0; i < critical.length; i++) {
        var c = critical[i]

        // ── Read "Before" from connected vehicle ──
        var vehicleVal = c.defaultVal
        var vehicleSource = "default"
        if (vehicle && vehicle.parameterManager) {
            try {
                var fact = vehicle.parameterManager.getParameter(-1, c.param)
                if (fact && fact.rawValue !== undefined && !isNaN(fact.rawValue)) {
                    vehicleVal = fact.rawValue / c.divisor
                    vehicleSource = "vehicle"
                }
            } catch (e) { }
        }

        // ── Read "After" from .param file ──
        var fileFound = parsedParams && parsedParams[c.field] !== undefined
        var fileVal = fileFound ? parsedParams[c.field] : vehicleVal

        // ── Detect change ──
        var changed = fileFound && (Math.abs(fileVal - vehicleVal) > 0.01)

        result.push({
            param:          c.param,
            label:          c.label,
            unit:           c.unit,
            found:          fileFound,
            oldValue:       vehicleVal,
            oldSource:      vehicleSource,
            newValue:       fileVal,
            changed:        changed,
            source:         fileFound ? c.param : vehicleSource,
            isDefault:      !fileFound && vehicleSource === "default",
            rawParamValue:  fileFound ? parsedParams["_raw_" + c.param] : undefined
        })
    }
    return result
}

// ─────────────────────────────────────────────────────────────────────────────
//  uploadParamsToVehicle(parsedParams, vehicle)
//  Writes .param file values to the connected vehicle.
//  Returns an array of { param, oldValue, newValue, success } for each write.
// ─────────────────────────────────────────────────────────────────────────────
function uploadParamsToVehicle(parsedParams, vehicle) {
    if (!vehicle || !vehicle.parameterManager || !parsedParams) return []

    var results = []
    var paramNames = Object.keys(parsedParams)

    for (var i = 0; i < paramNames.length; i++) {
        var key = paramNames[i]
        // Skip internal keys (prefixed with _raw_)
        if (key.startsWith("_raw_") || key.endsWith("_source") || key.endsWith("_raw")) continue

        // Find the ArduPilot param name from the field name
        var apName = null
        var apKeys = Object.keys(_parameterMap)
        for (var j = 0; j < apKeys.length; j++) {
            if (_parameterMap[apKeys[j]].field === key) {
                apName = apKeys[j]
                break
            }
        }
        if (!apName) continue

        // Get raw value from parsed params
        var rawVal = parsedParams["_raw_" + apName]
        if (rawVal === undefined) continue

        try {
            var fact = vehicle.parameterManager.getParameter(-1, apName)
            if (fact) {
                var oldVal = fact.rawValue
                fact.rawValue = rawVal
                results.push({
                    param:      apName,
                    oldValue:   oldVal,
                    newValue:   rawVal,
                    success:    true
                })
            }
        } catch (e) {
            results.push({
                param:      apName,
                oldValue:   0,
                newValue:   rawVal,
                success:    false,
                error:      e.toString()
            })
        }
    }

    return results
}

// ─────────────────────────────────────────────────────────────────────────────
//  getAllParamsFromFile(paramText)
//  Returns ALL parameters from a .param file (not just mapped ones).
//  Used for uploading all params to vehicle.
// ─────────────────────────────────────────────────────────────────────────────
function getAllParamsFromFile(paramText) {
    var params = []
    if (!paramText) return params

    var lines = paramText.split('\n')
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === '' || line.charAt(0) === '#') continue
        var comma = line.indexOf(',')
        if (comma < 0) continue
        var name = line.substring(0, comma).trim()
        var value = parseFloat(line.substring(comma + 1).trim())
        if (!isNaN(value)) {
            params.push({ param: name, value: value })
        }
    }
    return params
}

// ─────────────────────────────────────────────────────────────────────────────
//  uploadAllParamsToVehicle(paramText, vehicle)
//  Writes ALL parameters from .param file to vehicle.
//  Returns before/after report.
// ─────────────────────────────────────────────────────────────────────────────
function uploadAllParamsToVehicle(paramText, vehicle) {
    if (!vehicle || !vehicle.parameterManager || !paramText) return []

    var allParams = getAllParamsFromFile(paramText)
    var results = []

    for (var i = 0; i < allParams.length; i++) {
        var p = allParams[i]
        try {
            var fact = vehicle.parameterManager.getParameter(-1, p.param)
            if (fact) {
                var oldVal = fact.rawValue
                var changed = Math.abs(oldVal - p.value) > 0.001
                if (changed) {
                    fact.rawValue = p.value
                }
                results.push({
                    param:      p.param,
                    oldValue:   oldVal,
                    newValue:   p.value,
                    changed:    changed,
                    success:    true
                })
            }
        } catch (e) {
            results.push({
                param:      p.param,
                oldValue:   0,
                newValue:   p.value,
                changed:    true,
                success:    false
            })
        }
    }

    return results
}

// ─────────────────────────────────────────────────────────────────────────────
//  resolve(aircraftConfig, arduPilotParams)
//
//  Merges two sources into EffectiveLimits.
//  Rule: MOST RESTRICTIVE always wins.
//
//  For "maximum" limits: use the SMALLER value    (min of two)
//  For "minimum" limits: use the LARGER value     (max of two)
//
//  Each resolved limit records its source for the engineering report.
// ─────────────────────────────────────────────────────────────────────────────
function resolve(aircraftConfig, arduPilotParams) {

    var ac = aircraftConfig || _defaultAircraftConfig
    var ap = arduPilotParams || {}

    var limits = {
        // ── Resolved values ──
        cruiseSpeed:        0,
        stallSpeed:         0,
        minSpeed:           0,
        maxSpeed:           0,
        maxBankAngle:       0,
        maxClimbRate:       0,
        maxDescentRate:     0,
        maxAltitude:        0,
        minWaypointSpacing: 0,
        wpAcceptanceRadius: 0,

        // ── Source tracking ──
        sources: {},

        // ── Warnings (when a param is missing) ──
        warnings: []
    }

    // ── Helper: resolve a "maximum" limit (smaller wins) ──
    function resolveMax(fieldName, acValue, apValue, apParamName) {
        if (apValue !== undefined && !isNaN(apValue) && apValue > 0) {
            if (acValue > 0) {
                limits[fieldName] = Math.min(acValue, apValue)
                limits.sources[fieldName] = (apValue <= acValue) ? apParamName : "aircraft_config"
            } else {
                limits[fieldName] = apValue
                limits.sources[fieldName] = apParamName
            }
        } else if (acValue > 0) {
            limits[fieldName] = acValue
            limits.sources[fieldName] = "aircraft_config"
            if (apParamName) {
                limits.warnings.push(apParamName + " unavailable — using aircraft limit only")
            }
        }
    }

    // ── Helper: resolve a "minimum" limit (larger wins) ──
    function resolveMin(fieldName, acValue, apValue, apParamName) {
        if (apValue !== undefined && !isNaN(apValue) && apValue > 0) {
            if (acValue > 0) {
                limits[fieldName] = Math.max(acValue, apValue)
                limits.sources[fieldName] = (apValue >= acValue) ? apParamName : "aircraft_config"
            } else {
                limits[fieldName] = apValue
                limits.sources[fieldName] = apParamName
            }
        } else if (acValue > 0) {
            limits[fieldName] = acValue
            limits.sources[fieldName] = "aircraft_config"
        }
    }

    // ── Resolve each limit ──

    // Cruise speed: most restrictive max
    resolveMax("cruiseSpeed", ac.cruiseSpeed || 0, ap.cruiseSpeed, "TRIM_ARSPD_CM")

    // Stall speed: from aircraft only (ArduPilot doesn't have a direct stall param)
    limits.stallSpeed = ac.stallSpeed || 0
    limits.sources.stallSpeed = "aircraft_config"

    // Min speed: most restrictive min (higher wins = more restrictive)
    resolveMin("minSpeed", ac.stallSpeed || 0, ap.minSpeed, "ARSPD_FBW_MIN")

    // Max speed: most restrictive max (lower wins)
    resolveMax("maxSpeed", ac.maxSpeed || 0, ap.maxSpeed, "ARSPD_FBW_MAX")

    // Max bank angle: most restrictive (lower wins)
    resolveMax("maxBankAngle", ac.maxBankAngle || 0, ap.maxBankAngle, "ROLL_LIMIT_DEG")

    // Max climb rate: most restrictive (lower wins)
    resolveMax("maxClimbRate", ac.maxClimbRate || 0, ap.maxClimbRate, "TECS_CLMB_MAX")

    // Max descent rate: most restrictive (lower wins)
    resolveMax("maxDescentRate", ac.maxDescentRate || 0, ap.maxDescentRate, "TECS_SINK_MAX")

    // Max altitude: most restrictive (lower wins)
    resolveMax("maxAltitude", ac.maxAltitude || 0, ap.maxAltitude, "ALT_MAX")

    // Min waypoint spacing: from aircraft config only
    limits.minWaypointSpacing = ac.minWaypointSpacing || 20.0
    limits.sources.minWaypointSpacing = "aircraft_config"

    // WP acceptance radius: from ArduPilot only
    limits.wpAcceptanceRadius = ap.wpAcceptanceRadius || 30.0
    limits.sources.wpAcceptanceRadius = ap.wpAcceptanceRadius ? "WP_RADIUS" : "default"

    return limits
}

// ─────────────────────────────────────────────────────────────────────────────
//  resolveFromVehicle(vehicle)
//
//  Convenience function: reads ArduPilot params from vehicle and resolves.
//  If vehicle is null/disconnected, uses aircraft config only.
// ─────────────────────────────────────────────────────────────────────────────
function resolveFromVehicle(vehicle) {
    var ap = readArduPilotParams(vehicle)
    return resolve(_defaultAircraftConfig, ap)
}

// ─────────────────────────────────────────────────────────────────────────────
//  getDefaultAircraftConfig()
//  Returns a copy of the default aircraft config for reference/display.
// ─────────────────────────────────────────────────────────────────────────────
function getDefaultAircraftConfig() {
    return JSON.parse(JSON.stringify(_defaultAircraftConfig))
}

// ─────────────────────────────────────────────────────────────────────────────
//  setAircraftConfig(config)
//  Updates the aircraft config. Call once when aircraft type changes.
// ─────────────────────────────────────────────────────────────────────────────
function setAircraftConfig(config) {
    if (!config) return
    var fields = Object.keys(_defaultAircraftConfig)
    for (var i = 0; i < fields.length; i++) {
        var f = fields[i]
        if (config[f] !== undefined && !isNaN(config[f])) {
            _defaultAircraftConfig[f] = config[f]
        }
    }
}
