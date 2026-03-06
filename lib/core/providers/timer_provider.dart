import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimerState {
  final bool isRunning;
  final DateTime? startedAt;
  final String? activeSessionId;
  final String? ticketInput;
  final String? subtaskInput;
  final int elapsedSeconds;

  const TimerState({
    this.isRunning = false,
    this.startedAt,
    this.activeSessionId,
    this.ticketInput,
    this.subtaskInput,
    this.elapsedSeconds = 0,
  });

  TimerState copyWith({
    bool? isRunning,
    DateTime? startedAt,
    String? activeSessionId,
    String? ticketInput,
    String? subtaskInput,
    int? elapsedSeconds,
    bool clearStartedAt = false,
    bool clearActiveSessionId = false,
  }) {
    return TimerState(
      isRunning: isRunning ?? this.isRunning,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      activeSessionId:
          clearActiveSessionId ? null : (activeSessionId ?? this.activeSessionId),
      ticketInput: ticketInput ?? this.ticketInput,
      subtaskInput: subtaskInput ?? this.subtaskInput,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }

  String get formattedTime {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _ticker;
  bool _startInProgress = false;
  final _supabase = Supabase.instance.client;

  TimerNotifier() : super(const TimerState());

  void setTicket(String value) {
    state = state.copyWith(ticketInput: value);
  }

  void setSubtask(String value) {
    state = state.copyWith(subtaskInput: value);
  }

  Future<void> startTimer(String workspaceId) async {
    if (state.isRunning || _startInProgress) return;
    _startInProgress = true;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _startInProgress = false;
      return;
    }

    final now = DateTime.now();

    try {
      final response = await _supabase
          .from('sessions')
          .insert({
            'user_id': user.id,
            'workspace_id': workspaceId,
            'started_at': now.toUtc().toIso8601String(),
            'notes': state.subtaskInput?.trim().isNotEmpty == true
                ? state.subtaskInput!.trim()
                : null,
          })
          .select()
          .single();

      _ticker?.cancel();

      state = state.copyWith(
        isRunning: true,
        startedAt: now,
        activeSessionId: response['id'],
        elapsedSeconds: 0,
      );

      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state.startedAt != null) {
          state = state.copyWith(
            elapsedSeconds: DateTime.now().difference(state.startedAt!).inSeconds,
          );
        }
      });
    } catch (e) {
      debugPrint('startTimer error: $e');
    } finally {
      _startInProgress = false;
    }
  }

  Future<String?> stopTimer() async {
    if (!state.isRunning) return null;

    _ticker?.cancel();
    _ticker = null;

    final sessionId = state.activeSessionId;
    if (sessionId == null) return null;

    final now = DateTime.now();
    final durationSeconds = state.startedAt != null
        ? now.difference(state.startedAt!).inSeconds
        : state.elapsedSeconds;
    final ticket = state.ticketInput;
    final subtask = state.subtaskInput;

    state = state.copyWith(
      isRunning: false,
      elapsedSeconds: 0,
      clearActiveSessionId: true,
      clearStartedAt: true,
    );

    try {
      await _supabase
          .from('sessions')
          .update({
            'ended_at': now.toUtc().toIso8601String(),
            'ticket_id': ticket?.isNotEmpty == true ? ticket : null,
            'notes': subtask?.trim().isNotEmpty == true ? subtask!.trim() : null,
            'duration_seconds': durationSeconds,
          })
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('stopTimer DB error: $e');
    }

    return sessionId;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier();
});