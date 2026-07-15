/// User model representing an authenticated SmartDrip user
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? deviceId; // Linked ESP32 device
  final String role; // user | admin (future use)

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    this.lastLogin,
    this.deviceId,
    this.role = 'user',
  });

  // =========================
  // HELPERS
  // =========================

  bool get isAdmin => role == 'admin';

  String get firstName => name.trim().split(' ').first;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  bool get hasDevice => deviceId != null && deviceId!.isNotEmpty;

  // =========================
  // FIREBASE JSON
  // =========================

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'User',
      email: json['email'] ?? '',
      photoUrl: json['photoUrl'],
      createdAt: _parseDate(json['createdAt']),
      lastLogin: json['lastLogin'] != null
          ? _parseDate(json['lastLogin'])
          : null,
      deviceId: json['deviceId'],
      role: json['role'] ?? 'user',
    );
  }

  /// For Firebase Realtime Database / Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'deviceId': deviceId,
      'role': role,
    };
  }

  /// Alias (clean naming for Firebase writes)
  Map<String, dynamic> toFirebase() => toJson();

  // =========================
  // COPY WITH (FIXED + SAFE)
  // =========================

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? deviceId,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      deviceId: deviceId ?? this.deviceId,
      role: role ?? this.role,
    );
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, name: $name, email: $email, device: $deviceId)';
}

// ===============================
// SAFE DATE PARSER
// ===============================

DateTime _parseDate(dynamic value) {
  try {
    if (value == null) return DateTime.now();

    if (value is String) {
      return DateTime.parse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
}