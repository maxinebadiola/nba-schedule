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

function parseIdList(value) {
    if (!value) return [];
    return String(value).split(',').map(function(id) {
        return parseInt(id);
    }).filter(function(id) {
        return !isNaN(id) && id > 0;
    });
}

function containsId(ids, id) {
    for (var i = 0; i < ids.length; i++) {
        if (parseInt(ids[i]) === parseInt(id)) return true;
    }
    return false;
}

function buildDateRangeBetween(fromDate, toDate) {
    var start = new Date(fromDate);
    var end = new Date(toDate);
    var dates = [];
    if (isNaN(start.getTime()) || isNaN(end.getTime())) return dates;
    start.setHours(0, 0, 0, 0);
    end.setHours(0, 0, 0, 0);
    if (start > end) {
        var tmp = start;
        start = end;
        end = tmp;
    }
    var cursor = new Date(start);
    while (cursor <= end && dates.length < 370) {
        dates.push(toYYYYMMDD(cursor));
        cursor.setDate(cursor.getDate() + 1);
    }
    return dates;
}

function dateLabel(dateStr) {
    var parts = dateStr.split('-');
    var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
    var days   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var dayNum = d.getDate();
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    var cmp = new Date(d);
    cmp.setHours(0, 0, 0, 0);
    var diffDays = Math.round((cmp - today) / 86400000);
    var relative = '';
    if (diffDays === 0) relative = 'Today';
    else if (diffDays === 1) relative = 'Tomorrow';
    else if (diffDays === -1) relative = 'Yesterday';
    else relative = diffDays > 0 ? diffDays + 'd' : Math.abs(diffDays) + 'd ago';
    return dayNum + ' ' + months[d.getMonth()] + ', ' + days[d.getDay()] + ' (' + relative + ')';
}

function gameStatusType(state) {
    if (state === 'in')   return 'live';
    if (state === 'post') return 'final';
    return 'upcoming';
}

function periodLabel(period) {
    if (!period || period === 0) return '';
    if (period <= 4) return 'Q' + period;
    if (period === 5) return 'OT';
    return 'OT' + (period - 4);
}

function statusLabel(game) {
    var t = game.statusType;
    if (t === 'upcoming') return '';
    if (t === 'final') {
        if (game.period && game.period > 4) return 'F/' + periodLabel(game.period);
        return 'Final';
    }
    var p    = game.period ? periodLabel(game.period) : '';
    var time = (game.time || '').trim().replace(/^0:/, '');
    if (p && time) return p + ' ' + time;
    if (p) return p;
    return 'Live';
}

function extractLinescores(linescores) {
    if (!linescores || !Array.isArray(linescores)) return [];
    return linescores.map(function(ls) {
        if (ls.value !== undefined) return parseInt(ls.value);
        if (ls.score !== undefined) return parseInt(ls.score);
        if (ls.displayValue !== undefined) return parseInt(ls.displayValue);
        return 0;
    });
}

function linescoreText(linescores) {
    return extractLinescores(linescores).join('|');
}

function lineScoreAt(linescores, index) {
    var scores = extractLinescores(linescores);
    return index < scores.length ? scores[index] : -1;
}

function extractSummaryLink(event) {
    var links = event.links || [];
    for (var i = 0; i < links.length; i++) {
        var rel = links[i].rel || [];
        if (links[i].href && rel.indexOf('summary') !== -1) return links[i].href;
    }
    for (var j = 0; j < links.length; j++) {
        if (links[j].href) return links[j].href;
    }
    return '';
}

function extractVenue(competition) {
    var venue = competition.venue || {};
    var label = venue.fullName || '';
    var address = venue.address || {};
    var place = '';
    if (address.city && address.state) place = address.city + ', ' + address.state;
    else if (address.city) place = address.city;
    if (label && place) return label + ' · ' + place;
    return label || place;
}

function extractNoteHeadline(competition) {
    var notes = competition.notes || [];
    for (var i = 0; i < notes.length; i++) {
        if (notes[i].headline) return notes[i].headline;
    }
    return '';
}

function extractSummarySeasonSeries(event) {
    var summary = event._summary || {};
    var seasonSeries = summary.seasonseries || [];
    for (var i = 0; i < seasonSeries.length; i++) {
        if (seasonSeries[i].summary) return seasonSeries[i].summary;
    }
    return '';
}

function shortDateLabel(date) {
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return String(date.getDate()).padStart(2, '0') + ' ' + months[date.getMonth()];
}

function formatSeriesDate(month, day, year) {
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var m = parseInt(month);
    var d = parseInt(day);
    if (!m || !d || m < 1 || m > 12) return month + '/' + day;
    var y = year || new Date().getFullYear();
    return shortDateLabel(new Date(y, m - 1, d));
}

function normalizeSeriesSummary(summary, datetime) {
    if (!summary) return '';
    var eventTime = new Date(datetime || '');
    if (!isNaN(eventTime.getTime()) && String(summary).match(/^Series starts\b/)) {
        return 'Series starts ' + shortDateLabel(eventTime);
    }
    return String(summary).replace(/\b([0-9]{1,2})\/([0-9]{1,2})\b/g, function(match, month, day) {
        return formatSeriesDate(month, day, isNaN(eventTime.getTime()) ? null : eventTime.getFullYear());
    });
}

function seriesWinnerSummary(series, homeComp, awayComp, statusType, datetime) {
    if (!series) return '';
    if (series.summary) return normalizeSeriesSummary(series.summary, datetime);

    var competitors = series.competitors || [];
    var homeWins = -1;
    var awayWins = -1;
    for (var i = 0; i < competitors.length; i++) {
        var id = parseInt(competitors[i].id);
        if (id === parseInt(homeComp.team.id)) homeWins = competitors[i].wins || 0;
        if (id === parseInt(awayComp.team.id)) awayWins = competitors[i].wins || 0;
    }

    if (homeWins > awayWins) return homeComp.team.abbreviation + ' leads series ' + homeWins + '-' + awayWins;
    if (awayWins > homeWins) return awayComp.team.abbreviation + ' leads series ' + awayWins + '-' + homeWins;
    if (homeWins === awayWins && homeWins > 0) return 'Series tied ' + homeWins + '-' + awayWins;

    if (statusType === 'final') {
        if (homeComp.winner) return homeComp.team.abbreviation + ' leads series 1-0';
        if (awayComp.winner) return awayComp.team.abbreviation + ' leads series 1-0';
    }

    return '';
}

function extractNbaGameId(event, competition) {
    var candidates = [event.id, event.uid, competition.id, competition.uid];
    for (var i = 0; i < candidates.length; i++) {
        var value = String(candidates[i] || '');
        var match = value.match(/\b00[0-9]{8}\b/);
        if (match) return match[0];
    }
    return '';
}

function buildNbaGameUrl(awayAbbr, homeAbbr, nbaGameId, date) {
    if (nbaGameId) {
        return 'https://www.nba.com/game/' +
               String(awayAbbr || '').toLowerCase() +
               '-vs-' +
               String(homeAbbr || '').toLowerCase() +
               '-' +
               nbaGameId;
    }
    if (date) return 'https://www.nba.com/games?date=' + date;
    return 'https://www.nba.com/games';
}

function nbaScheduleDate(datetime) {
    if (!datetime) return '';
    var gameTime = new Date(datetime);
    if (isNaN(gameTime.getTime())) return '';
    return toYYYYMMDD(new Date(gameTime.getTime() - 12 * 60 * 60 * 1000));
}

function processEvents(rawEvents, filterTeamIds, favoriteTeamIds) {
    var games = [];
    var selectedIds = Array.isArray(filterTeamIds) ? filterTeamIds : parseIdList(filterTeamIds);
    var favoriteIds = Array.isArray(favoriteTeamIds) ? favoriteTeamIds : parseIdList(favoriteTeamIds);

    for (var i = 0; i < rawEvents.length; i++) {
        var event       = rawEvents[i];
        var competition = (event.competitions || [])[0];
        if (!competition) continue;

        var competitors = competition.competitors || [];
        var homeComp = null, awayComp = null;
        for (var j = 0; j < competitors.length; j++) {
            if (competitors[j].homeAway === 'home') homeComp = competitors[j];
            else                                    awayComp = competitors[j];
        }
        if (!homeComp || !awayComp) continue;

        var status     = event.status || {};
        var statusType = status.type  || {};
        var state      = statusType.state || 'pre';
        var st         = gameStatusType(state);
        var period     = status.period || 0;
        var postseason = !!(event.season && event.season.type === 3);
        var nbaGameId  = extractNbaGameId(event, competition);
        var seriesSummary = postseason
            ? seriesWinnerSummary(competition.series, homeComp, awayComp, st, event.date || '')
            : extractSummarySeasonSeries(event);

        var homeId = parseInt(homeComp.team.id);
        var awayId = parseInt(awayComp.team.id);

        if (selectedIds.length > 0 && !containsId(selectedIds, homeId) && !containsId(selectedIds, awayId)) continue;

        var gameDate = toYYYYMMDD(new Date(event.date || ''));
        var nbaDate = nbaScheduleDate(event.date || '') || gameDate;

        games.push({
            gameId:            event.id,
            date:              gameDate,
            datetime:          event.date || '',
            status:            statusType.detail || statusType.description || '',
            statusType:        st,
            statusLabel:       '',
            period:            period,
            time:              (status.displayClock || '').trim(),
            postseason:        postseason,
            gameNote:          extractNoteHeadline(competition),
            seriesSummary:     normalizeSeriesSummary(seriesSummary, event.date || ''),
            espnUrl:           extractSummaryLink(event),
            nbaUrl:            buildNbaGameUrl(awayComp.team.abbreviation, homeComp.team.abbreviation, nbaGameId, nbaDate),
            nbaGameId:         nbaGameId,
            venue:             extractVenue(competition),
            favoriteGame:      containsId(favoriteIds, homeId) || containsId(favoriteIds, awayId),
            homeAbbr:          homeComp.team.abbreviation,
            homeDisplayName:   homeComp.team.abbreviation,
            homeFullName:      homeComp.team.displayName,
            homeTeamId:        homeId,
            homeScore:         st !== 'upcoming' ? parseInt(homeComp.score || '0') : -1,
            homeLinescores:    extractLinescores(homeComp.linescores),
            homeLinescoreText: linescoreText(homeComp.linescores),
            homeQ1:            lineScoreAt(homeComp.linescores, 0),
            homeQ2:            lineScoreAt(homeComp.linescores, 1),
            homeQ3:            lineScoreAt(homeComp.linescores, 2),
            homeQ4:            lineScoreAt(homeComp.linescores, 3),
            homeOT1:           lineScoreAt(homeComp.linescores, 4),
            homeOT2:           lineScoreAt(homeComp.linescores, 5),
            homeOT3:           lineScoreAt(homeComp.linescores, 6),
            homeWinner:        !!homeComp.winner,
            visitorAbbr:       awayComp.team.abbreviation,
            visitorDisplayName: awayComp.team.abbreviation,
            visitorFullName:   awayComp.team.displayName,
            visitorTeamId:     awayId,
            visitorScore:      st !== 'upcoming' ? parseInt(awayComp.score || '0') : -1,
            visitorLinescores: extractLinescores(awayComp.linescores),
            visitorLinescoreText: linescoreText(awayComp.linescores),
            visitorQ1:         lineScoreAt(awayComp.linescores, 0),
            visitorQ2:         lineScoreAt(awayComp.linescores, 1),
            visitorQ3:         lineScoreAt(awayComp.linescores, 2),
            visitorQ4:         lineScoreAt(awayComp.linescores, 3),
            visitorOT1:        lineScoreAt(awayComp.linescores, 4),
            visitorOT2:        lineScoreAt(awayComp.linescores, 5),
            visitorOT3:        lineScoreAt(awayComp.linescores, 6),
            visitorWinner:     !!awayComp.winner
        });
    }

    games.sort(function(a, b) {
        if (a.date !== b.date) return new Date(a.date) - new Date(b.date);

        var aFav = a.favoriteGame ? 0 : 1;
        var bFav = b.favoriteGame ? 0 : 1;
        if (aFav !== bFav) return aFav - bFav;

        return new Date(a.datetime) - new Date(b.datetime);
    });

    for (var k = 0; k < games.length; k++) {
        games[k].statusLabel = statusLabel(games[k]);
    }

    return games;
}

function groupByDate(processedGames) {
    var groups = [];
    var byDate = {};
    for (var i = 0; i < processedGames.length; i++) {
        var g = processedGames[i];
        if (!byDate[g.date]) {
            byDate[g.date] = { date: g.date, label: dateLabel(g.date), games: [] };
            groups.push(byDate[g.date]);
        }
        byDate[g.date].games.push(g);
    }
    return groups;
}

function buildScoreboardUrls(dates) {
    return dates.map(function(date) {
        var espnDate = date.replace(/-/g, '');
        return 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=' + espnDate + '&limit=50';
    });
}

function buildSummaryUrl(eventId) {
    return 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event=' + eventId;
}

function buildTeamsUrl() {
    return 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams?limit=100';
}
