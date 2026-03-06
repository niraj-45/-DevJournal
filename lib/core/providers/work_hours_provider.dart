import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'workspace_provider.dart';

class WorkHours {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const WorkHours({
    this.startHour = 9,
    this.startMinute = 0,
    this.endHour = 18,
    this.endMinute = 0,
  });

  int get totalMinutes {
    final startMins = startHour * 60 + startMinute;
    final endMins = endHour * 60 + endMinute;
    // Support schedules that cross midnight (e.g. 6 PM → 12:30 AM)
    if (endMins <= startMins) return (24 * 60 - startMins) + endMins;
    return endMins - startMins;
  }

  TimeOfDay get start => TimeOfDay(hour: startHour, minute: startMinute);
  TimeOfDay get end => TimeOfDay(hour: endHour, minute: endMinute);

  String get startLabel => _fmt(startHour, startMinute);
  String get endLabel => _fmt(endHour, endMinute);

  String _fmt(int h, int m) {
    final period = h < 12 ? 'AM' : 'PM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }
}

class WorkHoursNotifier extends StateNotifier<WorkHours> {
  final String? _workspaceId;

  WorkHoursNotifier(this._workspaceId) : super(const WorkHours()) {
    _loadFromPrefs();
  }

  /// Prefix all SharedPreferences keys with the workspace ID so each
  /// workspace has its own independent work-hours setting.
  String _key(String base) =>
      _workspaceId != null ? 'wh_${_workspaceId}_$base' : base;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = WorkHours(
      startHour: prefs.getInt(_key('start_hour')) ?? 9,
      startMinute: prefs.getInt(_key('start_minute')) ?? 0,
      endHour: prefs.getInt(_key('end_hour')) ?? 18,
      endMinute: prefs.getInt(_key('end_minute')) ?? 0,
    );
  }

  Future<void> setHours(TimeOfDay start, TimeOfDay end) async {
    state = WorkHours(
      startHour: start.hour,
      startMinute: start.minute,
      endHour: end.hour,
      endMinute: end.minute,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key('start_hour'), start.hour);
    await prefs.setInt(_key('start_minute'), start.minute);
    await prefs.setInt(_key('end_hour'), end.hour);
    await prefs.setInt(_key('end_minute'), end.minute);
  }
}

/// The provider is scoped to the active workspace. When the user switches
/// workspaces the notifier is recreated and loads that workspace's settings.
final workHoursProvider =
    StateNotifierProvider<WorkHoursNotifier, WorkHours>((ref) {
  final ws = ref.watch(workspaceProvider);
  final wsId = ws.valueOrNull?['id'] as String?;
  return WorkHoursNotifier(wsId);
});
