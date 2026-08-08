// ─────────────────────────────────────────────────────────────────────────────
//  TTS GROUP — WaypointTable.qml
//  جدول نقاط المهمة القابل للتعديل — يعمل بالتوازي مع PlanViewRightPanel
//  المسار: ~/qgroundcontrol/src/PlanView/WaypointTable.qml
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Controls
import QtPositioning
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
Rectangle {
    id: wpRoot
    property var missionController
    property var planMasterController
    property var map
    readonly property var  _mc:     missionController
    readonly property var  _items:  _mc ? _mc.visualItems : null
    readonly property real _rowH:   ScreenTools.defaultFontPixelHeight * 1.9
    readonly property real _fs:     ScreenTools.defaultFontPixelHeight * 0.8
    readonly property real _u:      ScreenTools.defaultFontPixelWidth
    readonly property color cBg:     "#0A0C0E"
    readonly property color cPanel:  "#111518"
    readonly property color cRow:    "#0D1114"
    readonly property color cRowAlt: "#12171B"
    readonly property color cBorder: "#1E2830"
    readonly property color cNeon:   "#00FF88"
    readonly property color cWhite:  "#DDE5EA"
    readonly property color cGrey:   "#4A6070"
    readonly property color cRed:    "#FF2244"
    readonly property color cOrange: "#FF6600"
    // TTS: العروض الافتراضية مبنية على _rowH (ارتفاع الصف المضبوط) لا على _u،
    // لأن عرض الخط (defaultFontPixelWidth) يختلف بين الأجهزة. النِسب مقيسة من
    // صورة المستخدم (ارتفاع الصف ≈ 42px) فتطلع بالحجم الصحيح على أي شاشة.
    // قابلة للسحب اليدوي بالكامل من رأس كل عمود (مقبض السحب في HeadCell).
    property real colSeq:    _rowH * 0.55    // #          (~23px)
    property real colType:   _rowH * 4.75    // COMMAND    (~200px) — عمود التغيير
    property real colLat:    _rowH * 3.6     // LAT        (~151px)
    property real colLon:    _rowH * 4.4     // LON        (~185px)
    property real colAlt:    _rowH * 5.05    // ALT (AMSL) (~212px)
    property real colGr:     _rowH * 2.25    // GRAD       (~95px)
    property real colAn:     _rowH * 2.2     // ANGLE      (~92px)
    property real colAz:     _rowH * 1.5     // AZ         (~63px)
    property real colDp:     _rowH * 3.5     // DIST prev  (~147px)
    property real colAct:    _rowH * 3.6     // ACT        (~151px)
    readonly property real _totalW: colSeq + colType + colLat + colLon + colAlt +
                                     colGr + colAn + colDp + colAz + colAct +
                                     _extraFacts.reduce(function(sum, f) {
                                         return sum + wpRoot._paramColW(f ? f.name : "")
                                     }, 0)
    color:        cBg
    border.color: cBorder
    border.width: 1
    clip:         true
    // TTS: نفس ترتيب/مجموعة الحقول في SimpleItemEditor.qml الأصلي بـ QGC:
    //   comboboxFacts ← ثم → textFieldFacts ← ثم → nanFacts
    //   (النسخة الأساسية فقط، بدون قوائم Advanced — مطابقة لتبويب QGC الأساسي).
    // استثناء صريح بطلب المستخدم: "Abort Alt" و "Precision Land" (خاصتَي أمر
    // Land) لا تُعرض كأعمدة — تبقى بقية براميترات أي أمر آخر كما هي.
    readonly property var _hiddenFactNames: ["Abort Alt", "Precision Land"]
    function _dynamicFacts(item) {
        if (!item) return []
        var out = []
        var lists = [item.comboboxFacts, item.textFieldFacts, item.nanFacts]
        for (var l = 0; l < lists.length; l++) {
            var model = lists[l]
            if (!model || model.count === undefined) continue
            for (var i = 0; i < model.count; i++) {
                var f = model.get(i)
                if (f && wpRoot._hiddenFactNames.indexOf(f.name) === -1) out.push(f)
            }
        }
        return out
    }
    readonly property var _curItem: _mc ? _mc.currentPlanViewItem : null
    // TTS: صيغة الإحداثيات المشتركة — تُقرأ من الخريطة الممرَّرة (map)
    readonly property int _coordFmt: QGroundControl.settingsManager.appSettings.coordinateFormat.rawValue

    // TTS: ═══ أعمدة براميترات ديناميكية حسب الأمر المختار ═══════════════════
    //   LAT / LON / ALT تبقى أعمدة ثابتة. نضيف عموداً لكل براميتر يخص الأمر
    //   المختار (Loiter Time / Radius / Speed / Throttle / Type ...). facts
    //   الإحداثي (Lat/Lon/Alt) مستثناة أصلاً من textFieldFacts/comboboxFacts
    //   للأوامر الإحداثية — مؤكد من SimpleMissionItem.cc (params 5/6/7 بلا showUI).
    //   كل صف يملأ العمود بمطابقة اسم الـFact فقط، فلا يختلط أمر بأمر.
    property int  _selRev: 0            // يزيد عند تغيّر أمر البند المختار
    property real colParam: _rowH * 3.3     // عرض عمود براميتر ديناميكي (~139px) — الافتراضي لو ما اتسحب
    // TTS: عرض مستقل لكل عمود براميتر ديناميكي، مخزّن بـ"اسم" الـFact (مو
    //      موقعه) — عشان لو رجع نفس البراميتر يظهر بصف/أمر ثاني يحتفظ بنفس
    //      العرض اللي سحبته يدوياً له. الأعمدة اللي ما اتسحبت تاخذ colParam.
    property var colParamWidthsByName: ({})
    function _paramColW(name) {
        return (name && wpRoot.colParamWidthsByName[name] !== undefined)
               ? wpRoot.colParamWidthsByName[name] : wpRoot.colParam
    }
    function _setParamColW(name, w) {
        if (!name) return
        var obj = {}
        for (var k in wpRoot.colParamWidthsByName) obj[k] = wpRoot.colParamWidthsByName[k]
        obj[name] = w
        wpRoot.colParamWidthsByName = obj   // إعادة تعيين الكائن كامل عشان binding يتحدّث
    }
    readonly property var _extraFacts: {
        wpRoot._selRev                  // dependency: أمر البند تغيّر
        var it = wpRoot._curItem        // dependency: البند المختار تغيّر
        return it ? wpRoot._dynamicFacts(it) : []
    }
    // ترويسة عمودَي الإحداثي — ثابتة LAT/LON (أو EASTING/NORTHING/MGRS حسب الصيغة)
    function _coordHeader(slot) {
        if (wpRoot._coordFmt === 1) return slot === 0 ? "EASTING" : "NORTHING"
        if (wpRoot._coordFmt === 2) return slot === 0 ? "MGRS" : ""
        return slot === 0 ? "LAT" : "LON"
    }
    // يجيب Fact بنفس الاسم من بند صف معيّن (مطابقة بالاسم لا بالموقع)
    function _rowFactByName(item, name) {
        if (!item || !name) return null
        var facts = wpRoot._dynamicFacts(item)
        for (var i = 0; i < facts.length; i++)
            if (facts[i] && facts[i].name === name) return facts[i]
        return null
    }

    function _curFieldName(slotIndex) {
        if (!_curItem || _curItem.specifiesCoordinate) {
            if (wpRoot._coordFmt === 1) return slotIndex === 0 ? "EASTING" : "NORTHING"
            if (wpRoot._coordFmt === 2) return slotIndex === 0 ? "MGRS" : ""
            return slotIndex === 0 ? "LAT" : "LON"
        }
        var facts = _dynamicFacts(_curItem)
        return facts[slotIndex] ? facts[slotIndex].name : ""
    }
    // TTS: تنسيق خلية إحداثي حسب الصيغة. ctl = TransformPositionController
    //      خاص بالصف (يملأ نفسه تلقائياً من coordinate بدوال QGC).
    function _fmtCoordSlot(ctl, coord, slot) {
        if (!coord || !coord.isValid) return "-.-"
        if (wpRoot._coordFmt === 1) {
            if (!ctl.zone) return "-.-"
            var z = ctl.zone.rawValue
            if (z < 1 || z > 60) return "-.-"
            return slot === 0
                ? z + (ctl.hemisphere.rawValue ? "S" : "N") + " " + ctl.easting.rawValue.toFixed(0)
                : ctl.northing.rawValue.toFixed(0)
        }
        if (wpRoot._coordFmt === 2) {
            if (slot !== 0) return "\u2014"
            var s = ctl.mgrs ? ctl.mgrs.valueString : ""
            return (s && s.length > 0) ? s : "-.-"
        }
        return slot === 0 ? coord.latitude.toFixed(7) : coord.longitude.toFixed(7)
    }
    function _rowFieldFact(item, slotIndex) {
        if (!item || item.specifiesCoordinate) return null
        var facts = _dynamicFacts(item)
        return facts[slotIndex] || null
    }
    readonly property int  _globalAltFrame:    _mc ? _mc.globalAltitudeFrame : QGroundControl.AltitudeFrameMixed
    readonly property bool _isGlobalAltMixed:  _globalAltFrame === QGroundControl.AltitudeFrameMixed
    function _curAltHeaderLabel() {
        if (!wpRoot._isGlobalAltMixed) {
            var gu = QGroundControl.altitudeFrameExtraUnits(wpRoot._globalAltFrame)
            return gu ? "ALT (" + gu + ")" : "ALT"
        }
        if (!_curItem || _curItem.altitudeFrame === undefined) return "ALT"
        var u = QGroundControl.altitudeFrameExtraUnits(_curItem.altitudeFrame)
        return u ? "ALT (" + u + ")" : "ALT"
    }
    function _setLat(item, v) {
        if (!item || !item.coordinate) return
        item.coordinate = QtPositioning.coordinate(v, item.coordinate.longitude, item.coordinate.altitude)
    }
    function _setLon(item, v) {
        if (!item || !item.coordinate) return
        item.coordinate = QtPositioning.coordinate(item.coordinate.latitude, v, item.coordinate.altitude)
    }
    function _angleText(item) {
        if (!item) return "-.-"
        var dist = item.distance
        if (!(dist > 0.1)) return "-.-"
        var a = Math.atan2(item.altDifference, dist) * 180 / Math.PI
        return isNaN(a) ? "-.-" : (a >= 0 ? "+" : "") + a.toFixed(1) + "°"
    }
    function _gradPercentText(item) {
        if (!item) return "-.-"
        var dist = item.distance
        if (!(dist > 0.1)) return "-.-"
        var g = (item.altDifference / dist) * 100
        return isNaN(g) ? "-.-" : (g >= 0 ? "+" : "") + g.toFixed(1) + "%"
    }
    function _slopeColor(item) {
        if (!item) return wpRoot.cGrey
        var dist = item.distance
        if (!(dist > 0.1)) return wpRoot.cGrey
        var d = item.altDifference
        if (isNaN(d)) return wpRoot.cGrey
        return d < 0 ? wpRoot.cOrange : wpRoot.cNeon
    }
    function _remove(idx) {
        if (_mc && idx > 0 && typeof _mc.removeVisualItem === "function") _mc.removeVisualItem(idx)
    }
    // TTS: ما فيه دالة "تحريك/إعادة ترتيب" جاهزة بـ MissionController (مؤكد
    // بالـ grep — القائمة الكاملة لدوال Q_INVOKABLE ما فيها Move/Reorder/Swap).
    // الحل: حذف + إعادة إضافة بنفس الإحداثيات والارتفاع ونوع الإطار — محصور
    // بأمان على Waypoint العادي بس (command === 16، MAV_CMD_NAV_WAYPOINT)
    // عشان ما نفقد بيانات خاصة بأنواع تانية (Takeoff/Land/ROI).
    function _move(idx, newIdx) {
        if (!_mc || !_items) return
        if (newIdx < 1 || newIdx >= _items.count) return
        var item = _items.get(idx)
        if (!item || item.command !== 16 || !item.specifiesCoordinate) return
        var coord    = item.coordinate
        var altRaw   = item.altitude ? item.altitude.rawValue : 0
        var altFrame = item.altitudeFrame
        _mc.removeVisualItem(idx)
        var newItem = _mc.insertSimpleMissionItem(coord, newIdx, true)
        if (newItem) {
            if (newItem.altitude) newItem.altitude.rawValue = altRaw
            if (newItem.altitudeFrame !== undefined) newItem.altitudeFrame = altFrame
        }
    }
    function _addBelow() {
        if (!_mc || !_items) return
        var last = _items.count > 1 ? _items.get(_items.count - 1) : null
        var c = (last && last.coordinate && last.coordinate.isValid)
                ? last.coordinate : QtPositioning.coordinate(24.7136, 46.6753, 0)
        _mc.insertSimpleMissionItem(c, _items.count, true)
    }
    component EditCell: Rectangle {
        id: cell
        property string text:      ""
        property bool   editable:  true
        property color  textColor: wpRoot.cWhite
        signal committed(real value)
        height: wpRoot._rowH
        color:  ti.activeFocus ? Qt.rgba(0, 1, 0.53, 0.10) : "transparent"
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
        // TTS: يقيس عرض النص على الحجم الأساسي عشان نصغّره لو ما فِت
        TextMetrics {
            id: tiTM
            font.family:    "monospace"
            font.pixelSize: wpRoot._fs
            text:           ti.text
        }
        TextInput {
            id: ti
            anchors.fill:        parent
            anchors.leftMargin:  wpRoot._u * 0.5
            anchors.rightMargin: wpRoot._u * 0.5
            verticalAlignment:   TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            font.family:         "monospace"
            // TTS: يصغّر الخط تلقائياً لو الرقم أعرض من الخلية (يفِت داخلها)
            font.pixelSize: {
                var avail = width - wpRoot._u
                var need  = tiTM.advanceWidth
                return (need > 0 && avail > 0 && need > avail)
                       ? Math.max(wpRoot._fs * 0.55, wpRoot._fs * avail / need)
                       : wpRoot._fs
            }
            color:               cell.textColor
            selectByMouse:       true
            readOnly:            !cell.editable
            clip:                true
            text:                cell.text
            onEditingFinished: {
                var v = parseFloat(text)
                if (!isNaN(v)) cell.committed(v)
                focus = false
            }
        }
    }
    component ReadCell: Rectangle {
        property string text:      ""
        property color  textColor: wpRoot.cWhite
        height: wpRoot._rowH
        color:  "transparent"
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
        Text {
            anchors.fill:        parent
            anchors.leftMargin:  wpRoot._u * 0.5
            anchors.rightMargin: wpRoot._u * 0.5
            verticalAlignment:   Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text:                parent.text
            font.pixelSize:      wpRoot._fs
            font.family:         "monospace"
            color:               parent.textColor
            // TTS: يصغّر الخط ليفِت داخل الخلية بدل ما ينقطع
            fontSizeMode:        Text.HorizontalFit
            minimumPixelSize:    Math.max(6, wpRoot._fs * 0.55)
            elide:               Text.ElideRight
        }
    }
    component HeadCell: Rectangle {
        property string label: ""
        property string colName: ""
        // TTS: آلية سحب عامة إضافية (لأعمدة البراميترات الديناميكية، وزنها
        //      مو Property ثابتة بـ wpRoot بل مخزّنة باسم الـFact). لو مُمرَّرة
        //      تُستخدم بدل colName.
        property var getWidthFn: null
        property var setWidthFn: null
        height: wpRoot._rowH * 0.85
        color:  "transparent"
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
        Text {
            anchors.fill:       parent
            anchors.margins:    wpRoot._u * 0.3
            verticalAlignment:  Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text:               parent.label
            font.pixelSize:     wpRoot._fs * 0.85
            font.bold:          true
            font.letterSpacing: 0.5
            font.family:        "monospace"
            color:              wpRoot.cWhite
            elide:              Text.ElideRight
        }
        MouseArea {
            id: resizeMa
            readonly property bool _resizable: colName !== "" || setWidthFn !== null
            visible:      _resizable
            enabled:      _resizable
            width:        wpRoot._u * 0.6
            anchors.right: parent.right
            anchors.top:   parent.top
            anchors.bottom: parent.bottom
            hoverEnabled: true
            preventStealing: true
            cursorShape:  Qt.SizeHorCursor
            property real _startGX: 0
            property real _startW:  0
            property bool _active: false
            onEntered: _active = true
            onExited:  _active = false
            onPressed: (mouse) => {
                resizeMa._active = true
                var g = resizeMa.mapToItem(null, mouse.x, mouse.y)
                _startGX = g.x
                _startW  = colName !== "" ? wpRoot[colName] : getWidthFn()
            }
            onReleased: resizeMa._active = resizeMa.containsMouse
            onCanceled: resizeMa._active = false
            onPositionChanged: (mouse) => {
                if (!pressed) return
                var g = resizeMa.mapToItem(null, mouse.x, mouse.y)
                var delta = g.x - _startGX
                var newW  = Math.max(wpRoot._u * 2.5, _startW + delta)
                if (colName !== "") wpRoot[colName] = newW
                else setWidthFn(newW)
            }
            Rectangle {
                anchors.fill: parent
                color: resizeMa._active ? wpRoot.cNeon : "transparent"
                opacity: 0.6
            }
        }
    }
    // ── TTS: حاجز يمنع أحداث الماوس من التسرب للخريطة تحت الجدول ──────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        // يمسك الضغط فيمنع السحب (drag) من تحريك الخريطة
        onPressed: function(mouse) { mouse.accepted = true }
        // يمسك السكرول فيمنع الزوم على الخريطة
        onWheel: function(wheel) { wheel.accepted = true }
    }
    // TTS: يعيد حساب الأعمدة الديناميكية إذا تغيّر أمر البند المختار (عبر الدايلوق)
    Connections {
        target: wpRoot._curItem
        ignoreUnknownSignals: true
        function onCommandChanged() { wpRoot._selRev++ }
    }
    Rectangle {
        id: titleBar
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        height: wpRoot._rowH
        color:  wpRoot.cPanel
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: wpRoot.cBorder }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left:           parent.left
            anchors.leftMargin:     wpRoot._u
            text:               "WAYPOINTS"
            font.pixelSize:     wpRoot._fs
            font.bold:          true
            font.letterSpacing: 1.5
            font.family:        "monospace"
            color:              wpRoot.cNeon
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:          parent.right
            anchors.rightMargin:    wpRoot._u
            spacing:                wpRoot._u
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: wpRoot._mc && wpRoot._mc.missionTotalDistance > 0
                text: {
                    var d = wpRoot._mc ? wpRoot._mc.missionTotalDistance : 0
                    if (d <= 0) return ""
                    var dD = QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(d) * 1.0
                    var u = QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
                    return dD.toFixed(0) + " " + u
                }
                font.pixelSize: wpRoot._fs * 0.9
                font.family:    "monospace"
                color:          wpRoot.cNeon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                    var d   = wpRoot._mc ? wpRoot._mc.missionTotalDistance : 0
                    var spd = QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed.rawValue * 1.0
                    return d > 0 && spd > 0
                }
                text: {
                    var d   = wpRoot._mc ? wpRoot._mc.missionTotalDistance : 0
                    var spd = QGroundControl.settingsManager.appSettings.offlineEditingCruiseSpeed.rawValue * 1.0
                    if (d <= 0 || spd <= 0) return ""
                    var s   = Math.floor(d / spd)
                    var h   = Math.floor(s / 3600)
                    var m   = Math.floor((s % 3600) / 60)
                    var sec = s % 60
                    return "⏱ " + h.toString().padStart(2,"0") + ":" +
                           m.toString().padStart(2,"0") + ":" +
                           sec.toString().padStart(2,"0")
                }
                font.pixelSize: wpRoot._fs * 0.9
                font.family:    "monospace"
                color:          wpRoot.cNeon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "TOTAL: " + (wpRoot._items ? Math.max(0, wpRoot._items.count - 1) : 0)
                font.pixelSize: wpRoot._fs * 0.9
                font.family:    "monospace"
                color:          wpRoot.cWhite
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:  addTxt.implicitWidth + wpRoot._u * 1.6
                height: wpRoot._rowH * 0.65
                color:  addMa.containsMouse ? Qt.rgba(0, 1, 0.53, 0.18) : "transparent"
                border.color: wpRoot.cNeon
                border.width: 1
                radius: 2
                Text {
                    id: addTxt
                    anchors.centerIn: parent
                    text: "+ ADD"
                    font.pixelSize: wpRoot._fs * 0.8
                    font.bold:      true
                    font.family:    "monospace"
                    color:          wpRoot.cNeon
                }
                MouseArea { id: addMa; anchors.fill: parent; hoverEnabled: true; onClicked: wpRoot._addBelow() }
            }
        }
    }
    Item {
        id: tableBody
        anchors.top:    titleBar.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        Item {
            id: fixedPanel
            anchors.top:    parent.top
            anchors.left:   parent.left
            anchors.bottom: parent.bottom
            width: wpRoot.colSeq + wpRoot.colType
            clip:  true
            Item {
                id: fixedHeader
                width:  parent.width
                height: wpRoot._rowH * 0.85
                Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }
                Row {
                    anchors.fill: parent
                    HeadCell { width: wpRoot.colSeq;  label: "#";    colName: "colSeq"  }
                    HeadCell { width: wpRoot.colType; label: "COMMAND"; colName: "colType" }
                }
                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: wpRoot.cNeon; opacity: 0.35 }
            }
            ListView {
                id: fixedList
                anchors.top:    fixedHeader.bottom
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                clip:        true
                model:       wpRoot._items
                reuseItems:  false
                interactive: false
                contentY:    wpList.contentY
                delegate: Item {
                    id: fRowItem
                    width:   fixedList.width
                    height:  index > 0 ? wpRoot._rowH : 0
                    visible: index > 0
                    property var  _item:  object
                    property bool _isCur: wpRoot._mc && fRowItem._item && wpRoot._mc.currentPlanViewSeqNum === fRowItem._item.sequenceNumber
                    Rectangle {
                        anchors.fill: parent
                        color: fRowItem._isCur ? Qt.rgba(0, 1, 0.53, 0.10)
                                               : (index % 2 === 0 ? wpRoot.cRow : wpRoot.cRowAlt)
                    }
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: wpRoot.cBorder }
                    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: wpRoot.cNeon; visible: fRowItem._isCur }
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                            wpRoot.forceActiveFocus()
                            if (wpRoot._mc && fRowItem._item) wpRoot._mc.setCurrentPlanViewSeqNum(fRowItem._item.sequenceNumber, true)
                        }
                    }
                    Row {
                        anchors.fill: parent
                        ReadCell { width: wpRoot.colSeq; textColor: wpRoot.cNeon; text: index.toString() }
                        Rectangle {
                            id: fTypeCell
                            width:  wpRoot.colType
                            height: wpRoot._rowH
                            color:  fTypeMa.containsMouse ? Qt.rgba(0, 1, 0.53, 0.08) : "transparent"
                            Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: wpRoot._u * 0.5
                                anchors.rightMargin: wpRoot._u * 0.3
                                spacing: wpRoot._u * 0.3
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - fDropArrow.width - parent.spacing
                                    text: fRowItem._item && fRowItem._item.commandName ? fRowItem._item.commandName : "—"
                                    font.pixelSize: wpRoot._fs
                                    font.family: "monospace"
                                    color: wpRoot.cWhite
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: fDropArrow
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "▾"
                                    font.pixelSize: wpRoot._fs * 0.9
                                    color: wpRoot.cGrey
                                }
                            }
                            MouseArea {
                                id: fTypeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    wpRoot.forceActiveFocus()
                                    if (fRowItem._item && wpRoot.planMasterController && wpRoot.map) {
                                        cmdDialogFactory.currentItem = fRowItem._item
                                        cmdDialogFactory.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cNeon; opacity: 0.5; z: 10 }
        }
        Flickable {
            id: hFlick
            anchors.top:    parent.top
            anchors.left:   fixedPanel.right
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            contentWidth:   Math.max(width, wpRoot._totalW - wpRoot.colSeq - wpRoot.colType)
            contentHeight:  height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOn }
            Column {
                width:  hFlick.contentWidth
                height: hFlick.height
                Item {
                    id: header
                    width:  hFlick.contentWidth
                    height: wpRoot._rowH * 0.85
                    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }
                    Row {
                        anchors.fill: parent
                        HeadCell { width: wpRoot.colLat;    label: wpRoot._coordHeader(0);      colName: "colLat" }
                        HeadCell { width: wpRoot.colLon;    label: wpRoot._coordHeader(1);      colName: "colLon" }
                        HeadCell { width: wpRoot.colAlt;    label: wpRoot._curAltHeaderLabel(); colName: "colAlt" }
                        // ── أعمدة براميترات الأمر المختار (ديناميكية) — كل
                        //    عمود يسحب لحاله، محفوظ باسم البراميتر ──
                        Repeater {
                            model: wpRoot._extraFacts
                            HeadCell {
                                readonly property string _pn: modelData ? modelData.name : ""
                                width: wpRoot._paramColW(_pn)
                                label: _pn
                                getWidthFn: function() { return wpRoot._paramColW(_pn) }
                                setWidthFn: function(w) { wpRoot._setParamColW(_pn, w) }
                            }
                        }
                        HeadCell { width: wpRoot.colAct;    label: "ACT";           colName: "colAct"  }
                        HeadCell { width: wpRoot.colGr;     label: "GRAD";      colName: "colGr"   }
                        HeadCell { width: wpRoot.colAn;     label: "ANGLE";     colName: "colAn"   }
                        HeadCell { width: wpRoot.colDp;     label: "DIST prev"; colName: "colDp"   }
                        HeadCell { width: wpRoot.colAz;     label: "AZ";        colName: "colAz"   }
                    }
                    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: wpRoot.cNeon; opacity: 0.35 }
                }
                ListView {
                    id: wpList
                    width:  hFlick.contentWidth
                    height: hFlick.height - header.height
                    clip:   true
                    model:  wpRoot._items
                    reuseItems: false
                    ScrollBar.vertical: ScrollBar { }
                    delegate: Item {
                        id: rowItem
                        width:   wpList.width
                        height:  index > 0 ? wpRoot._rowH : 0
                        visible: index > 0
                        property var  _item:  object
                        property bool _isCur: wpRoot._mc && rowItem._item && wpRoot._mc.currentPlanViewSeqNum === rowItem._item.sequenceNumber
                        Rectangle {
                            anchors.fill: parent
                            color: rowItem._isCur ? Qt.rgba(0, 1, 0.53, 0.10)
                                                  : (index % 2 === 0 ? wpRoot.cRow : wpRoot.cRowAlt)
                        }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: wpRoot.cBorder }
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 2; color: wpRoot.cNeon; visible: rowItem._isCur }
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: {
                                wpRoot.forceActiveFocus()
                                if (wpRoot._mc && rowItem._item) wpRoot._mc.setCurrentPlanViewSeqNum(rowItem._item.sequenceNumber, true)
                            }
                        }
                        Row {
                            anchors.fill: parent
                            EditCell {
                                width:     wpRoot.colLat
                                editable:  wpRoot._coordFmt === 0 && rowItem._item && rowItem._item.specifiesCoordinate
                                textColor: (rowItem._item && rowItem._item.specifiesCoordinate) ? wpRoot.cWhite : wpRoot.cGrey
                                TransformPositionController {
                                    id: latCtl
                                    coordinate: (rowItem._item && rowItem._item.specifiesCoordinate && rowItem._item.coordinate)
                                                ? rowItem._item.coordinate : QtPositioning.coordinate()
                                    onCoordinateChanged: initValues()
                                    Component.onCompleted: initValues()
                                }
                                Connections {
                                    target: rowItem._item
                                    ignoreUnknownSignals: true
                                    function onCoordinateChanged() { latCtl.initValues() }
                                }
                                text: (rowItem._item && rowItem._item.specifiesCoordinate)
                                      ? wpRoot._fmtCoordSlot(latCtl, rowItem._item.coordinate, 0) : "—"
                                onCommitted: (v) => {
                                    if (rowItem._item && rowItem._item.specifiesCoordinate) wpRoot._setLat(rowItem._item, v)
                                }
                            }
                            EditCell {
                                width:     wpRoot.colLon
                                editable:  wpRoot._coordFmt === 0 && rowItem._item && rowItem._item.specifiesCoordinate
                                textColor: (rowItem._item && rowItem._item.specifiesCoordinate) ? wpRoot.cWhite : wpRoot.cGrey
                                TransformPositionController {
                                    id: lonCtl
                                    coordinate: (rowItem._item && rowItem._item.specifiesCoordinate && rowItem._item.coordinate)
                                                ? rowItem._item.coordinate : QtPositioning.coordinate()
                                    onCoordinateChanged: initValues()
                                    Component.onCompleted: initValues()
                                }
                                Connections {
                                    target: rowItem._item
                                    ignoreUnknownSignals: true
                                    function onCoordinateChanged() { lonCtl.initValues() }
                                }
                                text: (rowItem._item && rowItem._item.specifiesCoordinate)
                                      ? wpRoot._fmtCoordSlot(lonCtl, rowItem._item.coordinate, 1) : "—"
                                onCommitted: (v) => {
                                    if (rowItem._item && rowItem._item.specifiesCoordinate) wpRoot._setLon(rowItem._item, v)
                                }
                            }
                            Rectangle {
                                width:  wpRoot.colAlt
                                height: wpRoot._rowH
                                color:  "transparent"
                                Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: wpRoot._u * 0.2
                                    spacing: wpRoot._u * 0.3
                                    TextMetrics {
                                        id: altTM
                                        font.family:    "monospace"
                                        font.pixelSize: wpRoot._fs
                                        text:           altTi.text
                                    }
                                    TextInput {
                                        id: altTi
                                        width: wpRoot._isGlobalAltMixed ? parent.width * 0.42 : parent.width * 0.6
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        // TTS: يصغّر الخط ليفِت داخل مساحة الرقم
                                        font.pixelSize: {
                                            var need = altTM.advanceWidth
                                            return (need > 0 && width > 0 && need > width)
                                                   ? Math.max(wpRoot._fs * 0.55, wpRoot._fs * width / need)
                                                   : wpRoot._fs
                                        }
                                        font.family: "monospace"
                                        color: rowItem._item && rowItem._item.specifiesAltitude ? wpRoot.cNeon : wpRoot.cGrey
                                        selectByMouse: true
                                        readOnly: !(rowItem._item && rowItem._item.specifiesAltitude)
                                        text: (rowItem._item && rowItem._item.specifiesAltitude && rowItem._item.altitude)
                                              ? QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(rowItem._item.altitude.rawValue).toFixed(1)
                                              : "—"
                                        onEditingFinished: {
                                            if (rowItem._item && rowItem._item.altitude) {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) {
                                                    rowItem._item.altitude.rawValue = QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsToMeters(v)
                                                }
                                            }
                                            focus = false
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: rowItem._item && rowItem._item.specifiesAltitude
                                        text: QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
                                        font.pixelSize: wpRoot._fs * 0.85
                                        font.family: "monospace"
                                        color: wpRoot.cGrey
                                    }
                                    Loader {
                                        width: parent.width * 0.4
                                        anchors.verticalCenter: parent.verticalCenter
                                        active: rowItem._item && rowItem._item.specifiesAltitude && wpRoot.planMasterController && wpRoot.planMasterController.controllerVehicle && wpRoot._isGlobalAltMixed
                                        sourceComponent: AltFrameCombo {
                                            width: parent.width
                                            font.pixelSize: wpRoot._fs * 0.75
                                            altitudeFrame: rowItem._item.altitudeFrame
                                            vehicle: wpRoot.planMasterController.controllerVehicle
                                            onAltitudeFrameChanged: rowItem._item.altitudeFrame = altitudeFrame
                                        }
                                    }
                                }
                            }
                            // ── أعمدة البراميترات الديناميكية: كل صف يملأ العمود
                            //    بمطابقة اسم الـFact (Loiter Time / Speed / ...).
                            //    الصف اللي ما عنده هذا البراميتر يطلع "—".
                            Repeater {
                                model: wpRoot._extraFacts
                                Rectangle {
                                    id:     pCell
                                    width:  wpRoot._paramColW(_pname)
                                    height: wpRoot._rowH
                                    color:  pTi.activeFocus ? Qt.rgba(0, 1, 0.53, 0.10) : "transparent"
                                    Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
                                    property string _pname:  modelData ? modelData.name : ""
                                    property var    _rf:     wpRoot._rowFactByName(rowItem._item, _pname)
                                    property bool   _isEnum: _rf && _rf.enumStrings !== undefined && _rf.enumStrings.length > 0
                                    TextMetrics {
                                        id: pTM
                                        font.family:    "monospace"
                                        font.pixelSize: wpRoot._fs
                                        text:           pTi.text
                                    }
                                    TextInput {
                                        id: pTi
                                        anchors.fill:        parent
                                        anchors.leftMargin:  wpRoot._u * 0.5
                                        anchors.rightMargin: wpRoot._u * 0.5
                                        verticalAlignment:   TextInput.AlignVCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        // TTS: يصغّر الخط ليفِت داخل الخلية
                                        font.pixelSize: {
                                            var avail = width - wpRoot._u
                                            var need  = pTM.advanceWidth
                                            return (need > 0 && avail > 0 && need > avail)
                                                   ? Math.max(wpRoot._fs * 0.55, wpRoot._fs * avail / need)
                                                   : wpRoot._fs
                                        }
                                        font.family:         "monospace"
                                        color:               pCell._rf ? wpRoot.cOrange : wpRoot.cGrey
                                        selectByMouse:       true
                                        readOnly:            !pCell._rf || pCell._isEnum
                                        clip:                true
                                        // TTS: nanFacts غير المُغيّرة قيمتها NaN → تنعرض "—" مثل QGC
                                        text: {
                                            if (!pCell._rf) return "—"
                                            if (!pCell._isEnum && isNaN(pCell._rf.rawValue)) return "—"
                                            return pCell._rf.enumOrValueString
                                        }
                                        onEditingFinished: {
                                            if (pCell._rf && !pCell._isEnum) {
                                                var v = parseFloat(text)
                                                if (!isNaN(v)) pCell._rf.rawValue = v
                                            }
                                            focus = false
                                        }
                                    }
                                    // TTS: خانة enum (Center/Tangent وغيرها) تُعدَّل عبر قائمة منسدلة
                                    // بدل الكتابة النصية — مرتبطة بـ Fact.enumIndex (مؤكد من Fact.h:
                                    // Q_PROPERTY(int enumIndex READ enumIndex WRITE setEnumIndex)).
                                    MouseArea {
                                        anchors.fill: parent
                                        visible: pCell._isEnum
                                        enabled: pCell._isEnum
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            wpRoot.forceActiveFocus()
                                            enumMenu.open()
                                        }
                                    }
                                    Text {
                                        visible: pCell._isEnum
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.rightMargin: wpRoot._u * 0.3
                                        text: "▾"
                                        font.pixelSize: wpRoot._fs * 0.7
                                        color: wpRoot.cGrey
                                    }
                                    Menu {
                                        id: enumMenu
                                        Repeater {
                                            model: pCell._isEnum && pCell._rf ? pCell._rf.enumStrings : []
                                            MenuItem {
                                                text: modelData
                                                onTriggered: pCell._rf.enumIndex = index
                                            }
                                        }
                                    }
                                }
                            }
                            // ── ACTIONS: DELETE + ▲▼ لتحريك النقطة ──────────────
                            Item {
                                width:  wpRoot.colAct
                                height: wpRoot._rowH
                                Row {
                                    anchors.centerIn: parent
                                    spacing: wpRoot._u * 0.5
                                    Rectangle {
                                        width:  delTxt.implicitWidth + wpRoot._u * 1.2
                                        height: wpRoot._rowH * 0.7
                                        color:  delMa.containsMouse ? Qt.rgba(1, 0.13, 0.27, 0.25) : "transparent"
                                        border.color: wpRoot.cRed; border.width: 1; radius: 2
                                        Text {
                                            id: delTxt
                                            anchors.centerIn: parent
                                            text: "DELETE"
                                            font.pixelSize: wpRoot._fs * 0.85
                                            font.bold: true
                                            font.family: "monospace"
                                            color: wpRoot.cRed
                                        }
                                        MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true; onClicked: { wpRoot.forceActiveFocus(); if (wpRoot._mc && rowItem._item) wpRoot._mc.setCurrentPlanViewSeqNum(rowItem._item.sequenceNumber, true); wpRoot._remove(index) } }
                                    }
                                    Rectangle {
                                        readonly property bool _canMove: rowItem._item && rowItem._item.command === 16
                                        width:  wpRoot._rowH * 0.7; height: wpRoot._rowH * 0.6
                                        opacity: _canMove ? 1 : 0.35
                                        color:  upMa.containsMouse && _canMove ? Qt.rgba(0, 1, 0.53, 0.20) : "transparent"
                                        border.color: wpRoot.cGrey; border.width: 1; radius: 2
                                        Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: wpRoot._fs * 0.75; color: wpRoot.cWhite }
                                        MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true; enabled: parent._canMove; onClicked: { wpRoot.forceActiveFocus(); wpRoot._move(index, index - 1) } }
                                    }
                                    Rectangle {
                                        readonly property bool _canMove: rowItem._item && rowItem._item.command === 16
                                        width:  wpRoot._rowH * 0.7; height: wpRoot._rowH * 0.6
                                        opacity: _canMove ? 1 : 0.35
                                        color:  dnMa.containsMouse && _canMove ? Qt.rgba(0, 1, 0.53, 0.20) : "transparent"
                                        border.color: wpRoot.cGrey; border.width: 1; radius: 2
                                        Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: wpRoot._fs * 0.75; color: wpRoot.cWhite }
                                        MouseArea { id: dnMa; anchors.fill: parent; hoverEnabled: true; enabled: parent._canMove; onClicked: { wpRoot.forceActiveFocus(); wpRoot._move(index, index + 1) } }
                                    }
                                }
                            }
                            ReadCell {
                                width: wpRoot.colGr
                                text:  wpRoot._gradPercentText(rowItem._item)
                                textColor: wpRoot._slopeColor(rowItem._item)
                            }
                            ReadCell {
                                width: wpRoot.colAn
                                text:  wpRoot._angleText(rowItem._item)
                                textColor: wpRoot._slopeColor(rowItem._item)
                            }
                            ReadCell {
                                width: wpRoot.colDp
                                text:  (rowItem._item && !isNaN(rowItem._item.distance))
                                       ? QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(rowItem._item.distance).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
                                       : "-.-"
                                textColor: wpRoot.cWhite
                            }
                            ReadCell {
                                width: wpRoot.colAz
                                text:  (rowItem._item && !isNaN(rowItem._item.azimuth)) ? (Math.round(rowItem._item.azimuth) % 360).toString() + "°" : "-.-"
                                textColor: wpRoot.cWhite
                            }
                        }
                    }
                }
            }
        }
    }
    QGCPopupDialogFactory {
        id: cmdDialogFactory
        property var currentItem: null
        dialogComponent: cmdDialogComponent
    }
    Component {
        id: cmdDialogComponent
        MissionCommandDialog {
            vehicle:                   wpRoot.planMasterController ? wpRoot.planMasterController.controllerVehicle : null
            missionItem:                cmdDialogFactory.currentItem
            map:                        wpRoot.map
            flyThroughCommandsAllowed:  true
        }
    }
}