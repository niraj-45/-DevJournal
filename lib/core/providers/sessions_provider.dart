import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session_model.dart';

// ── Selected date for session history navigation ─────────────────────────────
final selectedDateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class SessionWithMood {
  final SessionModel session;
  final int? focusScore;
  final int? energyScore;
  final String? blocker;

  const SessionWithMood({
    required this.session,
    this.focusScore,
    this.energyScore,
    this.blocker,
  });
}

// Shared query logic
Future<List<SessionWithMood>> _fetchSessionsForDate(DateTime date) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  // Build the local day boundaries and convert to UTC for the query,
  // so the filter matches Supabase's timestamptz values correctly.
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

  final response = await Supabase.instance.client
      .from('sessions')
      .select('*, mood_logs(focus_score, energy_score, blocker)')
      .eq('user_id', user.id)
      .gte('started_at', dayStart.toUtc().toIso8601String())
      .lte('started_at', dayEnd.toUtc().toIso8601String())
      .not('ended_at', 'is', null)
      .order('started_at', ascending: false);

  return (response as List).map((row) {
    final moodRaw = row['mood_logs'];
    Map<String, dynamic>? mood;
    if (moodRaw is Map<String, dynamic>) {
      mood = moodRaw;
    } else if (moodRaw is List && moodRaw.isNotEmpty) {
      mood = moodRaw[0] as Map<String, dynamic>;
    }
    return SessionWithMood(
      session: SessionModel.fromMap(row),
      focusScore: mood?['focus_score'] as int?,
      energyScore: mood?['energy_score'] as int?,
      blocker: mood?['blocker'] as String?,
    );
  }).toList();
}

// Today's sessions (used by timer screen work hours bar + standup)
final todaySessionsProvider = FutureProvider<List<SessionWithMood>>((ref) async {
  return _fetchSessionsForDate(DateTime.now());
});

// Sessions for any date (used by sessions screen + standup with date navigation)
final sessionsForDateProvider =
    FutureProvider.family<List<SessionWithMood>, DateTime>((ref, date) async {
  return _fetchSessionsForDate(date);
});

/// Delete a session and its related mood_logs, then invalidate caches.
Future<void> deleteSession(String sessionId, WidgetRef ref) async {
  final supabase = Supabase.instance.client;
  // Delete mood_logs first (FK constraint), then the session row.
  await supabase.from('mood_logs').delete().eq('session_id', sessionId);
  await supabase.from('sessions').delete().eq('id', sessionId);
  // Refresh both providers so the UI updates immediately.
  ref.invalidate(todaySessionsProvider);
  final date = ref.read(selectedDateProvider);
  ref.invalidate(sessionsForDateProvider(dateOnly(date)));
}

/// Check whether a time range overlaps with any existing session for the user.
/// [excludeSessionId] allows an edit to ignore the session being edited.
Future<bool> hasOverlap({
  required DateTime start,
  required DateTime end,
  String? excludeSessionId,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;

  // A new session overlaps an existing one when:
  //   new.start < existing.end  AND  new.end > existing.start
  var query = Supabase.instance.client
      .from('sessions')
      .select('id')
      .eq('user_id', user.id)
      .not('ended_at', 'is', null)
      .lt('started_at', end.toUtc().toIso8601String())
      .gt('ended_at', start.toUtc().toIso8601String());

  if (excludeSessionId != null) {
    query = query.neq('id', excludeSessionId);
  }

  final rows = await query;
  return (rows as List).isNotEmpty;
}

/// Create a manual session (no live timer) with overlap validation.
Future<void> createManualSession({
  required String workspaceId,
  required DateTime start,
  required DateTime end,
  required String ticketId,
  String? notes,
  required WidgetRef ref,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('Not authenticated');

  if (await hasOverlap(start: start, end: end)) {
    throw Exception('This time range overlaps with an existing session');
  }

  final durationSeconds = end.difference(start).inSeconds;

  await Supabase.instance.client.from('sessions').insert({
    'user_id': user.id,
    'workspace_id': workspaceId,
    'started_at': start.toUtc().toIso8601String(),
    'ended_at': end.toUtc().toIso8601String(),
    'duration_seconds': durationSeconds,
    'ticket_id': ticketId.trim().isNotEmpty ? ticketId.trim() : null,
    'notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
  });

  ref.invalidate(todaySessionsProvider);
  final date = ref.read(selectedDateProvider);
  ref.invalidate(sessionsForDateProvider(dateOnly(date)));
}

/// Update an existing session's ticket, notes, and/or time range.
Future<void> updateSession({
  required String sessionId,
  required DateTime start,
  required DateTime end,
  required String ticketId,
  String? notes,
  required WidgetRef ref,
}) async {
  if (await hasOverlap(start: start, end: end, excludeSessionId: sessionId)) {
    throw Exception('This time range overlaps with an existing session');
  }

  final durationSeconds = end.difference(start).inSeconds;

  await Supabase.instance.client.from('sessions').update({
    'started_at': start.toUtc().toIso8601String(),
    'ended_at': end.toUtc().toIso8601String(),
    'duration_seconds': durationSeconds,
    'ticket_id': ticketId.trim().isNotEmpty ? ticketId.trim() : null,
    'notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
  }).eq('id', sessionId);

  ref.invalidate(todaySessionsProvider);
  final date = ref.read(selectedDateProvider);
  ref.invalidate(sessionsForDateProvider(dateOnly(date)));
}
