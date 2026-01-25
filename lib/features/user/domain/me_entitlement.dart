import 'package:chaput/features/user/domain/profile_entitlement.dart';

class MeEntitlement {
  final String userId;
  final List<ProfileEntitlement> profiles;

  MeEntitlement({
    required this.userId,
    required this.profiles,
  });

  factory MeEntitlement.fromJson(Map<String, dynamic> json) {
    return MeEntitlement(
      userId: json['user_id'] as String,
      profiles: (json['profiles'] as List<dynamic>? ?? [])
          .map((e) =>
          ProfileEntitlement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}