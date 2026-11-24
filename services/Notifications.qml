pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/**
 * Provides extra features not in Quickshell.Services.Notifications:
 *  - Persistent storage
 *  - Popup notifications, with timeout
 *  - Notification groups by app
 */
Singleton {
	id: root
    component Notif: QtObject {
        id: wrapper
        required property int notificationId // Could just be `id` but it conflicts with the default prop in QtObject
        property Notification notification
        property list<var> actions: notification?.actions.map((action) => ({
            "identifier": action.identifier,
            "text": action.text,
        })) ?? []
        property bool popup: false
        property bool isTransient: notification?.hints.transient ?? false
        property string appIcon: notification?.appIcon ?? ""
        property string appName: notification?.appName ?? ""
        property string body: notification?.body ?? ""
        property string image: notification?.image ?? ""
        property string summary: notification?.summary ?? ""
        property double time
        property string urgency: notification?.urgency.toString() ?? "normal"
        property Timer timer
        property Timer cleanupTimer
        property bool discarding: false

        function scheduleCleanup() {
            if (wrapper.cleanupTimer) return;
            wrapper.cleanupTimer = notifTimerComponent.createObject(root, {
                "notificationId": wrapper.notificationId,
                "interval": Appearance.animation.elementMove.duration + 100,
                "cleanupOnly": true,
                "cleanupObject": wrapper,
            });
        }

        onNotificationChanged: {
            if (notification === null && !wrapper.discarding) {
                root.discardNotification(notificationId);
            }
        }

    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
        }
    }
    function notifToString(notif) {
        return JSON.stringify(notifToJSON(notif), null, 2);
    }

    component NotifTimer: Timer {
        required property int notificationId
        property bool cleanupOnly: false
        property var cleanupObject
        interval: 7000
        running: true
        onTriggered: () => {
            if (cleanupOnly) {
                const notif = cleanupObject;
                if (notif) {
                    notif.cleanupTimer = null;
                    root.finalizeCleanup(notif);
                }
                destroy();
                return;
            }

            const index = root.list.findIndex((notif) => notif.notificationId === notificationId);
            // Already dismissed or discarded while the timer was running
            if (index === -1) {
                destroy();
                return;
            }
            const notifObject = root.list[index];
            print("[Notifications] Notification timer triggered for ID: " + notificationId + ", transient: " + notifObject?.isTransient);
            if (notifObject.isTransient) root.discardNotification(notificationId);
            else root.timeoutNotification(notificationId);
            destroy()
        }
    }

    property bool silent: false
    property int unread: 0
    property var filePath: Directories.notificationsPath
    property list<Notif> list: []
    property var popupList: list.filter((notif) => notif.popup).map((notif) => root.notificationData(notif));
    property bool popupInhibited: silent
    property var latestTimeForApp: ({})
    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    function stringifyList(list) {
        return JSON.stringify(list.map((notif) => notifToJSON(notif)), null, 2);
    }

    function notificationData(notif) {
        return {
            "notificationId": notif.notificationId,
            "actions": notif.actions,
            "popup": notif.popup,
            "isTransient": notif.isTransient,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
        };
    }

    function scheduleCleanup(notifications) {
        notifications.forEach(notif => notif.scheduleCleanup());
    }

    function finalizeCleanup(notif) {
        if (!notif || root.list.some(candidate => candidate === notif)) return;

        notif.discarding = true;
        if (notif.timer) {
            notif.timer.stop();
            notif.timer.destroy();
            notif.timer = null;
        }
        notif.notification = null;
        notif.destroy();
    }

    function replaceList(notifications) {
        const obsolete = root.list.filter(notif => !notifications.includes(notif));
        root.list = notifications;
        root.scheduleCleanup(obsolete);
    }
    
    onListChanged: {
        // Update latest time for each app
        root.list.forEach((notif) => {
            if (!root.latestTimeForApp[notif.appName] || notif.time > root.latestTimeForApp[notif.appName]) {
                root.latestTimeForApp[notif.appName] = Math.max(root.latestTimeForApp[notif.appName] || 0, notif.time);
            }
        });
        // Remove apps that no longer have notifications
        Object.keys(root.latestTimeForApp).forEach((appName) => {
            if (!root.list.some((notif) => notif.appName === appName)) {
                delete root.latestTimeForApp[appName];
            }
        });
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            // Sort by time, descending
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif) => {
            if (!groups[notif.appName]) {
                groups[notif.appName] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0
                };
            }
            groups[notif.appName].notifications.push(root.notificationData(notif));
            // Always set to the latest time in the group
            groups[notif.appName].time = latestTimeForApp[notif.appName] || notif.time;
        });
        return groups;
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.list.filter((notif) => notif.popup))
    property list<string> appNameList: appNameListForGroups(root.groupsByAppName)
    property list<string> popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    signal initDone();
    signal notify(notification: var);
    signal discard(id: int);
    signal discardAll();
    signal timeout(id: var);

	NotificationServer {
        id: notifServer
        // actionIconsSupported: true
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true
            const newNotifObject = notifComponent.createObject(root, {
                "notificationId": notification.id + root.idOffset,
                "notification": notification,
                "time": Date.now(),
            });
			root.list = [...root.list, newNotifObject];

            // Popup
            if (!root.popupInhibited) {
                newNotifObject.popup = true;
                if (notification.expireTimeout != 0) {
                    newNotifObject.timer = notifTimerComponent.createObject(root, {
                        "notificationId": newNotifObject.notificationId,
                        "interval": notification.expireTimeout < 0 ? (Config?.options.notifications.timeout ?? 7000) : notification.expireTimeout,
                    });
                }
                root.unread++;
            }
            root.notify(newNotifObject);
            // console.log(notifToString(newNotifObject));
            notifFileView.setText(stringifyList(root.list));
        }
    }

    function markAllRead() {
        root.unread = 0;
    }

    function discardNotification(id) {
        root.discardNotifications([id]);
    }

    function discardNotifications(ids) {
        console.log("[Notifications] Discarding notifications with IDs: " + ids.join(", "));
        const idSet = new Set(ids);
        const discarded = root.list.filter((notif) => idSet.has(notif.notificationId));
        discarded.forEach(notif => notif.discarding = true);
        // Assign a new array instead of splicing: on a list<> property, splice()
        // shifts the following elements one by one and emits listChanged for each,
        // re-running the grouping and every model bound to the list each time.
        const remaining = root.list.filter((notif) => !idSet.has(notif.notificationId));
        if (remaining.length !== root.list.length) {
            root.list = remaining;
            notifFileView.setText(stringifyList(root.list));
        }
        notifServer.trackedNotifications.values
            .filter((notif) => idSet.has(notif.id + root.idOffset))
            .forEach((notif) => notif.dismiss());
        root.scheduleCleanup(discarded);
        ids.forEach((id) => root.discard(id)); // Emit signal
    }

    function discardAllNotifications() {
        // A QML list property is a live view, even after assigning a new list.
        const discarded = root.list.slice();
        discarded.forEach(notif => notif.discarding = true);
        root.list = []
        triggerListChange()
        notifFileView.setText(stringifyList(root.list));
        notifServer.trackedNotifications.values.forEach((notif) => {
            notif.dismiss()
        })
        root.scheduleCleanup(discarded);
        root.discardAll();
    }

    function cancelTimeout(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null && root.list[index].timer != null)
            root.list[index].timer.stop();
    }

    function timeoutNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].popup = false;
        root.timeout(id);
    }

    function timeoutAll() {
        const popupNotifications = root.list.filter((notif) => notif.popup);
        popupNotifications.forEach((notif) => {
            root.timeout(notif.notificationId);
        })
        popupNotifications.forEach((notif) => {
            notif.popup = false;
        });
    }

    function attemptInvokeAction(id, notifIdentifier) {
        console.log("[Notifications] Attempting to invoke action with identifier: " + notifIdentifier + " for notification ID: " + id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id + root.idOffset === id);
        console.log("Notification server index: " + notifServerIndex);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find((action) => action.identifier === notifIdentifier);
            // console.log("Action found: " + JSON.stringify(action));
            if (action) {
                action.invoke();
            } else {
                console.warn("[Notifications] Action not found:", notifIdentifier);
            }
        } 
        else {
            console.log("Notification not found in server: " + id)
        }
        root.discardNotification(id);
    }

    function triggerListChange() {
        root.list = root.list.slice(0)
    }

    function refresh() {
        notifFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: notifFileView
        path: Qt.resolvedUrl(filePath)
        onLoaded: {
            try {
                const fileContents = notifFileView.text()
                const restoredNotifications = JSON.parse(fileContents).map((notif) => {
                    return notifComponent.createObject(root, {
                        "notificationId": notif.notificationId,
                        "actions": [], // Notification actions are meaningless if they're not tracked by the server or the sender is dead
                        "appIcon": notif.appIcon,
                        "appName": notif.appName,
                        "body": notif.body,
                        "image": notif.image,
                        "summary": notif.summary,
                        "time": notif.time,
                        "urgency": notif.urgency,
                    });
                });
                root.replaceList(restoredNotifications);
                // Find largest notificationId
                let maxId = 0
                root.list.forEach((notif) => {
                    maxId = Math.max(maxId, notif.notificationId)
                })

                root.idOffset = maxId
                root.initDone()
            } catch (e) {
                console.error("[Notifications] Failed to parse notifications file, resetting:", e)
                root.replaceList([])
                notifFileView.setText(stringifyList(root.list))
                root.idOffset = 0
                root.initDone()
            }
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[Notifications] File not found, creating new file.")
                root.replaceList([])
                notifFileView.setText(stringifyList(root.list));
            } else {
                console.log("[Notifications] Error loading file: " + error)
            }
        }
    }
}
