import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property Item pager
    property int staggerMs: 45

    Component.onCompleted: Notifications.markAllRead()

    ColumnLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(500, parent.width)
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: Translation.tr("Notifications")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                text: Notifications.list.length
                color: Appearance.colors.colSubtext
            }
            RippleButton {
                objectName: "dashboardNotificationsClearAll"
                implicitWidth: clearText.implicitWidth + 28
                implicitHeight: 32
                buttonRadius: 16
                enabled: Notifications.list.length > 0
                colBackground: Appearance.colors.colLayer1
                onClicked: Notifications.discardAllNotifications()

                contentItem: StyledText {
                    id: clearText
                    text: Translation.tr("Clear all")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        DashboardCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            pager: root.pager
            staggerMs: root.staggerMs
            tint: "transparent"
            animScale: 1

            NotificationListView {
                id: history
                objectName: "dashboardNotificationHistory"
                anchors.fill: parent
                clip: true
                spacing: 8
                popup: false
                popin: false

                delegate: NotificationGroup {
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    notificationGroup: Notifications.groupsByAppName[modelData]
                    compact: true
                    closeSidebarOnLink: false
                }
            }

            PagePlaceholder {
                objectName: "dashboardNotificationsEmpty"
                anchors.fill: parent
                shown: Notifications.list.length === 0
                icon: "notifications_none"
                description: Translation.tr("No notifications")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
