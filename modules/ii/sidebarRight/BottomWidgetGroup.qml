pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.pomodoro
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    WindowGlass {
        anchors.fill: parent
        glassEnabled: (parent?.color.a ?? 0) > 0
        cardRadius: parent?.radius ?? 0
        tint: parent?.color ?? 'transparent'
    }
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true
    implicitHeight: collapsed ? collapsedBottomWidgetGroupRow.implicitHeight : 350
    property bool collapsed: Persistent.states.sidebar.bottomGroup.collapsed

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    function setCollapsed(state) {
        Persistent.states.sidebar.bottomGroup.collapsed = state;
        if (collapsed) {
            bottomWidgetGroupRow.opacity = 0;
        } else {
            collapsedBottomWidgetGroupRow.opacity = 0;
        }
        collapseCleanFadeTimer.start();
    }

    Timer {
        id: collapseCleanFadeTimer
        interval: Appearance.animation.elementMove.duration / 2
        repeat: false
        onTriggered: {
            if (collapsed)
                collapsedBottomWidgetGroupRow.opacity = 1;
            else
                bottomWidgetGroupRow.opacity = 1;
        }
    }

    // The thing when collapsed
    RowLayout {
        id: collapsedBottomWidgetGroupRow
        opacity: collapsed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                id: collapsedBottomWidgetGroupRowFade
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        spacing: 15

        RippleButton {
            Layout.margins: 10
            Layout.rightMargin: 0
            implicitWidth: 30
            implicitHeight: 30
            buttonRadius: 15
            glass: true
            downAction: () => {
                root.setCollapsed(false);
            }
            contentItem: MaterialSymbol {
                text: "keyboard_arrow_up"
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colOnLayer1
            }
        }

        StyledText {
            Layout.margins: 10
            Layout.leftMargin: 0
            text: Translation.tr("Timer")
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
        }
    }

    // The thing when expanded
    ColumnLayout {
        id: bottomWidgetGroupRow

        opacity: collapsed ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                id: bottomWidgetGroupRowFade
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Timer")
                color: Appearance.colors.colOnLayer1
            }
            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: 15
                Accessible.name: Translation.tr("Collapse")
                onClicked: root.setCollapsed(true)
                contentItem: MaterialSymbol {
                    text: "keyboard_arrow_down"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
        PomodoroWidget {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
