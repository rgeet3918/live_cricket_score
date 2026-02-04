import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/cricket_matches_response_model.dart';
import '../data/models/match_model.dart';
import '../data/repositories/providers/cricket_repository_provider.dart';

part 'matches_provider.g.dart';

/// Match filter type enum
enum MatchFilterType {
  all,
  live,
  upcoming,
  finished,
}

/// State notifier for managing cricket matches data
@riverpod
class MatchesNotifier extends _$MatchesNotifier {
  MatchFilterType _currentFilter = MatchFilterType.all;

  @override
  Future<CricketMatchesResponseModel> build() async {
    return _fetchMatches();
  }

  /// Fetches matches based on current filter
  Future<CricketMatchesResponseModel> _fetchMatches() async {
    try {
      final repository = ref.read(cricketRepositoryProvider);

      final CricketMatchesResponseModel response;

      switch (_currentFilter) {
        case MatchFilterType.all:
          response = await repository.getAllMatches();
          break;
        case MatchFilterType.live:
          response = await repository.getLiveMatches();
          break;
        case MatchFilterType.upcoming:
          response = await repository.getUpcomingMatches();
          break;
        case MatchFilterType.finished:
          response = await repository.getFinishedMatches();
          break;
      }

      return response;
    } catch (e, stackTrace) {
      // Log the error for debugging
      debugPrint('❌ Error fetching matches (${_currentFilter.name}): $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Re-throw the exception so Riverpod can handle it in error state
      // This ensures the UI shows the error properly
      rethrow;
    }
  }

  /// Changes the filter and refetches data
  Future<void> changeFilter(MatchFilterType filter) async {
    _currentFilter = filter;
    // Invalidate to trigger rebuild with new filter
    ref.invalidateSelf();
    // Wait for the new data so callers can sequence UI actions, but do NOT
    // propagate fetch errors to the caller. Errors are already surfaced via the
    // provider's AsyncValue.error state (and handled in the UI).
    try {
      await future;
    } catch (_) {
      // Intentionally swallow to avoid "unhandled async exception" when callers
      // fire-and-forget (e.g. from initState).
    }
  }

  /// Refreshes the matches data
  Future<void> refresh() async {
    ref.invalidateSelf();
    // Same rationale as changeFilter(): keep error in provider state.
    try {
      await future;
    } catch (_) {
      // Intentionally swallowed.
    }
  }

  /// Gets the current filter
  MatchFilterType get currentFilter => _currentFilter;
}

/// Provider for the current match filter
@riverpod
class MatchFilterNotifier extends _$MatchFilterNotifier {
  @override
  MatchFilterType build() {
    return MatchFilterType.all;
  }

  void setFilter(MatchFilterType filter) {
    state = filter;
  }
}

/// Provider for getting matches filtered by type
@riverpod
Future<List<MatchModel>> matchesByType(
  MatchesByTypeRef ref,
  String matchType,
) async {
  final repository = ref.watch(cricketRepositoryProvider);

  try {
    final response = await repository.getMatchesByType(matchType);
    return response.data;
  } catch (e) {
    debugPrint('Error fetching matches by type: $e');
    rethrow;
  }
}

/// Data class holding split current matches for the live screen
class CurrentMatchesData {
  final List<MatchModel> liveMatches;
  final List<MatchModel> completedMatches;

  const CurrentMatchesData({
    required this.liveMatches,
    required this.completedMatches,
  });
}

/// Provider for current matches (live screen with auto-refresh).
/// Uses eCricScore + status text + time-based check to determine truly live.
@riverpod
class CurrentMatchesNotifier extends _$CurrentMatchesNotifier {
  static const _endedStatusPatterns = [
    'won by',
    'won the match',
    'match won',
    'match drawn',
    'match tied',
    'no result',
    'abandoned',
    'cancelled',
    'match ended',
    'match finished',
    'match completed',
    'completed',
    'result',
  ];

  // Cache for completed-match details so we don't refetch match_info on every
  // auto-refresh tick.
  final Map<String, MatchModel> _completedDetailsCache = {};

  @override
  Future<CurrentMatchesData> build() async {
    return _fetchAndSplit();
  }

  /// Check if match status text indicates the match has ended.
  bool _hasEndedStatus(String status) {
    final lower = status.toLowerCase();
    return _endedStatusPatterns.any((p) => lower.contains(p));
  }

  /// Check if a match hasn't actually started despite matchStarted=true.
  /// The API sometimes returns matchStarted=true for upcoming matches.
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

  bool _shouldEnrichCompletedWithMatchInfo(MatchModel match) {
    // If we already have a strong finished status, don't waste an API call.
    if (match.matchEnded) return false;
    if (_hasEndedStatus(match.status)) return false;
    return true;
  }

  Future<CurrentMatchesData> _fetchAndSplit() async {
    try {
      final repository = ref.read(cricketRepositoryProvider);

      // Fetch currentMatches + cricScore in parallel (2 API calls)
      final result = await repository.getCurrentMatchesWithLiveStatus();
      final allMatches = result.matches.data;
      final liveIds = result.liveIds;

      final liveMatches = <MatchModel>[];
      final completedMatches = <MatchModel>[];

      for (final match in allMatches) {
        if (!match.matchStarted) continue; // skip upcoming
        if (_isNotActuallyStarted(match)) continue; // skip false positives

        // A match is completed if ANY of these positive signals is true:
        // 1. matchEnded flag is true
        // 2. status text says "won by", "match drawn", etc.
        //
        // cricScore is used only as a POSITIVE live signal:
        // If a match IS in cricScore liveIds, it's definitely live.
        // But if it's NOT in cricScore, it doesn't mean finished —
        // cricScore may not cover all matches.
        final hasEndedSignal = match.matchEnded ||
            _hasEndedStatus(match.status);

        // cricScore is a strong live signal, but it can still be stale.
        // Never override a strong ended/stale signal for limited-overs matches.
        final isConfirmedLive = liveIds.contains(match.id);

        final treatAsLive = isConfirmedLive && !hasEndedSignal;

        if (hasEndedSignal && !treatAsLive) {
          completedMatches.add(match);
        } else {
          liveMatches.add(match);
        }
      }

      // Enrich completed matches: fetch match_info to convert stale
      // "need runs" statuses into final "won by ..." result text.
      // Limit enrichment API calls to avoid excessive requests.
      final enrichedCompleted = <MatchModel>[];
      var enrichmentCount = 0;
      const maxEnrichment = 25;

      for (final m in completedMatches) {
        final cached = _completedDetailsCache[m.id];
        if (cached != null) {
          enrichedCompleted.add(cached);
          continue;
        }

        if (!_shouldEnrichCompletedWithMatchInfo(m)) {
          _completedDetailsCache[m.id] = m;
          enrichedCompleted.add(m);
          continue;
        }

        if (enrichmentCount >= maxEnrichment) {
          _completedDetailsCache[m.id] = m;
          enrichedCompleted.add(m);
          continue;
        }

        try {
          enrichmentCount++;
          final details = await repository.getMatchById(m.id);
          final resolved = details.data.isNotEmpty ? details.data.first : m;

          final accept = resolved.matchEnded || _hasEndedStatus(resolved.status);
          final finalMatch = accept ? resolved : m;
          _completedDetailsCache[m.id] = finalMatch;
          enrichedCompleted.add(finalMatch);
        } catch (_) {
          _completedDetailsCache[m.id] = m;
          enrichedCompleted.add(m);
        }
      }
      completedMatches
        ..clear()
        ..addAll(enrichedCompleted);

      debugPrint(
        '🏏 cricScore liveIds: ${liveIds.length}, '
        'Live: ${liveMatches.length}, Completed: ${completedMatches.length}',
      );
      for (final m in liveMatches) {
        debugPrint('  🟢 LIVE: ${m.name}');
      }
      for (final m in completedMatches.take(5)) {
        debugPrint('  ✅ DONE: ${m.name} | status: ${m.status}');
      }

      // Sort live matches: latest first
      liveMatches.sort((a, b) {
        if (a.dateTimeGMT.isNotEmpty && b.dateTimeGMT.isNotEmpty) {
          return b.dateTimeGMT.compareTo(a.dateTimeGMT);
        }
        return 0;
      });

      // Sort completed matches: most recent first
      completedMatches.sort((a, b) {
        if (a.dateTimeGMT.isNotEmpty && b.dateTimeGMT.isNotEmpty) {
          return b.dateTimeGMT.compareTo(a.dateTimeGMT);
        }
        return 0;
      });

      return CurrentMatchesData(
        liveMatches: liveMatches,
        completedMatches: completedMatches,
      );
    } catch (e, stackTrace) {
      debugPrint('Error fetching current matches: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Silently refreshes data — updates in background without loading spinner.
  /// On error (e.g. timeout), keeps existing data instead of showing error.
  Future<void> refresh() async {
    try {
      final newData = await _fetchAndSplit();
      state = AsyncData(newData);
    } catch (e) {
      debugPrint('Silent refresh failed (keeping existing data): $e');
    }
  }
}

/// Provider for getting a specific match by ID
@riverpod
Future<MatchModel?> matchById(MatchByIdRef ref, String matchId) async {
  final repository = ref.watch(cricketRepositoryProvider);

  try {
    final response = await repository.getMatchById(matchId);
    if (response.data.isNotEmpty) {
      return response.data.first;
    }
    return null;
  } catch (e) {
    debugPrint('Error fetching match by ID: $e');
    rethrow;
  }
}
