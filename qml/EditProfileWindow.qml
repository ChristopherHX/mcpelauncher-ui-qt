import QtQuick 2.4

import QtQuick.Layouts 1.2
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2
import QtQuick.Controls.Styles 1.4
import "ThemedControls"
import io.mrarm.mcpelauncher 1.0

Window {

    property VersionManager versionManager
    property ProfileManager profileManager
    property ProfileInfo profile: null

    width: 500
    height: layout.implicitHeight
    flags: Qt.Dialog
    title: "Edit profile"

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 20

        Image {
            id: title
            smooth: false
            fillMode: Image.Tile
            source: "qrc:/Resources/noise.png"
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            RowLayout {
                anchors.fill: parent

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 20
                    color: "#ffffff"
                    text: qsTr("Edit profile")
                    font.pixelSize: 24
                    verticalAlignment: Text.AlignVCenter
                }

                MButton {
                    text: "Delete profile"
                    Layout.rightMargin: 20
                    visible: profile !== null && profile !== profileManager.defaultProfile
                    onClicked: {
                        profileManager.deleteProfile(profile)
                        close()
                    }
                }

            }

        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.alignment: Qt.AlignTop
            columnSpacing: 20
            rowSpacing: 8

            property int labelFontSize: 11

            Text {
                text: "Profile Name"
                font.pixelSize: parent.labelFontSize
            }
            MTextField {
                id: profileName
                Layout.fillWidth: true
            }

            Text {
                text: "Version"
                font.pixelSize: parent.labelFontSize
            }
            MComboBox {
                property var versions: versionManager.versions.getAll().sort(function(a, b) { return b.versionCode - a.versionCode; })
                property var archivalVersions: excludeInstalledVersions(versionManager.archivalVersions.versions)
                property var extraVersionName: null
                property int extraVersionIndex: 1 + versions.length + archivalVersions.length

                function excludeInstalledVersions(arr) {
                    var ret = []
                    var installed = {}
                    for (var i = 0; i < versions.length; i++)
                        installed[versions[i].versionName] = true
                    for (i = 0; i < arr.length; i++) {
                        if (arr[i].versionName in installed)
                            continue;
                        ret.push(arr[i])
                    }
                    return ret
                }

                id: profileVersion
                Layout.fillWidth: true
                model: {
                    var ret = []
                    ret.push("Latest version (Google Play)")
                    for (var i = 0; i < versions.length; i++)
                        ret.push(versions[i].versionName + " (installed)")
                    for (i = 0; i < archivalVersions.length; i++)
                        ret.push(archivalVersions[i].versionName + (archivalVersions[i].isBeta ? " (beta)" : ""))
                    if (extraVersionName != null) {
                        ret.push(extraVersionName)
                    }
                    return ret
                }
            }

            Item {
                height: 8
                Layout.columnSpan: 2
            }

            MCheckBox {
                id: dataDirCheck
                text: "Data directory"
                font.pixelSize: parent.labelFontSize
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                MTextField {
                    id: dataDirPath
                    enabled: dataDirCheck.checked
                    Layout.fillWidth: true
                }
                MButton {
                    text: "..."
                    enabled: dataDirCheck.checked
                    onClicked: {
                        if (dataDirPath.text !== null && dataDirPath.text.length > 0)
                            dataDirPathDialog.folder = QmlUrlUtils.localFileToUrl(dataDirPath.text)
                        dataDirPathDialog.open()
                    }
                }
                FileDialog {
                    id: dataDirPathDialog
                    selectFolder: true
                    onAccepted: {
                        dataDirPath.text = QmlUrlUtils.urlToLocalFile(fileUrl)
                    }
                }
            }

            MCheckBox {
                id: windowSizeCheck
                text: "Window size"
                font.pixelSize: parent.labelFontSize
            }
            RowLayout {
                Layout.fillWidth: true
                MTextField {
                    id: windowWidth
                    enabled: windowSizeCheck.checked
                    Layout.fillWidth: true
                    validator: IntValidator {
                        bottom: 0
                        top: 3840
                    }
                }
                Text {
                    text: "x"
                    font.pixelSize: 11
                }
                MTextField {
                    id: windowHeight
                    enabled: windowSizeCheck.checked
                    Layout.fillWidth: true
                    validator: IntValidator {
                        bottom: 0
                        top: 2160
                    }
                }
                Item {
                    Layout.preferredWidth: 10
                }
                MTextField {
                    id: pixelScale
                    enabled: windowSizeCheck.checked
                    Layout.preferredWidth: 50
                    validator: DoubleValidator {
                        bottom: 0
                        top: 16
                    }
                }
                Text {
                    text: "px scale"
                    font.pixelSize: 11
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Image {
            id: buttons
            smooth: false
            fillMode: Image.Tile
            source: "qrc:/Resources/noise.png"
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            RowLayout {
                x: parent.width / 2 - width / 2
                y: parent.height / 2 - height / 2

                spacing: 20

                PlayButton {
                    Layout.preferredWidth: 150
                    text: "Save"
                    onClicked: {
                        saveProfile()
                        close()
                    }
                }

                PlayButton {
                    Layout.preferredWidth: 150
                    text: "Cancel"
                    onClicked: close()
                }

            }

        }

    }

    function reset() {
        profile = null
        profileName.text = ""
        profileName.enabled = true
        profileVersion.currentIndex = 0
        dataDirCheck.checked = false
        dataDirPath.text = ""
        windowSizeCheck.checked = false
        windowWidth.text = "720"
        windowHeight.text = "480"
        pixelScale.text = "2"
    }

    function setProfile(p) {
        profile = p
        profileName.text = profile.name
        profileName.enabled = !profile.nameLocked
        if (profile.versionType == ProfileInfo.LATEST_GOOGLE_PLAY) {
            profileVersion.currentIndex = 0
        } else if (profile.versionType == ProfileInfo.LOCKED_CODE) {
            var index = -1
            for (var i = 0; i < profileVersion.versions.length; i++) {
                if (profileVersion.versions[i].versionCode === profile.versionCode) {
                    index = 1 + i
                    break
                }
            }
            for (var i = 0; i < profileVersion.archivalVersions.length; i++) {
                if (profileVersion.archivalVersions[i].versionCode === profile.versionCode) {
                    index = 1 + profileVersion.versions.length + i
                    break
                }
            }
            if (index === -1) {
                profileVersion.extraVersionName = "Archival (" + profile.versionDirName + ")"
                profileVersion.currentIndex = profileVersion.extraVersionIndex
            } else {
                profileVersion.currentIndex = index
            }
        } else if (profile.versionType == ProfileInfo.LOCKED_NAME) {
            var index = -1
            for (var i = 0; i < profileVersion.versions.length; i++) {
                if (profileVersion.versions[i].directory === profile.versionDirName) {
                    index = i
                    break
                }
            }
            if (index === -1) {
                profileVersion.extraVersionName = profile.versionDirName
                profileVersion.currentIndex = profileVersion.extraVersionIndex
            } else {
                profileVersion.currentIndex = index + 1
            }
        }

        dataDirCheck.checked = profile.dataDirCustom
        dataDirPath.text = profile.dataDir
        windowSizeCheck.checked = profile.windowCustomSize
        windowWidth.text = profile.windowWidth
        windowHeight.text = profile.windowHeight
        pixelScale.text = profile.pixelScale
    }

    function saveProfile() {
        if (!profileManager.validateName(profileName.text)) {
            profileInvalidNameDialog.open()
            return
        }
        if (profile == null || (profile.name !== profileName.text && !profile.nameLocked)) {
            var profiles = profileManager.profiles
            for (var i = 0; i < profiles.length; i++) {
                if (profiles[i].name === profileName.text) {
                    profileNameConflictDialog.open()
                    return
                }
            }
            if (profile == null)
                profile = profileManager.createProfile(profileName.text)
            else
                profile.setName(profileName.text)
        }
        if (profileVersion.currentIndex == 0) {
            profile.versionType = ProfileInfo.LATEST_GOOGLE_PLAY
        } else if (profileVersion.currentIndex >= 1 && profileVersion.currentIndex < 1 + profileVersion.versions.length) {
            profile.versionType = ProfileInfo.LOCKED_NAME
            profile.versionDirName = profileVersion.versions[profileVersion.currentIndex - 1].directory
        } else if (profileVersion.currentIndex >= 1 + profileVersion.versions.length && profileVersion.currentIndex < 1 + profileVersion.versions.length + profileVersion.archivalVersions.length) {
            profile.versionType = ProfileInfo.LOCKED_CODE
            profile.versionCode = profileVersion.archivalVersions[profileVersion.currentIndex - 1 - profileVersion.versions.length].versionCode
        }

        profile.windowCustomSize = windowSizeCheck.checked
        profile.dataDirCustom = dataDirCheck.checked
        profile.dataDir = dataDirPath.text
        profile.windowWidth = parseInt(windowWidth.text) || profile.windowWidth
        profile.windowHeight = parseInt(windowHeight.text) || profile.windowHeight
        profile.pixelScale = parseFloat(pixelScale.text) || profile.pixelScale
        profile.save()
    }

    MessageDialog {
        id: profileNameConflictDialog
        text: "A profile with the specified name already exists"
        title: "Profile Edit Error"
    }

    MessageDialog {
        id: profileInvalidNameDialog
        text: "The specified profile name is not valid"
        title: "Profile Edit Error"
    }

}
