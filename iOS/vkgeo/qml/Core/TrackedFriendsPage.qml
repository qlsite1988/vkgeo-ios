import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0

import "Misc"

import "../Util.js" as UtilScript

Page {
    id: trackedFriendsPage

    header: Rectangle {
        height: trackedFriendsPage.safeAreaTopMargin + headerControlsLayout.height
        color:  "lightsteelblue"

        RowLayout {
            id:             headerControlsLayout
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height:         UtilScript.pt(48)
            spacing:        UtilScript.pt(4)

            VKButton {
                width:             UtilScript.pt(80)
                height:            UtilScript.pt(32)
                text:              qsTr("Cancel")
                Layout.leftMargin: UtilScript.pt(8)
                Layout.alignment:  Qt.AlignHCenter | Qt.AlignVCenter

                onClicked: {
                    mainStackView.pop();
                }
            }

            Text {
                text:                qsTr("Tracked friends")
                color:               "white"
                font.pointSize:      16
                font.family:         "Helvetica"
                font.bold:           true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                wrapMode:            Text.Wrap
                fontSizeMode:        Text.Fit
                minimumPointSize:    8
                Layout.fillWidth:    true
                Layout.fillHeight:   true
            }

            VKButton {
                width:              UtilScript.pt(80)
                height:             UtilScript.pt(32)
                text:               qsTr("Save")
                Layout.rightMargin: UtilScript.pt(8)
                Layout.alignment:   Qt.AlignHCenter | Qt.AlignVCenter

                onClicked: {
                    var tracked_friends_list = [];

                    for (var i = 0; i < trackedFriendsPage.friendsList.length; i++) {
                        var frnd = trackedFriendsPage.friendsList[i];

                        if (frnd.tracked) {
                            tracked_friends_list.push(frnd.userId);
                        }
                    }

                    VKHelper.updateTrackedFriendsList(tracked_friends_list);

                    mainStackView.pop();
                }
            }
        }
    }

    footer: Rectangle {
        height: trackedFriendsPage.safeAreaBottomMargin
        color:  "lightsteelblue"
    }

    property int safeAreaTopMargin:    0
    property int safeAreaBottomMargin: 0
    property int trackedFriendsCount:  0

    property var friendsList:          []

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Activating ||
            StackView.status === StackView.Active) {
            safeAreaTopMargin    = UIHelper.safeAreaTopMargin();
            safeAreaBottomMargin = UIHelper.safeAreaBottomMargin();
        }
    }

    function updateModel() {
        trackedFriendsListModel.clear();

        for (var i = 0; i < friendsList.length; i++) {
            var frnd = friendsList[i];

            if ("%1 %2".arg(frnd.firstName).arg(frnd.lastName).toUpperCase()
                       .includes(filterTextField.text.toUpperCase())) {
                trackedFriendsListModel.append(frnd);
            }
        }
    }

    function setTrack(user_id, tracked) {
        if (trackedFriendsCount < VKHelper.maxTrackedFriendsCount || !tracked) {
            for (var i = 0; i < friendsList.length; i++) {
                var frnd = friendsList[i];

                if (user_id === frnd.userId) {
                    frnd.tracked = tracked;

                    friendsList[i] = frnd;

                    break;
                }
            }

            for (var j = 0; j < trackedFriendsListModel.count; j++) {
                var model_frnd = trackedFriendsListModel.get(j);

                if (user_id === model_frnd.userId) {
                    trackedFriendsListModel.set(j, { "tracked": tracked });

                    break;
                }
            }

            if (tracked) {
                trackedFriendsCount++;
            } else {
                trackedFriendsCount--;
            }

            return true;
        } else {
            return false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing:      UtilScript.pt(8)

        TextField {
            id:               filterTextField
            placeholderText:  qsTr("Quick search")
            inputMethodHints: Qt.ImhNoPredictiveText
            Layout.topMargin: UtilScript.pt(8)
            Layout.fillWidth: true

            background: Rectangle {
                color:        "lightsteelblue"
                radius:       UtilScript.pt(8)
                border.width: UtilScript.pt(1)
                border.color: "steelblue"
            }

            onTextChanged: {
                trackedFriendsPage.updateModel();
            }

            onEditingFinished: {
                focus = false;
            }
        }

        ListView {
            orientation:       ListView.Vertical
            clip:              true
            Layout.fillWidth:  true
            Layout.fillHeight: true

            model: ListModel {
                id: trackedFriendsListModel
            }

            delegate: Rectangle {
                id:           friendDelegate
                width:        listView.width
                height:       UtilScript.pt(80)
                clip:         true
                border.width: UtilScript.pt(1)
                border.color: "lightsteelblue"

                property var listView: ListView.view

                RowLayout {
                    anchors.fill: parent
                    spacing:      UtilScript.pt(8)

                    OpacityMask {
                        id:                opacityMask
                        width:             UtilScript.pt(64)
                        height:            UtilScript.pt(64)
                        Layout.leftMargin: UtilScript.pt(16)
                        Layout.alignment:  Qt.AlignHCenter | Qt.AlignVCenter

                        source: Image {
                            width:    opacityMask.width
                            height:   opacityMask.height
                            source:   photoUrl
                            fillMode: Image.PreserveAspectCrop
                            visible:  false
                        }

                        maskSource: Image {
                            width:    opacityMask.width
                            height:   opacityMask.height
                            source:   "qrc:/resources/images/main/avatar_mask.png"
                            fillMode: Image.PreserveAspectFit
                            visible:  false
                        }
                    }

                    Text {
                        text:                "%1 %2".arg(firstName).arg(lastName)
                        color:               "black"
                        font.pointSize:      16
                        font.family:         "Helvetica"
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment:   Text.AlignVCenter
                        wrapMode:            Text.Wrap
                        fontSizeMode:        Text.Fit
                        minimumPointSize:    8
                        Layout.fillWidth:    true
                        Layout.fillHeight:   true
                    }

                    Switch {
                        checked:            tracked
                        Layout.rightMargin: UtilScript.pt(16)
                        Layout.alignment:   Qt.AlignHCenter | Qt.AlignVCenter

                        onToggled: {
                            if (!friendDelegate.listView.setTrack(userId, checked)) {
                                checked = !checked;
                            }
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOn
            }

            function setTrack(user_id, tracked) {
                return trackedFriendsPage.setTrack(user_id, tracked);
            }
        }
    }

    Component.onCompleted: {
        var friends_list = VKHelper.getFriendsList();

        for (var i = 0; i < friends_list.length; i++) {
            var frnd = friends_list[i];

            if (!frnd.trusted) {
                friendsList.push(frnd);

                if (frnd.tracked) {
                    trackedFriendsCount++;
                }
            }
        }

        updateModel();
    }
}