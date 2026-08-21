/****************************************************************************
 *
 * (c) 2009-2026 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QtCore
/// Pre-Flight Inspection — popup opened from the sidebar "PFI" button.
///
/// Five collapsible cards:
///   0. Identification         — aircraft serial (fixed "M X-X" format,
///                                1-2 digits per part) + operator name.
///                                REQUIRED before the control surface test
///                                or DONE/CONFIRM can proceed.
///   1. Automatic Checks       — 6 live vehicle checks (Battery, GPS, Compass,
///                                EKF, Vibration, Mission). Telemetry is
///                                temporarily disabled (commented out) — may
///                                be re-enabled later. Battery is judged by
///                                VOLTAGE (not ArduPilot's percentage, which
///                                assumes a full pack at every boot) and
///                                reads BOTH packs when a second one is
///                                connected; the worst of the two decides.
///   2. Control Surface Test   — RC_CHANNELS_OVERRIDE driven. Operator picks
///                                Automatic (runs all 4 steps unattended,
///                                waiting between each) or Manual (Run /
///                                Retry / Back / Next per step). Reads elevon
///                                servo assignment, RC channel mapping and
///                                stick calibration from the vehicle itself;
///                                nothing is hardcoded. Supports airframes
///                                with MULTIPLE servos per side (e.g. dual
///                                redundant elevon actuators) — every servo
///                                matching SERVOx_FUNCTION 77/78 is detected,
///                                and ALL of them on a given side must move
///                                for that side to count as passing (strict
///                                AND), so a single failed servo isn't masked
///                                by a working twin.
///   3. Manual Checklist       — 5 operator confirmations
///   4. Inspection Summary     — go / no-go banner, DONE / fly-at-own-risk
///
/// On DONE (or CONFIRM, for the fly-at-own-risk path) the inspection report
/// is silently saved via the global fileWriter context property (the same
/// proven pattern already used elsewhere in the app for Risk Report saves —
/// see MissionReviewPanel.qml). The operator sees nothing about the save
/// itself — the file exists purely for auditing and compliance.
///
/// Save location: QGroundControl.settingsManager.appSettings.logSavePath
/// — QGC's own fixed log-save folder, used consistently across the app for
/// onboard/application logs. This avoids all StandardPaths/toLocalFile
/// platform-portability issues entirely, since this setting is already
/// guaranteed to resolve correctly on every platform QGC runs on (Linux,
/// Windows, macOS).
Column {
    id: control
    property int  sectionIndex: 9
    property bool expanded:     false
    property var  planMasterController: null
    readonly property alias controller: inspectionController
    spacing: 0
    /// Emitted when the operator confirms DONE. The host (MainWindow's popup
    /// dialog) closes the window in response to this.
    signal inspectionCompleted()
    readonly property real _pad: ScreenTools.defaultFontPixelWidth
    readonly property int _checkColumns:
        Math.max(1, Math.floor(width / (ScreenTools.defaultFontPixelWidth * 46)))
    QGCPalette { id: qgcPal }
    // FactPanelController captures the active vehicle once in its constructor.
    // The Loader rebuilds it whenever the active vehicle changes, so the
    // controller always holds the vehicle that is actually connected rather
    // than latching onto the offline placeholder.
    Loader {
        id:              paramControllerLoader
        active:          inspectionController._ok
        sourceComponent: Component { FactPanelController {} }
        property var _vehicleWatch: QGroundControl.multiVehicleManager.activeVehicle
        on_VehicleWatchChanged: {
            active = false
            active = inspectionController._ok
        }
    }
    // ═══════════════════════════════════════════════════════════════════════
    //  CONTROLLER — all state and logic, no layout
    // ═══════════════════════════════════════════════════════════════════════
    QtObject {
        id: inspectionController
        readonly property var  _v:  QGroundControl.multiVehicleManager.activeVehicle
        readonly property bool _ok: _v !== null && _v !== undefined
        // ── Automatic check thresholds ────────────────────────────────────
        // Airframe decisions, not code decisions. Only the vibration figures
        // come from published ArduPilot guidance; tune the rest per aircraft.
        //
        // batteryMinVolts is a VOLTAGE threshold, not a percentage.
        // ArduPilot derives percentRemaining by subtracting consumed mAh
        // from BATT_CAPACITY starting at 100% on every boot — so a pack
        // that was only 66% charged when powered on still reports ~99%.
        // Voltage is measured directly and doesn't lie.
        //
        // 8.22V on a 2S LiPo (4.11V/cell) is roughly 90% state of charge.
        // For other pack sizes: 3S = 12.33, 4S = 16.44, 6S = 24.66
        property real batteryMinVolts: 8
        property int  gpsMinSats:     10
        property real gpsMaxHdop:     1.5
        property real vibeWarnMs2:    30      // ArduPilot: <30 good, >60 bad
        property real vibeFailMs2:    60
        property int  rssiWarnDbm:    -90
        // ── Models ────────────────────────────────────────────────────────
        readonly property ListModel automaticChecks: ListModel {
            ListElement { name: qsTr("Battery");   iconSource: "/qmlimages/Battery.svg";    status: 0; detail: "" }
            ListElement { name: qsTr("GPS");       iconSource: "/qmlimages/Gps.svg";        status: 0; detail: "" }
            ListElement { name: qsTr("Compass");   iconSource: "/qmlimages/Compass.svg";    status: 0; detail: "" }
            ListElement { name: qsTr("EKF");       iconSource: "/qmlimages/PaperPlane.svg"; status: 0; detail: "" }
            ListElement { name: qsTr("Vibration"); iconSource: "/qmlimages/Vibration.svg";  status: 0; detail: "" }
           // ListElement { name: qsTr("Telemetry"); iconSource: "/qmlimages/Antenna.svg";    status: 0; detail: "" }
            ListElement { name: qsTr("Mission");   iconSource: "/qmlimages/Plan.svg";       status: 0; detail: "" }
        }
        readonly property ListModel manualChecklist: ListModel {
            ListElement { label: qsTr("Pushrod connected"); checked: false; mandatory: true }
            ListElement { label: qsTr("Fins Locked");        checked: false; mandatory: true }
            ListElement { label: qsTr("Payload Secured");     checked: false; mandatory: true }
            ListElement { label: qsTr("Battery Secured");     checked: false; mandatory: true }
            ListElement { label: qsTr("ESAD Connected");      checked: false; mandatory: true }
        }
        // Elevon test steps. ch1/ch2 start at 0 and are populated at runtime
        // by populateStepValues() from the vehicle's own RC calibration and
        // RCMAP settings — no hardcoded PWM values.
        readonly property ListModel elevonSteps: ListModel {
            ListElement {
                title:       qsTr("Pitch Up")
                instruction: qsTr("Both elevons deflect UPWARDS by an equal amount.")
                status:      0; ch1: 0; ch2: 0
            }
            ListElement {
                title:       qsTr("Pitch Down")
                instruction: qsTr("Both elevons deflect DOWNWARDS by an equal amount.")
                status:      0; ch1: 0; ch2: 0
            }
            ListElement {
                title:       qsTr("Roll Left")
                instruction: qsTr("Left elevon UP, right elevon DOWN.")
                status:      0; ch1: 0; ch2: 0
            }
            ListElement {
                title:       qsTr("Roll Right")
                instruction: qsTr("Right elevon UP, left elevon DOWN.")
                status:      0; ch1: 0; ch2: 0
            }
        }
        // ── Aggregation ───────────────────────────────────────────────────
        property int  automaticStatus:      PreFlightStatus.Pending
        property int  controlSurfaceStatus: PreFlightStatus.Pending
        property int  manualStatus:         PreFlightStatus.Pending
        property bool   controlSurfaceTestStarted: false
        property bool   hazardAcknowledged:        false
        property string testMessage:               ""
        property int    testMessageLevel:          PreFlightStatus.Pass
        // DONE / fly-at-own-risk state
        property bool flyAtOwnRisk:     false
        property bool riskAcknowledged: false
        property bool inspectionDone:   false
        /// Two digit groups (1-2 digits each) typed by the operator; combined
        /// into the fixed "M X-X" aircraft serial format. Each part accepts
        /// 1 or 2 digits — e.g. "M 1-10" or "M 10-1" are both valid.
        /// vehicleSerial itself is derived, never typed directly.
        property string _serialPart1: ""
        property string _serialPart2: ""
        /// Derived fixed-format aircraft serial, e.g. "M 1-10".
        /// REQUIRED (both parts non-empty) before running the control
        /// surface test or completing the inspection (DONE / CONFIRM).
        /// Embedded in the saved report's filename and body.
        property string vehicleSerial: ""
        function _updateVehicleSerial() {
            vehicleSerial = "M " + _serialPart1 + "-" + _serialPart2
        }
        /// Operator-entered name, REQUIRED for accountability before the
        /// control surface test or DONE / CONFIRM can proceed.
        property string operatorName: ""
        // ── Auto-detected elevon servo numbers (from SERVOn_FUNCTION 77/78)
        //    ─────────────────────────────────────────────────────────────
        //    Arrays, not single numbers: an airframe may have more than one
        //    servo assigned to the same side (e.g. dual redundant elevon
        //    actuators). Every matching SERVOx_FUNCTION is collected, not
        //    just the first one found.
        property var detectedLeftServos:  []   // e.g. [1] or [1, 5]
        property var detectedRightServos: []   // e.g. [2] or [2, 6]
        readonly property int overallStatus:
            PreFlightStatus.worst(PreFlightStatus.worst(automaticStatus, controlSurfaceStatus), manualStatus)
        // Judged from the three group results directly, not from
        // overallStatus: worst() ranks Warn above Pending, so a battery
        // advisory would otherwise mask an unticked manual checklist.
        readonly property bool readyForFlight:
            PreFlightStatus.isReadyFromGroups(automaticStatus, controlSurfaceStatus, manualStatus)
        /// True once both serial number parts and the operator name are
        /// filled in. Gates the control surface test start button and the
        /// DONE/CONFIRM buttons.
        readonly property bool identificationComplete:
            _serialPart1.length >= 1 && _serialPart2.length >= 1 && operatorName.trim() !== ""
        // ── RC channel mapping — read from vehicle, never hardcoded ───────
        //
        // ArduPilot's RCMAP parameters define which physical RC channel
        // carries each axis. The default is 1=Roll 2=Pitch, but many
        // airframes swap them. sendRcOverride(ch1, ch2) always sends on
        // physical channels 1 and 2, so the value must be placed on the
        // correct physical channel, not the axis name.
        property int  rcPitchChannel: 2   // default, overwritten by RCMAP_PITCH
        property int  rcRollChannel:  1   // default, overwritten by RCMAP_ROLL
        /// Fraction of stick travel used for the test (0.0–1.0). 0.70 gives a
        /// clearly visible deflection without hitting servo limits.
        property real testDeflection: 0.70
        // Computed from the vehicle's own RC calibration (RCn_TRIM/MIN/MAX).
        property int pitchTrim: 1500
        property int pitchHigh: 1750
        property int pitchLow:  1250
        property int rollTrim:  1500
        property int rollHigh:  1750
        property int rollLow:   1250
        // ── Helpers ───────────────────────────────────────────────────────
        /// Evaluates fn() and swallows any error from a Fact path that does
        /// not exist on this firmware, so one bad source degrades one row
        /// instead of blanking the page.
        function _try(fn) {
            try { return fn() } catch (e) { return undefined }
        }
        function _isNum(v) {
            return v !== undefined && v !== null && !isNaN(v)
        }
        function _result(status, detail) {
            return { "status": status, "detail": detail }
        }
        function _noVehicle() { return _result(PreFlightStatus.Pending, qsTr("No vehicle")) }
        function _noSource()  { return _result(PreFlightStatus.Pending, qsTr("Source unavailable")) }
        function _apply(index, res) {
            automaticChecks.setProperty(index, "status", res.status)
            automaticChecks.setProperty(index, "detail", res.detail)
        }
        /// Parameter access through the Loader-managed FactPanelController.
        /// ParameterManager exposes no QML-callable getter of its own.
        function _paramFact(name) {
            var c = paramControllerLoader.item
            if (!c) return undefined
            return _try(function() { return c.getParameterFact(-1, name, false) })
        }
        /// Live PWM value from SERVO_OUTPUT_RAW (requires the servoOutputs
        /// Q_PROPERTY added to Vehicle.h).
        function _servoOutput(servoNumber) {
            var arr = _try(function() { return _v.servoOutputs })
            if (!arr || servoNumber < 1 || servoNumber > arr.length) return -1
            return arr[servoNumber - 1]
        }
        // ── Battery ───────────────────────────────────────────────────────
        // QGC moved from vehicle.battery to vehicle.batteries.get(0).
        function _batteryGroup() {
            var b = _try(function() { return _v.batteries.get(0) })
            return b ? b : _try(function() { return _v.battery })
        }
        /// Judges state of charge by VOLTAGE rather than percentRemaining.
        /// ArduPilot computes its percentage by subtracting consumed mAh
        /// from BATT_CAPACITY starting at 100% every boot — so a pack that
        /// was only 66% charged when powered on still reports ~99%.
        /// Voltage is measured directly by the power module and reflects
        /// the real state of charge.
        ///
        /// Reads both batteries when a second is present; the worst pack
        /// decides the overall status — a full Battery 1 can't mask a low
        /// Battery 2 (or vice versa). Airframes with one battery fall back
        /// to single-pack behavior automatically.
        ///
        /// NOTE: Battery 2 requires BATT2_MONITOR != 0 AND non-zero
        /// BATT2_LOW_VOLT / BATT2_CRT_VOLT — with zero thresholds ArduPilot
        /// rejects the reading as unhealthy and the pack never appears here.
        function _checkBattery() {
            if (!_ok) return _noVehicle()
            var b1 = _try(function() { return _v.batteries.get(0) })
            if (!b1) return _noSource()
            var volt1 = _try(function() { return b1.voltage.rawValue })
            if (!_isNum(volt1) || volt1 <= 0) return _noSource()
            var b2 = _try(function() { return _v.batteries.get(1) })
            if (b2) {
                var volt2 = _try(function() { return b2.voltage.rawValue })
                if (_isNum(volt2) && volt2 > 0) {
                    var worstVolt = Math.min(volt1, volt2)
                    var status2   = worstVolt < batteryMinVolts ? PreFlightStatus.Fail : PreFlightStatus.Pass
                    var detail2   = "B1: " + volt1.toFixed(2) + "V  \u00B7  B2: " + volt2.toFixed(2) + "V"
                    return _result(status2, detail2)
                }
            }
            // Single-battery fallback.
            var status = volt1 < batteryMinVolts ? PreFlightStatus.Fail : PreFlightStatus.Pass
            var detail = volt1.toFixed(2) + "V"
            return _result(status, detail)
        }
        // ── GPS ───────────────────────────────────────────────────────────
        function _checkGps() {
            if (!_ok) return _noVehicle()
            var lock = _try(function() { return _v.gps.lock.rawValue })
            var sats = _try(function() { return _v.gps.count.rawValue })
            var hdop = _try(function() { return _v.gps.hdop.rawValue })
            if (!_isNum(lock)) return _noSource()
            if (lock < 3) return _result(PreFlightStatus.Fail, qsTr("No 3D fix"))
            var status = PreFlightStatus.Pass
            if (_isNum(sats) && sats < gpsMinSats) status = PreFlightStatus.Warn
            if (_isNum(hdop) && hdop > gpsMaxHdop) status = PreFlightStatus.Warn
            var fixText = lock >= 6 ? qsTr("RTK Fixed") : lock >= 5 ? qsTr("RTK Float")
                        : lock >= 4 ? qsTr("DGPS") : qsTr("3D Fix")
            var detail = fixText
            if (_isNum(sats)) detail += "  \u00B7  " + sats + qsTr(" sats")
            if (_isNum(hdop)) detail += "  \u00B7  HDOP " + hdop.toFixed(1)
            return _result(status, detail)
        }
        // ── SYS_STATUS health bits ────────────────────────────────────────
        // CONFIRMED: SysStatusSensorInfo.h exposes sensorNames/sensorStatus
        // as QStringList; status strings are "Normal"/"Disabled"/"Error".
        function _sensorHealth(nameFragment) {
            var names  = _try(function() { return _v.sysStatusSensorInfo.sensorNames })
            var states = _try(function() { return _v.sysStatusSensorInfo.sensorStatus })
            if (!names || !states) return undefined
            var needle = nameFragment.toLowerCase()
            for (var i = 0; i < names.length && i < states.length; ++i) {
                if (names[i].toLowerCase().indexOf(needle) !== -1)
                    return { "name": names[i], "state": states[i] }
            }
            return undefined
        }
        function _checkFromSensorHealth(nameFragment) {
            if (!_ok) return _noVehicle()
            var s = _sensorHealth(nameFragment)
            if (!s) return _noSource()
            var state = s.state.toLowerCase()
            if (state.indexOf("error") !== -1) return _result(PreFlightStatus.Fail, s.state)
            if (state.indexOf("disabled") !== -1) return _result(PreFlightStatus.Warn, s.state)
            return _result(PreFlightStatus.Pass, s.state)
        }
        function _checkCompass() { return _checkFromSensorHealth("mag") }
        // ── EKF ───────────────────────────────────────────────────────────
        // SYS_STATUS (AHRS bit) is tried first because it always arrives.
        // ESTIMATOR_STATUS Facts default to false when the message is not
        // streamed at all, which looks identical to a genuinely bad estimate
        // — a permanent false FAIL that would block every flight.
        function _checkEkf() {
            if (!_ok) return _noVehicle()
            var health = _checkFromSensorHealth("ahrs")
            if (health.status !== PreFlightStatus.Pending) return health
            var goodAtt = _try(function() { return _v.estimatorStatus.goodAttitudeEstimate.rawValue })
            if (goodAtt === undefined)
                goodAtt = _try(function() { return _v.estimatorStatus.goodAttitudeEsimate.rawValue }) // upstream typo
            var goodPos = _try(function() { return _v.estimatorStatus.goodHorizPosRelEstimate.rawValue })
            if (goodAtt === undefined || goodPos === undefined) return _noSource()
            if (!goodAtt && !goodPos) return _result(PreFlightStatus.Pending, qsTr("ESTIMATOR_STATUS not streamed"))
            if (!goodAtt) return _result(PreFlightStatus.Fail, qsTr("Attitude estimate not good"))
            if (!goodPos) return _result(PreFlightStatus.Warn, qsTr("Position estimate not good"))
            return _result(PreFlightStatus.Pass, qsTr("Estimates nominal"))
        }
        // ── Vibration ─────────────────────────────────────────────────────
        function _checkVibration() {
            if (!_ok) return _noVehicle()
            var x = _try(function() { return _v.vibration.xAxis.rawValue })
            var y = _try(function() { return _v.vibration.yAxis.rawValue })
            var z = _try(function() { return _v.vibration.zAxis.rawValue })
            if (!_isNum(x) || !_isNum(y) || !_isNum(z)) return _noSource()
            var worst = Math.max(x, Math.max(y, z))
            var status = worst > vibeFailMs2 ? PreFlightStatus.Fail
                       : worst > vibeWarnMs2 ? PreFlightStatus.Warn : PreFlightStatus.Pass
            return _result(status, qsTr("Peak %1 m/s\u00B2").arg(worst.toFixed(1)))
        }
        // ── Telemetry ─────────────────────────────────────────────────────
        // CONFIRMED: Vehicle.h → radioStatus group; RadioStatusFactGroup.h
        // exposes lrssi/rrssi in dBm.
        // Currently disabled (see automaticChecks list and evaluate()) but
        // kept here in case it's needed again later.
        function _checkTelemetry() {
            if (!_ok) return _noVehicle()
            var lost = _try(function() { return _v.vehicleLinkManager.communicationLost })
            if (lost === true) return _result(PreFlightStatus.Fail, qsTr("Communication lost"))
            var lrssi = _try(function() { return _v.radioStatus.lrssi.rawValue })
            var rrssi = _try(function() { return _v.radioStatus.rrssi.rawValue })
            if (!_isNum(lrssi) || lrssi === 0) return _result(PreFlightStatus.Pass, qsTr("Link up"))
            var worst = _isNum(rrssi) && rrssi !== 0 ? Math.min(lrssi, rrssi) : lrssi
            var status = worst < rssiWarnDbm ? PreFlightStatus.Warn : PreFlightStatus.Pass
            return _result(status, qsTr("RSSI %1 dBm").arg(worst.toFixed(0)))
        }
        // ── Mission ───────────────────────────────────────────────────────
        // CONFIRMED: PlanMasterController.h exposes containsItems and
        // dirtyForUpload as Q_PROPERTY. MissionManager itself exposes none.
        function _checkMission() {
            if (!_ok) return _noVehicle()
            var pmc = control.planMasterController
            if (!pmc) return _noSource()
            var hasItems = _try(function() { return pmc.containsItems })
            if (hasItems === false) return _result(PreFlightStatus.Fail, qsTr("No mission loaded"))
            if (hasItems === undefined) return _noSource()
            var unsent = _try(function() { return pmc.dirtyForUpload })
            if (unsent === true) return _result(PreFlightStatus.Warn, qsTr("Unsent changes \u2013 upload the plan"))
            return _result(PreFlightStatus.Pass, qsTr("Synced with vehicle"))
        }
        // ── Evaluate all automatic checks ─────────────────────────────────
        // Indices track the automaticChecks ListModel above: Battery(0),
        // GPS(1), Compass(2), EKF(3), Vibration(4), Mission(5). Telemetry
        // is skipped — see the commented-out ListElement and the commented
        // _apply(5, _checkTelemetry()) call below.
        function evaluate() {
            _apply(0, _checkBattery())
            _apply(1, _checkGps())
            _apply(2, _checkCompass())
            _apply(3, _checkEkf())
            _apply(4, _checkVibration())
          //  _apply(5, _checkTelemetry())
            _apply(5, _checkMission())
            recalculateAutomaticStatus()
        }
        function _rollUp(model) {
            var result = PreFlightStatus.Pass
            for (var i = 0; i < model.count; ++i)
                result = PreFlightStatus.worst(result, model.get(i).status)
            return result
        }
        function recalculateAutomaticStatus() { automaticStatus = _rollUp(automaticChecks) }
        function recalculateControlSurfaceStatus() {
            controlSurfaceStatus = controlSurfaceTestStarted ? _rollUp(elevonSteps) : PreFlightStatus.Pending
        }
        function recalculateManualStatus() {
            for (var i = 0; i < manualChecklist.count; ++i) {
                if (manualChecklist.get(i).mandatory && !manualChecklist.get(i).checked) {
                    manualStatus = PreFlightStatus.Pending; return
                }
            }
            manualStatus = PreFlightStatus.Pass
        }
        function setManualItemChecked(index, checked) {
            manualChecklist.setProperty(index, "checked", checked)
            recalculateManualStatus()
        }
        function setElevonStepStatus(index, status) {
            elevonSteps.setProperty(index, "status", status)
            recalculateControlSurfaceStatus()
        }
        // ═══════════════════════════════════════════════════════════════
        //  CONTROL SURFACE TEST — RC_CHANNELS_OVERRIDE
        // ═══════════════════════════════════════════════════════════════
        //
        // Tells the autopilot "pretend the stick moved." The autopilot does
        // the elevon mixing itself and drives the servos. No parameter is
        // written, no SERVOn_FUNCTION is touched, and ch3 (throttle) is
        // NEVER overridden — see Vehicle::sendRcOverride().
        //
        // ArduPilot's RC_OVERRIDE_TIMEOUT (default 3 s) auto-releases even
        // if QGC crashes mid-test.
        /// SAFEGUARD: never with a live propeller.
        function canRunElevonTest() {
            return _ok && _try(function() { return !_v.armed }) === true
        }
        /// Scans SERVO1–16_FUNCTION for ALL servos assigned to Elevon Left
        /// (77) and Elevon Right (78) — not just the first one found.
        /// Airframes with dual (or more) servos per surface — e.g.
        /// redundant elevon actuators — are fully supported: every matching
        /// servo number is collected into the corresponding array. Called
        /// once when the test starts — no hardcoded servo numbers.
        function detectElevons() {
            var left = []
            var right = []
            for (var i = 1; i <= 16; ++i) {
                var f = _paramFact("SERVO" + i + "_FUNCTION")
                if (!f) continue
                if (f.rawValue === 77) left.push(i)
                if (f.rawValue === 78) right.push(i)
            }
            detectedLeftServos  = left
            detectedRightServos = right
        }
        function elevonsDetected() {
            return detectedLeftServos.length > 0 && detectedRightServos.length > 0
        }
        /// Reads RCMAP_PITCH/ROLL to find which physical RC channel carries
        /// each axis, then reads RCn_TRIM/MIN/MAX to compute the override
        /// values. Called once when the test starts. All values come from
        /// the vehicle — nothing here is hardcoded.
        function readRcCalibration() {
            var mapPitch = _paramFact("RCMAP_PITCH")
            var mapRoll  = _paramFact("RCMAP_ROLL")
            if (mapPitch) rcPitchChannel = mapPitch.rawValue
            if (mapRoll)  rcRollChannel  = mapRoll.rawValue
            var pTrim = _paramFact("RC" + rcPitchChannel + "_TRIM")
            var pMin  = _paramFact("RC" + rcPitchChannel + "_MIN")
            var pMax  = _paramFact("RC" + rcPitchChannel + "_MAX")
            if (pTrim) pitchTrim = pTrim.rawValue
            if (pMin && pMax) {
                pitchHigh = Math.round(pitchTrim + testDeflection * (pMax.rawValue - pitchTrim))
                pitchLow  = Math.round(pitchTrim - testDeflection * (pitchTrim - pMin.rawValue))
            }
            var rTrim = _paramFact("RC" + rcRollChannel + "_TRIM")
            var rMin  = _paramFact("RC" + rcRollChannel + "_MIN")
            var rMax  = _paramFact("RC" + rcRollChannel + "_MAX")
            if (rTrim) rollTrim = rTrim.rawValue
            if (rMin && rMax) {
                rollHigh = Math.round(rollTrim + testDeflection * (rMax.rawValue - rollTrim))
                rollLow  = Math.round(rollTrim - testDeflection * (rollTrim - rMin.rawValue))
            }
        }
        /// Fills the four step ch1/ch2 values from the calibration data.
        /// sendRcOverride(ch1, ch2) always sends ch1 on physical channel 1
        /// and ch2 on physical channel 2. RCMAP tells us which axis lives on
        /// which physical channel, so each value is placed correctly.
        function populateStepValues() {
            function val(ch, pitchVal, rollVal) {
                if (ch === rcPitchChannel) return pitchVal
                if (ch === rcRollChannel)  return rollVal
                return 1500 // fallback — should never happen
            }
            elevonSteps.setProperty(0, "ch1", val(1, pitchHigh, rollTrim))
            elevonSteps.setProperty(0, "ch2", val(2, pitchHigh, rollTrim))
            elevonSteps.setProperty(1, "ch1", val(1, pitchLow, rollTrim))
            elevonSteps.setProperty(1, "ch2", val(2, pitchLow, rollTrim))
            elevonSteps.setProperty(2, "ch1", val(1, pitchTrim, rollLow))
            elevonSteps.setProperty(2, "ch2", val(2, pitchTrim, rollLow))
            elevonSteps.setProperty(3, "ch1", val(1, pitchTrim, rollHigh))
            elevonSteps.setProperty(3, "ch2", val(2, pitchTrim, rollHigh))
        }
        /// Sends RC_CHANNELS_OVERRIDE for the current step.
        function driveStep(index) {
            var step = elevonSteps.get(index)
            _try(function() { _v.sendRcOverride(step.ch1, step.ch2) })
        }
        /// Releases the RC override — the autopilot returns to normal control.
        function releaseOverride() {
            _try(function() { _v.releaseRcOverride() })
        }
        /// Reads the current PWM of every detected elevon servo on both
        /// sides, returning an array per side rather than a single value —
        /// supports any number of servos per side (1, 2, or more).
        function readServos() {
            var leftValues = []
            var rightValues = []
            for (var i = 0; i < detectedLeftServos.length; ++i) {
                leftValues.push(_servoOutput(detectedLeftServos[i]))
            }
            for (var j = 0; j < detectedRightServos.length; ++j) {
                rightValues.push(_servoOutput(detectedRightServos[j]))
            }
            return { "left": leftValues, "right": rightValues }
        }
        /// Entry point for the control surface test:
        /// 1. Checks the vehicle is disarmed
        /// 2. Detects elevon servo outputs (77/78) automatically
        /// 3. Reads RC calibration and RCMAP from the vehicle
        /// 4. Computes override values — no hardcoded numbers
        /// 5. Starts the wizard
        function runElevonTest() {
            if (!identificationComplete) {
                testMessage      = qsTr("Enter aircraft serial and operator name first")
                testMessageLevel = PreFlightStatus.Fail
                return
            }
            if (!canRunElevonTest()) {
                testMessage      = qsTr("Vehicle is ARMED \u2013 disarm first")
                testMessageLevel = PreFlightStatus.Fail
                return
            }
            detectElevons()
            if (!elevonsDetected()) {
                testMessage      = qsTr("Elevon outputs not found \u2013 check SERVO_FUNCTION")
                testMessageLevel = PreFlightStatus.Fail
                return
            }
            readRcCalibration()
            populateStepValues()
            testMessage      = qsTr("Detected: SERVO%1 (Left) \u00B7 SERVO%2 (Right) \u00B7 Pitch=ch%3 Roll=ch%4")
                                   .arg(detectedLeftServos.join(","))
                                   .arg(detectedRightServos.join(","))
                                   .arg(rcPitchChannel).arg(rcRollChannel)
            testMessageLevel = PreFlightStatus.Pass
            controlSurfaceTestStarted = true
            resetElevonTest()
        }
        function resetElevonTest() {
            for (var i = 0; i < elevonSteps.count; ++i)
                elevonSteps.setProperty(i, "status", PreFlightStatus.Pending)
            recalculateControlSurfaceStatus()
        }
        function endElevonTest() {
            releaseOverride()
            controlSurfaceTestStarted = false
            hazardAcknowledged        = false
        }
        // ═══════════════════════════════════════════════════════════════
        //  SILENT REPORT SAVE — via global fileWriter (same proven pattern
        //  used elsewhere in the app, e.g. Risk Report save)
        // ═══════════════════════════════════════════════════════════════
        /// Builds the full inspection report and saves it silently via the
        /// global fileWriter context property (registered in
        /// QGCCorePlugin.cc, available everywhere in QML with no import).
        /// No UI feedback is shown for the save itself — only the popup
        /// closing signals completion.
        ///
        /// Save location: QGroundControl.settingsManager.appSettings
        /// .logSavePath — QGC's own fixed log-save location. Same
        /// proven-working pattern as MissionReviewPanel.qml's Risk Report
        /// save, just pointed at the log folder instead of the mission
        /// folder.
        ///
        /// Both the aircraft serial (fixed "M X-X" format) and operator name
        /// are required fields (enforced by the calling buttons' enabled
        /// state), so both are always embedded in the saved filename and
        /// report body.
        function saveInspectionReport() {
            var timestamp = new Date().toISOString().replace(/[:.]/g, "-")
            var lines = []
            lines.push("==================================================")
            lines.push("         PRE-FLIGHT INSPECTION REPORT              ")
            lines.push("==================================================")
            lines.push("")
            lines.push("Date:            " + new Date().toLocaleString())
            lines.push("Aircraft Serial: " + vehicleSerial)
            lines.push("Operator:        " + operatorName.trim())
            lines.push("Result:          " + (readyForFlight ? "READY FOR FLIGHT" : "FLY AT OWN RISK"))
            lines.push("")
            lines.push("-- Vehicle Information --")
            if (_ok) {
                lines.push("System ID:      " + (_try(function(){return _v.id})                    || "-"))
                lines.push("Firmware:       " + (_try(function(){return _v.firmwareTypeString})     || "-"))
                lines.push("Firmware Ver:   " + (_try(function(){return _v.firmwareVersionString})  || "-"))
                lines.push("Vehicle Type:   " + (_try(function(){return _v.vehicleTypeString})      || "-"))
                lines.push("Flight Mode:    " + (_try(function(){return _v.flightMode})             || "-"))
                var armed = _try(function(){return _v.armed})
                lines.push("Armed:          " + (armed !== undefined ? (armed ? "YES" : "NO") : "-"))
                var lat = _try(function(){return _v.coordinate.latitude})
                var lon = _try(function(){return _v.coordinate.longitude})
                if (lat !== undefined && lon !== undefined)
                    lines.push("Position:       " + lat.toFixed(6) + ", " + lon.toFixed(6))
                var alt = _try(function(){return _v.altitudeAMSL.valueString})
                if (alt) lines.push("Altitude AMSL:  " + alt)
                var bg = _batteryGroup()
                if (bg) {
                    var volt = _try(function(){return bg.voltage.rawValue})
                    lines.push("Battery 1:      " + (_isNum(volt) ? volt.toFixed(2)+"V" : "-"))
                }
                var bg2 = _try(function(){return _v.batteries.get(1)})
                if (bg2) {
                    var volt2 = _try(function(){return bg2.voltage.rawValue})
                    lines.push("Battery 2:      " + (_isNum(volt2) ? volt2.toFixed(2)+"V" : "-"))
                }
                lines.push("Batt Threshold: " + batteryMinVolts.toFixed(2) + "V minimum")
                var lock = _try(function(){return _v.gps.lock.rawValue})
                var sats = _try(function(){return _v.gps.count.rawValue})
                var hdop = _try(function(){return _v.gps.hdop.rawValue})
                lines.push("GPS:            Lock=" + (lock||"-") + "  Sats=" + (sats||"-") + "  HDOP=" + (hdop ? hdop.toFixed(1) : "-"))
            } else {
                lines.push("No vehicle connected")
            }
            lines.push("")
            lines.push("-- Servo Configuration --")
            if (detectedLeftServos.length > 0) {
                lines.push("Left Elevon:    SERVO" + detectedLeftServos.join(", SERVO"))
                lines.push("Right Elevon:   SERVO" + detectedRightServos.join(", SERVO"))
            } else {
                lines.push("Elevon outputs not detected")
            }
            lines.push("RC Pitch Ch:    " + rcPitchChannel + "  [" + pitchLow + "/" + pitchTrim + "/" + pitchHigh + "]")
            lines.push("RC Roll Ch:     " + rcRollChannel  + "  [" + rollLow  + "/" + rollTrim  + "/" + rollHigh  + "]")
            lines.push("")
            lines.push("-- Automatic Checks --")
            for (var i = 0; i < automaticChecks.count; ++i) {
                var c = automaticChecks.get(i)
                lines.push("  " + PreFlightStatus.text(c.status) + "  " + c.name + "  " + c.detail)
            }
            lines.push("")
            lines.push("-- Control Surface Test --")
            lines.push("  Status: " + PreFlightStatus.text(controlSurfaceStatus))
            for (var k = 0; k < elevonSteps.count; ++k) {
                var es = elevonSteps.get(k)
                lines.push("  " + PreFlightStatus.text(es.status) + "  " + es.title)
            }
            lines.push("")
            lines.push("-- Manual Checklist --")
            for (var j = 0; j < manualChecklist.count; ++j) {
                var m = manualChecklist.get(j)
                lines.push("  " + (m.checked ? "\u2713" : "\u2717") + "  " + m.label)
            }
            lines.push("")
            lines.push("==================================================")
            if (readyForFlight)
                lines.push("  VERDICT:  READY FOR FLIGHT")
            else if (flyAtOwnRisk)
                lines.push("  VERDICT:  FLY AT OWN RISK")
            else
                lines.push("  VERDICT:  NOT READY")
            lines.push("==================================================")
            var content = lines.join("\n")
            // Sanitize both fields for use in a filename: keep only
            // letters, digits, hyphen and underscore. Both fields are
            // required by this point, so namePart is never empty.
            var serial   = vehicleSerial.trim().replace(/[^a-zA-Z0-9_-]/g, "")
            var operator = operatorName.trim().replace(/[^a-zA-Z0-9_-]/g, "")
            var namePart = serial + "_" + operator + "_"
            // Save using the same proven pattern already used elsewhere in
            // the app (see MissionReviewPanel.qml's Risk Report save):
            // fileWriter is a global context property (registered in
            // QGCCorePlugin.cc), and appSettings.logSavePath is QGC's own
            // fixed log-save location — sidesteps all StandardPaths/
            // toLocalFile portability issues entirely.
            var saveDir  = _try(function() { return QGroundControl.settingsManager.appSettings.logSavePath.toString() }) || ""
            var savePath = saveDir + "/PFI_" + namePart + timestamp + ".txt"
            if (fileWriter.save(savePath, content)) {
                console.log("PFI report saved: " + savePath + " (" + content.length + " chars)")
            } else {
                console.warn("FAILED to save PFI report: " + savePath)
            }
        }
    }
    // ═══════════════════════════════════════════════════════════════════════
    //  TIMERS
    // ═══════════════════════════════════════════════════════════════════════
    // Polls the automatic checks once per second while the popup is
    // expanded. Stops when collapsed to save CPU.
    Timer {
        interval:         1000
        running:          control.expanded
        repeat:           true
        triggeredOnStart: true
        onTriggered:      inspectionController.evaluate()
    }
    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() { inspectionController.evaluate() }
    }
    Component.onCompleted: {
        inspectionController.evaluate()
        inspectionController.recalculateControlSurfaceStatus()
        inspectionController.recalculateManualStatus()
    }
    // ═══════════════════════════════════════════════════════════════════════
    //  SECTION HEADER
    // ═══════════════════════════════════════════════════════════════════════
    Rectangle {
        width:  parent.width
        height: ScreenTools.implicitComboBoxHeight + ScreenTools.defaultFontPixelWidth
        color:  qgcPal.windowShade
        RowLayout {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            anchors.right:          parent.right
            anchors.margins:        ScreenTools.defaultFontPixelWidth * 0.5
            spacing:                ScreenTools.defaultFontPixelWidth * 0.5
            QGCColoredImage {
                Layout.alignment:       Qt.AlignVCenter
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.75
                Layout.preferredHeight: Layout.preferredWidth
                source:                 "/InstrumentValueIcons/cheveron-right.svg"
                color:                  qgcPal.text
                rotation:               control.expanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 150 } }
            }
            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               qsTr("Pre-Flight Checklist")
                font.bold:          true
            }
            QGCLabel {
                Layout.alignment:       Qt.AlignBaseline
                Layout.fillWidth:       true
                text:                   PreFlightStatus.text(inspectionController.overallStatus)
                horizontalAlignment:    Text.AlignRight
                elide:                  Text.ElideRight
                font.pointSize:         ScreenTools.smallFontPointSize
                font.bold:              true
                color:                  PreFlightStatus.color(inspectionController.overallStatus)
            }
        }
        MouseArea {
            anchors.fill:   parent
            onClicked:      control.expanded = !control.expanded
        }
    }
    // ═══════════════════════════════════════════════════════════════════════
    //  SECTION BODY
    // ═══════════════════════════════════════════════════════════════════════
    Column {
        width:      parent.width
        visible:    control.expanded
        Rectangle {
            width:  parent.width
            height: cards.implicitHeight + ScreenTools.defaultFontPixelHeight
            color:  qgcPal.window
            ColumnLayout {
                id:                         cards
                width:                      parent.width - control._pad * 2
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          ScreenTools.defaultFontPixelHeight * 0.5
                spacing:                    ScreenTools.defaultFontPixelHeight * 0.5
                // ─────────────────────────────── 0. IDENTIFICATION ────────
                PreFlightSectionCard {
                    Layout.fillWidth: true
                    title: qsTr("Identification")
                    status: inspectionController.identificationComplete ? PreFlightStatus.Pass : PreFlightStatus.Pending
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4
                        // ── Aircraft serial: fixed "M X-X" format ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel {
                                text: qsTr("Aircraft Serial:")
                                font.bold: true
                            }
                            QGCLabel {
                                text: "M"
                                font.bold: true
                                font.family: "monospace"
                            }
                            QGCTextField {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                                placeholderText: qsTr("#")
                                maximumLength: 2
                                validator: RegularExpressionValidator { regularExpression: /^[0-9]{1,2}$/ }
                                text: inspectionController._serialPart1
                                onEditingFinished: {
                                    inspectionController._serialPart1 = text
                                    inspectionController._updateVehicleSerial()
                                }
                            }
                            QGCLabel {
                                text: "-"
                                font.bold: true
                                font.family: "monospace"
                            }
                            QGCTextField {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                                placeholderText: qsTr("#")
                                maximumLength: 2
                                validator: RegularExpressionValidator { regularExpression: /^[0-9]{1,2}$/ }
                                text: inspectionController._serialPart2
                                onEditingFinished: {
                                    inspectionController._serialPart2 = text
                                    inspectionController._updateVehicleSerial()
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.5
                            QGCLabel {
                                text: qsTr("Operator Name:")
                                font.bold: true
                            }
                            QGCTextField {
                                Layout.fillWidth: true
                                placeholderText: qsTr("e.g. Saleh")
                                text: inspectionController.operatorName
                                color: "white"
                                onEditingFinished: inspectionController.operatorName = text
                            }
                        }
                        QGCLabel {
                            Layout.fillWidth: true
                            visible: !inspectionController.identificationComplete
                            text: qsTr("Both fields are required before the control surface test or DONE/CONFIRM can proceed.")
                            wrapMode: Text.WordWrap
                            font.pointSize: ScreenTools.smallFontPointSize
                            font.bold: true
                            color: PreFlightStatus.color(PreFlightStatus.Warn)
                        }
                    }
                }
                // ─────────────────────────────── 1. AUTOMATIC CHECKS ──────
                PreFlightSectionCard {
                    Layout.fillWidth:   true
                    title:              qsTr("Automatic Checks")
                    status:             inspectionController.automaticStatus
                    GridLayout {
                        Layout.fillWidth:   true
                        columns:            control._checkColumns
                        columnSpacing:      ScreenTools.defaultFontPixelWidth
                        rowSpacing:         0
                        Repeater {
                            model: inspectionController.automaticChecks
                            delegate: Rectangle {
                                id: checkRow
                                required property var model
                                Layout.fillWidth:   true
                                implicitHeight:     Math.max(checkLayout.implicitHeight + control._pad,
                                                             ScreenTools.defaultFontPixelHeight * 2.6)
                                radius:             ScreenTools.defaultFontPixelWidth * 0.4
                                color:              checkHover.hovered ? qgcPal.windowShadeDark : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                HoverHandler { id: checkHover }
                                RowLayout {
                                    id:                 checkLayout
                                    anchors.fill:       parent
                                    anchors.margins:    control._pad * 0.5
                                    spacing:            ScreenTools.defaultFontPixelWidth * 0.75
                                    Item {
                                        Layout.alignment:       Qt.AlignVCenter
                                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 1.8
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: ScreenTools.defaultFontPixelWidth * 0.4
                                            color: PreFlightStatus.color(checkRow.model.status)
                                            opacity: 0.14
                                        }
                                        QGCColoredImage {
                                            id: checkIcon
                                            anchors.centerIn: parent
                                            width: parent.width * 0.6; height: width
                                            source: checkRow.model.iconSource
                                            sourceSize.height: height
                                            fillMode: Image.PreserveAspectFit
                                            color: PreFlightStatus.color(checkRow.model.status)
                                            visible: checkIcon.status === Image.Ready
                                        }
                                        QGCLabel {
                                            anchors.centerIn: parent
                                            visible: !checkIcon.visible
                                            text: checkRow.model.name.charAt(0)
                                            font.bold: true
                                            color: PreFlightStatus.color(checkRow.model.status)
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 0
                                        QGCLabel {
                                            Layout.fillWidth: true
                                            text: checkRow.model.name
                                            font.bold: true; elide: Text.ElideRight
                                        }
                                        QGCLabel {
                                            Layout.fillWidth: true
                                            visible: checkRow.model.detail !== ""
                                            text: checkRow.model.detail
                                            font.pointSize: ScreenTools.smallFontPointSize
                                            opacity: 0.7; elide: Text.ElideRight
                                        }
                                    }
                                    QGCLabel {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: PreFlightStatus.text(checkRow.model.status)
                                        font.bold: true
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        color: PreFlightStatus.color(checkRow.model.status)
                                    }
                                }
                            }
                        }
                    }
                }
                // ─────────────────────────── 2. CONTROL SURFACE TEST ──────
                PreFlightSectionCard {
                    Layout.fillWidth:   true
                    title:              qsTr("Control Surface Test")
                    status:             inspectionController.controlSurfaceStatus
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.5
                        // ── Status / detection banner ──
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: testMsgText.implicitHeight + control._pad
                            visible: inspectionController.testMessage !== ""
                            radius: ScreenTools.defaultFontPixelWidth * 0.4
                            color: "transparent"; border.width: 1
                            border.color: PreFlightStatus.color(inspectionController.testMessageLevel)
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: parent.border.color; opacity: 0.15
                            }
                            QGCLabel {
                                id: testMsgText; anchors.centerIn: parent
                                width: parent.width - control._pad
                                text: inspectionController.testMessage; wrapMode: Text.WordWrap
                                font.bold: inspectionController.testMessageLevel === PreFlightStatus.Fail
                                color: parent.border.color
                            }
                        }
                        // ── Pre-start instructions ──
                        QGCLabel {
                            Layout.fillWidth: true
                            visible: !inspectionController.controlSurfaceTestStarted
                            text: qsTr("Ensure the pushrod is properly connected to the servo before starting the test.")
                            wrapMode: Text.WordWrap; opacity: 0.8
                        }
                        // ── Hazard acknowledgment ──
                        QGCCheckBox {
                            Layout.fillWidth: true
                            visible: !inspectionController.controlSurfaceTestStarted
                            text: qsTr("Pushrod connected, test area clear")
                            checked: inspectionController.hazardAcknowledged
                            onClicked: inspectionController.hazardAcknowledged = checked
                        }
                        // ── Start button ──
                        QGCButton {
                            primary: true
                            visible: !inspectionController.controlSurfaceTestStarted
                            enabled: inspectionController.hazardAcknowledged &&
                                     inspectionController.canRunElevonTest() &&
                                     inspectionController.identificationComplete
                            text: !inspectionController.identificationComplete
                                      ? qsTr("Enter serial and operator name first")
                                      : inspectionController.canRunElevonTest() ? qsTr("Run Elevon Test") : qsTr("Disarm to run test")
                            onClicked: inspectionController.runElevonTest()
                        }
                        // ── Mode selection: shown after Run Elevon Test succeeds,
                        //    before the wizard itself starts ──
                        ColumnLayout {
                            id: modeChoice
                            Layout.fillWidth: true
                            visible: inspectionController.controlSurfaceTestStarted && wizard.mode === ""
                            spacing: ScreenTools.defaultFontPixelHeight * 0.4
                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("How would you like to run the test?")
                                font.bold: true
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                QGCButton {
                                    Layout.fillWidth: true
                                    primary: true
                                    text: qsTr("Automatic")
                                    onClicked: wizard.startAutomatic()
                                }
                                QGCButton {
                                    Layout.fillWidth: true
                                    text: qsTr("Manual")
                                    onClicked: wizard.mode = "manual"
                                }
                            }
                        }
                        // ── Wizard (visible after a mode is chosen) ──
                        ColumnLayout {
                            id: wizard
                            Layout.fillWidth: true
                            visible: inspectionController.controlSurfaceTestStarted && mode !== ""
                            spacing: ScreenTools.defaultFontPixelHeight * 0.5
                            /// "" = no mode chosen yet | "manual" | "automatic"
                            property string mode:        ""
                            property int    stepIndex:   0
                            /// idle | driving | pass | fail
                            property string state:       "idle"
                            /// Arrays of PWM readings per side — one entry
                            /// per detected servo, supporting any number of
                            /// servos per side.
                            property var beforeLeft:  []
                            property var beforeRight: []
                            property var afterLeft:   []
                            property var afterRight:  []
                            readonly property var  steps:      inspectionController.elevonSteps
                            readonly property var  step:       steps.get(stepIndex)
                            readonly property bool isLastStep: stepIndex === steps.count - 1
                            onStepIndexChanged: state = "idle"
                            function goToStep(index) {
                                state = "idle"
                                stepIndex = Math.max(0, Math.min(steps.count - 1, index))
                            }
                            /// Entry point for the Automatic mode: sets the
                            /// mode flag and kicks off the first step. From
                            /// here on, checkReadback()'s own auto-advance
                            /// timer keeps calling startStep() for each
                            /// subsequent step with no operator input.
                            function startAutomatic() {
                                mode = "automatic"
                                goToStep(0)
                                startStep()
                            }
                            /// Reads servos, sends override, starts readback timer.
                            function startStep() {
                                var s = inspectionController.readServos()
                                beforeLeft  = s.left
                                beforeRight = s.right
                                state = "driving"
                                inspectionController.driveStep(stepIndex)
                                readbackTimer.restart()
                            }
                            /// Compares every detected servo's PWM before and
                            /// after, per side. Strict AND: every servo on a
                            /// given side must move by more than 30µs for
                            /// that side to count as moved — a single
                            /// unresponsive servo (e.g. one of two redundant
                            /// actuators failing) fails the whole step,
                            /// rather than being masked by its working twin.
                            /// Both sides must pass for the step overall to
                            /// pass.
                            ///
                            /// In Automatic mode, a passing step also queues
                            /// the next step's startStep() via autoAdvanceTimer
                            /// below — the operator does nothing until the
                            /// whole sequence finishes.
                            function checkReadback() {
                                var s = inspectionController.readServos()
                                afterLeft  = s.left
                                afterRight = s.right
                                inspectionController.releaseOverride()
                                var allLeftMoved = beforeLeft.length > 0
                                for (var i = 0; i < beforeLeft.length; ++i) {
                                    var moved = afterLeft[i] > 0 && Math.abs(afterLeft[i] - beforeLeft[i]) > 30
                                    if (!moved) { allLeftMoved = false; break }
                                }
                                var allRightMoved = beforeRight.length > 0
                                for (var j = 0; j < beforeRight.length; ++j) {
                                    var movedR = afterRight[j] > 0 && Math.abs(afterRight[j] - beforeRight[j]) > 30
                                    if (!movedR) { allRightMoved = false; break }
                                }
                                if (allLeftMoved && allRightMoved) {
                                    state = "pass"
                                    inspectionController.setElevonStepStatus(stepIndex, PreFlightStatus.Pass)
                                    if (mode === "automatic") autoAdvanceTimer.restart()
                                } else {
                                    state = "fail"
                                    inspectionController.setElevonStepStatus(stepIndex, PreFlightStatus.Fail)
                                    // Automatic mode stops on a failure rather
                                    // than silently skipping past it — the
                                    // operator must intervene (Retry/Manual).
                                }
                            }
                            // Wait for the autopilot to process the override
                            // and echo at least one SERVO_OUTPUT_RAW before
                            // reading it back.
                            Timer {
                                id:          readbackTimer
                                interval:    1000
                                repeat:      false
                                onTriggered: wizard.checkReadback()
                            }
                            // Automatic mode only: after a passing step,
                            // waits before moving to (and starting) the next
                            // step with zero operator input. In Manual mode
                            // this timer is never started (see checkReadback).
                            Timer {
                                id:          autoAdvanceTimer
                                interval:    800
                                repeat:      false
                                onTriggered: {
                                    if (!wizard.isLastStep) {
                                        wizard.goToStep(wizard.stepIndex + 1)
                                        wizard.startStep()
                                    } else {
                                        wizard.state = "idle"
                                    }
                                }
                            }
                            // ── Progress dots ──
                            RowLayout {
                                Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 0.4
                                Repeater {
                                    model: wizard.steps
                                    delegate: Rectangle {
                                        id: stepDot
                                        required property int index
                                        required property int status
                                        readonly property bool isCurrent: stepDot.index === wizard.stepIndex
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: ScreenTools.defaultFontPixelHeight * 1.5
                                        implicitHeight: implicitWidth; radius: width / 2
                                        color: stepDot.status === PreFlightStatus.Pending
                                                   ? (stepDot.isCurrent ? qgcPal.buttonHighlight : qgcPal.windowShadeDark)
                                                   : PreFlightStatus.color(stepDot.status)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        QGCLabel {
                                            anchors.centerIn: parent
                                            text: stepDot.index + 1; font.bold: true
                                            font.pointSize: ScreenTools.smallFontPointSize
                                            color: stepDot.status === PreFlightStatus.Pending && !stepDot.isCurrent
                                                       ? qgcPal.text : PreFlightStatus.contrastingTextColor(stepDot.status)
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: qgcPal.windowShadeDark }
                            // ── Step title + status ──
                            RowLayout {
                                Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: qsTr("Step %1 of %2  \u00B7  %3").arg(wizard.stepIndex+1).arg(wizard.steps.count).arg(wizard.step ? wizard.step.title : "")
                                    font.bold: true; elide: Text.ElideRight
                                }
                                QGCLabel {
                                    text: PreFlightStatus.text(wizard.step ? wizard.step.status : PreFlightStatus.Pending)
                                    font.bold: true; font.pointSize: ScreenTools.smallFontPointSize
                                    color: PreFlightStatus.color(wizard.step ? wizard.step.status : PreFlightStatus.Pending)
                                }
                            }
                            // ── Instruction ──
                            QGCLabel { Layout.fillWidth: true; text: wizard.step ? wizard.step.instruction : ""; wrapMode: Text.WordWrap; opacity: 0.8 }
                            // ── Run button — MANUAL MODE ONLY ──
                            QGCButton {
                                Layout.fillWidth: true; primary: true
                                visible: wizard.mode === "manual" && (wizard.state === "idle" || wizard.state === "fail")
                                enabled: inspectionController.canRunElevonTest()
                                text: wizard.state === "fail" ? qsTr("Retry") : qsTr("\u25B6  Run")
                                onClicked: wizard.startStep()
                            }
                            // ── Retry button — AUTOMATIC MODE, only on failure ──
                            QGCButton {
                                Layout.fillWidth: true; primary: true
                                visible: wizard.mode === "automatic" && wizard.state === "fail"
                                enabled: inspectionController.canRunElevonTest()
                                text: qsTr("Retry")
                                onClicked: wizard.startStep()
                            }
                            // ── Driving indicator ──
                            QGCLabel {
                                Layout.fillWidth: true; visible: wizard.state === "driving"
                                text: qsTr("Moving surfaces..."); font.bold: true
                                color: PreFlightStatus.color(PreFlightStatus.Warn)
                            }
                            // ── Result ──
                            QGCLabel {
                                Layout.fillWidth: true
                                visible: wizard.state === "pass" || wizard.state === "fail"
                                wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize
                                text: wizard.state === "pass"
                                          ? qsTr("\u2713 Moved \u2013 L [%1]\u2192[%2]  \u00B7  R [%3]\u2192[%4] \u00B5s")
                                                .arg(wizard.beforeLeft.join(","))
                                                .arg(wizard.afterLeft.join(","))
                                                .arg(wizard.beforeRight.join(","))
                                                .arg(wizard.afterRight.join(","))
                                          : qsTr("\u2717 No movement detected on at least one servo \u2013 check wiring and safety switch")
                                color: wizard.state === "pass" ? PreFlightStatus.color(PreFlightStatus.Pass) : PreFlightStatus.color(PreFlightStatus.Fail)
                            }
                            // ── Auto advance notice — AUTOMATIC MODE ONLY ──
                            QGCLabel { Layout.fillWidth: true; visible: wizard.mode === "automatic" && wizard.state === "pass" && !wizard.isLastStep; text: qsTr("Advancing to next step..."); font.pointSize: ScreenTools.smallFontPointSize; opacity: 0.6 }
                            QGCLabel { Layout.fillWidth: true; visible: wizard.state === "pass" && wizard.isLastStep; text: qsTr("\u2713 All steps passed"); font.bold: true; color: PreFlightStatus.color(PreFlightStatus.Pass) }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: qgcPal.windowShadeDark }
                            // ── Navigation — MANUAL MODE ONLY ──
                            Flow {
                                Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                visible: wizard.mode === "manual"
                                QGCButton { text: qsTr("Back");    enabled: wizard.stepIndex > 0;    onClicked: wizard.goToStep(wizard.stepIndex - 1) }
                                QGCButton { text: qsTr("Next");    enabled: !wizard.isLastStep;      onClicked: wizard.goToStep(wizard.stepIndex + 1) }
                                QGCButton { text: qsTr("Restart"); onClicked: { inspectionController.resetElevonTest(); wizard.goToStep(0) } }
                            }
                            QGCButton {
                                Layout.fillWidth: true; text: qsTr("Finish Test")
                                onClicked: {
                                    inspectionController.endElevonTest()
                                    wizard.state = "idle"
                                    wizard.mode  = ""
                                    wizard.goToStep(0)
                                }
                            }
                        }
                    }
                }
                // ─────────────────────────────── 3. MANUAL CHECKLIST ──────
                PreFlightSectionCard {
                    Layout.fillWidth: true
                    title: qsTr("Manual Checklist")
                    status: inspectionController.manualStatus
                    GridLayout {
                        Layout.fillWidth: true; columns: control._checkColumns
                        columnSpacing: ScreenTools.defaultFontPixelWidth; rowSpacing: 0
                        Repeater {
                            model: inspectionController.manualChecklist
                            delegate: Rectangle {
                                id: manualRow
                                required property var model
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: Math.max(manualLayout.implicitHeight + control._pad * 0.5, ScreenTools.defaultFontPixelHeight * 2.2)
                                radius: ScreenTools.defaultFontPixelWidth * 0.4
                                color: manualHover.hovered ? qgcPal.windowShadeDark : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                HoverHandler { id: manualHover }
                                RowLayout {
                                    id: manualLayout; anchors.fill: parent; anchors.margins: control._pad * 0.5
                                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                    QGCCheckBox {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                        text: manualRow.model.label; checked: manualRow.model.checked
                                        onClicked: inspectionController.setManualItemChecked(manualRow.index, checked)
                                    }
                                    QGCLabel {
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: manualRow.model.mandatory && !manualRow.model.checked
                                        text: qsTr("REQUIRED"); font.pointSize: ScreenTools.smallFontPointSize
                                        font.bold: true; color: PreFlightStatus.color(PreFlightStatus.Warn); opacity: 0.8
                                    }
                                }
                            }
                        }
                    }
                }
                // ──────────────────────────── 4. INSPECTION SUMMARY ───────
                PreFlightSectionCard {
                    Layout.fillWidth: true
                    title: qsTr("Inspection Summary")
                    status: inspectionController.overallStatus
                    ColumnLayout {
                        id: summary; Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4
                        readonly property var rows: [
                            { "label": qsTr("Automatic Checks"),     "status": inspectionController.automaticStatus },
                            { "label": qsTr("Control Surface Test"), "status": inspectionController.controlSurfaceStatus },
                            { "label": qsTr("Manual Checklist"),     "status": inspectionController.manualStatus }
                        ]
                        Repeater {
                            model: summary.rows
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 0.5
                                QGCLabel { Layout.fillWidth: true; text: modelData.label; elide: Text.ElideRight }
                                QGCLabel {
                                    text: PreFlightStatus.text(modelData.status); font.bold: true
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    color: PreFlightStatus.color(modelData.status)
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.25; color: qgcPal.windowShadeDark }
                        // ── Readiness banner ──
                        Rectangle {
                            id:                     banner
                            Layout.fillWidth:       true
                            Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 3.2,
                                                             bannerLayout.implicitHeight + control._pad * 2)
                            radius:                 ScreenTools.defaultFontPixelWidth * 0.6
                            color:                  "transparent"
                            border.width:           1
                            border.color:           accentColor
                            readonly property bool isDone: inspectionController.inspectionDone
                            readonly property color accentColor:
                                isDone ? PreFlightStatus.color(PreFlightStatus.Pass)
                                       : inspectionController.readyForFlight ? PreFlightStatus.color(PreFlightStatus.Pass)
                                                                             : PreFlightStatus.color(PreFlightStatus.Fail)
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: banner.accentColor; opacity: 0.15
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            ColumnLayout {
                                id: bannerLayout; anchors.centerIn: parent
                                width: parent.width - control._pad * 2; spacing: 0
                                QGCLabel {
                                    id: readinessLabel; Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: banner.isDone
                                              ? (inspectionController.readyForFlight ? qsTr("DONE") : qsTr("DONE \u2014 FLY AT YOUR OWN RISK"))
                                              : inspectionController.readyForFlight ? qsTr("READY FOR FLIGHT") : qsTr("NOT READY")
                                    font.bold: true; font.pointSize: ScreenTools.mediumFontPointSize
                                    color: banner.accentColor; elide: Text.ElideRight
                                }
                                QGCLabel {
                                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                                    text: banner.isDone ? qsTr("Inspection complete")
                                              : inspectionController.readyForFlight ? qsTr("All checks passed")
                                              : qsTr("Resolve the outstanding items above")
                                    font.pointSize: ScreenTools.smallFontPointSize; opacity: 0.8; wrapMode: Text.WordWrap
                                }
                            }
                        }
                        // ── READY: DONE button ──
                        QGCButton {
                            Layout.fillWidth: true; primary: true
                            visible: inspectionController.readyForFlight && !inspectionController.inspectionDone
                            enabled: inspectionController.identificationComplete
                            text: qsTr("DONE")
                            onClicked: {
                                inspectionController.inspectionDone = true
                                inspectionController.saveInspectionReport()
                                control.inspectionCompleted()
                            }
                        }
                        // ── NOT READY: two-step override ──
                        QGCCheckBox {
                            Layout.fillWidth: true
                            visible: !inspectionController.readyForFlight && !inspectionController.inspectionDone
                            text: qsTr("Fly at your own risk \u2014 I accept responsibility")
                            checked: inspectionController.riskAcknowledged
                            onClicked: inspectionController.riskAcknowledged = checked
                        }
                        QGCButton {
                            Layout.fillWidth: true; primary: true
                            visible: inspectionController.riskAcknowledged && !inspectionController.inspectionDone && !inspectionController.readyForFlight
                            enabled: inspectionController.identificationComplete
                            text: qsTr("CONFIRM")
                            onClicked: {
                                inspectionController.inspectionDone = true
                                inspectionController.flyAtOwnRisk  = true
                                inspectionController.saveInspectionReport()
                                control.inspectionCompleted()
                            }
                        }
                    }
                }
            }
        }
    }
}