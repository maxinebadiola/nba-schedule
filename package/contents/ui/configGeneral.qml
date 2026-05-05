import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: configPage

    //cfg_ props auto-bind to plasmoid config
    property string cfg_apiKey:          ""
    property int    cfg_teamId:          -1
    property string cfg_teamName:        "All Teams"
    property int    cfg_daysAhead:       7
    property int    cfg_daysBehind:      1
    property int    cfg_refreshInterval: 30

    property bool   teamsLoaded:      false
    property bool   teamsLoading:     false
    property bool   syncingTeamCombo: false
    property string teamsError:       ""

    ListModel {
        id: teamsModel
        ListElement { teamId: -1; label: "All Teams" }
    }

    onCfg_apiKeyChanged: {
        if (cfg_apiKey !== "") loadTeams(cfg_apiKey);
    }

    onCfg_teamIdChanged: {
        if (teamsLoaded) Qt.callLater(syncTeamCombo);
    }

    Component.onCompleted: {
        if (cfg_apiKey !== "") loadTeams(cfg_apiKey);
    }

    function loadTeams(apiKey) {
        teamsLoading = true;
        teamsError = "";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            teamsLoading = false;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    var teams = data.data || [];
                    teams.sort(function(a, b) {
                        return a.full_name.localeCompare(b.full_name);
                    });
                    teamsModel.clear();
                    teamsModel.append({ teamId: -1, label: "All Teams" });
                    for (var i = 0; i < teams.length; i++) {
                        teamsModel.append({
                            teamId: teams[i].id,
                            label: teams[i].full_name + " (" + teams[i].abbreviation + ")"
                        });
                    }
                    teamsLoaded = true;
                    Qt.callLater(syncTeamCombo);
                } catch(e) {
                    teamsError = "Failed to parse teams response";
                }
            } else if (xhr.status === 401) {
                teamsError = "Invalid API key";
            } else {
                teamsError = "Could not load teams (HTTP " + xhr.status + ")";
            }
        };
        xhr.open("GET", "https://api.balldontlie.io/v1/teams?per_page=100");
        xhr.setRequestHeader("Authorization", apiKey);
        xhr.send();
    }

    function syncTeamCombo() {
        syncingTeamCombo = true;
        for (var i = 0; i < teamsModel.count; i++) {
            if (teamsModel.get(i).teamId === cfg_teamId) {
                teamCombo.currentIndex = i;
                syncingTeamCombo = false;
                return;
            }
        }
        teamCombo.currentIndex = 0;
        syncingTeamCombo = false;
    }

    Kirigami.FormLayout {
        id: form
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: Kirigami.Units.smallSpacing

        RowLayout {
            Kirigami.FormData.label: "API Key:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: apiKeyField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                text: cfg_apiKey
                echoMode: showKeyButton.checked ? TextInput.Normal : TextInput.Password
                placeholderText: "Enter your balldontlie.io API key"
                onEditingFinished: cfg_apiKey = text
                onTextChanged: {
                    if (text !== cfg_apiKey) cfg_apiKey = text;
                }
            }

            QQC2.Button {
                id: showKeyButton
                checkable: true
                icon.name: checked ? "password-show-off" : "password-show-on"
                QQC2.ToolTip.text: checked ? "Hide key" : "Show key"
                QQC2.ToolTip.visible: hovered
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        ColumnLayout {
            Kirigami.FormData.label: "Favorite Team:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.ComboBox {
                id: teamCombo
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                model: teamsModel
                textRole: "label"
                enabled: teamsLoaded && !teamsLoading

                onCurrentIndexChanged: {
                    if (syncingTeamCombo) return;
                    if (currentIndex >= 0 && currentIndex < teamsModel.count) {
                        var item = teamsModel.get(currentIndex);
                        cfg_teamId   = item.teamId;
                        cfg_teamName = item.label === "All Teams" ? "All Teams"
                                       : item.label.split("(")[0].trim();
                    }
                }
            }

            PlasmaComponents.BusyIndicator {
                visible: teamsLoading
                running: visible
                Layout.preferredWidth:  Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }

            PlasmaComponents.Label {
                visible: teamsError !== ""
                text: teamsError
                color: Kirigami.Theme.negativeTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                wrapMode: Text.Wrap
            }

            PlasmaComponents.Label {
                visible: !teamsLoaded && !teamsLoading && cfg_apiKey === ""
                text: "Enter your API key above to load teams."
                opacity: 0.6
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: daysAheadSpin
            Kirigami.FormData.label: "Days ahead:"
            from: 1; to: 30
            value: cfg_daysAhead
            onValueChanged: cfg_daysAhead = value
        }

        QQC2.SpinBox {
            id: daysBehindSpin
            Kirigami.FormData.label: "Days behind:"
            from: 0; to: 7
            value: cfg_daysBehind
            onValueChanged: cfg_daysBehind = value
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: "Refresh every:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                id: refreshSpin
                from: 5; to: 120
                value: cfg_refreshInterval
                onValueChanged: cfg_refreshInterval = value
            }

            PlasmaComponents.Label { text: "minutes" }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        PlasmaComponents.Label {
            Kirigami.FormData.label: "API key:"
            text: "Get a free key at balldontlie.io"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.7
        }
    }
}
