import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

RowLayout {
    TelemetryValuesBar {
        Layout.alignment:       Qt.AlignBottom
        extraWidth:             instrumentPanel.extraValuesWidth
        settingsGroup:          factValueGrid.telemetryBarSettingsGroup
        specificVehicleForCard: null // Tracks active vehicle
        visible:            false

    }

    FlyViewInstrumentPanel {
        id:                 instrumentPanel
        Layout.alignment:   Qt.AlignBottom
        // ── تم إخفاؤه لصالح الأفق/البوصلة المخصصة في FlyViewCustomLayer.qml ──
        // كان أصلاً:
        // visible: QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
        visible:            false
    }
}