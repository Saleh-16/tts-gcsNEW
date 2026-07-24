// ─────────────────────────────────────────────────────────────────────────────
//  TTS GROUP — WaypointTable.qml
//  جدول نقاط المهمة القابل للتعديل — يعمل بالتوازي مع PlanViewRightPanel
//  المسار: ~/qgroundcontrol/src/PlanView/WaypointTable.qml
//
//  كل عمود مصدره Fact/Property حقيقي مؤكد من الكود المصدري لـ QGC:
//    - item.distance          ← نفس المصدر المستخدم في MissionStats.qml (Dist prev WP)
//    - item.altDifference     ← نفس المصدر المستخدم في MissionStats.qml (Alt diff)
//    - item.azimuth           ← نفس المصدر المستخدم في MissionStats.qml (Azimuth)
//    - item.missionVehicleYaw ← نفس المصدر المستخدم في MissionStats.qml (Heading)
//    - Gradient: نفس معادلة MissionStats.qml الحرفية (atan) لأنها غير مخزّنة كـ Fact
//                مع نفس استثناء VTOL Takeoff (command==84 → gradient=0)
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Controls
import QtPositioning
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
Rectangle {
    id: wpRoot
    // يُمرَّر من PlanView.qml
    property var missionController
    property var planMasterController
    property var map   ///< خريطة editorMap، مطلوبة لـ MissionCommandDialog الأصلي
    readonly property var  _mc:     missionController
    readonly property var  _items:  _mc ? _mc.visualItems : null
    readonly property real _rowH:   ScreenTools.defaultFontPixelHeight * 1.9
    readonly property real _fs:     ScreenTools.defaultFontPixelHeight * 0.8
    readonly property real _u:      ScreenTools.defaultFontPixelWidth
    // ── Palette (هوية TTS) ────────────────────────────────────────────────
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
    // ── أعمدة قابلة للتوسيع بالماوس (تبدأ بقيم مبنية على ScreenTools مثل باقي
    //    المشروع، لكنها غير readonly عشان يقدر المستخدم يسحب حافتها ويغيّرها) —
    //    لازمة أيضاً لدعم السكرول الأفقي، لأن النسب المئوية ما تشتغل مع محتوى أعرض من الحاوية
    property real colSeq:    _u * 6
    property real colType:   _u * 20
    property real colLat:    _u * 20
    property real colLon:    _u * 20
    property real colAlt:    _u * 18
    property real colGr:     _u * 10   // GRAD (%)
    property real colAn:     _u * 10   // ANGLE (° pitch)
    property real colAz:     _u * 10   // Azimuth
    property real colDp:     _u * 18   // Dist prev
    property real colAct:    _u * 16
    readonly property real _totalW: colSeq + colType + colLat + colLon + colAlt +
                                     colGr + colAn + colDp + colAz + colAct
    color:        cBg
    border.color: cBorder
    border.width: 1
    clip:         true
    // ملاحظة: عمود FRAME حُذف عمداً — MissionItem::frame() دالة C++ عادية،
    // ليست Q_PROPERTY ولا Q_INVOKABLE، فهي غير متاحة من QML بأي اسم. تأكيد بتاريخ 24 يوليو 2026
    // عبر grep على MissionItem.h (راجع TTS_PROJECT_RULES.md قاعدة رقم 2 و4).
    // ملاحظة: تغيير TYPE يتم عبر MissionCommandDialog الأصلي (زر يفتح نفس نافذة
    // "Select Mission Command" بـ QGC حرفياً)، وليس عبر قائمة مبنية يدوياً هنا.
    // ── مساعدات وصول آمنة لبيانات العنصر ──────────────────────────────────
    // Facts النصية الخاصة بالأمر (مثل Pitch لـ Takeoff) — نفس مصدر اللوحة اليمنى
    // بالضبط: item.textFieldFacts + item.comboboxFacts (Q_PROPERTY مؤكدة عبر grep)
    function _dynamicFacts(item) {
        if (!item) return []
        var out = []
        var lists = [item.textFieldFacts, item.comboboxFacts]
        for (var l = 0; l < lists.length; l++) {
            var model = lists[l]
            if (!model || model.count === undefined) continue
            for (var i = 0; i < model.count; i++) {
                var f = model.get(i)
                if (f) out.push(f)
            }
        }
        return out
    }
    // العنصر المحدد حالياً بالجدول — نفس Property المستخدمة بـ MissionStats.qml
    readonly property var _curItem: _mc ? _mc.currentPlanViewItem : null
    // اسم/قيمة الحقل الديناميكي رقم slotIndex (0 أو 1) للعنصر المحدد حالياً —
    // يُستخدم لعنوان عمودي LAT/LON لما العنصر المحدد ما يحدد إحداثيات
    function _curFieldName(slotIndex) {
        if (!_curItem || _curItem.specifiesCoordinate) return slotIndex === 0 ? "LAT" : "LON"
        var facts = _dynamicFacts(_curItem)
        return facts[slotIndex] ? facts[slotIndex].name : ""
    }
    // اسم/قيمة الحقل الديناميكي لعنصر أي صف (مو بس المحدد) — يُستخدم بخلايا الصفوف
    function _rowFieldFact(item, slotIndex) {
        if (!item || item.specifiesCoordinate) return null
        var facts = _dynamicFacts(item)
        return facts[slotIndex] || null
    }
    // ── نوع الارتفاع العام للمهمة — نفس المصدر المؤكد بـ SimpleItemEditor.qml:
    //    missionController.globalAltitudeFrame + AltitudeFrameMixed
    //    (grep بتاريخ 24 يوليو 2026 على SimpleItemEditor.qml و MissionController.h)
    readonly property int  _globalAltFrame:    _mc ? _mc.globalAltitudeFrame : QGroundControl.AltitudeFrameMixed
    readonly property bool _isGlobalAltMixed:  _globalAltFrame === QGroundControl.AltitudeFrameMixed
    // عنوان عمود ALT الديناميكي:
    //  - لو المهمة موحّدة (غير Mixed) → يعرض نوع الارتفاع العام (زي "ALT (Rel)")
    //  - لو Mixed → يعرض نوع الصف المحدد حالياً (لأن كل صف يقدر يكون مختلف)
    // كلاهما عبر QGroundControl.altitudeFrameExtraUnits() الحقيقية (مؤكدة بالـ grep)
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
    // ANGLE — مؤكدة حرفياً عبر grep بتاريخ 24 يوليو 2026 من:
    //   src/PlanView/SimpleItemEditor.qml:253
    //   readonly property real _angle: _valid ? Math.atan2(_dAlt, _dist) * 180 / Math.PI : 0
    //   readonly property bool  _valid: _dist > 0.1   (سطر 248)
    // نفس المعادلة والعتبة تماماً — atan2 وليس atan، وعتبة >0.1 وليس >0
    function _angleText(item) {
        if (!item) return "-.-"
        var dist = item.distance
        if (!(dist > 0.1)) return "-.-"
        var a = Math.atan2(item.altDifference, dist) * 180 / Math.PI
        return isNaN(a) ? "-.-" : (a >= 0 ? "+" : "") + a.toFixed(1) + "°"
    }
    // GRAD (%) — مؤكدة حرفياً عبر grep بتاريخ 24 يوليو 2026 من:
    //   src/PlanView/SimpleItemEditor.qml:251
    //   readonly property real _grad: _valid ? (_dAlt / _dist) * 100 : 0
    //   readonly property bool  _valid: _dist > 0.1   (سطر 248)
    // نفس المعادلة والعتبة تماماً، بدون أي فرق.
    function _gradPercentText(item) {
        if (!item) return "-.-"
        var dist = item.distance
        if (!(dist > 0.1)) return "-.-"
        var g = (item.altDifference / dist) * 100
        return isNaN(g) ? "-.-" : (g >= 0 ? "+" : "") + g.toFixed(1) + "%"
    }
    // لون GRAD/ANGLE حسب الإشارة — نفس ألوان ttsGeoTable الحرفية (سطر 382):
    //   ttsGeoTable._angle < 0 ? "#FF6600" : "#00FF88"   ، رمادي لو !_valid (سطر 381)
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
    function _addBelow() {
        if (!_mc || !_items) return
        var last = _items.count > 1 ? _items.get(_items.count - 1) : null
        var c = (last && last.coordinate && last.coordinate.isValid)
                ? last.coordinate : QtPositioning.coordinate(24.7136, 46.6753, 0)
        _mc.insertSimpleMissionItem(c, _items.count, true)
    }
    // ── خلية نصية قابلة للتعديل ──────────────────────────────────────────
    component EditCell: Rectangle {
        id: cell
        property string text:      ""
        property bool   editable:  true
        property color  textColor: wpRoot.cWhite
        signal committed(real value)
        height: wpRoot._rowH
        color:  ti.activeFocus ? Qt.rgba(0, 1, 0.53, 0.10) : "transparent"
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
        TextInput {
            id: ti
            anchors.fill:        parent
            anchors.leftMargin:  wpRoot._u * 0.5
            anchors.rightMargin: wpRoot._u * 0.5
            verticalAlignment:   TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            font.pixelSize:      wpRoot._fs
            font.family:         "monospace"
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
            elide:               Text.ElideRight
        }
    }
    component HeadCell: Rectangle {
        property string label: ""
        property string colName: ""   ///< اسم الخاصية بـ wpRoot (مثل "colType") — فارغ = بدون سحب
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
        // ── مقبض سحب لتوسيع/تصغير العمود بالماوس ─────────────────────────
        MouseArea {
            id: resizeMa
            visible:      colName !== ""
            enabled:      colName !== ""
            width:        wpRoot._u * 0.6
            anchors.right: parent.right
            anchors.top:   parent.top
            anchors.bottom: parent.bottom
            hoverEnabled: true
            preventStealing: true   // TTS: يمنع Flickable من سرقة السحب أثناء تحريك حافة العمود
            cursorShape:  Qt.SizeHorCursor
            property real _startGX: 0
            property real _startW:  0
            onPressed: (mouse) => {
                var g = resizeMa.mapToItem(null, mouse.x, mouse.y)
                _startGX = g.x
                _startW  = wpRoot[colName]
            }
            onPositionChanged: (mouse) => {
                if (!pressed) return
                var g = resizeMa.mapToItem(null, mouse.x, mouse.y)
                var delta = g.x - _startGX
                wpRoot[colName] = Math.max(wpRoot._u * 2.5, _startW + delta)
            }
            Rectangle {
                anchors.fill: parent
                color: (resizeMa.containsMouse || resizeMa.pressed) ? wpRoot.cNeon : "transparent"
                opacity: 0.6
            }
        }
    }
    // ══ TTS: طبقة حاجزة تمنع تسريب الضغط للخريطة تحت الجدول ══════════════
    // بدونها، الضغط على مساحة فاضية بالجدول (غير مستهلكة من زر/حقل) كان
    // ينفذ للخريطة تحته (يضيف نقطة مهمة رغم إن المستخدم يضغط على الجدول).
    // موضوعة أول عنصر جوّه wpRoot عشان تبقى "تحت" باقي المحتوى بترتيب
    // الأولوية (الأزرار والحقول تاخذ الضغطة أول، وهذي بس تمسك الباقي).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: {}   // تستهلك الضغطة بدون أي فعل — فقط توقفها هنا
    }
    // ══ END TTS CLICK BLOCKER ═════════════════════════════════════════════
    // ═════════════════════════════════════════════════════════════════════
    //  1. شريط العنوان
    // ═════════════════════════════════════════════════════════════════════
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
    // ═════════════════════════════════════════════════════════════════════
    //  2+3. لوحة ثابتة (# + TYPE) يسار الجدول + منطقة سكرول أفقي لباقي الأعمدة
    // ═════════════════════════════════════════════════════════════════════
    Item {
        id: tableBody
        anchors.top:    titleBar.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        // ── اللوحة الثابتة: # و TYPE، لا تتحرك مع سكرول باقي الأعمدة ────────
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
                reuseItems:  false   // TTS: يمنع تعليق حالة الهوفر/الفوكس بين الصفوف
                interactive: false            // السكرول العمودي يتبع الجدول الرئيسي
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
                            wpRoot.forceActiveFocus()   // TTS: يسحب التركيز عن أي حقل كتابة عالق بصف تاني
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
            // فاصل بصري بين اللوحة الثابتة ومنطقة السكرول
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cNeon; opacity: 0.5; z: 10 }
        }
        // ── منطقة قابلة للسكرول أفقياً (باقي الأعمدة) ───────────────────────
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
                        HeadCell { width: wpRoot.colLat;    label: wpRoot._curFieldName(0); colName: "colLat" }
                        HeadCell { width: wpRoot.colLon;    label: wpRoot._curFieldName(1); colName: "colLon" }
                        HeadCell { width: wpRoot.colAlt;    label: wpRoot._curAltHeaderLabel(); colName: "colAlt" }
                        HeadCell { width: wpRoot.colAct;    label: "DELETE";       colName: "colAct"  }
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
                    reuseItems: false   // TTS: يمنع تعليق حالة الهوفر/الفوكس بين الصفوف
                    ScrollBar.vertical: ScrollBar { }
                    delegate: Item {
                        id: rowItem
                        width:   wpList.width
                        height:  index > 0 ? wpRoot._rowH : 0   // index 0 = Planned Home، لا يُعرض
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
                            wpRoot.forceActiveFocus()   // TTS: يسحب التركيز عن أي حقل كتابة عالق بصف تاني
                            if (wpRoot._mc && rowItem._item) wpRoot._mc.setCurrentPlanViewSeqNum(rowItem._item.sequenceNumber, true)
                        }
                        }
                        Row {
                            anchors.fill: parent
                            // LAT / LON — تتحول لحقول ديناميكية (زي Pitch لـ Takeoff)
                            // لو نفس الصف ما يحدد إحداثيات، مصدرها Fact حقيقي مؤكد
                            EditCell {
                                width:     wpRoot.colLat
                                editable:  rowItem._item ? (rowItem._item.specifiesCoordinate || wpRoot._rowFieldFact(rowItem._item, 0) !== null) : false
                                textColor: rowItem._item && rowItem._item.specifiesCoordinate ? wpRoot.cWhite
                                         : (rowItem._item && wpRoot._rowFieldFact(rowItem._item, 0)) ? wpRoot.cOrange : wpRoot.cGrey
                                text: {
                                    if (!rowItem._item) return "0"
                                    if (rowItem._item.specifiesCoordinate) return rowItem._item.coordinate.latitude.toFixed(7)
                                    var f = wpRoot._rowFieldFact(rowItem._item, 0)
                                    return f ? f.rawValue.toString() : "—"
                                }
                                onCommitted: (v) => {
                                    if (rowItem._item && rowItem._item.specifiesCoordinate) {
                                        wpRoot._setLat(rowItem._item, v)
                                    } else {
                                        var f = wpRoot._rowFieldFact(rowItem._item, 0)
                                        if (f) f.rawValue = v
                                    }
                                }
                            }
                            EditCell {
                                width:     wpRoot.colLon
                                editable:  rowItem._item ? (rowItem._item.specifiesCoordinate || wpRoot._rowFieldFact(rowItem._item, 1) !== null) : false
                                textColor: rowItem._item && rowItem._item.specifiesCoordinate ? wpRoot.cWhite
                                         : (rowItem._item && wpRoot._rowFieldFact(rowItem._item, 1)) ? wpRoot.cOrange : wpRoot.cGrey
                                text: {
                                    if (!rowItem._item) return "0"
                                    if (rowItem._item.specifiesCoordinate) return rowItem._item.coordinate.longitude.toFixed(7)
                                    var f = wpRoot._rowFieldFact(rowItem._item, 1)
                                    return f ? f.rawValue.toString() : "—"
                                }
                                onCommitted: (v) => {
                                    if (rowItem._item && rowItem._item.specifiesCoordinate) {
                                        wpRoot._setLon(rowItem._item, v)
                                    } else {
                                        var f = wpRoot._rowFieldFact(rowItem._item, 1)
                                        if (f) f.rawValue = v
                                    }
                                }
                            }
                            // ALT — رمادي مقفول لو الأمر ما يحدد ارتفاع (specifiesAltitude)
                            // تصحيح: كان مربوط غلط بـ specifiesCoordinate، بسببه Takeoff
                            // (يحدد ارتفاع بدون إحداثيات) كان يظهر مقفول غلط
                            //
                            // تصحيح ثاني (24 يوليو 2026): FactTextField كان يعتمد على
                            // Fact.value/.units التلقائية، واللي فيها خلل حقيقي بـ QGC —
                            // بعض Facts الارتفاع (SimpleMissionItem._altitudeFact) تتبع
                            // إعداد "Horizontal Distance" غلط بدل "Vertical Distance"
                            // (مؤكد بالتحقيق مع المستخدم بتاريخ اليوم، السبب الجذري بكود
                            // C++ خارج نطاقنا). الحل: نفس الأسلوب اليدوي المُثبت فعلياً
                            // بملف المستخدم FlyViewCustomLayer.qml (_altText/_unitAlt) —
                            // نقرأ rawValue (متر SI ثابت دايماً) ونحوّله يدوياً عبر
                            // QGroundControl.unitsConversion الصريحة، بدل الاعتماد على
                            // Fact.value/.units المكسورة. التحويل العكسي (وقت الكتابة)
                            // عبر appSettingsVerticalDistanceUnitsToMeters — مؤكدة بالـ
                            // grep من src/QmlControls/QmlUnitsConversion.h.
                            Rectangle {
                                width:  wpRoot.colAlt
                                height: wpRoot._rowH
                                color:  "transparent"
                                Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: wpRoot.cBorder }
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: wpRoot._u * 0.2
                                    spacing: wpRoot._u * 0.3
                                    TextInput {
                                        id: altTi
                                        width: wpRoot._isGlobalAltMixed ? parent.width * 0.42 : parent.width * 0.6
                                        anchors.verticalCenter: parent.verticalCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        font.pixelSize: wpRoot._fs
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
                            // ── ACTIONS: DELETE فقط ──────────────────────────────
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
    // ── ديالوج اختيار الأمر — نفس MissionCommandDialog الأصلي بـ QGC حرفياً
    //    (المصدر: src/PlanView/MissionItemEditor.qml، مؤكد عبر الكود المصدري)
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