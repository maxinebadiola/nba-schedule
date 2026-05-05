import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "../code/schedule.js" as Schedule

PlasmaExtras.Representation {
    id: fullRoot

    property var    gamesGroups:  []
    property int    gamesCount:   0
    property bool   loading:      false
    property string errorMessage: ""
    property var    lastUpdated:  null
    property var    teamsList:    []
    property date   now:          new Date()
    property var    expandedGames: ({})
    readonly property int scrollRightPadding: Kirigami.Units.gridUnit
    signal refreshRequested()
    signal selectedTeamsChanged(string teamIds, string teamName)

    Layout.minimumWidth:    Kirigami.Units.gridUnit * 22
    Layout.minimumHeight:   Kirigami.Units.gridUnit * 20
    Layout.preferredWidth:  Kirigami.Units.gridUnit * 28
    Layout.preferredHeight: Kirigami.Units.gridUnit * 40

    function isGameExpanded(gameId) {
        return fullRoot.expandedGames[String(gameId)] === true;
    }

    function setGameExpanded(gameId, expanded) {
        var next = {};
        for (var key in fullRoot.expandedGames) next[key] = fullRoot.expandedGames[key];
        if (expanded) next[String(gameId)] = true;
        else delete next[String(gameId)];
        fullRoot.expandedGames = next;
    }

    function lineScore(linescores, index) {
        if (!linescores || index >= linescores.length || linescores[index] === undefined)
            return "–";
        return linescores[index];
    }

    function lineScoreFromText(linescoreText, index) {
        if (!linescoreText) return "–";
        var values = String(linescoreText).split("|");
        if (index >= values.length || values[index] === "") return "–";
        return values[index];
    }

    function visitorLineScore(game, index) {
        var value = -1;
        if (index === 0) value = game.visitorQ1;
        else if (index === 1) value = game.visitorQ2;
        else if (index === 2) value = game.visitorQ3;
        else if (index === 3) value = game.visitorQ4;
        else if (index === 4) value = game.visitorOT1;
        else if (index === 5) value = game.visitorOT2;
        else if (index === 6) value = game.visitorOT3;
        return value >= 0 ? value : "–";
    }

    function homeLineScore(game, index) {
        var value = -1;
        if (index === 0) value = game.homeQ1;
        else if (index === 1) value = game.homeQ2;
        else if (index === 2) value = game.homeQ3;
        else if (index === 3) value = game.homeQ4;
        else if (index === 4) value = game.homeOT1;
        else if (index === 5) value = game.homeOT2;
        else if (index === 6) value = game.homeOT3;
        return value >= 0 ? value : "–";
    }

    function lineScoreCount(linescoreText, linescores) {
        if (linescoreText) return String(linescoreText).split("|").length;
        return (linescores || []).length;
    }

    function visitorLineScoreCount(game) {
        if (game.visitorOT3 >= 0) return 7;
        if (game.visitorOT2 >= 0) return 6;
        if (game.visitorOT1 >= 0) return 5;
        if (game.visitorQ4 >= 0) return 4;
        return 0;
    }

    function homeLineScoreCount(game) {
        if (game.homeOT3 >= 0) return 7;
        if (game.homeOT2 >= 0) return 6;
        if (game.homeOT1 >= 0) return 5;
        if (game.homeQ4 >= 0) return 4;
        return 0;
    }

    function escapeText(value) {
        return String(value || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    function htmlColor(colorValue) {
        function hex(channel) {
            return Math.round(channel * 255).toString(16).padStart(2, "0");
        }
        return "#" + hex(colorValue.r) + hex(colorValue.g) + hex(colorValue.b);
    }

    function teamMarkup(label, winner, statusType) {
        var text = fullRoot.escapeText(label);
        if (statusType === "final" && winner) {
            return "<font color=\"" + fullRoot.htmlColor(Kirigami.Theme.positiveTextColor) + "\"><b>" + text + "</b></font>";
        }
        if (statusType === "live") return "<b>" + text + "</b>";
        return text;
    }

    function prettySeries(series) {
        return String(series || "").replace(/([0-9]+)-([0-9]+)/g, "$1–$2");
    }

    function gameStage(game) {
        return String(game.gameNote || (game.postseason ? "Playoffs" : "Regular season"))
            .replace(/ - /g, " · ");
    }

    function compactTeamMarkup(abbr, winner, statusType) {
        var label = abbr;
        return fullRoot.teamMarkup(label, winner, statusType);
    }

    function teamIconPath(abbr) {
        var paths = {
            "BOS": "east/atlantic/bos.svg", "BKN": "east/atlantic/bkn.svg",
            "NY":  "east/atlantic/ny.svg",  "NYK": "east/atlantic/ny.svg",
            "PHI": "east/atlantic/phi.svg", "TOR": "east/atlantic/tor.svg",
            "CHI": "east/central/chi.svg",  "CLE": "east/central/cle.svg",
            "DET": "east/central/det.svg",  "IND": "east/central/ind.svg",
            "MIL": "east/central/mil.svg",
            "ATL": "east/southeast/atl.svg","CHA": "east/southeast/cha.svg",
            "MIA": "east/southeast/mia.svg","ORL": "east/southeast/orl.svg",
            "WAS": "east/southeast/was.svg","WSH": "east/southeast/was.svg",
            "DEN": "west/northwest/den.svg","MIN": "west/northwest/min.svg",
            "OKC": "west/northwest/okc.svg","POR": "west/northwest/por.svg",
            "UTA": "west/northwest/uta.svg",
            "GS":  "west/pacific/gs.svg",   "GSW": "west/pacific/gs.svg",
            "LAC": "west/pacific/lac.svg",  "LAL": "west/pacific/lal.svg",
            "PHX": "west/pacific/phx.svg",  "SAC": "west/pacific/sac.svg",
            "DAL": "west/southwest/dal.svg","HOU": "west/southwest/hou.svg",
            "MEM": "west/southwest/mem.svg",
            "NO":  "west/southwest/no.svg", "NOP": "west/southwest/no.svg",
            "SA":  "west/southwest/sa.svg", "SAS": "west/southwest/sa.svg"
        };
        var p = paths[String(abbr || "").toUpperCase()];
        return p ? Qt.resolvedUrl("../images/icons/" + p) : "";
    }

    function matchupMarkup(game) {
        return fullRoot.compactTeamMarkup(game.visitorAbbr, game.visitorWinner, game.statusType) +
               " <font color=\"" + fullRoot.htmlColor(Kirigami.Theme.disabledTextColor) + "\">@</font> " +
               fullRoot.compactTeamMarkup(game.homeAbbr, game.homeWinner, game.statusType);
    }

    function expandedSeriesLabel(game) {
        return fullRoot.prettySeries(game.seriesSummary);
    }

    function expandedVenueLabel(game) {
        return game.venue || "";
    }

    function localGameTime(datetime) {
        if (!datetime) return "TBD";
        return Qt.formatTime(new Date(datetime), "h:mm AP");
    }

    function minutesSince(dateValue) {
        if (!dateValue) return 0;
        return Math.max(0, Math.floor((fullRoot.now - new Date(dateValue)) / 60000));
    }

    function lastUpdatedLabel() {
        if (!fullRoot.lastUpdated) return "";
        return "Updated " + Qt.formatTime(new Date(fullRoot.lastUpdated), "h:mm AP");
    }

    function countdownLabel(datetime) {
        if (!datetime) return "";
        var diff = Math.max(0, Math.floor((new Date(datetime) - fullRoot.now) / 60000));
        var hours = Math.floor(diff / 60);
        var minutes = diff % 60;
        return String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0");
    }

    function gameDetailLabel(game) {
        return fullRoot.expandedVenueLabel(game);
    }

    function selectedTeamIds() {
        var ids = String(Plasmoid.configuration.selectedTeamIds || "");
        if (!ids && Plasmoid.configuration.teamId > 0) ids = String(Plasmoid.configuration.teamId);
        if (!ids) return [];
        return ids.split(",").filter(function(id) { return id !== ""; });
    }

    function isTeamSelected(teamId) {
        var ids = fullRoot.selectedTeamIds();
        for (var i = 0; i < ids.length; i++) {
            if (parseInt(ids[i]) === parseInt(teamId)) return true;
        }
        return false;
    }

    function teamAbbr(teamId) {
        for (var i = 0; i < fullRoot.teamsList.length; i++) {
            if (parseInt(fullRoot.teamsList[i].id) === parseInt(teamId))
                return fullRoot.teamsList[i].abbreviation || fullRoot.teamsList[i].displayName;
        }
        return "";
    }

    function teamConference(abbr) {
        var east = ["ATL", "BOS", "BKN", "CHA", "CHI", "CLE", "DET", "IND", "MIA", "MIL", "NY", "NYK", "ORL", "PHI", "TOR", "WSH", "WAS"];
        var value = String(abbr || "");
        for (var i = 0; i < east.length; i++) {
            if (east[i] === value) return "East";
        }
        return "West";
    }

    function teamIsConference(team, conference) {
        return fullRoot.teamConference(team.abbreviation || team.displayName) === conference;
    }

    function labelForTeamIds(ids) {
        if (ids.length === 0) return "All Teams";
        var labels = [];
        for (var i = 0; i < ids.length && i < 3; i++) {
            labels.push(fullRoot.teamAbbr(ids[i]) || String(ids[i]));
        }
        if (ids.length > 3) labels.push("...");
        return labels.join(", ");
    }

    function selectedTeamsLabel() {
        return fullRoot.labelForTeamIds(fullRoot.selectedTeamIds());
    }

    function setTeamSelected(teamId, selected) {
        var ids = fullRoot.selectedTeamIds();
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
        fullRoot.selectedTeamsChanged(next.join(","), fullRoot.labelForTeamIds(next));
    }

    function clearSelectedTeams() {
        fullRoot.selectedTeamsChanged("", "All Teams");
    }

    function favoriteTeamIds() {
        var ids = String(Plasmoid.configuration.favoriteTeamIds || "");
        if (!ids) return [];
        return ids.split(",").filter(function(id) { return id !== ""; });
    }

    function isFavoriteTeam(teamId) {
        var ids = fullRoot.favoriteTeamIds();
        for (var i = 0; i < ids.length; i++) {
            if (parseInt(ids[i]) === parseInt(teamId)) return true;
        }
        return false;
    }

    function setFavoriteTeam(teamId, selected) {
        var ids = fullRoot.favoriteTeamIds();
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
        Plasmoid.configuration.favoriteTeamIds = next.join(",");
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fullRoot.now = new Date()
    }

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    Rectangle {
        id: heading
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: headerContent.implicitHeight + Kirigami.Units.smallSpacing * 2
        z: 20
        opacity: 1
        color: Kirigami.Theme.backgroundColor

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.16
        }

        RowLayout {
            id: headerContent
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing * 1.5
            anchors.rightMargin: Kirigami.Units.largeSpacing * 1.5
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Item {
                id: teamMenuButton
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6

                Rectangle {
                    anchors.fill: parent
                    color: teamButtonMouse.containsMouse
                           ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                     Kirigami.Theme.highlightColor.g,
                                     Kirigami.Theme.highlightColor.b, 0.10)
                           : "transparent"
                    radius: 4
                }

                PlasmaComponents.Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Kirigami.Units.smallSpacing
                        rightMargin: Kirigami.Units.smallSpacing
                    }
                    text: fullRoot.selectedTeamsLabel() + " ▾"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    font.bold: true
                }

                MouseArea {
                    id: teamButtonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: teamPopup.open()
                }
            }

            PlasmaComponents.Label {
                visible: fullRoot.lastUpdatedLabel() !== ""
                text: fullRoot.lastUpdatedLabel()
                opacity: 0.65
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            PlasmaComponents.ToolButton {
                icon.name: "configure"
                onClicked: settingsPopup.open()
                PlasmaComponents.ToolTip.text: "Settings"
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: !fullRoot.loading
                onClicked: fullRoot.refreshRequested()
                PlasmaComponents.ToolTip.text: "Refresh"
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        QQC2.Popup {
            id: teamPopup
            x: headerContent.x
            y: heading.height
            width: Math.min(fullRoot.width - Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 18)
            height: Math.min(Kirigami.Units.gridUnit * 22, teamsColumn.implicitHeight + Kirigami.Units.largeSpacing * 2)
            padding: Kirigami.Units.smallSpacing
            modal: false
            focus: true
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 4
            }

            QQC2.ScrollView {
                anchors.fill: parent
                clip: true

                Column {
                    id: teamsColumn
                    width: teamPopup.availableWidth
                    spacing: 0

                    QQC2.CheckBox {
                        width: parent.width
                        text: "All Teams"
                        checked: fullRoot.selectedTeamIds().length === 0
                        onToggled: if (checked) fullRoot.clearSelectedTeams()
                    }

                    PlasmaComponents.Label {
                        width: parent.width
                        text: "East"
                        font.bold: true
                        opacity: 0.7
                    }

                    Repeater {
                        model: fullRoot.teamsList

                        QQC2.CheckBox {
                            width: teamsColumn.width
                            visible: fullRoot.teamIsConference(modelData, "East")
                            height: visible ? implicitHeight : 0
                            text: modelData.abbreviation || modelData.displayName
                            checked: fullRoot.isTeamSelected(modelData.id)
                            onToggled: fullRoot.setTeamSelected(modelData.id, checked)
                        }
                    }

                    PlasmaComponents.Label {
                        width: parent.width
                        text: "West"
                        font.bold: true
                        opacity: 0.7
                    }

                    Repeater {
                        model: fullRoot.teamsList

                        QQC2.CheckBox {
                            width: teamsColumn.width
                            visible: fullRoot.teamIsConference(modelData, "West")
                            height: visible ? implicitHeight : 0
                            text: modelData.abbreviation || modelData.displayName
                            checked: fullRoot.isTeamSelected(modelData.id)
                            onToggled: fullRoot.setTeamSelected(modelData.id, checked)
                        }
                    }
                }
            }
        }

        QQC2.Popup {
            id: settingsPopup
            x: Math.max(Kirigami.Units.smallSpacing, fullRoot.width - width - Kirigami.Units.largeSpacing)
            y: heading.height
            width: Math.min(fullRoot.width - Kirigami.Units.largeSpacing * 2, Kirigami.Units.gridUnit * 24)
            height: Math.min(
                Math.max(Kirigami.Units.gridUnit * 6, fullRoot.height - heading.height - Kirigami.Units.largeSpacing),
                settingsContent.implicitHeight + Kirigami.Units.largeSpacing * 2
            )
            padding: Kirigami.Units.smallSpacing
            modal: false
            focus: true
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 4
            }

            Flickable {
                id: settingsFlick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: settingsContent.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

                ColumnLayout {
                    id: settingsContent
                    width: settingsFlick.width
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "Favorite teams"
                        font.bold: true
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
                            model: fullRoot.teamsList

                            QQC2.CheckBox {
                                visible: fullRoot.teamIsConference(modelData, "East")
                                width: visible ? implicitWidth : 0
                                height: visible ? implicitHeight : 0
                                text: modelData.abbreviation || modelData.displayName
                                checked: fullRoot.isFavoriteTeam(modelData.id)
                                onToggled: fullRoot.setFavoriteTeam(modelData.id, checked)
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
                            model: fullRoot.teamsList

                            QQC2.CheckBox {
                                visible: fullRoot.teamIsConference(modelData, "West")
                                width: visible ? implicitWidth : 0
                                height: visible ? implicitHeight : 0
                                text: modelData.abbreviation || modelData.displayName
                                checked: fullRoot.isFavoriteTeam(modelData.id)
                                onToggled: fullRoot.setFavoriteTeam(modelData.id, checked)
                            }
                        }
                    }

                    Kirigami.Separator { Layout.fillWidth: true }

                    PlasmaComponents.Label {
                        text: "Completed games"
                        font.bold: true
                    }

                    QQC2.ComboBox {
                        id: completedGamesCombo
                        Layout.fillWidth: true
                        textRole: "label"
                        model: [
                            { label: "Last 1 day" },
                            { label: "Last 3 days" },
                            { label: "Last 7 days" }
                        ]
                        currentIndex: Plasmoid.configuration.daysBehind === 1 ? 0
                                      : Plasmoid.configuration.daysBehind === 3 ? 1
                                      : Plasmoid.configuration.daysBehind === 7 ? 2
                                      : 0
                        onActivated: function(index) {
                            Plasmoid.configuration.dateFilterMode = "range";
                            Plasmoid.configuration.daysBehind = [1, 3, 7][index];
                        }
                    }

                    PlasmaComponents.Label {
                        text: "Upcoming games"
                        font.bold: true
                    }

                    QQC2.ComboBox {
                        id: upcomingGamesCombo
                        Layout.fillWidth: true
                        textRole: "label"
                        model: [
                            { label: "Next 1 day" },
                            { label: "Next 3 days" },
                            { label: "Next 7 days" }
                        ]
                        currentIndex: Plasmoid.configuration.daysAhead === 1 ? 0
                                      : Plasmoid.configuration.daysAhead === 3 ? 1
                                      : Plasmoid.configuration.daysAhead === 7 ? 2
                                      : 0
                        onActivated: function(index) {
                            Plasmoid.configuration.dateFilterMode = "range";
                            Plasmoid.configuration.daysAhead = [1, 3, 7][index];
                        }
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: "Max: 14 days total (7 past + 7 future)"
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.7
                    }
                }
            }
        }
    }

    Item {
        anchors {
            fill: parent
            topMargin: heading.height
        }

        Rectangle {
            anchors.fill: parent
            color: Kirigami.Theme.backgroundColor
        }

        //spinner, only before first load
        PlasmaComponents.BusyIndicator {
            anchors.centerIn: parent
            visible: fullRoot.loading && fullRoot.gamesCount === 0
            running: visible
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 4
            visible: !fullRoot.loading &&
                     (fullRoot.errorMessage !== "" || fullRoot.gamesCount === 0)
            iconName: fullRoot.errorMessage !== "" ? "dialog-warning" : "calendar-symbolic"
            text: fullRoot.errorMessage !== ""
                  ? fullRoot.errorMessage
                  : "No games in the selected date range"
        }

        Flickable {
            id: flick
            anchors.fill: parent
            visible: fullRoot.gamesCount > 0
            contentWidth:  Math.max(0, width - fullRoot.scrollRightPadding)
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

            Column {
                id: contentCol
                width: flick.contentWidth
                spacing: 0

                Repeater {
                    model: fullRoot.gamesGroups

                    Column {
                        width: contentCol.width
                        spacing: 0

                        //date header
                        Rectangle {
                            width:  parent.width
                            height: dateLabel.implicitHeight + Kirigami.Units.smallSpacing * 3
                            color:  Kirigami.Theme.alternateBackgroundColor

                            PlasmaComponents.Label {
                                id: dateLabel
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Kirigami.Units.largeSpacing
                                }
                                text: modelData.label
                                font.bold: true
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                color: Kirigami.Theme.textColor
                            }
                        }

                        Repeater {
                            model: modelData.games

                            Column {
                                id: gameContainer
                                width: parent.width
                                spacing: 0

                                property var game: modelData
                                property bool expanded: fullRoot.isGameExpanded(modelData.gameId)
                                property int periodCount: Math.max(
                                    modelData.period || 0,
                                    fullRoot.homeLineScoreCount(modelData),
                                    fullRoot.visitorLineScoreCount(modelData),
                                    fullRoot.lineScoreCount(modelData.homeLinescoreText, modelData.homeLinescores),
                                    fullRoot.lineScoreCount(modelData.visitorLinescoreText, modelData.visitorLinescores),
                                    4
                                )

                                Connections {
                                    target: fullRoot
                                    function onExpandedGamesChanged() {
                                        gameContainer.expanded = fullRoot.isGameExpanded(modelData.gameId);
                                    }
                                }

                                Item {
                                    id: gameRow
                                    width:  parent.width
                                    height: rowContent.implicitHeight + Kirigami.Units.smallSpacing * 2

                                    Rectangle {
                                        anchors.fill: parent
                                        color:   Kirigami.Theme.highlightColor
                                        opacity: rowMouse.containsMouse ? 0.08 : 0
                                        Behavior on opacity { NumberAnimation { duration: 80 } }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: fullRoot.setGameExpanded(modelData.gameId, !gameContainer.expanded)
                                    }

                                    RowLayout {
                                        id: rowContent
                                        anchors {
                                            left:  parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin:  Kirigami.Units.largeSpacing
                                            rightMargin: Kirigami.Units.largeSpacing
                                        }
                                        spacing: 2

                                        //time / status
                                        Item {
                                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                                            implicitHeight: statusLabel.implicitHeight

                                            //live dot
                                            Rectangle {
                                                id: liveDot
                                                visible: modelData.statusType === "live"
                                                anchors {
                                                    right: statusLabel.left
                                                    rightMargin: 4
                                                    verticalCenter: parent.verticalCenter
                                                }
                                                width: 7; height: 7; radius: 4
                                                color: Kirigami.Theme.positiveTextColor

                                                SequentialAnimation on opacity {
                                                    running: liveDot.visible
                                                    loops:   Animation.Infinite
                                                    NumberAnimation { to: 0.15; duration: 700 }
                                                    NumberAnimation { to: 1.0;  duration: 700 }
                                                }
                                            }

                                            PlasmaComponents.Label {
                                                id: statusLabel
                                                anchors {
                                                    left: parent.left
                                                    verticalCenter: parent.verticalCenter
                                                }
                                                text: {
                                                    if (modelData.statusType === "upcoming") {
                                                        return fullRoot.localGameTime(modelData.datetime);
                                                    }
                                                    return modelData.statusLabel;
                                                }
                                                font.bold:      modelData.statusType === "live"
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                color: {
                                                    if (modelData.statusType === "live")
                                                        return Kirigami.Theme.positiveTextColor;
                                                    if (modelData.statusType === "final")
                                                        return Kirigami.Theme.disabledTextColor;
                                                    return Kirigami.Theme.textColor;
                                                }
                                            }
                                        }

                                        //favorite marker
                                        PlasmaComponents.Label {
                                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                            visible: modelData.favoriteGame === true
                                            text: "★"
                                            color: Kirigami.Theme.neutralTextColor
                                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                        }

                                        //matchup — @ pinned to center, teams expand outward
                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: atLabel.implicitHeight

                                            PlasmaComponents.Label {
                                                id: atLabel
                                                anchors.centerIn: parent
                                                text: "@"
                                                color: Kirigami.Theme.disabledTextColor
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                            }

                                            RowLayout {
                                                anchors {
                                                    right: atLabel.left
                                                    rightMargin: Kirigami.Units.smallSpacing / 2
                                                    verticalCenter: parent.verticalCenter
                                                }
                                                spacing: Kirigami.Units.smallSpacing / 2

                                                Image {
                                                    readonly property int sz: Kirigami.Theme.defaultFont.pixelSize
                                                    source: fullRoot.teamIconPath(modelData.visitorAbbr)
                                                    Layout.preferredWidth: sz
                                                    Layout.preferredHeight: sz
                                                    Layout.maximumWidth: sz
                                                    Layout.maximumHeight: sz
                                                    Layout.alignment: Qt.AlignVCenter
                                                    sourceSize.width: sz * 2
                                                    sourceSize.height: sz * 2
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    visible: status === Image.Ready
                                                }
                                                PlasmaComponents.Label {
                                                    text: fullRoot.compactTeamMarkup(modelData.visitorAbbr, modelData.visitorWinner, modelData.statusType)
                                                    textFormat: Text.StyledText
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }

                                            RowLayout {
                                                anchors {
                                                    left: atLabel.right
                                                    leftMargin: Kirigami.Units.smallSpacing / 2
                                                    verticalCenter: parent.verticalCenter
                                                }
                                                spacing: Kirigami.Units.smallSpacing / 2

                                                PlasmaComponents.Label {
                                                    text: fullRoot.compactTeamMarkup(modelData.homeAbbr, modelData.homeWinner, modelData.statusType)
                                                    textFormat: Text.StyledText
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                                Image {
                                                    readonly property int sz: Kirigami.Theme.defaultFont.pixelSize
                                                    source: fullRoot.teamIconPath(modelData.homeAbbr)
                                                    Layout.preferredWidth: sz
                                                    Layout.preferredHeight: sz
                                                    Layout.maximumWidth: sz
                                                    Layout.maximumHeight: sz
                                                    Layout.alignment: Qt.AlignVCenter
                                                    sourceSize.width: sz * 2
                                                    sourceSize.height: sz * 2
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    visible: status === Image.Ready
                                                }
                                            }
                                        }

                                        //score badge
                                        Item {
                                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
                                            implicitHeight: scoreRow.implicitHeight

                                            Row {
                                                id: scoreRow
                                                visible: modelData.statusType !== "upcoming"
                                                anchors.centerIn: parent
                                                spacing: 2

                                                PlasmaComponents.Label {
                                                    text: modelData.visitorScore
                                                    font.bold: modelData.statusType === "live" ||
                                                               (modelData.statusType === "final" && modelData.visitorWinner)
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                    color: modelData.statusType === "live" ||
                                                           (modelData.statusType === "final" && modelData.visitorWinner)
                                                           ? Kirigami.Theme.positiveTextColor
                                                           : Kirigami.Theme.textColor
                                                }
                                                PlasmaComponents.Label {
                                                    text: "–"
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                    color: Kirigami.Theme.textColor
                                                }
                                                PlasmaComponents.Label {
                                                    text: modelData.homeScore
                                                    font.bold: modelData.statusType === "live" ||
                                                               (modelData.statusType === "final" && modelData.homeWinner)
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                    color: modelData.statusType === "live" ||
                                                           (modelData.statusType === "final" && modelData.homeWinner)
                                                           ? Kirigami.Theme.positiveTextColor
                                                           : Kirigami.Theme.textColor
                                                }
                                            }
                                        }

                                        Kirigami.Icon {
                                            source: gameContainer.expanded ? "arrow-up" : "arrow-down"
                                            Layout.preferredWidth:  Kirigami.Units.iconSizes.small
                                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                            opacity: 0.4
                                        }
                                    }

                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 1
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.12
                                    }
                                }

                                Item {
                                    id: expandPanel
                                    width:  parent.width
                                    height: gameContainer.expanded
                                            ? expandInner.implicitHeight + Kirigami.Units.smallSpacing * 3
                                            : 0
                                    clip: true
                                    visible: height > 0

                                    Behavior on height {
                                        NumberAnimation { duration: 140; easing.type: Easing.InOutQuad }
                                    }

                                    Column {
                                        id: expandInner
                                        width: parent.width - Kirigami.Units.largeSpacing * 4
                                        anchors {
                                            top:              parent.top
                                            topMargin:        Kirigami.Units.smallSpacing
                                            horizontalCenter: parent.horizontalCenter
                                        }
                                        spacing: 2

                                        //game context
                                        RowLayout {
                                            width: parent.width
                                            spacing: Kirigami.Units.smallSpacing

                                            PlasmaComponents.Label {
                                                Layout.fillWidth: true
                                                text: fullRoot.gameStage(modelData)
                                                elide: Text.ElideRight
                                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                opacity: 0.78
                                            }

                                            PlasmaComponents.Label {
                                                visible: fullRoot.expandedSeriesLabel(modelData) !== ""
                                                Layout.fillWidth: true
                                                text: fullRoot.expandedSeriesLabel(modelData)
                                                elide: Text.ElideRight
                                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                opacity: 0.78
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }

                                        RowLayout {
                                            width: parent.width
                                            spacing: Kirigami.Units.smallSpacing

                                            PlasmaComponents.Label {
                                                Layout.fillWidth: true
                                                visible: fullRoot.gameDetailLabel(modelData) !== ""
                                                text: fullRoot.gameDetailLabel(modelData)
                                                elide: Text.ElideRight
                                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                opacity: 0.58
                                            }

                                            PlasmaComponents.ToolButton {
                                                visible: modelData.espnUrl !== ""
                                                icon.source: Qt.resolvedUrl("../images/icons/espn.svg")
                                                onClicked: Qt.openUrlExternally(modelData.espnUrl)
                                                PlasmaComponents.ToolTip.text: "Open ESPN game page"
                                                PlasmaComponents.ToolTip.visible: hovered
                                                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                                            }

                                            PlasmaComponents.ToolButton {
                                                visible: modelData.nbaUrl !== ""
                                                icon.source: Qt.resolvedUrl("../images/icons/nba.svg")
                                                onClicked: Qt.openUrlExternally(modelData.nbaUrl)
                                                PlasmaComponents.ToolTip.text: "Open NBA game page"
                                                PlasmaComponents.ToolTip.visible: hovered
                                                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                                            }
                                        }

                                        //quarter scores
                                        Column {
                                            id: scoreTable
                                            width: parent.width
                                            visible: modelData.statusType !== "upcoming"
                                            spacing: 2
                                            property real teamColumnWidth: Kirigami.Units.gridUnit * 3
                                            property real totalColumnWidth: Kirigami.Units.gridUnit * 3
                                            property real periodColumnWidth: Math.max(
                                                Kirigami.Units.gridUnit * 1.35,
                                                (width - teamColumnWidth - totalColumnWidth -
                                                 Kirigami.Units.smallSpacing * (gameContainer.periodCount + 1)) /
                                                gameContainer.periodCount
                                            )

                                            //period headers
                                            RowLayout {
                                                width: parent.width
                                                spacing: Kirigami.Units.smallSpacing
                                                Item { Layout.preferredWidth: scoreTable.teamColumnWidth }
                                                Repeater {
                                                    model: gameContainer.periodCount
                                                    PlasmaComponents.Label {
                                                        Layout.minimumWidth: scoreTable.periodColumnWidth
                                                        Layout.preferredWidth: scoreTable.periodColumnWidth
                                                        Layout.maximumWidth: scoreTable.periodColumnWidth
                                                        text: index < 4
                                                              ? "Q" + (index + 1)
                                                              : (index === 4 ? "OT" : "OT" + (index - 3))
                                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                        opacity: 0.55
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: scoreTable.totalColumnWidth
                                                    text: "Total"
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    font.bold: true
                                                    opacity: 0.7
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }

                                            //visitor
                                            RowLayout {
                                                width: parent.width
                                                spacing: Kirigami.Units.smallSpacing
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: scoreTable.teamColumnWidth
                                                    text: modelData.visitorAbbr
                                                    font.bold: modelData.statusType === "final" && modelData.visitorWinner
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                }
                                                Repeater {
                                                    model: gameContainer.periodCount
                                                    PlasmaComponents.Label {
                                                        Layout.minimumWidth: scoreTable.periodColumnWidth
                                                        Layout.preferredWidth: scoreTable.periodColumnWidth
                                                        Layout.maximumWidth: scoreTable.periodColumnWidth
                                                        text: fullRoot.visitorLineScore(gameContainer.game, index)
                                                        opacity: text === "–" ? 0.35 : 0.9
                                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: scoreTable.totalColumnWidth
                                                    text: modelData.visitorScore >= 0 ? modelData.visitorScore : "–"
                                                    font.bold: modelData.statusType === "final" && modelData.visitorWinner
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    color: modelData.statusType === "final" && modelData.visitorWinner
                                                           ? Kirigami.Theme.positiveTextColor
                                                           : Kirigami.Theme.textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }

                                            //home
                                            RowLayout {
                                                width: parent.width
                                                spacing: Kirigami.Units.smallSpacing
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: scoreTable.teamColumnWidth
                                                    text: modelData.homeAbbr
                                                    font.bold: modelData.statusType === "final" && modelData.homeWinner
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                }
                                                Repeater {
                                                    model: gameContainer.periodCount
                                                    PlasmaComponents.Label {
                                                        Layout.minimumWidth: scoreTable.periodColumnWidth
                                                        Layout.preferredWidth: scoreTable.periodColumnWidth
                                                        Layout.maximumWidth: scoreTable.periodColumnWidth
                                                        text: fullRoot.homeLineScore(gameContainer.game, index)
                                                        opacity: text === "–" ? 0.35 : 0.9
                                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: scoreTable.totalColumnWidth
                                                    text: modelData.homeScore >= 0 ? modelData.homeScore : "–"
                                                    font.bold: modelData.statusType === "final" && modelData.homeWinner
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    color: modelData.statusType === "final" && modelData.homeWinner
                                                           ? Kirigami.Theme.positiveTextColor
                                                           : Kirigami.Theme.textColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 1
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        //refresh bar
        Rectangle {
            id: refreshBar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 2
            visible: fullRoot.loading && fullRoot.gamesCount > 0
            color: Kirigami.Theme.highlightColor

            SequentialAnimation on opacity {
                running: refreshBar.visible
                loops:   Animation.Infinite
                NumberAnimation { to: 0.15; duration: 700 }
                NumberAnimation { to: 0.8;  duration: 700 }
            }
        }
    }
}
