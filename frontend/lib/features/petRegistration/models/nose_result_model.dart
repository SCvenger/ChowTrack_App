// ═════════════════════════════════════════════════════════════════════════════
// lib/features/petRegistration/models/nose_result_model.dart
// ═════════════════════════════════════════════════════════════════════════════

class NoseRegisterResult {
  final bool success;
  final double qualityScore;
  final int keypointCount;
  final String pattern;
  final List<String> features;
  final String message;

  const NoseRegisterResult({
    required this.success,
    required this.qualityScore,
    required this.keypointCount,
    required this.pattern,
    required this.features,
    required this.message,
  });

  factory NoseRegisterResult.fromJson(Map<String, dynamic> json) =>
      NoseRegisterResult(
        success:       json['success']        as bool,
        qualityScore:  (json['quality_score'] as num).toDouble(),
        keypointCount: json['keypoint_count'] as int,
        pattern:       json['pattern']        as String? ?? '',
        features:      (json['features'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        message:       json['message']        as String? ?? '',
      );
}

class NoseMatchResult {
  final bool match;
  final String? petId;
  final String? petName;
  final double score;
  final String explanation;
  final String message;

  const NoseMatchResult({
    required this.match,
    this.petId,
    this.petName,
    this.score = 0.0,
    this.explanation = '',
    this.message = '',
  });

  factory NoseMatchResult.fromJson(Map<String, dynamic> json) => NoseMatchResult(
        match:       json['match']       as bool,
        petId:       json['pet_id']      as String?,
        petName:     json['pet_name']    as String?,
        score:       (json['score']      as num?)?.toDouble() ?? 0.0,
        explanation: json['explanation'] as String? ?? '',
        message:     json['message']     as String? ?? '',
      );
}

