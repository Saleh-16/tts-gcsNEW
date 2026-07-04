import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
Item {
    id: root
    anchors.fill: parent
    property var parentToolInsets
    property var totalToolInsets: _toolInsets
    property var mapControl
    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       0
        leftEdgeCenterInset:    0
        leftEdgeBottomInset:    0
        rightEdgeTopInset:      0
        rightEdgeCenterInset:   0
        rightEdgeBottomInset:   0
        topEdgeLeftInset:       0
        topEdgeCenterInset:     0
        topEdgeRightInset:      0
        bottomEdgeLeftInset:    0
        bottomEdgeCenterInset:  0
        bottomEdgeRightInset:   0
    }
    // ── Palette ───────────────────────────────────────────────────────────
    readonly property color cBg:       "#0A0C0E"
    readonly property color cPanel:    "#111518"
    readonly property color cBorder:   "#1E2830"
    readonly property color cBorderHi: "#2E4050"
    readonly property color cNeon:     "#00FF88"
    readonly property color cNeonMid:  "#00CC6A"
    readonly property color cWhite:    "#DDE5EA"
    readonly property color cGrey:     "#4A6070"
    readonly property color cOrange:   "#FF6600"
    readonly property color cRed:      "#FF2244"
    readonly property color cGreyDark: "#1E2830"
    readonly property color cGreyMid:  "#3A4E5A"
    // ── UNIT SCALE (ScreenTools) ─ يتكيّف مع أي شاشة/دقة/إعدادات المستخدم ─
    // كل قياس بالواجهة أدناه = _u × مضاعف بدل ما يكون بكسل ثابت
    readonly property real _u: ScreenTools.defaultFontPixelWidth
    // ── Layout ────────────────────────────────────────────────────────────
    // نستخدم نسب من ارتفاع النافذة (بدل _u * قيمة) لأن هذي القياسات تقسّم
    // مساحة عمودية محددة. لو كانت مرتبطة بـ _u ممكن تتجاوز الشاشة على
    // نوافذ قصيرة الارتفاع
    readonly property real botPanH: root.height * 0.42
    readonly property real botBarH: root.height * 0.09
    readonly property int sidebarW: 0
    // ── Vehicle data ──────────────────────────────────────────────────────
    property var  _v:    QGroundControl.multiVehicleManager.activeVehicle
    property bool _ok:   _v !== null && _v !== undefined
    property var  _bat0: _ok && _v.batteries && _v.batteries.count > 0 ? _v.batteries.get(0) : null
    property real _bat:  _bat0 && _bat0.percentRemaining && _bat0.percentRemaining.value !== undefined ? _bat0.percentRemaining.value : 0
    property int  _msgCount: _ok ? _v.messageCount : 0
    property bool _msgWarn:  _ok ? _v.messageTypeWarning : false
    property bool _msgErr:   _ok ? _v.messageTypeError   : false
    property real _rawHdg:    _ok && _v.heading.rawValue         !== undefined && !isNaN(_v.heading.rawValue)         ? _v.heading.rawValue         : 0
    property real _rawSpd:    _ok && _v.airSpeed.rawValue        !== undefined && !isNaN(_v.airSpeed.rawValue)        ? _v.airSpeed.rawValue        : 0
    property real _rawAlt:    _ok && _v.altitudeAMSL.rawValue    !== undefined && !isNaN(_v.altitudeAMSL.rawValue)    ? _v.altitudeAMSL.rawValue    : 0
    property real _rawRoll:   _ok && _v.roll.rawValue            !== undefined && !isNaN(_v.roll.rawValue)            ? _v.roll.rawValue            : 0
    property real _rawPitch:  _ok && _v.pitch.rawValue           !== undefined && !isNaN(_v.pitch.rawValue)           ? _v.pitch.rawValue           : 0
    property real _dispHdg:      _ok && _v.heading.value         !== undefined && !isNaN(_v.heading.value)              ? _v.heading.value              : 0
    property real _dispSpd:      _ok && _v.airSpeed.value        !== undefined && !isNaN(_v.airSpeed.value)             ? _v.airSpeed.value             : 0
    property real _dispAlt:      _ok && _v.altitudeAMSL.value    !== undefined && !isNaN(_v.altitudeAMSL.value)         ? _v.altitudeAMSL.value         : 0
    property real _dispAlt_AGL:  _ok && _v.altitudeRelative.value !== undefined && !isNaN(_v.altitudeRelative.value)    ? _v.altitudeRelative.value     : 0
    property real _dispGndSpd:   _ok && _v.groundSpeed.value     !== undefined && !isNaN(_v.groundSpeed.value)          ? _v.groundSpeed.value          : 0
    // ── سرعة خام ثابتة بالمتر/الثانية دايمًا (SI)، بغض النظر عن إعداد وحدة عرض السرعة (km/h, kn, m/s...) ──
    // نستخدمها فقط بالحسابات الداخلية (زي ETA)؛ أما "_dispGndSpd" فتبقى للعرض المباشر لأنها تتبع إعداد المستخدم
    property real _rawGndSpd:    _ok && _v.groundSpeed.rawValue  !== undefined && !isNaN(_v.groundSpeed.rawValue)       ? _v.groundSpeed.rawValue       : 0
    // ── نصوص مطابقة 100% لنفس تنسيق QGC الأصلي (نأخذ الرقم من valueString مباشرة) ──
    // valueString مثال: "42.8 kn" — نفصل الرقم عن الوحدة عشان نستخدم كل جزء في مكانه بتصميمنا
    function _numOnly(vs) {
        if (!vs) return "0"
        var parts = vs.toString().trim().split(" ")
        return parts.length > 0 ? parts[0] : "0"
    }
    property string _spdText:     _ok ? _numOnly(_v.airSpeed.valueString)        : "0"
    property string _altText:     _ok ? _numOnly(_v.altitudeAMSL.valueString)    : "0"
    property string _altAglText:  _ok ? _numOnly(_v.altitudeRelative.valueString): "0"
    property string _gndSpdText:  _ok ? _numOnly(_v.groundSpeed.valueString)     : "0"
    property string _unitSpd:    _ok ? _v.airSpeed.units         : qsTr("m/s")
    property string _unitAlt:    _ok ? _v.altitudeAMSL.units     : qsTr("m")
    property string _unitAltAGL: _ok ? _v.altitudeRelative.units : qsTr("m")
    property string _unitGndSpd: _ok ? _v.groundSpeed.units      : qsTr("m/s")
    property string _unitVolt:   _bat0 && _bat0.voltage ? _bat0.voltage.units : qsTr("V")
    property string _unitWndSpd: _ok ? _v.wind.speed.units       : qsTr("m/s")
    property real _spdMax:  0
    property real _spdMin:  0
    property bool _spdInit: false
    on_DispGndSpdChanged: {
        if (_ok) {
            if (!_spdInit) {
                _spdMax  = _dispGndSpd
                _spdMin  = _dispGndSpd
                _spdInit = true
            } else {
                if (_dispGndSpd > _spdMax) _spdMax = _dispGndSpd
                if (_dispGndSpd < _spdMin) _spdMin = _dispGndSpd
            }
        }
    }
    Column {
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.right:      parent.right
            anchors.left:       parent.left
            anchors.leftMargin: root.sidebarW
            spacing: 0
            Item {
                id: videoArea
                width:  parent.width
                height: parent.height - root.botPanH - root.botBarH
                Image {
                    anchors.fill: parent
                    source:   "qrc:/res/terrain_bg.png"
                    fillMode: Image.PreserveAspectCrop
                }
                // ── MINI HEADING TAPE ─ اتجاه معكوس ─ مقياسها نسبة من HUD نفسه ─
                Item {
                    id: miniHdgTape
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    // ── فوق مستوى SPD / ALT AMSL بمسافة إضافية ──
                    anchors.topMargin: spdTape.y - height - root._u * 3
                    z: 200
                    // العرض: 42% من عرض الفيديو (حدود آمان بـ _u)
                    // الارتفاع: 9% من ارتفاع الفيديو (حدود آمان بـ _u)
                    width:  Math.max(root._u * 32, Math.min(root._u * 70, parent.width * 0.42))
                    height: Math.max(root._u *  6, Math.min(root._u * 12, parent.height * 0.09))
                    clip: true
                    // ── Mini Heading Scale: كل شي داخلها يتبع حجمها هي (مو _u مباشرة)
                    readonly property real _mhs: height / 45
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.4)
                    }
                    Row {
                        id: miniHdgRow
                        width: miniHdgTape._mhs * 40 * 60
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        // معكوس
                        anchors.horizontalCenterOffset: (safeHdgMini % 10) * miniHdgTape._mhs * 6
                        property real safeHdgMini: Number.isFinite(root._rawHdg) ? root._rawHdg : 0
                        Repeater {
                            model: 40
                            delegate: Item {
                                width: miniHdgTape._mhs * 60; height: miniHdgTape._mhs * 36
                                // معكوس
                                property int normDeg: ((Math.floor(miniHdgRow.safeHdgMini / 10) + 20 - index) * 10 % 360 + 360) % 360
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.topMargin: miniHdgTape._mhs * 4
                                    width: 1; height: normDeg % 30 === 0 ? miniHdgTape._mhs * 14 : miniHdgTape._mhs * 8
                                    color: normDeg === 0 ? root.cRed : root.cNeonMid
                                }
                                Text {
                                    visible: normDeg % 10 === 0
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    font.bold: true
                                    anchors.bottomMargin: miniHdgTape._mhs * 4
                                    text: normDeg===0   ? qsTr("N") :
                                          normDeg===90  ? qsTr("E") :
                                          normDeg===180 ? qsTr("S") :
                                          normDeg===270 ? qsTr("W") : normDeg.toString()
                                    font.pixelSize: normDeg % 30 === 0 ? miniHdgTape._mhs * 14 : miniHdgTape._mhs * 11
                                    font.family: "monospace"
                                    color: normDeg===0 ? root.cRed : (normDeg % 90 === 0 ? root.cWhite : root.cNeonMid)
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: miniHdgTape._mhs * 2
                        width: miniHdgTape._mhs * 40; height: miniHdgTape._mhs * 16
                        color: "transparent"
                        border.color: root.cNeonMid
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: (Number.isFinite(root._dispHdg) ? root._dispHdg : 0).toFixed(0).padStart(3,"0")
                            font.pixelSize: miniHdgTape._mhs * 9; font.bold: true; font.family: "monospace"; color: root.cNeonMid
                        }
                    }
                    Canvas {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: miniHdgTape._mhs * 18; height: miniHdgTape._mhs * 11
                        property real hs: miniHdgTape._mhs
                        onHsChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.clearRect(0,0,width,height)
                            c.fillStyle = root.cNeon
                            c.beginPath(); c.moveTo(0,0); c.lineTo(width,0); c.lineTo(width/2,height); c.closePath(); c.fill()
                        }
                    }
                }
                // ── ARTIFICIAL HORIZON ─ وضع "المراقب الخارجي" مع تكيّف كامل ─
                // كل الرسم داخل الأفق يعتمد على _hs (Horizon Scale)
                // بحيث الأفق كامل يكبر ويصغر مع مساحة الفيديو
                Item {
                    id: ahCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    // Horizon Scale: يعتمد على أصغر بُعد مع حدود آمان (بحيث يتكيّف عمودياً وأفقياً)
                    readonly property real _hs: Math.max(0.6, Math.min(2.5, Math.min(width / 700, height / 400)))
                    Canvas {
                        id: ahCanvas
                        anchors.fill: parent
                        property real ahRoll:  root._rawRoll
                        property real ahPitch: root._rawPitch
                        property real hs:      ahCenter._hs
                        onAhRollChanged:  requestPaint()
                        onAhPitchChanged: requestPaint()
                        onHsChanged:      requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width/2, cy = height/2
                            var s  = hs   // Horizon Scale — كل رقم يترضب في * s
                            // معكوس: pitch إشارة سالبة، بكسل لكل درجة = 3.9 * s
                            var pitchPx = -ahPitch * 3.9 * s
                            var rollRad = ahRoll * Math.PI / 180
                            ctx.save()
                            ctx.translate(cx, cy)
                            ctx.rotate(rollRad)
                            function pitchLine(deg, lineWidth, label) {
                                var y = -deg * 3.9 * s + pitchPx
                                ctx.strokeStyle = "rgba(255,255,255,0.9)"
                                ctx.lineWidth = 1.5
                                ctx.beginPath()
                                ctx.moveTo(-lineWidth/2, y); ctx.lineTo(lineWidth/2, y)
                                ctx.stroke()
                                if (label !== "") {
                                    ctx.fillStyle = "rgba(255,255,255,0.9)"
                                    ctx.font = (13 * s) + "px monospace"
                                    ctx.textAlign = "center"; ctx.textBaseline = "middle"
                                    ctx.fillText(label, -lineWidth/2 - 18*s, y)
                                    ctx.fillText(label,  lineWidth/2 + 18*s, y)
                                }
                            }
                            pitchLine(20, 140*s, "20")
                            pitchLine(10, 100*s, "10")
                            pitchLine(-10, 100*s, "-10")
                            pitchLine(-20, 140*s, "-20")
                            var hy = pitchPx
                            ctx.strokeStyle = root.cNeon
                            ctx.lineWidth = 1.5
                            ctx.beginPath()
                            ctx.moveTo(-140*s, hy); ctx.lineTo(140*s, hy)
                            ctx.stroke()
                            ctx.restore()
                            // Aircraft symbol (fixed brackets around center — no roll rotation)
                            ctx.strokeStyle = root.cWhite; ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.moveTo(cx-150*s, cy+20*s); ctx.lineTo(cx-110*s, cy+20*s); ctx.lineTo(cx-90*s, cy)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(cx+150*s, cy+20*s); ctx.lineTo(cx+110*s, cy+20*s); ctx.lineTo(cx+90*s, cy)
                            ctx.stroke()
                            // Roll indicator triangle
                            ctx.save()
                            ctx.translate(cx, cy)
                            ctx.rotate(rollRad)
                            ctx.fillStyle = root.cNeon
                            ctx.beginPath()
                            ctx.moveTo(-6*s, -100*s); ctx.lineTo(0, -90*s); ctx.lineTo(6*s, -100*s)
                            ctx.closePath(); ctx.fill()
                            ctx.restore()
                        }
                    }
                    // ── Center crosshair — يتكيّف مع _hs ──
                    Canvas {
                        anchors.centerIn: parent
                        width: 60 * ahCenter._hs; height: 60 * ahCenter._hs
                        property real hs: ahCenter._hs
                        onHsChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.clearRect(0,0,width,height)
                            var cx=width/2, cy=height/2, s=hs
                            c.strokeStyle = root.cNeon; c.lineWidth = 1.5
                            c.beginPath(); c.arc(cx,cy,14*s,0,Math.PI*2); c.stroke()
                            var dirs=[[0,-1],[0,1],[-1,0],[1,0]]
                            for (var i=0;i<4;i++) {
                                c.beginPath()
                                c.moveTo(cx+dirs[i][0]*17*s, cy+dirs[i][1]*17*s)
                                c.lineTo(cx+dirs[i][0]*26*s, cy+dirs[i][1]*26*s)
                                c.stroke()
                            }
                            c.fillStyle = root.cNeon
                            c.beginPath(); c.arc(cx,cy,2*s,0,Math.PI*2); c.fill()
                        }
                    }
                    // ── Dashed horizontal line under center — يتكيّف مع _hs ──
                    Canvas {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 14 * ahCenter._hs
                        width: 240 * ahCenter._hs; height: 4
                        property real hs: ahCenter._hs
                        onHsChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.clearRect(0,0,width,height)
                            c.strokeStyle = root.cNeon; c.lineWidth = 1.5
                            c.setLineDash([6*hs, 5*hs])
                            c.beginPath()
                            c.moveTo(0, 2); c.lineTo(width, 2)
                            c.stroke()
                            c.setLineDash([])
                        }
                    }
                    // ── Small tick marks row across center — يتكيّف مع _hs ──
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 56 * ahCenter._hs
                        Repeater {
                            model: 6
                            Rectangle {
                                width: 2 * ahCenter._hs; height: 14 * ahCenter._hs
                                color: index === 2 || index === 3 ? "transparent" : root.cNeon
                            }
                        }
                    }
                }
                Item {
                    id: spdTape
                    // Dynamic position + size
                    // الارتفاع يتكيف مع مساحة الفيديو (55% ، حدود آمان بـ _u)
                    // العرض يتبع نسبة التصميم الأصلي (7.2:28)
                    // كل العناصر الداخلية تعتمد على _ts (Tape Scale)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -Math.max(root._u * 15, Math.min(root._u * 50, parent.width * 0.25))
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    height: Math.max(root._u * 18, Math.min(root._u * 32, parent.height * 0.55))
                    width:  height * (7.2 / 28)
                    // ── Tape Scale: كل الخطوط والمواقع داخل الشريط تعتمد على _ts
                    readonly property real _ts: height / 28
                    Text {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("SPD") + "\n" + root._unitSpd
                        font.pixelSize: spdTape._ts * 2; font.bold: true; font.family: "monospace"; color: root.cNeon
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item {
                        anchors.top: parent.top
                        anchors.topMargin: spdTape._ts * 5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: spdTape._ts * 16.8
                        clip: true
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: (root._rawSpd % 20) * spdTape._ts * 0.84
                            spacing: spdTape._ts * 2.8
                            Repeater {
                                model: 9
                                delegate: Row {
                                    spacing: spdTape._ts * 0.6
                                    property real val: ((root._rawSpd/20|0) + 4 - index) * 20
                                    Rectangle { width: spdTape._ts * 1.6; height: Math.max(1, spdTape._ts * 0.2); color: root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                                    Text { text: Math.max(0, val).toFixed(0); font.bold:true; font.pixelSize: spdTape._ts * 2; font.family:"monospace"; color: root.cWhite }
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        // ── موقع ثابت دايماً (بدون معادلة تحرك) — الأرقام هي اللي تتزحلق
                        // من ورا، ومعادلة scroll بالشريط نفسه مصممة عشان القيمة الحالية
                        // تصير بالضبط بهذي النقطة الثابتة تلقائياً ──
                        anchors.topMargin: spdTape._ts * 11.7
                        height: spdTape._ts * 3.4
                        color: root.cNeon
                        clip: true
                        Text {
                            anchors.centerIn: parent
                            text: root._spdText
                            font.bold:true; color:root.cBg; font.family:"monospace"
                            width: parent.width - (spdTape._ts * 1.2)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: spdTape._ts * 0.8
                            font.pixelSize: spdTape._ts * 2.2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.AlignRight
                        }
                    }
                }
                Item {
                    id: altTape
                    // موضع بالنسبة لمركز الفيديو (زي الأفق) — يبعد 25% من العرض لليمين
                    // مع حد أدنى 150px وحد أعلى 500px عشان يظل بمكانه على كل الشاشات
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: Math.max(root._u * 15, Math.min(root._u * 50, parent.width * 0.25))
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    height: Math.max(root._u * 18, Math.min(root._u * 32, parent.height * 0.55))
                    width:  height * (7.6 / 28)
                    // ── Tape Scale ──
                    readonly property real _ts: height / 28
                    Text {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("ALT AMSL") + "\n" + root._unitAlt
                        font.pixelSize: altTape._ts * 2; font.bold: true; font.family: "monospace"; color: root.cNeon
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item {
                        anchors.top: parent.top
                        anchors.topMargin: altTape._ts * 5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: altTape._ts * 16.8
                        clip: true
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: (root._rawAlt % 100) * altTape._ts * 0.168
                            spacing: altTape._ts * 2.8
                            Repeater {
                                model: 9
                                delegate: Row {
                                    spacing: altTape._ts * 0.6
                                    property real val: ((root._rawAlt/100|0) + 4 - index) * 100
                                    Text { text: val.toFixed(0); font.bold:true; font.pixelSize: altTape._ts * 2; font.family:"monospace"; color: root.cWhite }
                                    Rectangle { width: altTape._ts * 1.6; height: Math.max(1, altTape._ts * 0.2); color: root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        // ── موقع ثابت دايماً (بدون معادلة تحرك) — الأرقام هي اللي تتزحلق
                        // من ورا، ومعادلة scroll بالشريط نفسه مصممة عشان القيمة الحالية
                        // تصير بالضبط بهذي النقطة الثابتة تلقائياً ──
                        anchors.topMargin: altTape._ts * 11.7
                        height: altTape._ts * 3.4
                        color: root.cNeon
                        clip: true
                        Text {
                            anchors.centerIn: parent
                            text: root._altText
                            font.bold:true; color:root.cBg; font.family:"monospace"
                            width: parent.width - (altTape._ts * 1.2)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: altTape._ts * 0.8
                            font.pixelSize: altTape._ts * 2.2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.AlignRight
                        }
                    }
                }
                Rectangle {
                    id: altitudeCard
                    // Dynamic adaptive positioning + sizing
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: Math.max(root._u * 25, Math.min(root._u * 75, parent.width * 0.40))
                    width:  Math.max(root._u * 12, Math.min(root._u * 22, parent.width * 0.14))
                    height: Math.max(root._u *  9, Math.min(root._u * 17, parent.width * 0.11))
                    // ── Card Scale: كل الخطوط والفراغات داخل الكارد تعتمد على _cs
                    // بحيث تتناسب تلقائياً مع حجم الكارد نفسه
                    readonly property real _cs: width / 16.8
                    radius: _cs * 1
                    color: Qt.rgba(0.02, 0.03, 0.04, 0.82)
                    border.color: root.cNeon
                    border.width: 1.5
                    z: 100
                    Column {
                        anchors.fill: parent
                        anchors.margins: altitudeCard._cs * 1.2
                        spacing: altitudeCard._cs * 0.4
                        Text {
                            text: qsTr("ALTITUDE")
                            font.pixelSize: altitudeCard._cs * 1.1; font.bold: true; font.letterSpacing: altitudeCard._cs * 0.15
                            font.family: "monospace"; color: root.cWhite
                        }
                        Row {
                            spacing: altitudeCard._cs * 0.4
                            Text {
                                text: root._altText
                                font.pixelSize: altitudeCard._cs * 3.4; font.bold: true
                                font.family: "monospace"; color: root.cNeon
                            }
                            Text {
                                text: root._unitAlt
                                font.pixelSize: altitudeCard._cs * 1.4; font.family: "monospace"; color: root.cWhite
                                anchors.bottom: parent.bottom; anchors.bottomMargin: altitudeCard._cs * 0.6
                            }
                        }
                        Item { width: 1; height: altitudeCard._cs * 0.4 }
                        Row {
                            spacing: altitudeCard._cs * 0.6
                            Text { text: qsTr("AGL");  font.pixelSize: altitudeCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: altitudeCard._cs * 4 }
                            Text { text: root._altAglText + " " + root._unitAltAGL; font.pixelSize: altitudeCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                        Row {
                            spacing: altitudeCard._cs * 0.6
                            Text { text: qsTr("AMSL"); font.pixelSize: altitudeCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: altitudeCard._cs * 4 }
                            Text { text: root._altText + " " + root._unitAlt; font.pixelSize: altitudeCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                    }
                }
                Rectangle {
                    id: groundSpeedCard
                    // Dynamic adaptive positioning + sizing
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: root._u * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -Math.max(root._u * 25, Math.min(root._u * 75, parent.width * 0.40))
                    width:  Math.max(root._u * 12, Math.min(root._u * 22, parent.width * 0.14))
                    height: Math.max(root._u *  9, Math.min(root._u * 17, parent.width * 0.11))
                    // ── Card Scale ──
                    readonly property real _cs: width / 16.8
                    radius: _cs * 1
                    color: Qt.rgba(0.02, 0.03, 0.04, 0.82)
                    border.color: root.cNeon
                    border.width: 1.5
                    z: 100
                    Column {
                        anchors.fill: parent
                        anchors.margins: groundSpeedCard._cs * 1.2
                        spacing: groundSpeedCard._cs * 0.4
                        Text {
                            text: qsTr("GROUND SPEED")
                            font.pixelSize: groundSpeedCard._cs * 1.1; font.bold: true; font.letterSpacing: groundSpeedCard._cs * 0.15
                            font.family: "monospace"; color: root.cWhite
                        }
                        Row {
                            spacing: groundSpeedCard._cs * 0.4
                            Text {
                                text: root._gndSpdText
                                font.pixelSize: groundSpeedCard._cs * 3.4; font.bold: true
                                font.family: "monospace"; color: root.cNeon
                            }
                            Text {
                                text: root._unitGndSpd
                                font.pixelSize: groundSpeedCard._cs * 1.4; font.family: "monospace"; color: root.cWhite
                                anchors.bottom: parent.bottom; anchors.bottomMargin: groundSpeedCard._cs * 0.6
                            }
                        }
                        Item { width: 1; height: groundSpeedCard._cs * 0.4 }
                        Row {
                            spacing: groundSpeedCard._cs * 0.6
                            Text { text: qsTr("MAX"); font.pixelSize: groundSpeedCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: groundSpeedCard._cs * 3.4 }
                            Text { text: root._spdMax.toFixed(1) + " " + root._unitGndSpd; font.pixelSize: groundSpeedCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                        Row {
                            spacing: groundSpeedCard._cs * 0.6
                            Text { text: qsTr("MIN"); font.pixelSize: groundSpeedCard._cs * 1.2; font.family: "monospace"; color: root.cGrey; width: groundSpeedCard._cs * 3.4 }
                            Text { text: root._spdMin.toFixed(1) + " " + root._unitGndSpd; font.pixelSize: groundSpeedCard._cs * 1.2; font.bold: true; font.family: "monospace"; color: root.cWhite }
                        }
                    }
                }
            }
            Item {
                id: middleArea
                width:  parent.width
                height: root.botPanH
                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    height: 1; color: root.cBorderHi
                }
                Row {
                    anchors.fill: parent
                    Rectangle {
                        id: mapPanel
                        width: parent.width * 0.50; height: parent.height
                        color: "transparent"; border.color: root.cBorder; border.width: 1
                        Rectangle {
                            id: mapHeader
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: root._u * 3; color: Qt.rgba(0, 0, 0, 0.5)
                            border.color: root.cBorder; border.width: 1
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: root._u * 1.4
                                text: qsTr("TACTICAL MAP")
                                font.pixelSize: root._u * 1; font.bold: true; font.letterSpacing: root._u * 0.15
                                font.family: "monospace"; color: root.cWhite
                            }
                        }
                        Item { anchors.top: mapHeader.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom }
                    }
                    Rectangle { width: 1; height:parent.height; color:root.cBorderHi }
                    Rectangle {
                        id: missionPanel
                        width: parent.width - mapPanel.width - 1; height: parent.height
                        color: root.cPanel; border.color: root.cBorder; border.width: 1
                        Rectangle {
                            id: missionHeader
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            height: root._u * 3; color: Qt.rgba(0, 0, 0, 0.5)
                            border.color: root.cBorder; border.width: 1
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: root._u * 1.4
                                text: qsTr("MISSION / TARGETS")
                                font.pixelSize: root._u * 1; font.bold: true; font.letterSpacing: root._u * 0.15
                                font.family: "monospace"; color: root.cWhite
                            }
                        }
                        // ── جدول عناصر المهمة (Mission Items Table) ──
                        Item {
                            id: missionTableRoot
                            anchors.top: missionHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            // ── نقرأ من نفس مصدر الخريطة (planMasterController) أولاً
                            // ── لو فاضي، نرجع لبيانات المركبة الفعلية (missionManager) كخيار احتياطي
                            readonly property var _planItems: {
                                try {
                                    if (typeof globals !== "undefined" && globals.planMasterControllerFlyView
                                        && globals.planMasterControllerFlyView.missionController
                                        && globals.planMasterControllerFlyView.missionController.visualItems) {
                                        return globals.planMasterControllerFlyView.missionController.visualItems
                                    }
                                } catch (e) { }
                                return null
                            }
                            readonly property var _vehicleItems: root._ok && root._v.missionManager && root._v.missionManager.missionItems ? root._v.missionManager.missionItems : null
                            readonly property var _missionItems: (_planItems && _planItems.count > 0) ? _planItems : _vehicleItems
                            readonly property int _itemCount: _missionItems ? _missionItems.count : 0
                            readonly property int _curSeq: root._ok && root._v.missionItemIndex && root._v.missionItemIndex.value !== undefined ? root._v.missionItemIndex.value : -1
                            // ── نستبعد الصفوف اللي ماهي نقاط ملاحية حقيقية (زي أوامر إعدادات الكاميرا
                            // اللي ماعندها ارتفاع محدد إطلاقًا) — نبقي بس النقاط اللي فيها بيانات ارتفاع فعلية ──
                            readonly property var _validIndices: {
                                var arr = []
                                if (!_missionItems) return arr
                                for (var i = 0; i < _itemCount; i++) {
                                    var mi = _missionItems.get(i)
                                    if (mi && mi.altitude !== undefined && mi.altitude.value !== undefined) {
                                        arr.push(i)
                                    }
                                }
                                return arr
                            }
                            // ── رأس الجدول (أسماء الأعمدة) — عروض نسبية تغطي العرض الكامل ──
                            Item {
                                id: tableHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: root._u * 3.2
                                readonly property real cSeq:   width * 0.06
                                readonly property real cType:  width * 0.18
                                readonly property real cName:  width * 0.20
                                readonly property real cCoord: width * 0.36
                                readonly property real cStat:  width * 0.20
                                Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.35) }
                                Row {
                                    anchors.fill: parent
                                    Text { width: tableHeader.cSeq;   height: parent.height; verticalAlignment: Text.AlignVCenter; text: "#";              font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey; leftPadding: root._u * 0.6 }
                                    Text { width: tableHeader.cType;  height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("TYPE");     font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                    Text { width: tableHeader.cName;  height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("NAME");     font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                    Text { width: tableHeader.cCoord; height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("COORDINATES"); font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                    Text { width: tableHeader.cStat;  height: parent.height; verticalAlignment: Text.AlignVCenter; text: qsTr("STATUS");   font.pixelSize: root._u * 1.4; font.bold: true; font.family: "monospace"; color: root.cGrey }
                                }
                            }
                            Rectangle { anchors.top: tableHeader.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.cBorderHi }
                            // ── صفوف الجدول (تُقرأ من مهمة المركبة الفعلية) ──
                            // ملاحظة إصلاح: بدل الوصول لبيانات الجدول عبر "parent.parent" داخل الـ delegate
                            // (غير موثوق لأن ListView يضع الـ delegate داخل contentItem داخلي، فسلسلة
                            // parent.parent ما توصل للعنصر الصحيح وترجع null) — نمرر البيانات كخصائص
                            // مباشرة على الـ ListView نفسه ونوصل لها داخل الـ delegate عبر ListView.view.xxx
                            // بشكل مضمون دائمًا. كذلك: أُزيلت anchors.fill من داخل Row (ممنوعة)، واستُبدل
                            // الـ delegate نفسه من Row إلى Item يحوي Row داخلي بدل ما يكون هو نفسه Row.
                            ListView {
                                id: missionListView
                                anchors.top: tableHeader.bottom
                                anchors.topMargin: 1
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                clip: true
                                model: parent._validIndices
                                property var missionItemsRef: parent._missionItems
                                property int curSeqRef:       parent._curSeq
                                property int itemCountRef:    parent._itemCount
                                delegate: Item {
                                    id: rowRoot
                                    width: ListView.view.width
                                    height: root._u * 3.6
                                    // ── modelData = الفهرس الحقيقي بمصفوفة المهمة الأصلية (بعد الفلترة)
                                    // بينما index = ترتيب الصف بالجدول المعروض بس (يُستخدم للترقيم #)
                                    property int realIndex: modelData
                                    property var _mi: ListView.view.missionItemsRef ? ListView.view.missionItemsRef.get(realIndex) : null
                                    readonly property bool _isCurrent: realIndex === ListView.view.curSeqRef
                                    readonly property bool _isDone: ListView.view.curSeqRef >= 0 && realIndex < ListView.view.curSeqRef
                                    Rectangle {
                                        anchors.fill: parent
                                        color: index % 2 === 0 ? Qt.rgba(1,1,1,0.02) : "transparent"
                                    }
                                    Row {
                                        anchors.fill: parent
                                        Text {
                                            width: tableHeader.cSeq; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: (index + 1).toString()
                                            font.pixelSize: root._u * 1.4; font.family: "monospace"; color: root.cWhite
                                            leftPadding: root._u * 0.6
                                        }
                                        Text {
                                            width: tableHeader.cType; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._mi && rowRoot._mi.commandName !== undefined ? rowRoot._mi.commandName
                                                : (realIndex === 0 ? qsTr("TAKEOFF") : (realIndex === ListView.view.itemCountRef - 1 ? qsTr("LAND") : qsTr("WAYPOINT")))
                                            font.pixelSize: root._u * 1.3; font.bold: true; font.family: "monospace"; color: root.cNeon
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: tableHeader.cName; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._mi && rowRoot._mi.missionItemName !== undefined ? rowRoot._mi.missionItemName : ("WPT-" + (realIndex + 1))
                                            font.pixelSize: root._u * 1.3; font.family: "monospace"; color: root.cWhite
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: tableHeader.cCoord; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._mi && rowRoot._mi.coordinate !== undefined
                                                  ? rowRoot._mi.coordinate.latitude.toFixed(6) + " N  " + rowRoot._mi.coordinate.longitude.toFixed(6) + " E"
                                                  : "--"
                                            font.pixelSize: root._u * 1.2; font.family: "monospace"; color: root.cWhite
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: tableHeader.cStat; height: parent.height; verticalAlignment: Text.AlignVCenter
                                            text: rowRoot._isCurrent ? qsTr("ACTIVE") : (rowRoot._isDone ? qsTr("DONE") : qsTr("PENDING"))
                                            font.pixelSize: root._u * 1.3; font.bold: true; font.family: "monospace"
                                            color: rowRoot._isCurrent ? root.cNeon : (rowRoot._isDone ? "#4ADE80" : root.cOrange)
                                        }
                                    }
                                }
                                // رسالة عند عدم وجود مهمة
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.count === 0
                                    text: qsTr("NO MISSION LOADED")
                                    font.pixelSize: root._u * 1; font.family: "monospace"; color: root.cGrey
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: statusBar
                width: parent.width; height: root.botBarH
                color: root.cPanel; border.color: root.cBorder; border.width: 1
                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.cBorderHi }
                Row {
                    anchors.fill: parent
                    spacing: 0
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        Text {
                            text: qsTr("WIND"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.5
                            Canvas {
                                id: windArrowCanvas
                                width: root._u * 4.5; height: root._u * 4.5; anchors.verticalCenter:parent.verticalCenter
                                // ── زاوية دوران السهم = اتجاه الرياح الحقيقي القادم من المركبة ──
                                property real windDeg: root._ok && root._v.wind.direction.value !== undefined && !isNaN(root._v.wind.direction.value)
                                                        ? root._v.wind.direction.value : 0
                                onWindDegChanged: requestPaint()
                                onPaint: {
                                    var c=getContext("2d"); c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cGreyMid; c.lineWidth=1
                                    c.beginPath(); c.arc(15,15,12,0,Math.PI*2); c.stroke()
                                    // ── السهم يشير لاتجاه هبوب الرياح (from-direction)، بنفس معيار عرض QGC الأصلي ──
                                    c.save(); c.translate(15,15); c.rotate(windDeg*Math.PI/180)
                                    c.strokeStyle=root.cNeon; c.lineWidth=2
                                    c.beginPath(); c.moveTo(0,-11); c.lineTo(0,11); c.stroke()
                                    c.fillStyle=root.cNeon
                                    c.beginPath(); c.moveTo(-4,3); c.lineTo(0,-10); c.lineTo(4,3); c.closePath(); c.fill()
                                    c.restore()
                                }
                            }
                            Column {
                                spacing: root._u * 0.3; anchors.verticalCenter:parent.verticalCenter
                                Text {
                                    text: root._ok ? root._v.wind.speed.valueString : ("– " + root._unitWndSpd)
                                    font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                }
                                Text {
                                    text: root._ok && root._v.wind.direction.value !== undefined ?
                                          root._v.wind.direction.value.toFixed(0) + "°" : "–°"
                                    font.pixelSize: root._u * 1.5; color:root.cGrey; font.family:"monospace"
                                }
                            }
                        }
                    }
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        Text {
                            text: qsTr("WAYPOINTS"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.2
                            Canvas {
                                width: root._u * 3; height: root._u * 3; anchors.verticalCenter:parent.verticalCenter
                                onPaint: {
                                    var c=getContext("2d"); c.clearRect(0,0,width,height)
                                    c.strokeStyle=root.cNeon; c.lineWidth=2
                                    c.beginPath(); c.arc(10,10,8,0,Math.PI*2); c.stroke()
                                    c.fillStyle=root.cNeon
                                    c.beginPath(); c.arc(10,10,3,0,Math.PI*2); c.fill()
                                }
                            }
                            Column {
                                spacing: root._u * 0.3; anchors.verticalCenter:parent.verticalCenter
                                Text {
                                    text: {
                                    if (!root._ok) return "– / –"
                                    var rawCur = root._v.missionItemIndex && root._v.missionItemIndex.value !== undefined ? root._v.missionItemIndex.value : -1
                                    var validArr = missionTableRoot._validIndices
                                    if (!validArr || validArr.length === 0) return "– / –"
                                    var pos = validArr.indexOf(rawCur)
                                    var cur = pos >= 0 ? (pos + 1) : "–"
                                    var tot = validArr.length
                                    return cur + " / " + tot
                                }
                                    font.pixelSize: root._u * 2.7; font.bold:true; color:root.cNeon; font.family:"monospace"
                                }
                                Text { text: qsTr("NEXT:") + " –"; font.pixelSize: root._u * 1.35; color:root.cGrey; font.family:"monospace" }
                            }
                        }
                    }
                    Item {
                        id: distToNextBox
                        width: parent.width / 6; height: parent.height
                        clip: true
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        Text {
                            text: qsTr("DIST TO NEXT"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 0.45
                            // ── المسافة الفعلية من موقع المركبة الحالي إلى النقطة القادمة بالمهمة ──
                            // (مو المسافة لنقطة الإقلاع/Home — دي مسافة حقيقية بين إحداثيتين)
                            readonly property var _nextItem: {
                                if (!root._ok) return null
                                var seq = root._v.missionItemIndex && root._v.missionItemIndex.value !== undefined ? root._v.missionItemIndex.value : -1
                                if (seq < 0) return null
                                var candidate = null
                                try {
                                    if (typeof globals !== "undefined" && globals.planMasterControllerFlyView
                                        && globals.planMasterControllerFlyView.missionController
                                        && globals.planMasterControllerFlyView.missionController.visualItems
                                        && globals.planMasterControllerFlyView.missionController.visualItems.count > 0) {
                                        var planItems = globals.planMasterControllerFlyView.missionController.visualItems
                                        if (seq < planItems.count) candidate = planItems.get(seq)
                                    }
                                } catch (e) { }
                                if (!candidate && root._v.missionManager && root._v.missionManager.missionItems) {
                                    var items = root._v.missionManager.missionItems
                                    if (seq < items.count) candidate = items.get(seq)
                                }
                                // ── تجاهل النقاط بإحداثيات وهمية (Null Island 0,0) — زي أوامر RTL
                                // اللي إحداثياتها تُحسب ديناميكيًا وقت التنفيذ الفعلي، مو مخزّنة بالمهمة ──
                                if (candidate && candidate.coordinate !== undefined) {
                                    var lat = candidate.coordinate.latitude
                                    var lon = candidate.coordinate.longitude
                                    if (Math.abs(lat) < 0.0001 && Math.abs(lon) < 0.0001) return null
                                }
                                return candidate
                            }
                            readonly property bool _hasNextCoord: _nextItem !== null && _nextItem.coordinate !== undefined && root._ok && root._v.coordinate !== undefined
                            readonly property real _distValMeters: _hasNextCoord ? root._v.coordinate.distanceTo(_nextItem.coordinate) : -1
                            readonly property real _etaSec: (_distValMeters >= 0 && root._rawGndSpd > 0.3) ? (_distValMeters / root._rawGndSpd) : -1
                            // ── احترام وحدة القياس المفعّلة بإعدادات QGC (Feet/Meters) بدل التثبيت على المتر ──
                            // ملاحظة: enum HorizontalDistanceUnits بمصدر QGC: Feet=0, Meters=1
                            // ملاحظة أهم: unitsSettings موجودة تحت settingsManager، مو تحت QGroundControl مباشرة
                            readonly property bool _useFeet: QGroundControl.settingsManager && QGroundControl.settingsManager.unitsSettings
                                                              && QGroundControl.settingsManager.unitsSettings.horizontalDistanceUnits
                                                              && QGroundControl.settingsManager.unitsSettings.horizontalDistanceUnits.rawValue === 0
                            readonly property string _distText: {
                                if (_distValMeters < 0) return qsTr("-- ") + (_useFeet ? "ft" : "m")
                                var val = _useFeet ? (_distValMeters / 0.3048) : _distValMeters
                                return val.toFixed(0) + " " + (_useFeet ? "ft" : "m")
                            }
                            readonly property string _etaText: {
                                if (_etaSec < 0) return "--:--:--"
                                var s = Math.floor(_etaSec)
                                var h = Math.floor(s / 3600)
                                var m = Math.floor((s % 3600) / 60)
                                var ss = s % 60
                                return String(h).padStart(2,"0") + ":" + String(m).padStart(2,"0") + ":" + String(ss).padStart(2,"0")
                            }
                            Column {
                                spacing: root._u * 0.4
                                Row {
                                    spacing: root._u * 0.9
                                    Text { text:"→"; font.pixelSize: root._u * 2.7; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                                    Text {
                                        text: parent.parent.parent._distText
                                        font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                        anchors.verticalCenter:parent.verticalCenter
                                    }
                                }
                                Row {
                                    spacing: root._u * 0.9
                                    Text { text:"◷"; font.pixelSize: root._u * 2.25; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                                    Text {
                                        text: qsTr("ETA ") + parent.parent.parent._etaText
                                        font.pixelSize: root._u * 1.95; font.bold:true; color:root.cNeonMid; font.family:"monospace"
                                        anchors.verticalCenter:parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        Text {
                            text: qsTr("FLIGHT TIME"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.2
                            Text { text:"◷"; font.pixelSize: root._u * 2.7; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: root._ok && root._v.flightTime && root._v.flightTime.valueString !== undefined ? root._v.flightTime.valueString : "00:00:00"
                                font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                    Item {
                        width: parent.width / 6; height: parent.height
                        Rectangle { anchors.right:parent.right; anchors.top:parent.top; anchors.bottom:parent.bottom; width: 1; color:root.cBorder }
                        Text {
                            text: qsTr("MESSAGES"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.2
                            Text { text:"☰"; font.pixelSize: root._u * 2.7; color:root.cNeon; anchors.verticalCenter:parent.verticalCenter }
                            Text {
                                text: root._msgCount > 0 ? root._msgCount + " " + qsTr("New") : "0 " + qsTr("New")
                                font.pixelSize: root._u * 2.7; font.bold:true; color:root.cWhite; font.family:"monospace"
                                anchors.verticalCenter:parent.verticalCenter
                            }
                        }
                    }
                    Item {
                        width: parent.width / 6; height: parent.height
                        Text {
                            text: qsTr("ALERTS"); font.pixelSize: root._u * 1.725; font.bold: true; font.letterSpacing: root._u * 0.225; color:root.cWhite; font.family:"monospace"
                            anchors.top: parent.top; anchors.topMargin: root._u * 0.9
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root._u * 1.35
                            anchors.left: parent.left; anchors.leftMargin: root._u * 2.4
                            spacing: root._u * 1.5
                            Text {
                                text: "⚠"
                                font.pixelSize: root._u * 3.6; color:root.cOrange
                                SequentialAnimation on opacity {
                                    running: root._msgErr || root._msgWarn
                                    loops: Animation.Infinite
                                    NumberAnimation { from:1.0; to:0.3; duration:700 }
                                    NumberAnimation { from:0.3; to:1.0; duration:700 }
                                }
                            }
                            Text {
                                text: root._msgErr || root._msgWarn ? "!" : "0"
                                font.pixelSize: root._u * 3.6; font.bold:true; font.family:"monospace"
                                color: root._msgErr ? root.cRed : root._msgWarn ? root.cOrange : root.cGrey
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
}