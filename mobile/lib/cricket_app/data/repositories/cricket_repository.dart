import 'package:flutter/foundation.dart';

import '../models/cricket_matches_response_model.dart';
import '../models/match_model.dart';
import '../models/match_scorecard_response_model.dart';
import '../models/score_model.dart';
import '../models/team_info_model.dart';
import '../remote/api_client/cricket_api_client.dart';

/// Repository for cricket match data.
///
/// Adds:
/// - pagination helpers (default: ~50 items)
/// - dedupe + sorting
/// - filtering for Live/Upcoming/Finished lists
class CricketRepository {
  final CricketApiClient _apiClient;
  final String _apiKey;

  // CricAPI pagination:
  // Most endpoints return ~25 items per call and use `offset` as a start index.
  // To load ~50 items we fetch offsets 0 and 25.
  static const int _offsetStep = 25;
  static const int _defaultPaginationSize = 50;

  CricketRepository({
    required CricketApiClient apiClient,
    required String apiKey,
  }) : _apiClient = apiClient,
       _apiKey = apiKey;

  DateTime? _parseUtcDateTime(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final hasTz =
        v.endsWith('Z') ||
        v.contains('+') ||
        (v.contains('-') && v.contains(':'));
    final parsed = DateTime.tryParse(hasTz ? v : '${v}Z');
    return parsed?.toUtc();
  }

  bool _isStaleLimitedOvers(MatchModel match) {
    final t = match.matchType.toLowerCase();
    if (t == 'test') return false;
    final dt = _parseUtcDateTime(match.dateTimeGMT);
    if (dt == null) return false;
    final elapsed = DateTime.now().toUtc().difference(dt);
    if (t == 't20') return elapsed.inHours >= 8;
    if (t == 'odi') return elapsed.inHours >= 14;
    return elapsed.inHours >= 14;
  }

  bool _isNotActuallyStarted(MatchModel match) {
    final s = match.status.toLowerCase();
    if (s.contains('match not started') ||
        s.contains('not started') ||
        s.contains('match starts at') ||
        s.contains('yet to start')) {
      return true;
    }
    if (match.score.isEmpty && (s.contains('starts at') || s.isEmpty)) {
      return true;
    }
    return false;
  }

  bool _hasFinishedStatus(String status) {
    final s = status.toLowerCase();
    return s.contains('won by') ||
        s.contains('won the match') ||
        s.contains('match won') ||
        s.contains('match drawn') ||
        s.contains('match tied') ||
        s.contains('no result') ||
        s.contains('abandoned') ||
        s.contains('cancelled') ||
        s.contains('completed');
  }

  int _pagesForDesiredCount(int desiredCount) {
    return (desiredCount / _offsetStep).ceil().clamp(1, 50);
  }

  Future<List<Map<String, dynamic>>> _fetchCricScoreEntries({
    int desiredCount = _defaultPaginationSize,
  }) async {
    final pages = _pagesForDesiredCount(desiredCount);
    final futures = <Future<Map<String, dynamic>>>[];
    for (var i = 0; i < pages; i++) {
      futures.add(
        _apiClient.getCricScore(apiKey: _apiKey, offset: i * _offsetStep),
      );
    }
    final results = await Future.wait(futures);
    final all = <Map<String, dynamic>>[];
    for (final page in results) {
      final data = page['data'];
      if (data is List) {
        all.addAll(data.whereType<Map<String, dynamic>>());
      }
    }
    return all;
  }

  Future<List<MatchModel>> _fetchMatchesPages({
    int desiredCount = _defaultPaginationSize,
  }) async {
    final pages = _pagesForDesiredCount(desiredCount);
    final futures = <Future<CricketMatchesResponseModel>>[];
    for (var i = 0; i < pages; i++) {
      futures.add(
        _apiClient.getMatches(apiKey: _apiKey, offset: i * _offsetStep),
      );
    }
    final results = await Future.wait(futures);
    final byId = <String, MatchModel>{};
    for (final resp in results) {
      for (final m in resp.data) {
        if (m.id.isEmpty) continue;
        byId.putIfAbsent(m.id, () => m);
      }
    }
    return byId.values.toList();
  }

  Future<List<MatchModel>> _fetchCurrentMatchesPages({
    int desiredCount = _defaultPaginationSize,
  }) async {
    final pages = _pagesForDesiredCount(desiredCount);
    final futures = <Future<CricketMatchesResponseModel>>[];
    for (var i = 0; i < pages; i++) {
      futures.add(
        _apiClient.getCurrentMatches(apiKey: _apiKey, offset: i * _offsetStep),
      );
    }
    final results = await Future.wait(futures);
    final byId = <String, MatchModel>{};
    for (final resp in results) {
      for (final m in resp.data) {
        if (m.id.isEmpty) continue;
        byId.putIfAbsent(m.id, () => m);
      }
    }
    return byId.values.toList();
  }

  String _parseTeamName(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final open = v.indexOf('(');
    if (open > 0) return v.substring(0, open).trim();
    return v;
  }

  String _parseTeamShortname(String raw) {
    final v = raw.trim();
    final open = v.indexOf('(');
    final close = v.indexOf(')');
    if (open >= 0 && close > open) {
      final inside = v.substring(open + 1, close).trim();
      if (inside.isNotEmpty) return inside;
    }
    final name = _parseTeamName(v);
    final letters = name.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return '';
    return letters.length <= 3
        ? letters.toUpperCase()
        : letters.substring(0, 3).toUpperCase();
  }

  ScoreModel? _parseScoreString(String raw, String inning) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    try {
      double overs = 0.0;
      String mainPart = v;

      final parenStart = v.indexOf('(');
      final parenEnd = v.indexOf(')');
      if (parenStart >= 0 && parenEnd > parenStart) {
        final inside = v.substring(parenStart + 1, parenEnd).trim();
        // examples: "19.2 ov", "76.0 ov", "20 ov"
        final numStr = inside.split(' ').first.trim();
        overs = double.tryParse(numStr) ?? 0.0;
        mainPart = v.substring(0, parenStart).trim();
      }

      if (mainPart.contains('/')) {
        final parts = mainPart.split('/');
        return ScoreModel(
          r: int.tryParse(parts[0].trim()) ?? 0,
          w: int.tryParse(parts[1].trim()) ?? 0,
          o: overs,
          inning: inning,
        );
      }

      return ScoreModel(
        r: int.tryParse(mainPart) ?? 0,
        w: 0,
        o: overs,
        inning: inning,
      );
    } catch (_) {
      return null;
    }
  }

  MatchModel _cricScoreEntryToMatchModel(
    Map<String, dynamic> entry, {
    required bool matchStarted,
    required bool matchEnded,
  }) {
    final t1Raw = (entry['t1'] as String?) ?? '';
    final t2Raw = (entry['t2'] as String?) ?? '';
    final t1s = (entry['t1s'] as String?) ?? '';
    final t2s = (entry['t2s'] as String?) ?? '';
    final t1img = (entry['t1img'] as String?) ?? '';
    final t2img = (entry['t2img'] as String?) ?? '';
    final series = (entry['series'] as String?) ?? '';
    final dateTimeGMT = (entry['dateTimeGMT'] as String?) ?? '';

    final t1Name = _parseTeamName(t1Raw);
    final t1Short = _parseTeamShortname(t1Raw);
    final t2Name = _parseTeamName(t2Raw);
    final t2Short = _parseTeamShortname(t2Raw);

    final score1 = _parseScoreString(t1s, '$t1Name Inning 1');
    final score2 = _parseScoreString(t2s, '$t2Name Inning 1');
    final scores = <ScoreModel>[
      if (score1 != null) score1,
      if (score2 != null) score2,
    ];

    final date = dateTimeGMT.contains('T')
        ? dateTimeGMT.split('T').first
        : dateTimeGMT;

    return MatchModel(
      id: (entry['id'] as String?) ?? '',
      name: '$t1Name vs $t2Name${series.isNotEmpty ? ', $series' : ''}',
      matchType: (entry['matchType'] as String?) ?? '',
      status: (entry['status'] as String?) ?? '',
      venue: '',
      date: date,
      dateTimeGMT: dateTimeGMT,
      teams: [t1Name, t2Name],
      teamInfo: [
        TeamInfoModel(name: t1Name, shortname: t1Short, img: t1img),
        TeamInfoModel(name: t2Name, shortname: t2Short, img: t2img),
      ],
      score: scores,
      matchStarted: matchStarted,
      matchEnded: matchEnded,
    );
  }

  void _sortByDateDesc(List<MatchModel> list) {
    list.sort((a, b) {
      if (a.dateTimeGMT.isNotEmpty && b.dateTimeGMT.isNotEmpty) {
        return b.dateTimeGMT.compareTo(a.dateTimeGMT);
      }
      if (a.date.isNotEmpty && b.date.isNotEmpty) {
        return b.date.compareTo(a.date);
      }
      return 0;
    });
  }

  void _sortByDateAsc(List<MatchModel> list) {
    list.sort((a, b) {
      if (a.dateTimeGMT.isNotEmpty && b.dateTimeGMT.isNotEmpty) {
        return a.dateTimeGMT.compareTo(b.dateTimeGMT);
      }
      if (a.date.isNotEmpty && b.date.isNotEmpty) {
        return a.date.compareTo(b.date);
      }
      return 0;
    });
  }

  /// Fetches all matches for a given offset page.
  /// (Used by schedule screen which stitches multiple offsets.)
  Future<CricketMatchesResponseModel> getAllMatches({int offset = 0}) async {
    final matchesResp = await _apiClient.getMatches(
      apiKey: _apiKey,
      offset: offset,
    );

    CricketMatchesResponseModel? currentResp;
    try {
      currentResp = await _apiClient.getCurrentMatches(
        apiKey: _apiKey,
        offset: offset,
      );
    } catch (_) {
      currentResp = null;
    }

    final byId = <String, MatchModel>{};
    for (final m in matchesResp.data) {
      if (m.id.isEmpty) continue;
      byId[m.id] = m;
    }
    for (final m in currentResp?.data ?? const <MatchModel>[]) {
      if (m.id.isEmpty) continue;
      byId.putIfAbsent(m.id, () => m);
    }

    final sorted = byId.values.toList();
    _sortByDateDesc(sorted);
    return matchesResp.copyWith(data: sorted);
  }

  Future<CricketMatchesResponseModel> getMatchesByType(String matchType) async {
    final res = await getAllMatches(offset: 0);
    final t = matchType.toLowerCase().trim();
    final filtered = res.data
        .where((m) => m.matchType.toLowerCase().trim() == t)
        .toList();
    return res.copyWith(data: filtered);
  }

  Future<CricketMatchesResponseModel> getLiveMatches() async {
    final results = await Future.wait([
      _fetchMatchesPages(desiredCount: _defaultPaginationSize),
      _fetchCurrentMatchesPages(desiredCount: _defaultPaginationSize),
      _fetchCricScoreEntries(desiredCount: _defaultPaginationSize),
    ]);

    final matchesData = results[0] as List<MatchModel>;
    final currentData = results[1] as List<MatchModel>;
    final cricScoreEntries = results[2] as List<Map<String, dynamic>>;

    final byId = <String, MatchModel>{};
    for (final m in matchesData) {
      if (m.id.isEmpty) continue;
      byId.putIfAbsent(m.id, () => m);
    }
    for (final m in currentData) {
      if (m.id.isEmpty) continue;
      byId.putIfAbsent(m.id, () => m);
    }
    for (final entry in cricScoreEntries) {
      final id = (entry['id'] as String?) ?? '';
      final ms = (entry['ms'] as String?) ?? '';
      if (id.isEmpty) continue;
      if (ms == 'fixture' || ms == 'result') continue;
      byId.putIfAbsent(
        id,
        () => _cricScoreEntryToMatchModel(
          entry,
          matchStarted: true,
          matchEnded: false,
        ),
      );
    }

    final live = byId.values.where((m) {
      if (!m.matchStarted || m.matchEnded) return false;
      if (_isNotActuallyStarted(m)) return false;
      return !_hasFinishedStatus(m.status);
    }).toList();
    _sortByDateDesc(live);
    return CricketMatchesResponseModel(data: live);
  }

  Future<CricketMatchesResponseModel> getUpcomingMatches() async {
    final results = await Future.wait([
      _fetchMatchesPages(desiredCount: _defaultPaginationSize),
      _fetchCurrentMatchesPages(desiredCount: _defaultPaginationSize),
      _fetchCricScoreEntries(desiredCount: _defaultPaginationSize),
    ]);

    final matchesData = results[0] as List<MatchModel>;
    final currentData = results[1] as List<MatchModel>;
    final cricScoreEntries = results[2] as List<Map<String, dynamic>>;

    final byId = <String, MatchModel>{};
    for (final m in matchesData) {
      if (m.id.isEmpty) continue;
      byId.putIfAbsent(m.id, () => m);
    }
    for (final m in currentData) {
      if (m.id.isEmpty) continue;
      byId.putIfAbsent(m.id, () => m);
    }
    for (final entry in cricScoreEntries) {
      final id = (entry['id'] as String?) ?? '';
      final ms = (entry['ms'] as String?) ?? '';
      if (id.isEmpty) continue;
      if (ms != 'fixture') continue;
      byId.putIfAbsent(
        id,
        () => _cricScoreEntryToMatchModel(
          entry,
          matchStarted: false,
          matchEnded: false,
        ),
      );
    }

    final upcoming = byId.values.where((m) {
      if (m.matchEnded) return false;
      if (_hasFinishedStatus(m.status)) return false;
      if (!m.matchStarted) return true;
      return _isNotActuallyStarted(m);
    }).toList();
    _sortByDateAsc(upcoming);
    return CricketMatchesResponseModel(data: upcoming);
  }

  Future<CricketMatchesResponseModel> getFinishedMatches() async {
    final results = await Future.wait([
      _fetchCricScoreEntries(desiredCount: _defaultPaginationSize),
      _fetchCurrentMatchesPages(desiredCount: _defaultPaginationSize),
      _fetchMatchesPages(desiredCount: _defaultPaginationSize),
    ]);

    final cricScoreEntries = results[0] as List<Map<String, dynamic>>;
    final currentData = results[1] as List<MatchModel>;
    final matchesData = results[2] as List<MatchModel>;

    final byId = <String, MatchModel>{};
    for (final entry in cricScoreEntries) {
      final id = (entry['id'] as String?) ?? '';
      final ms = (entry['ms'] as String?) ?? '';
      if (id.isEmpty) continue;
      if (ms != 'result') continue;
      byId.putIfAbsent(
        id,
        () => _cricScoreEntryToMatchModel(
          entry,
          matchStarted: true,
          matchEnded: true,
        ),
      );
    }
    for (final m in [...currentData, ...matchesData]) {
      if (m.id.isEmpty) continue;
      if (!m.matchStarted) continue;
      final isFinished =
          m.matchEnded ||
          _hasFinishedStatus(m.status) ||
          _isStaleLimitedOvers(m);
      if (!isFinished) continue;
      byId.putIfAbsent(m.id, () => m);
    }

    final finished = byId.values.toList();
    _sortByDateDesc(finished);
    return CricketMatchesResponseModel(data: finished);
  }

  Future<({CricketMatchesResponseModel matches, Set<String> liveIds})>
  getCurrentMatchesWithLiveStatus() async {
    final results = await Future.wait([
      _fetchCurrentMatchesPages(desiredCount: _defaultPaginationSize),
      _fetchCricScoreEntries(desiredCount: _defaultPaginationSize),
    ]);

    final currentData = results[0] as List<MatchModel>;
    final cricScoreEntries = results[1] as List<Map<String, dynamic>>;

    final matchById = <String, MatchModel>{};
    for (final m in currentData) {
      if (m.id.isEmpty) continue;
      matchById.putIfAbsent(m.id, () => m);
    }

    final liveIds = <String>{};
    for (final entry in cricScoreEntries) {
      final id = (entry['id'] as String?) ?? '';
      final ms = (entry['ms'] as String?) ?? '';
      if (id.isEmpty) continue;
      if (ms == 'fixture' || ms == 'result') continue;
      liveIds.add(id);
      matchById.putIfAbsent(
        id,
        () => _cricScoreEntryToMatchModel(
          entry,
          matchStarted: true,
          matchEnded: false,
        ),
      );
    }

    return (
      matches: CricketMatchesResponseModel(data: matchById.values.toList()),
      liveIds: liveIds,
    );
  }

  Future<CricketMatchesResponseModel> getMatchById(String matchId) {
    return _apiClient.getMatchById(apiKey: _apiKey, matchId: matchId);
  }

  Future<MatchScorecardResponseModel?> getMatchScorecard(String matchId) async {
    try {
      final raw = await _apiClient.getMatchScorecard(
        apiKey: _apiKey,
        matchId: matchId,
      );
      return MatchScorecardResponseModel.fromJson(raw);
    } catch (e) {
      debugPrint('getMatchScorecard error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSeriesList({int offset = 0}) async {
    final raw = await _apiClient.getSeriesList(apiKey: _apiKey, offset: offset);
    final data = raw['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> getSeriesPoints(String seriesId) async {
    final raw = await _apiClient.getSeriesPoints(
      apiKey: _apiKey,
      seriesId: seriesId,
    );
    final data = raw['data'];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    if (data is Map<String, dynamic>) {
      final pt = data['pointsTable'] ?? data['points_table'] ?? data['table'];
      if (pt is List) return pt.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}
