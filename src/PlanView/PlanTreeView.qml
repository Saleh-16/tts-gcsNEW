import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.PlanView
/// Unified plan tree view showing Mission Items, GeoFence, and Rally Points
/// as collapsible sections using a real TreeView with type-discriminating delegates.
TreeView {
    id: root
    model: _missionController.visualItemsTree
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    reuseItems: false
    pointerNavigationEnabled: false
    selectionBehavior: TableView.SelectionDisabled
    rowSpacing: 2
    required property var editorMap
    required property var planMasterController
    signal editingLayerChangeRequested(int layer)
    readonly property int _layerMission: 1
    readonly property int _layerFence:   2
    readonly property int _layerRally:   3
    readonly property bool _createNewPlanMode: planMasterController.showCreateFromTemplate
    on_CreateNewPlanModeChanged: {
        if (_createNewPlanMode) {
            var planFileRow = _rowFor(_missionController.planFileGroupIndex)
            if (!root.isExpanded(planFileRow)) {
                root.expand(planFileRow)
            }
            root.contentY = 0
        }
    }
    property var _missionController: planMasterController.missionController

    // TTS: ضمان إضافي — فتح Plan Info افتراضياً من أول لحظة يظهر فيها المكوّن
    Component.onCompleted: {
        var row = _rowFor(_missionController.planFileGroupIndex)
        if (row >= 0 && !root.isExpanded(row)) {
            root.expand(row)
        }
    }
    property var _geoFenceController: planMasterController.geoFenceController
    property var _rallyPointController: planMasterController.rallyPointController
    // Helper: convert a persistent model index to the current visual row
    function _rowFor(modelIndex) { return root.rowAtIndex(modelIndex) }
    // QGCFlickableScrollIndicator expects parent to have indicatorColor (provided by QGCFlickable/QGCListView)
    property color indicatorColor: qgcPal.text
    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    QGCFlickableScrollIndicator { parent: root; orientation: QGCFlickableScrollIndicator.Horizontal }
    QGCFlickableScrollIndicator { parent: root; orientation: QGCFlickableScrollIndicator.Vertical }
    property int _lastMissionItemCount: 0
    // ── Section ordering — single source of truth for numbering ──────────
    // To reorder or add a section: edit this list only.
    // paramSection and missionReviewSection numbers are derived externally
    // via root.sectionCount so they always follow on automatically.
    readonly property var _groupOrder: [
        "planFileGroup",
        "defaultsGroup",
        "missionGroup",
        "fenceGroup",
        "rallyGroup",
        "transformGroup"
    ]
    // TTS: المجموعات المخفية بطلب صريح (نفس nodeType المستخدمة بـ _ttsHiddenGroup
    // بمستوى delegate) — تُستبعد من الترقيم عشان يرجع متتالي بدون قفزات (1،2،3،4)
    readonly property var _ttsHiddenGroupTypes: ["missionGroup", "fenceGroup", "rallyGroup", "transformGroup"]
    // القائمة الفعلية للترقيم — نفس _groupOrder بعد استبعاد المخفي، الترتيب معلّق أدناه:
    // readonly property int sectionCount: _groupOrder.length
    readonly property var _visibleGroupOrder: _groupOrder.filter(function(g) { return _ttsHiddenGroupTypes.indexOf(g) === -1 })
    readonly property int sectionCount: _visibleGroupOrder.length
    function _groupNumber(nodeType) {
        var idx = _visibleGroupOrder.indexOf(nodeType)
        return idx >= 0 ? (idx + 1).toString() : ""
    }
    Connections {
        target: root._missionController.visualItems
        function onCountChanged() {
            var newCount = _missionController.visualItems ? _missionController.visualItems.count : 0
            // ══ TTS: تعطيل السلوك التلقائي بالكامل بطلب صريح — إضافة نقاط مهمة
            // ما تعود تؤثر على حالة طي/فتح أي قسم بهذي اللوحة (Plan Info/Defaults/
            // Mission Items)، لأن الأخيرة أصلاً مخفية ومُدارة عبر WaypointTable.
            // الكود الأصلي معلّق أدناه (قاعدة رقم 8 بمشروع TTS):
            //
            // if (newCount > root._lastMissionItemCount) {
            //     // First waypoint added — collapse Plan Info and Defaults
            //     if (root._lastMissionItemCount <= 1 && newCount > 1) {
            //         var planFileRow = _rowFor(_missionController.planFileGroupIndex)
            //         if (root.isExpanded(planFileRow)) {
            //             root.collapse(planFileRow)
            //         }
            //         var defaultsRow = _rowFor(_missionController.defaultsGroupIndex)
            //         if (root.isExpanded(defaultsRow)) {
            //             root.collapse(defaultsRow)
            //         }
            //     }
            //     // Expand mission group and scroll to the new item
            //     var missionRow = _rowFor(_missionController.missionGroupIndex)
            //     if (!root.isExpanded(missionRow)) {
            //         root.expand(missionRow)
            //     }
            //     // Scroll happens when the editor signals editorExpandedAndLoaded
            // }
            // ══ END TTS DISABLE ══════════════════════════════════════════════
            root._lastMissionItemCount = newCount
        }
    }
    Connections {
        target: root._missionController
        function onVisualItemsReset() {
            root.collapseRecursively()
            // TTS: فتح Plan Info افتراضياً دائماً عند تحميل/إعادة تعيين الخطة
            root.expand(_rowFor(_missionController.planFileGroupIndex))
            if (_missionController.containsItems) {
                // Non-empty plan: expand mission group
                root.expand(_rowFor(_missionController.missionGroupIndex))
            } else {
                // Empty plan: all sections stay collapsed — user opens what they need
                root.contentY = 0
            }
            root._lastMissionItemCount = _missionController.visualItems ? _missionController.visualItems.count : 0
            root.editingLayerChangeRequested(root._layerMission)
        }
        function onPlanViewStateChanged() {
            // ══ TTS: تعطيل السكرول التلقائي بطلب صريح — تحديد صف بجدول TTS
            // (WaypointTable) ما يعود يحرّك سكرول اللوحة اليمنى، لأن صفوف
            // Mission Items أصلاً مخفية (height=0) وما فيه داعي نسكرول لها.
            // الكود الأصلي معلّق (قاعدة رقم 8):
            //
            // // Current item changed — bring it on-screen if completely off-screen.
            // // Fine-tuned scroll happens later via editorExpandedAndLoaded.
            // var item = _missionController.currentPlanViewItem
            // if (item) {
            //     var modelIndex = _missionController.visualItemsTree.indexForObject(item)
            //     var row = root.rowAtIndex(modelIndex)
            //     if (row >= 0) {
            //         root.forceLayout()
            //         root.positionViewAtRow(row, TableView.Visible)
            //     }
            // }
            // ══ END TTS DISABLE ══════════════════════════════════════════════
        }
    }
    // Public API: select a layer and expand its group. Called by the layer tool buttons.
    function selectLayer(nodeType) {
        let targetRow = -1
        switch (nodeType) {
        case "missionGroup":
            targetRow = _rowFor(_missionController.missionGroupIndex)
            editingLayerChangeRequested(_layerMission)
            break
        case "fenceGroup":
            targetRow = _rowFor(_missionController.fenceGroupIndex)
            editingLayerChangeRequested(_layerFence)
            break
        case "rallyGroup":
            targetRow = _rowFor(_missionController.rallyGroupIndex)
            editingLayerChangeRequested(_layerRally)
            break
        }
        if (targetRow >= 0) {
            if (!root.isExpanded(targetRow))
                root.expand(targetRow)
            root.forceLayout()
            root.positionViewAtRow(targetRow, TableView.AlignTop)
        }
    }
    // Toggle expand/collapse for a group header. Does not affect the editing layer.
    // Caller is responsible for calling allowViewSwitch() before invoking this.
    function _toggleGroup(row, nodeType) {
        var wasExpanded = root.isExpanded(row)
        if (wasExpanded) {
            root.collapse(row)
        } else {
            root.expand(row)
            // TTS: فتح Defaults يقفل Plan Info تلقائياً (اتجاه واحد فقط —
            // فتح Plan Info لاحقاً ما يقفل Defaults، بطلب صريح من المستخدم)
            if (nodeType === "defaultsGroup") {
                var planFileRow = _rowFor(_missionController.planFileGroupIndex)
                if (planFileRow >= 0 && root.isExpanded(planFileRow)) {
                    root.collapse(planFileRow)
                }
            }
        }
        root.forceLayout()
    }
    // Subtitle text shown on group headers, varies by node type
    function _groupSubtitle(nodeType) {
        switch (nodeType) {
        case "planFileGroup":   return planMasterController.currentPlanFileName === "" ? qsTr("<Untitled>") : planMasterController.currentPlanFileName
        case "missionGroup":    return _missionController.visualItems ? (_missionController.visualItems.count - 1) + qsTr(" items") : ""
        case "rallyGroup":      return _rallyPointController.points ? _rallyPointController.points.count + qsTr(" points") : ""
        default:                return ""
        }
    }
    // Coalesces multiple delegate height changes into a single forceLayout() call
    Timer {
        id: layoutTimer
        interval: 0
        running: false
        repeat: false
        onTriggered: root.forceLayout()
    }
    // Called by MissionItemEditor delegates when their editor height has settled.
    function _scrollToMissionItem(delegateItem) {
        root.forceLayout()
        var bottomY = delegateItem.mapToItem(root.contentItem, 0, delegateItem.height).y
        var neededContentY = bottomY - root.height
        if (neededContentY > root.contentY) {
            root.contentY = neededContentY
        }
    }
    delegate: Item {
        id: delegateRoot
        implicitWidth: root.width
        // TTS: implicitHeight يصفّر مباشرة للصفوف المخفية، لأن TableView/TreeView
        // يعتمد عليه (مو height) بحساب المساحة المحجوزة لكل صف — الكود الأصلي معلّق:
        // implicitHeight: (loader.item ? loader.item.height : 1) + (separatorLine.visible ? separatorLine.height + root.rowSpacing : 0)
        implicitHeight: _ttsHiddenGroup ? 0 : (loader.item ? loader.item.height : 1) + (separatorLine.visible ? separatorLine.height + root.rowSpacing : 0)
        // TTS: الشرط الأصلي معلّق مو محذوف (قاعدة رقم 8 بمشروع TTS) —
        // visible: !root._createNewPlanMode || _visibleInCreateMode
        visible: (!root._createNewPlanMode || _visibleInCreateMode) && !_ttsHiddenGroup
        height: visible ? implicitHeight : 0
        width: root.width
        required property TreeView treeView
        required property bool isTreeNode
        required property bool expanded
        required property bool hasChildren
        required property int depth
        required property int row
        required property var model
        readonly property var nodeObject: model.object
        readonly property string nodeType: model.nodeType
        readonly property bool separator: model.separator ?? false
        // In create-new-plan mode, only show Plan Info and Defaults groups and their children
        readonly property bool _visibleInCreateMode: nodeType === "planFileGroup" || nodeType === "planFileInfo"
                                                     || nodeType === "defaultsGroup" || nodeType === "defaultsInfo"

        // ══ TTS: إخفاء المجموعات الأربعة التالية من اللوحة اليمنى بطلب صريح من المستخدم ══
        // Mission Items / GeoFence / Rally Points / Transform — لأنها الآن تُدار عبر
        // WaypointTable المخصص (src/PlanView/WaypointTable.qml) بدل هذي اللوحة.
        // ملاحظة: هذا يخفي أيضاً قدرة إضافة/تعديل GeoFence و Rally Points من الواجهة،
        // لأن أزرار التحكم فيهم موجودة فقط داخل هذي الأقسام.
        readonly property bool _ttsHiddenGroup: nodeType === "missionGroup"    || nodeType === "missionItem"
                                              || nodeType === "fenceGroup"     || nodeType === "fenceEditor"
                                              || nodeType === "rallyGroup"     || nodeType === "rallyHeader" || nodeType === "rallyItem"
                                              || nodeType === "transformGroup" || nodeType === "transformEditor"
        // ══ END TTS HIDDEN GROUPS ══════════════════════════════════════════════════════

        onImplicitHeightChanged: layoutTimer.restart()
        // TTS: إعادة تخطيط إضافية عند تغيّر height نفسه — ضروري عشان تختفي
        // الصفوف المخفية (_ttsHiddenGroup) فعلياً من التخطيط بدل ما تترك فراغ
        onHeightChanged: layoutTimer.restart()
        Component.onCompleted: if (_ttsHiddenGroup) layoutTimer.restart()
        readonly property string _qrcBase: "qrc:/qml/QGroundControl/PlanView/"
        // We use setSource() instead of sourceComponent so that required properties
        // (e.g. missionItem) are injected before internal bindings activate,
        // preventing "Cannot read property of null" warnings.
        Loader {
            id: loader
            width: parent.width
            Component.onCompleted: {
                switch (delegateRoot.nodeType) {
                case "planFileGroup":
                case "defaultsGroup":
                case "missionGroup":
                case "fenceGroup":
                case "rallyGroup":
                case "transformGroup":
                    sourceComponent = groupHeaderComponent
                    break
                case "planFileInfo":
                    setSource(delegateRoot._qrcBase + "PlanInfoEditor.qml", {
                        width:                  Qt.binding(() => delegateRoot.width),
                        planMasterController:   root.planMasterController,
                        missionController:      root._missionController,
                        editorMap:              root.editorMap
                    })
                    break
                case "defaultsInfo":
                    setSource(delegateRoot._qrcBase + "MissionDefaultsEditor.qml", {
                        width:                  Qt.binding(() => delegateRoot.width),
                        missionController:      root._missionController,
                        planMasterController:   root.planMasterController
                    })
                    break
                case "missionItem":
                    if (delegateRoot.nodeObject) {
                        setSource(delegateRoot._qrcBase + "MissionItemEditor.qml", {
                            width:          Qt.binding(() => delegateRoot.width),
                            map:            root.editorMap,
                            missionItem:    delegateRoot.nodeObject
                        })
                    }
                    break
                case "fenceEditor":
                    if (delegateRoot.nodeObject) {
                        setSource(delegateRoot._qrcBase + "GeoFenceEditor.qml", {
                            width:                  Qt.binding(() => delegateRoot.width),
                            myGeoFenceController:   root._geoFenceController,
                            flightMap:              root.editorMap
                        })
                    }
                    break
                case "rallyHeader":
                    if (delegateRoot.nodeObject) {
                        setSource(delegateRoot._qrcBase + "RallyPointEditorHeader.qml", {
                            width:      Qt.binding(() => delegateRoot.width),
                            controller: root._rallyPointController
                        })
                    }
                    break
                case "rallyItem":
                    if (delegateRoot.nodeObject) {
                        setSource(delegateRoot._qrcBase + "RallyPointItemEditor.qml", {
                            width:      Qt.binding(() => delegateRoot.width),
                            rallyPoint: delegateRoot.nodeObject,
                            controller: root._rallyPointController
                        })
                    }
                    break
                case "transformEditor":
                    setSource(delegateRoot._qrcBase + "TransformEditor.qml", {
                        width:              Qt.binding(() => delegateRoot.width),
                        missionController:  root._missionController
                    })
                    break
                }
            }
            onLoaded: {
                if (delegateRoot.nodeType === "missionItem" && item) {
                    item.clicked.connect(function() {
                        root._missionController.setCurrentPlanViewSeqNum(delegateRoot.nodeObject.sequenceNumber, false)
                    })
                    item.remove.connect(function() {
                        var viIndex = root._missionController.visualItemIndexForObject(delegateRoot.nodeObject)
                        if (viIndex > 0) {
                            root._missionController.removeVisualItem(viIndex)
                        }
                    })
                    item.selectNextNotReadyItem.connect(function() {
                        for (var i = 0; i < root._missionController.visualItems.count; i++) {
                            var vmi = root._missionController.visualItems.get(i)
                            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                                root._missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                                break
                            }
                        }
                    })
                    item.editorExpandedAndLoaded.connect(function() {
                        root._scrollToMissionItem(delegateRoot)
                    })
                }
            }
        }
        Rectangle {
            id: separatorLine
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
            anchors.topMargin: root.rowSpacing
            anchors.top: loader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: qgcPal.groupBorder
            visible: delegateRoot.separator
        }
        // ── Group header (Mission Items / GeoFence / Rally Points) ──
        Component {
            id: groupHeaderComponent
            Rectangle {
                objectName: "planTree_" + delegateRoot.nodeType + "Header"
                width:  delegateRoot.width
                height: ScreenTools.implicitComboBoxHeight + ScreenTools.defaultFontPixelWidth
                color:  qgcPal.windowShade
                RowLayout {
                    id: groupHeaderRow
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                    // ── Numbered circle (auto from _groupOrder) ──
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.0
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: width / 2
                        color: delegateRoot.expanded ? qgcPal.colorGreen : qgcPal.windowShadeDark
                        Text {
                            anchors.centerIn: parent
                            text: root._groupNumber(delegateRoot.nodeType)
                            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.5
                            font.bold: true
                            font.family: "monospace"
                            color: delegateRoot.expanded ? "#0A0C0E" : qgcPal.colorGrey
                        }
                    }
                    // ── Chevron ──
                    QGCColoredImage {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 0.75
                        Layout.preferredHeight: Layout.preferredWidth
                        source: "/InstrumentValueIcons/cheveron-right.svg"
                        color: qgcPal.text
                        rotation: delegateRoot.expanded ? 90 : 0
                    }
                    // ── Title ──
                    QGCLabel {
                        Layout.alignment: Qt.AlignBaseline
                        text: delegateRoot.nodeObject ? delegateRoot.nodeObject.objectName : ""
                        font.bold: true
                    }
                    // ── Subtitle ──
                    QGCLabel {
                        Layout.alignment: Qt.AlignBaseline
                        Layout.fillWidth: true
                        text: root._groupSubtitle(delegateRoot.nodeType)
                        elide: Text.ElideRight
                        font.pointSize: ScreenTools.smallFontPointSize
                        color: qgcPal.colorGrey
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!mainWindow.allowViewSwitch()) {
                            return
                        }
                        root._toggleGroup(delegateRoot.row, delegateRoot.nodeType)
                    }
                }
            }
        }
    }
}