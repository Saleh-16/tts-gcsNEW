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
//  DEFAULT AIRCRAFT CONFIG — TTS GROUP measured values (July 2026)
//
//  These are the MOST RESTRICTIVE options from flight data analysis.
//  Choosing the most restrictive = maximum warnings = minimum liability.
//  If the system warns and the operator ignores → operator's responsibility.
//  If the system doesn't warn and something fails → our responsibility.
//
//  Source:  Flight log analysis (BIN dataflash), confidence noted per value.
//  Policy:  Conservative values chosen deliberately — see SDD ED-04.
// ─────────────────────────────────────────────────────────────────────────────
var _defaultAircraftConfig = {
    cruiseSpeed:        32.5,   // m/s  — option C (highest from logs → largest turn radius → most warnings)    [confirmed]
    stallSpeed:         19.6,   // m/s  — option C (highest safety margin → narrowest speed envelope)            [estimated]
    maxSpeed:           39.0,   // m/s  — option C (lowest ceiling → most restrictive)                          [estimated]
    maxBankAngle:       28.0,   // deg  — option B (max observed in flight → realistic, not theoretical 45°)    [estimated]
    maxClimbRate:        2.9,   // m/s  — option C (lowest capability → catches more steep climbs)              [confirmed]
    maxDescentRate:      1.8,   // m/s  — option C (lowest safe rate → catches more steep descents)             [confirmed]
    maxAltitude:       144.0,   // m    — option C (lowest ceiling above home → catches more altitude violations)[confirmed]
    minWaypointSpacing: 40.0    // m    — option B (largest minimum → catches more close-spacing issues)        [estimated]
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
        }
    }
    return params
}

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
        var mapping = _parameterMap[paramName]
        if (mapping) {
            params[mapping.field] = paramValue / mapping.divisor
            params[mapping.field + "_source"] = paramName
            params[mapping.field + "_raw"] = paramValue
        }
        params["_raw_" + paramName] = paramValue
    }
    return params
}

function resolveFromParamText(paramText) {
    var ap = parseParamText(paramText)
    return resolve(_defaultAircraftConfig, ap)
}

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
        var fileFound = parsedParams && parsedParams[c.field] !== undefined
        var fileVal = fileFound ? parsedParams[c.field] : vehicleVal
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

function uploadParamsToVehicle(parsedParams, vehicle) {
    if (!vehicle || !vehicle.parameterManager || !parsedParams) return []
    var results = []
    var paramNames = Object.keys(parsedParams)
    for (var i = 0; i < paramNames.length; i++) {
        var key = paramNames[i]
        if (key.startsWith("_raw_") || key.endsWith("_source") || key.endsWith("_raw")) continue
        var apName = null
        var apKeys = Object.keys(_parameterMap)
        for (var j = 0; j < apKeys.length; j++) {
            if (_parameterMap[apKeys[j]].field === key) {
                apName = apKeys[j]
                break
            }
        }
        if (!apName) continue
        var rawVal = parsedParams["_raw_" + apName]
        if (rawVal === undefined) continue
        try {
            var fact = vehicle.parameterManager.getParameter(-1, apName)
            if (fact) {
                var oldVal = fact.rawValue
                fact.rawValue = rawVal
                results.push({ param: apName, oldValue: oldVal, newValue: rawVal, success: true })
            }
        } catch (e) {
            results.push({ param: apName, oldValue: 0, newValue: rawVal, success: false, error: e.toString() })
        }
    }
    return results
}

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
                results.push({ param: p.param, oldValue: oldVal, newValue: p.value, changed: changed, success: true })
            }
        } catch (e) {
            results.push({ param: p.param, oldValue: 0, newValue: p.value, changed: true, success: false })
        }
    }
    return results
}

function resolve(aircraftConfig, arduPilotParams) {
    var ac = aircraftConfig || _defaultAircraftConfig
    var ap = arduPilotParams || {}
    var limits = {
        cruiseSpeed: 0, stallSpeed: 0, minSpeed: 0, maxSpeed: 0,
        maxBankAngle: 0, maxClimbRate: 0, maxDescentRate: 0,
        maxAltitude: 0, minWaypointSpacing: 0, wpAcceptanceRadius: 0,
        sources: {}, warnings: []
    }
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
    resolveMax("cruiseSpeed", ac.cruiseSpeed || 0, ap.cruiseSpeed, "TRIM_ARSPD_CM")
    limits.stallSpeed = ac.stallSpeed || 0
    limits.sources.stallSpeed = "aircraft_config"
    resolveMin("minSpeed", ac.stallSpeed || 0, ap.minSpeed, "ARSPD_FBW_MIN")
    resolveMax("maxSpeed", ac.maxSpeed || 0, ap.maxSpeed, "ARSPD_FBW_MAX")
    resolveMax("maxBankAngle", ac.maxBankAngle || 0, ap.maxBankAngle, "ROLL_LIMIT_DEG")
    resolveMax("maxClimbRate", ac.maxClimbRate || 0, ap.maxClimbRate, "TECS_CLMB_MAX")
    resolveMax("maxDescentRate", ac.maxDescentRate || 0, ap.maxDescentRate, "TECS_SINK_MAX")
    resolveMax("maxAltitude", ac.maxAltitude || 0, ap.maxAltitude, "ALT_MAX")
    limits.minWaypointSpacing = ac.minWaypointSpacing || 20.0
    limits.sources.minWaypointSpacing = "aircraft_config"
    limits.wpAcceptanceRadius = ap.wpAcceptanceRadius || 30.0
    limits.sources.wpAcceptanceRadius = ap.wpAcceptanceRadius ? "WP_RADIUS" : "default"
    return limits
}

function resolveFromVehicle(vehicle) {
    var ap = readArduPilotParams(vehicle)
    return resolve(_defaultAircraftConfig, ap)
}

function getDefaultAircraftConfig() {
    return JSON.parse(JSON.stringify(_defaultAircraftConfig))
}

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