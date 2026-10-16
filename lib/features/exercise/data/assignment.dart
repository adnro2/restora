class Assignment {
  const Assignment({
    required this.id,
    required this.exerciseId,
    required this.title,
    required this.description,
    required this.instructions,
    required this.targetRepetitions,
    required this.flexedThreshold,
    required this.extendedThreshold,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    if (json['exercise_id'] != 'elbow_flexion_extension' ||
        json['demonstration_only'] != true ||
        json['professional_review_required'] != true) {
      throw const FormatException('Unsupported assignment');
    }
    final flexed = (json['flexed_threshold_degrees'] as num).toDouble();
    final extended = (json['extended_threshold_degrees'] as num).toDouble();
    if (flexed < 0 || extended > 180 || flexed >= extended - 10) {
      throw const FormatException('Invalid thresholds');
    }
    return Assignment(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      instructions: List<String>.from(json['instructions'] as List<dynamic>),
      targetRepetitions: json['target_repetitions'] as int,
      flexedThreshold: flexed,
      extendedThreshold: extended,
    );
  }

  final String id, exerciseId, title, description;
  final List<String> instructions;
  final int targetRepetitions;
  final double flexedThreshold, extendedThreshold;
}
