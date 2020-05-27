import QtQuick 2.0

import QtQuick.Layouts 1.2
import "ThemedControls"

GridLayout {
    columns: 2
    columnSpacing: 20
    rowSpacing: 8

    property int labelFontSize: 12

    Text {
        text: "Google Account"
        font.pointSize: parent.labelFontSize
    }
    Item {
        id: item1
        Layout.fillWidth: true
        height: childrenRect.height

        RowLayout {
            anchors.right: parent.right
            spacing: 20
            Text {
                text: googleLoginHelper.account !== null ? googleLoginHelper.account.accountIdentifier : ""
                id: googleAccountIdLabel
                Layout.alignment: Qt.AlignRight
                font.pointSize: 11
            }
            MButton {
                Layout.alignment: Qt.AlignRight
                text: googleLoginHelper.account !== null ? "Sign out" : "Sign in"
                onClicked: {
                    if (googleLoginHelper.account !== null)
                        googleLoginHelper.signOut()
                    else
                        googleLoginHelper.acquireAccount(window)
                }
            }
        }
    }

    MComboBox {
        Layout.columnSpan: 2
        property var values: gen(googleLoginHelper.getAbis().map(function(x) {
            return [x];
        }))
        property var keys: values.map(function(x) { return x.join(", ");})
        
        function gen(a, b, c) {
            b = b || a
            c = c || a.length
            var y = b.reduce(function(o, n) {
                return o.concat(a.map(function(x) {
                    return n.indexOf(x[0]) !== -1 ? null : n.concat(x)
                }).reduce(function(o, n) {
                    return n === null ? o : o.concat([n])
                }, []))
            }, [])
            return b.concat(c > 1 ? gen(a, y, c - 1) : y)
        }
        id: androidabis
        Layout.fillWidth: true
        model: {
            return keys
        }
        Component.onCompleted: { 
            var abi = googleLoginHelper.getDeviceStateABIs().join(", ")
            //currentIndex = 
            console.log("abi was :\""+ abi + "\"")
            var index = keys.indexOf(abi)
            console.log("index of abi was :\""+ index + "\"")
            if(index === -1) {
                console.log("manual search");
                for(var i = 0; i < keys.length; ++i) {
                    if(keys[i] === abi) {
                        console.log("Found at " + i)
                        index = i
                        break;
                    }
                }
            }
            if(index === -1) {
                console.log("Failed")
            } else {
                currentIndex = index
            }
        }
    }

    MCheckBox {
        Layout.topMargin: 20
        id: autoShowGameLog
        text: "Show log when starting the game"
        font.pointSize: parent.labelFontSize
        Layout.columnSpan: 2
        Component.onCompleted: checked = launcherSettings.startOpenLog
        onCheckedChanged: launcherSettings.startOpenLog = checked
    }

    MCheckBox {
        id: hideLauncher
        text: "Hide the launcher when starting the game"
        font.pointSize: parent.labelFontSize
        Layout.columnSpan: 2
        Component.onCompleted: checked = launcherSettings.startHideLauncher
        onCheckedChanged: launcherSettings.startHideLauncher = checked
    }

    MCheckBox {
        id: disableGameLog
        text: "Disable the GameLog"
        font.pointSize: parent.labelFontSize
        Layout.columnSpan: 2
        Component.onCompleted: checked = launcherSettings.disableGameLog
        onCheckedChanged: launcherSettings.disableGameLog = checked
    }

    MCheckBox {
        id: checkForUpdates
        text: "Enable checking for updates (startup)"
        font.pointSize: parent.labelFontSize
        Layout.columnSpan: 2
        Component.onCompleted: checked = launcherSettings.checkForUpdates
        onCheckedChanged: launcherSettings.checkForUpdates = checked
    }

    MButton {
        Layout.topMargin: 20
        id: runTroubleshooter
        text: "Run troubleshooter"
        Layout.columnSpan: 1
        onClicked: troubleshooterWindow.findIssuesAndShow()
    }

    MButton {
        Layout.topMargin: 20
        id: openGameData
        text: "Open GameData Folder"
        Layout.columnSpan: 1
        onClicked: Qt.openUrlExternally(launcherSettings.gameDataDir)
    }

    MButton {
        id: checkForUpdatesbtn
        text: "Check for Updates"
        Layout.columnSpan: 2
        onClicked: updateChecker.checkForUpdates()
    }
}
