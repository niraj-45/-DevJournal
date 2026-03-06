class SessionModel {
  final String id;
  final String userId;
  final String workspaceId;
  final String? ticketId;
  final String? ticketLabel;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? notes;
  final bool isBillable;

  SessionModel({
    required this.id,
    required this.userId,
    required this.workspaceId,
    this.ticketId,
    this.ticketLabel,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.notes,
    this.isBillable = true,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'],
      userId: map['user_id'],
      workspaceId: map['workspace_id'],
      ticketId: map['ticket_id'],
      ticketLabel: map['tickets'] != null ? map['tickets']['ticket_id'] : null,
      startedAt: DateTime.parse(map['started_at']),
      endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at']) : null,
      durationSeconds: map['duration_seconds'],
      notes: map['notes'],
      isBillable: map['is_billable'] ?? true,
    );
  }

  String get formattedDuration {
    final seconds = durationSeconds ?? 0;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}