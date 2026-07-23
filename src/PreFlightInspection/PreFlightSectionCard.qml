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

/// Collapsible card used for each of the four inspection sections.
///
/// Separate file because it is instantiated four times; QML requires one type
/// per file, so a reused type cannot be folded into its caller.
///
/// Usage:
///     PreFlightSectionCard {
///         width:  parent.width
///         title:  qsTr("Manual Checklist")
///         status: inspectionController.manualStatus
///
///         ColumnLayout { Layout.fillWidth: true; ... }   // becomes the body
///     }
///
/// Implementation note: because the card exposes a *default* property alias
/// into its body column, its own internal items are assigned through the
/// explicit `children` list. Declaring them inline would re-parent them into
/// the body.
Rectangle {
    id: control

    default property alias cardContent: bodyColumn.data

    property string title
    property int    status:   PreFlightStatus.Pending
    property bool   expanded: true

    /// Optional trailing control in the header (refresh button, counter, ...).
    property Component headerTrailingComponent

    property QGCPalette qgcPal: QGCPalette { colorGroupEnabled: control.enabled }

    signal toggled(bool expanded)

    implicitWidth:  Math.max(headerRow.implicitWidth, bodyColumn.implicitWidth) + _padding * 2
    implicitHeight: header.height + bodyClip.height

    color:              qgcPal.windowShade
    radius:             _radius
    border.width:       1
    border.color:       control.activeFocus ? qgcPal.text : qgcPal.windowShadeDark
    clip:               true
    activeFocusOnTab:   true

    Accessible.role: Accessible.Grouping
    Accessible.name: title

    readonly property real _padding: ScreenTools.defaultFontPixelWidth * 1.5
    readonly property real _radius:  ScreenTools.defaultFontPixelWidth * 0.6

    Keys.onSpacePressed:  toggleExpanded()
    Keys.onReturnPressed: toggleExpanded()
    Keys.onEnterPressed:  toggleExpanded()

    function toggleExpanded() {
        expanded = !expanded
        toggled(expanded)
    }

    children: [

        // -------------------------------------------------------------- Header
        Item {
            id:             header
            anchors.top:    control.top
            anchors.left:   control.left
            anchors.right:  control.right
            height:         headerRow.implicitHeight + control._padding * 2

            Rectangle {
                anchors.fill:   parent
                color:          control.qgcPal.text
                opacity:        headerHover.hovered ? 0.06 : 0

                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            HoverHandler { id: headerHover; cursorShape: Qt.PointingHandCursor }

            TapHandler {
                onTapped: {
                    control.forceActiveFocus()
                    control.toggleExpanded()
                }
            }

            RowLayout {
                id:                 headerRow
                anchors.fill:       parent
                anchors.margins:    control._padding
                spacing:            ScreenTools.defaultFontPixelWidth

                // Disclosure chevron drawn from a rotated glyph: scales with the
                // font, needs no artwork, stays correct in every theme.
                QGCLabel {
                    text:               "\u25B6"
                    font.pointSize:     ScreenTools.smallFontPointSize
                    Layout.alignment:   Qt.AlignVCenter
                    rotation:           control.expanded ? 90 : 0

                    Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    text:               control.title
                    font.bold:          true
                    elide:              Text.ElideRight
                }

                Loader {
                    Layout.alignment:   Qt.AlignVCenter
                    sourceComponent:    control.headerTrailingComponent
                }

                // Status pill. Inlined rather than a separate type: the rest of
                // the module shows results as coloured labels, so this is the
                // only pill in the design.
                Rectangle {
                    Layout.alignment:   Qt.AlignVCenter
                    implicitWidth:      statusLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.4
                    implicitHeight:     statusLabel.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.3
                    radius:             height / 2
                    color:              PreFlightStatus.color(control.status)
                    opacity:            control.status === PreFlightStatus.Pending ? 0.35 : 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    QGCLabel {
                        id:                 statusLabel
                        anchors.centerIn:   parent
                        text:               PreFlightStatus.text(control.status)
                        font.bold:          true
                        font.pointSize:     ScreenTools.smallFontPointSize
                        color:              PreFlightStatus.contrastingTextColor(control.status)
                    }
                }
            }
        },

        // ---------------------------------------------------------------- Body
        Item {
            id:             bodyClip
            anchors.top:    header.bottom
            anchors.left:   control.left
            anchors.right:  control.right
            height:         control.expanded ? bodyColumn.implicitHeight + control._padding * 2 : 0
            clip:           true
            visible:        height > 0

            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

            Rectangle {
                anchors.top:            parent.top
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.leftMargin:     control._padding
                anchors.rightMargin:    control._padding
                height:                 1
                color:                  control.qgcPal.windowShadeDark
            }

            ColumnLayout {
                id:                 bodyColumn
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.margins:    control._padding
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
            }
        }
    ]
}
