import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import "../code/schedule.js" as Schedule

PlasmoidItem {
    id: root

    property bool   loading:      false
    property string errorMessage: ""
    property var    lastUpdated:  null
    property int    gamesCount:   0
    property var    gamesData:    []
    property var    gamesGroups:  []
    property var    teamsList:    []
    property int    fetchGeneration: 0
    property bool   hasLiveGames: false
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
            teamsList:    root.teamsList
            onRefreshRequested: root.doFetchGames()
            onSelectedTeamsChanged: function(teamIds, teamName) {
                Plasmoid.configuration.selectedTeamIds = teamIds;
                Plasmoid.configuration.teamId = -1;
                Plasmoid.configuration.teamName = teamName;
                root.doFetchGames();
            }
        }
    }
    preferredRepresentation: useCompactRepresentation ? compactRepresentation : fullRepresentation

    Timer {
        id: refreshTimer
        interval: 60 * 60 * 1000
        running:  true
        repeat:   true
        onTriggered: root.doFetchGames()
    }

    onHasLiveGamesChanged: {
        var newInterval = root.hasLiveGames ? 30 * 1000 : 60 * 60 * 1000;
        refreshTimer.interval = newInterval;
        refreshTimer.restart();
    }

    Component.onCompleted: {
        root.doFetchTeams();
        root.doFetchGames();
    }

    Connections {
        target: Plasmoid.configuration
        function onTeamIdChanged()      { root.doFetchGames(); }
        function onSelectedTeamIdsChanged() { root.doFetchGames(); }
        function onFavoriteTeamIdsChanged() { root.doFetchGames(); }
        function onDaysAheadChanged()   { root.doFetchGames(); }
        function onDaysBehindChanged()  { root.doFetchGames(); }
        function onDateFilterModeChanged() { root.doFetchGames(); }
    }

    function doFetchGames() {
        var generation = ++root.fetchGeneration;
        root.loading = true;
        root.errorMessage = "";

        var dates = root.buildConfiguredDateRange();
        var urls    = Schedule.buildScoreboardUrls(dates);

        if (urls.length === 0) { root.loading = false; return; }

        var allEvents = [];

        function requestQueue(items, maxActive, handler, done) {
            var index = 0;
            var active = 0;
            var finished = 0;
            if (items.length === 0) {
                done();
                return;
            }

            function pump() {
                if (generation !== root.fetchGeneration) return;
                while (active < maxActive && index < items.length) {
                    active++;
                    handler(items[index++], function() {
                        active--;
                        finished++;
                        if (finished >= items.length) done();
                        else pump();
                    });
                }
            }

            pump();
        }

        function selectedIdsForFetch() {
            var selectedIds = Plasmoid.configuration.selectedTeamIds || "";
            if (!selectedIds && Plasmoid.configuration.teamId > 0)
                selectedIds = String(Plasmoid.configuration.teamId);
            return Schedule.parseIdList(selectedIds);
        }

        function eventMatchesSelectedTeams(event, selectedIds) {
            if (selectedIds.length === 0) return true;
            var competition = (event.competitions || [])[0];
            var competitors = competition ? (competition.competitors || []) : [];
            for (var i = 0; i < competitors.length; i++) {
                if (Schedule.containsId(selectedIds, parseInt(competitors[i].team.id))) return true;
            }
            return false;
        }

        function fetchSummaries(events, done) {
            if (events.length === 0) {
                done();
                return;
            }

            requestQueue(events.slice(0, 180), 4, function(event, next) {
                var xhr = new XMLHttpRequest();
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE) return;
                    if (generation !== root.fetchGeneration) return;
                    if (xhr.status === 200) {
                        try {
                            event._summary = JSON.parse(xhr.responseText);
                        } catch(e) {}
                    }
                    next();
                };
                xhr.open("GET", Schedule.buildSummaryUrl(event.id));
                xhr.send();
            }, done);
        }

        function processDone() {
            if (generation !== root.fetchGeneration) return;
            root.loading = false;
            try {
                var selectedIds = Plasmoid.configuration.selectedTeamIds || "";
                if (!selectedIds && Plasmoid.configuration.teamId > 0)
                    selectedIds = String(Plasmoid.configuration.teamId);
                var processed = Schedule.processEvents(
                    allEvents,
                    selectedIds,
                    Plasmoid.configuration.favoriteTeamIds || ""
                );
                root.gamesData = processed;
                var groups = Schedule.groupByDate(processed);
                root.gamesGroups = groups;
                root.gamesCount  = processed.length;
                root.errorMessage = "";
                root.lastUpdated  = new Date();
                var live = false;
                for (var li = 0; li < processed.length; li++) {
                    if (processed[li].statusType === 'live') { live = true; break; }
                }
                root.hasLiveGames = live;
            } catch(e) {
                if (root.gamesCount === 0) {
                    root.gamesData   = [];
                    root.gamesGroups = [];
                    root.gamesCount  = 0;
                }
                root.hasLiveGames = false;
                root.errorMessage = "Failed to parse response: " + e.message;
            }
        }

        requestQueue(urls, 4, function(url, next) {
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (generation !== root.fetchGeneration) return;
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        allEvents = allEvents.concat(data.events || []);
                    } catch(e) {}
                } else if (xhr.status === 0 && root.gamesCount === 0) {
                    root.errorMessage = "Network error. Check your connection.";
                }
                next();
            };
            xhr.open("GET", url);
            xhr.send();
        }, function() {
            var selectedIds = selectedIdsForFetch();
            var visibleEvents = [];
            for (var i = 0; i < allEvents.length; i++) {
                if (eventMatchesSelectedTeams(allEvents[i], selectedIds)) visibleEvents.push(allEvents[i]);
            }
            fetchSummaries(visibleEvents, processDone);
        });
    }

    function buildConfiguredDateRange() {
        var daysAhead = root.clampInt(Plasmoid.configuration.daysAhead, 1, 7, 7);
        var daysBehind = root.clampInt(Plasmoid.configuration.daysBehind, 1, 7, 7);
        return Schedule.buildDateRange(daysAhead, daysBehind);
    }

    function clampInt(value, minValue, maxValue, fallback) {
        var number = parseInt(value);
        if (isNaN(number)) number = fallback;
        return Math.max(minValue, Math.min(maxValue, number));
    }

    function refreshIntervalMs() {
        return root.clampInt(Plasmoid.configuration.refreshInterval, 5, 120, 30) * 60 * 1000;
    }

    function seasonStartDate() {
        var now = new Date();
        var year = now.getFullYear();
        if (now.getMonth() < 8) year--;
        return year + "-10-01";
    }

    function doFetchTeams() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var data     = JSON.parse(xhr.responseText);
                    var sports   = data.sports  || [];
                    var leagues  = (sports[0]   || {}).leagues || [];
                    var teamsArr = (leagues[0]  || {}).teams   || [];
                    root.teamsList = teamsArr.map(function(t) { return t.team; });
                } catch(e) {}
            }
        };
        xhr.open("GET", Schedule.buildTeamsUrl());
        xhr.send();
    }
}
