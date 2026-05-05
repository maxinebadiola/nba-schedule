.pragma library

function toYYYYMMDD(date) {
    var y = date.getFullYear();
    var m = String(date.getMonth() + 1).padStart(2, '0');
    var d = String(date.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + d;
}

function buildDateRange(daysAhead, daysBehind) {
    var dates = [];
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    for (var i = -daysBehind; i <= daysAhead; i++) {
        var d = new Date(today);
        d.setDate(today.getDate() + i);
        dates.push(toYYYYMMDD(d));
    }
    return dates;
}

function dateLabel(dateStr) {
    var parts = dateStr.split('-');
    var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
    var days   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    var months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    var dayNum = String(d.getDate()).padStart(2, '0');
    return dayNum + ' ' + months[d.getMonth()] + ' | ' + days[d.getDay()];
}

function gameStatusType(status) {
    if (!status) return 'upcoming';
    if (status === 'Final' || status.indexOf('Final') === 0) return 'final';
    if (status.indexOf('T') !== -1) return 'upcoming'; //iso datetime = not started
    return 'live';
}

function periodLabel(period) {
    if (!period || period === 0) return '';
    if (period <= 4) return 'Q' + period;
    if (period === 5) return 'OT';
    return 'OT' + (period - 4);
}

function statusLabel(game) {
    var t = gameStatusType(game.status);
    if (t === 'upcoming') return '';
    if (t === 'final') {
        if (game.period && game.period > 4) return 'F/' + periodLabel(game.period);
        return 'Final';
    }
    var p = game.period ? periodLabel(game.period) : '';
    var time = (game.time || '').trim().replace(/^0:/, '');
    if (p && time) return p + ' ' + time;
    if (p) return p;
    if (game.status && game.status !== 'In Progress') return game.status;
    return 'Live';
}

function processGames(rawGames) {
    rawGames.sort(function(a, b) {
        return new Date(a.datetime || a.date) - new Date(b.datetime || b.date);
    });

    return rawGames.map(function(g) {
        var st = gameStatusType(g.status);
        return {
            gameId:          g.id,
            date:            g.date,
            datetime:        g.datetime || '',
            status:          g.status || '',
            statusType:      st,
            statusLabel:     statusLabel(g),
            period:          g.period || 0,
            time:            (g.time || '').trim(),
            postseason:      g.postseason || false,
            homeAbbr:        g.home_team.abbreviation,
            homeFullName:    g.home_team.full_name,
            homeTeamId:      g.home_team.id,
            homeScore:       (st !== 'upcoming') ? (g.home_team_score || 0) : -1,
            visitorAbbr:     g.visitor_team.abbreviation,
            visitorFullName: g.visitor_team.full_name,
            visitorTeamId:   g.visitor_team.id,
            visitorScore:    (st !== 'upcoming') ? (g.visitor_team_score || 0) : -1
        };
    });
}

function groupByDate(processedGames) {
    var groups = [];
    var currentDate = null;
    for (var i = 0; i < processedGames.length; i++) {
        var g = processedGames[i];
        if (g.date !== currentDate) {
            currentDate = g.date;
            groups.push({ date: currentDate, label: dateLabel(currentDate), games: [] });
        }
        groups[groups.length - 1].games.push(g);
    }
    return groups;
}

function buildGamesUrl(teamId, daysAhead, daysBehind) {
    var dates = buildDateRange(daysAhead, daysBehind);
    var url = 'https://api.balldontlie.io/v1/games?per_page=100';
    for (var i = 0; i < dates.length; i++) {
        url += '&dates[]=' + dates[i];
    }
    if (teamId && teamId > 0) {
        url += '&team_ids[]=' + teamId;
    }
    return url;
}
