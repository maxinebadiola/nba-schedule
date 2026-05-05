import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: configPage

    property int    cfg_teamId:          -1
    property string cfg_teamName:        "All Teams"
    property string cfg_selectedTeamIds: ""
    property string cfg_favoriteTeamIds: ""
    property int    cfg_daysAhead:       7
    property int    cfg_daysBehind:      1
    property string cfg_dateFilterMode:  "range"
    property int    cfg_refreshInterval: 30

    property bool   teamsLoaded:  false
    property bool   teamsLoading: false
    property string teamsError:   ""

    ListModel { id: teamsModel }

    Component.onCompleted: loadTeams()

    function splitIds(value) {
        if (!value) return [];
        return String(value).split(",").filter(function(id) { return id !== ""; });
    }

    function containsId(value, teamId) {
        var ids = splitIds(value);
        for (var i = 0; i < ids.length; i++) {
            if (parseInt(ids[i]) === parseInt(teamId)) return true;
        }
        return false;
    }

    function setId(value, teamId, selected) {
        var ids = splitIds(value);
        var next = [];
        var found = false;
        for (var i = 0; i < ids.length; i++) {
            if (parseInt(ids[i]) === parseInt(teamId)) {
                found = true;
                if (selected) next.push(String(ids[i]));
            } else {
                next.push(String(ids[i]));
            }
        }
        if (selected && !found) next.push(String(teamId));
        return next.join(",");
    }

    function labelForSelectedTeams() {
        var ids = splitIds(cfg_selectedTeamIds);
        if (ids.length === 0) return "All Teams";
        if (ids.length === 1) {
            for (var i = 0; i < teamsModel.count; i++) {
                if (parseInt(teamsModel.get(i).teamId) === parseInt(ids[0]))
                    return teamsModel.get(i).abbr;
            }
            return "1 Team";
        }
        return ids.length + " Teams";
    }

    function teamConference(abbr) {
        var east = ["ATL", "BOS", "BKN", "CHA", "CHI", "CLE", "DET", "IND", "MIA", "MIL", "NY", "NYK", "ORL", "PHI", "TOR", "WSH", "WAS"];
        var value = String(abbr || "");
        for (var i = 0; i < east.length; i++) {
            if (east[i] === value) return "East";
        }
        return "West";
    }

    function loadTeams() {
        teamsLoading = true;
        teamsError = "";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            teamsLoading = false;
            if (xhr.status === 200) {
                try {
                    var data     = JSON.parse(xhr.responseText);
                    var sports   = data.sports  || [];
                    var leagues  = (sports[0]   || {}).leagues || [];
                    var teamsArr = (leagues[0]  || {}).teams   || [];
                    var teams    = teamsArr.map(function(t) { return t.team; });
                    teams.sort(function(a, b) {
                        return a.abbreviation.localeCompare(b.abbreviation);
                    });
                    teamsModel.clear();
                    for (var i = 0; i < teams.length; i++) {
                        teamsModel.append({
                            teamId: parseInt(teams[i].id),
                            abbr: teams[i].abbreviation,
                            label: teams[i].displayName + " (" + teams[i].abbreviation + ")"
                        });
                    }
                    teamsLoaded = true;
                } catch(e) {
                    teamsError = "Failed to parse teams response";
                }
            } else {
                teamsError = "Could not load teams (HTTP " + xhr.status + ")";
            }
        };
        xhr.open("GET", "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams?limit=100");
        xhr.send();
    }

    Kirigami.FormLayout {
        id: form
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Kirigami.FormData.label: "Visible teams:"
            text: labelForSelectedTeams()
            opacity: 0.75
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                text: "All Teams"
                checked: cfg_selectedTeamIds === ""
                onToggled: {
                    if (checked) {
                        cfg_selectedTeamIds = "";
                        cfg_teamId = -1;
                        cfg_teamName = "All Teams";
                    }
                }
            }

            PlasmaComponents.Label {
                text: "East"
                font.bold: true
                opacity: 0.7
            }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: teamsModel

                    QQC2.CheckBox {
                        visible: configPage.teamConference(abbr) === "East"
                        width: visible ? implicitWidth : 0
                        height: visible ? implicitHeight : 0
                        text: abbr
                        checked: configPage.containsId(cfg_selectedTeamIds, teamId)
                        onToggled: {
                            cfg_selectedTeamIds = configPage.setId(cfg_selectedTeamIds, teamId, checked);
                            cfg_teamId = -1;
                            cfg_teamName = configPage.labelForSelectedTeams();
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                text: "West"
                font.bold: true
                opacity: 0.7
            }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: teamsModel

                    QQC2.CheckBox {
                        visible: configPage.teamConference(abbr) === "West"
                        width: visible ? implicitWidth : 0
                        height: visible ? implicitHeight : 0
                        text: abbr
                        checked: configPage.containsId(cfg_selectedTeamIds, teamId)
                        onToggled: {
                            cfg_selectedTeamIds = configPage.setId(cfg_selectedTeamIds, teamId, checked);
                            cfg_teamId = -1;
                            cfg_teamName = configPage.labelForSelectedTeams();
                        }
                    }
                }
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        ColumnLayout {
            Kirigami.FormData.label: "Favorite teams:"
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "East"
                font.bold: true
                opacity: 0.7
            }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: teamsModel

                    QQC2.CheckBox {
                        visible: configPage.teamConference(abbr) === "East"
                        width: visible ? implicitWidth : 0
                        height: visible ? implicitHeight : 0
                        text: abbr
                        checked: configPage.containsId(cfg_favoriteTeamIds, teamId)
                        onToggled: cfg_favoriteTeamIds = configPage.setId(cfg_favoriteTeamIds, teamId, checked)
                    }
                }
            }

            PlasmaComponents.Label {
                text: "West"
                font.bold: true
                opacity: 0.7
            }

            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: teamsModel

                    QQC2.CheckBox {
                        visible: configPage.teamConference(abbr) === "West"
                        width: visible ? implicitWidth : 0
                        height: visible ? implicitHeight : 0
                        text: abbr
                        checked: configPage.containsId(cfg_favoriteTeamIds, teamId)
                        onToggled: cfg_favoriteTeamIds = configPage.setId(cfg_favoriteTeamIds, teamId, checked)
                    }
                }
            }
        }

        PlasmaComponents.Label {
            visible: teamsLoading
            text: "Loading teams..."
            opacity: 0.7
        }

        PlasmaComponents.Label {
            visible: teamsError !== ""
            text: teamsError
            color: Kirigami.Theme.negativeTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            wrapMode: Text.Wrap
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: completedCombo
            Kirigami.FormData.label: "Completed matches:"
            textRole: "label"
            model: [
                { label: "Last 1 day" },
                { label: "Last 3 days" },
                { label: "Last 7 days" }
            ]
            currentIndex: cfg_daysBehind === 1 ? 0
                          : cfg_daysBehind === 3 ? 1
                          : cfg_daysBehind === 7 ? 2
                          : 0
            onActivated: function(index) {
                cfg_daysBehind = [1, 3, 7][index];
                cfg_dateFilterMode = "range";
            }
        }

        QQC2.ComboBox {
            id: upcomingCombo
            Kirigami.FormData.label: "Upcoming matches:"
            textRole: "label"
            model: [
                { label: "Next 1 day" },
                { label: "Next 3 days" },
                { label: "Next 7 days" }
            ]
            currentIndex: cfg_daysAhead === 1 ? 0
                          : cfg_daysAhead === 3 ? 1
                          : cfg_daysAhead === 7 ? 2
                          : 0
            onActivated: function(index) {
                cfg_daysAhead = [1, 3, 7][index];
                cfg_dateFilterMode = "range";
            }
        }

        PlasmaComponents.Label {
            Kirigami.FormData.label: "Date range:"
            text: "Maximum 14 days (7 past + 7 future)"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.7
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: "Refresh every:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.SpinBox {
                from: 5; to: 120
                value: cfg_refreshInterval
                onValueChanged: cfg_refreshInterval = value
            }

            PlasmaComponents.Label { text: "minutes" }
        }

        PlasmaComponents.Label {
            Kirigami.FormData.label: "Data source:"
            text: "ESPN (no API key required)"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.7
        }
    }
}
