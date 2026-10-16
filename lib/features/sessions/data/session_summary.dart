/// Immutable stopped summary. Retries serialize these same values and UUID.
class SessionSummary {
  const SessionSummary({
    required this.clientSessionId,
    required this.assignmentId,
    required this.exerciseId,
    required this.startedAt,
    required this.endedAt,
    required this.completedRepetitions,
    required this.trackingMode,
    required this.stopReason,
  });

  final String clientSessionId,
      assignmentId,
      exerciseId,
      trackingMode,
      stopReason;
  final DateTime startedAt, endedAt;
  final int completedRepetitions;

  Map<String, dynamic> toJson() => {
    'client_session_id': clientSessionId,
    'assignment_id': assignmentId,
    'exercise_id': exerciseId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'completed_repetitions': completedRepetitions,
    'tracking_mode': trackingMode,
    'stop_reason': stopReason,
  };
}

class SavedSession {
  const SavedSession({
    required this.id,
    required this.clientSessionId,
    required this.repetitions,
    required this.startedAt,
    required this.trackingMode,
    required this.stopReason,
  });

  factory SavedSession.fromJson(Map<String, dynamic> json) => SavedSession(
    id: json['id'] as String,
    clientSessionId: json['client_session_id'] as String,
    repetitions: json['completed_repetitions'] as int,
    startedAt: DateTime.parse(json['started_at'] as String),
    trackingMode: json['tracking_mode'] as String,
    stopReason: json['stop_reason'] as String,
  );

  final String id, clientSessionId, trackingMode, stopReason;
  final int repetitions;
  final DateTime startedAt;
}
