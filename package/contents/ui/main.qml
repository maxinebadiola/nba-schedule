import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import "../code/schedule.js" as Schedule

PlasmoidItem {
    id: root

    property bool   loading:      false
    property string errorMessage: ""
    property string lastUpdated:  ""
    property int    gamesCount:   0
    property var    gamesData:    []
    property var    gamesGroups:  []
    property var    teamsList:    []
    readonly property bool useCompactRepresentation:
        Plasmoid.formFactor === Plasmoid.Horizontal || Plasmoid.formFactor === Plasmoid.Vertical

    ListModel { id: gamesModel }

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: Component {
        FullRepresentation {
            gamesGroups:  root.gamesGroups
            gamesCount:   root.gamesCount
            loading:      root.loading
            errorMessage: root.errorMessage
            lastUpdated:  root.lastUpdated
            onRefreshRequested: root.doFetchGames()
        }
    }
    preferredRepresentation: useCompactRepresentation ? compactRepresentation : fullRepresentation

    Plasmoid.configurationRequired: Plasmoid.configuration.apiKey === ""

    Timer {
        id: refreshTimer
        interval: Plasmoid.configuration.refreshInterval * 60 * 1000
        running:  Plasmoid.configuration.apiKey !== ""
        repeat:   true
        onTriggered: root.doFetchGames()
    }

    Component.onCompleted: {
        if (Plasmoid.configuration.apiKey !== "") {
            root.doFetchTeams();
            root.doFetchGames();
            root.burstCount = 1;
            burstTimer.start();
            minuteTimer.start();
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onApiKeyChanged() {
            if (Plasmoid.configuration.apiKey !== "") {
                root.doFetchTeams();
                root.doFetchGames();
                refreshTimer.restart();
                root.burstCount = 1;
                burstTimer.start();
                minuteTimer.start();
            }
        }
        function onTeamIdChanged()      { root.doFetchGames(); }
        function onDaysAheadChanged()   { root.doFetchGames(); }
        function onDaysBehindChanged()  { root.doFetchGames(); }
        function onRefreshIntervalChanged() {
            refreshTimer.interval = Plasmoid.configuration.refreshInterval * 60 * 1000;
            refreshTimer.restart();
        }
    }

    //4 quick fetches on load, then once per minute
    property int burstCount: 0
    Timer {
        id: burstTimer
        interval: 15000
        repeat: true
        running: false
        onTriggered: {
            if (burstCount < 4) {
                root.doFetchGames();
                burstCount++;
            }
            if (burstCount >= 4) burstTimer.stop();
        }
    }

    Timer {
        id: minuteTimer
        interval: 60000
        repeat: true
        running: false
        onTriggered: {
            burstCount = 0;
            burstTimer.start();
        }
    }

    function doFetchGames() {
        var apiKey = Plasmoid.configuration.apiKey;
        if (!apiKey) {
            root.errorMessage = "Please add your API key in settings.";
            root.gamesCount = 0;
            return;
        }
        root.loading = true;
        root.errorMessage = "";

        var url = Schedule.buildGamesUrl(
            Plasmoid.configuration.teamId,
            Plasmoid.configuration.daysAhead,
            Plasmoid.configuration.daysBehind
        );

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.loading = false;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    var processed = Schedule.processGames(data.data || []);
                    gamesModel.clear();
                    for (var i = 0; i < processed.length; i++) {
                        gamesModel.append(processed[i]);
                    }
                    root.gamesData = processed;
                    //sort live games first in today's group
                    var groups = Schedule.groupByDate(processed);
                    var todayStr = Schedule.toYYYYMMDD(new Date());
                    for (var g = 0; g < groups.length; g++) {
                        if (groups[g].date === todayStr) {
                            groups[g].games.sort(function(a, b) {
                                var rank = { live: 0, final: 1, upcoming: 2 };
                                return (rank[a.statusType] || 2) - (rank[b.statusType] || 2);
                            });
                            break;
                        }
                    }
                    root.gamesGroups = groups;
                    root.gamesCount = processed.length;
                    root.errorMessage = "";
                    root.lastUpdated = Qt.formatTime(new Date(), "HH:mm:ss");
                } catch(e) {
                    //keep stale data on parse error
                    if (root.gamesCount === 0) {
                        root.gamesData   = [];
                        root.gamesGroups = [];
                        root.gamesCount  = 0;
                    }
                    root.errorMessage = "Failed to parse API response: " + e.message;
                }
            } else if (xhr.status === 401) {
                root.gamesData   = [];
                root.gamesGroups = [];
                root.gamesCount  = 0;
                root.errorMessage = "API Error 401: Invalid or missing API key. Status: " + xhr.status + " Response: " + xhr.responseText.substring(0, 100);
            } else if (xhr.status === 0) {
                //keep stale data on network error
                if (root.gamesCount === 0) {
                    root.gamesData   = [];
                    root.gamesGroups = [];
                    root.gamesCount  = 0;
                }
                root.errorMessage = "Network error (refresh failed). Showing last known data.";
            } else {
                if (root.gamesCount === 0) {
                    root.gamesData   = [];
                    root.gamesGroups = [];
                    root.gamesCount  = 0;
                }
                root.errorMessage = "API error HTTP " + xhr.status + " (showing cached data). " + (xhr.responseText ? xhr.responseText.substring(0, 60) : "No response");
            }
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("Authorization", apiKey);
        xhr.send();
    }

    function doFetchTeams() {
        var apiKey = Plasmoid.configuration.apiKey;
        if (!apiKey) return;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    root.teamsList = data.data || [];
                } catch(e) {}
            }
        };
        xhr.open("GET", "https://api.balldontlie.io/v1/teams?per_page=100");
        xhr.setRequestHeader("Authorization", apiKey);
        xhr.send();
    }
}
