// lib/features/profile/models/profile_model.dart

class ProfileModel {
  final String id;
  final String? displayName;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    this.displayName,
    this.phone,
    this.avatarUrl,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id:          json['id']           as String,
        displayName: json['display_name'] as String?,
        phone:       json['phone']        as String?,
        avatarUrl:   json['avatar_url']   as String?,
        createdAt:   json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  bool get hasPhone  => phone != null && phone!.isNotEmpty;
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  ProfileModel copyWith({
    String? displayName,
    String? phone,
    String? avatarUrl,
  }) =>
      ProfileModel(
        id:          id,
        displayName: displayName ?? this.displayName,
        phone:       phone       ?? this.phone,
        avatarUrl:   avatarUrl   ?? this.avatarUrl,
        createdAt:   createdAt,
      );
}