import 'package:cloud_firestore/cloud_firestore.dart';

/// 18+ policy (founder decision, 2026-11-01). A self-declaration, not proof
/// of age: no birthdate or ID is collected.
///
/// `users/{uid}.ageDeclaration` is 'adult' or 'minor'. A 'minor' account
/// is restricted, not deleted; Firestore rules keep it restricted until an
/// operator reviews it.
enum AgeStatus { adult, minor, unknown }

class AgePolicy {
  AgePolicy._();

  static const String field = 'ageDeclaration';
  static const String declaredAtField = 'ageDeclaredAt';
  static const String versionField = 'agePolicyVersion';
  static const int version = 1;

  static AgeStatus statusOf(Map<String, dynamic> data) {
    switch (data[field]) {
      case 'adult':
        return AgeStatus.adult;
      case 'minor':
        return AgeStatus.minor;
    }
    return AgeStatus.unknown;
  }

  static Map<String, dynamic> declaration({required bool adult}) => {
        field: adult ? 'adult' : 'minor',
        declaredAtField: FieldValue.serverTimestamp(),
        versionField: version,
      };
}
