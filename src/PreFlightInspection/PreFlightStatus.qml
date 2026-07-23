/****************************************************************************
 *
 * (c) 2009-2026 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

pragma Singleton

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

/// Single source of truth for the states used by the Pre-Flight Inspection page.
///
/// Keeping the enum, the localized strings, the palette colors and the
/// aggregation rules in one singleton means a delegate never has to invent its
/// own color mapping, and a future C++ backend only has to speak in
/// PreFlightStatus values.
QtObject {
    id: root

    enum Value {
        Pending,    ///< Not evaluated yet (initial state, or check in progress)
        Pass,
        Warn,
        Fail
    }

    readonly property QGCPalette _palette: QGCPalette { colorGroupEnabled: true }

    /// Severity ranking used when rolling several results up into one.
    /// A single Fail dominates, a Warn dominates a Pending, Pass is the floor.
    function severity(status) {
        switch (status) {
        case PreFlightStatus.Pass:  return 0
        case PreFlightStatus.Warn:  return 2
        case PreFlightStatus.Fail:  return 3
        default:                    return 1     // Pending
        }
    }

    function text(status) {
        switch (status) {
        case PreFlightStatus.Pass:  return qsTr("PASS")
        case PreFlightStatus.Warn:  return qsTr("WARN")
        case PreFlightStatus.Fail:  return qsTr("FAIL")
        default:                    return qsTr("PENDING")
        }
    }

    function color(status) {
        switch (status) {
        case PreFlightStatus.Pass:  return _palette.colorGreen
        case PreFlightStatus.Warn:  return _palette.colorOrange
        case PreFlightStatus.Fail:  return _palette.colorRed
        default:                    return _palette.colorGrey
        }
    }

    /// Text color that stays legible on top of color(status).
    function contrastingTextColor(status) {
        return status === PreFlightStatus.Pending ? _palette.buttonText : "#000000"
    }

    /// Rolls two results into one. Fold over a list with reduce() for N results.
    ///
    /// Suitable for a headline badge, NOT for the go / no-go decision - see
    /// isReadyFromGroups() for why.
    function worst(lhs, rhs) {
        return severity(lhs) >= severity(rhs) ? lhs : rhs
    }

    /// Go / no-go decision. Takes the three group results directly rather than
    /// the rolled-up value.
    ///
    /// This matters: worst() ranks Warn above Pending, so a rolled-up result of
    /// Warn is indistinguishable from "one group warned and another was never
    /// touched at all". Judging readiness off that value let a low battery
    /// advisory mask an entirely unticked manual checklist and still report
    /// READY FOR FLIGHT.
    ///
    /// Warnings are advisory and pass; Pending never does.
    function isReadyFromGroups(automatic, controlSurface, manual) {
        var groups = [automatic, controlSurface, manual]
        for (var i = 0; i < groups.length; ++i) {
            if (groups[i] === PreFlightStatus.Fail || groups[i] === PreFlightStatus.Pending) {
                return false
            }
        }
        return true
    }

    /// Single status variant, kept for callers that genuinely have only one
    /// result to judge. Do not use it on a value produced by worst().
    function isReady(status) {
        return status === PreFlightStatus.Pass || status === PreFlightStatus.Warn
    }
}