import QtQml.Models
import QGroundControl
import QGroundControl.Controls
import QGroundControl.Viewer3D
ToolStripActionList {
    id: _root
    signal displayPreFlightChecklist
    model: [
        Viewer3DShowAction { },
        PreFlightCheckListShowAction { onTriggered: displayPreFlightChecklist() },
        /* TTS: Takeoff button removed by request */
        // GuidedActionTakeoff { },
        GuidedActionLand { },
        /* TTS: RTL (Return) button removed by request */
        // GuidedActionRTL { },
        GuidedActionPause { },
        FlyViewAdditionalActionsButton { },
        FlyViewGripperButton { }
    ]
}