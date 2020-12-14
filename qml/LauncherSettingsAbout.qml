import QtQuick 2.9

import QtQuick.Layouts 1.2
import QtQuick.Controls 2.2
import QtQuick.Dialogs 1.2
import "ThemedControls"

ColumnLayout {
    id: columnlayout
    property var maximumWidth: 100

    TextEdit {
        textFormat: TextEdit.RichText
        text: qsTr("This project allows you to launch Minecraft: Bedrock Edition (as in the edition w/o the Edition suffix, previously known as Minecraft: Pocket Edition). The launcher supports Linux and OS X.<br/><br/>Version %1 (build %2)<br/> © Copyright 2018-2020, MrARM & contributors").arg(LAUNCHER_VERSION_NAME).arg(LAUNCHER_VERSION_CODE)
        readOnly: true
        wrapMode: Text.WordWrap
        selectByMouse: true
        Layout.maximumWidth: columnlayout.maximumWidth
    }

    RowLayout {

        MButton {
            text: qsTr("Show Changelog")
            onClicked: stackView.push(panelChangelog)
        }

        MButton {
            text: qsTr("Check for Updates")
            Layout.columnSpan: 1
            onClicked: {
                updateCheckerConnectorSettings.enabled = true
                updateChecker.checkForUpdates()
            }
        }

        MButton {
            text: qsTr("Reset Launcher Settings")
            Layout.columnSpan: 1
            onClicked: {
                launcherSettings.resetSettings()
                launcherreset.open()
            }
        }
    }

    MessageDialog {
        id: launcherreset
        title: "Settings cleared"
        text: qsTr("Please reopen the Launcher to see the changes")
    }

    property var updateUrl: "";

    Connections {
        id: updateCheckerConnectorSettings
        target: updateChecker
        enabled: false
        function onUpdateError(error) {
            updateCheckerConnectorSettings.enabled = false
            updateError.text = error
            updateError.open()
        }
        function onUpdateAvailable(url) {
            columnlayout.updateUrl = url;
        }
        function onUpdateCheck(available) {
            updateCheckerConnectorSettings.enabled = false
            if (available) {
                updateInfo.text = qsTr("An Update of the Launcher is available for download") + "<br/>" + (columnlayout.updateUrl.length !== 0 ? qsTr("You can download the new Update here: %1").arg(columnlayout.updateUrl) + "<br/>" : "") + qsTr("Do you want to update now?");
                updateInfo.standardButtons = StandardButton.Yes | StandardButton.No
            } else {
                updateInfo.standardButtons = StandardButton.Ok
                updateInfo.text = qsTr("Your installed Launcher Version %1 (build %2) seems uptodate").arg(LAUNCHER_VERSION_NAME).arg(LAUNCHER_VERSION_CODE)
            }
            updateInfo.open()
        }
    }

    Connections {
        target: updateChecker
        enabled: updateCheckerConnectorSettings.enabled
        onUpdateError: function() { updateCheckerConnectorSettings.onUpdateError.apply(this, arguments); }
        onUpdateAvailable: function() { updateCheckerConnectorSettings.onUpdateAvailable.apply(this, arguments); }
        onUpdateCheck: function() { updateCheckerConnectorSettings.onUpdateCheck.apply(this, arguments); }
    }

    MessageDialog {
        id: updateError
        title: qsTr("Update failed")
    }

    MessageDialog {
        id: updateInfo
        title: qsTr("Update Information")
        onYes: {
            if (columnlayout.updateUrl.length !== 0) {
                Qt.openUrlExternally(columnlayout.updateUrl)
            } else {
                updateCheckerConnectorSettings.enabled = true
                updateChecker.startUpdate()
            }
        }
    }

}
