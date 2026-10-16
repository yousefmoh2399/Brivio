import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a user profile and credentials saved on this device (Facebook-style account switcher).
class SavedAccount {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'admin', 'teacher', 'student', 'parent', 'staff'
  final String? avatarUrl;
  final String? centerName;
  final String? password;
  final DateTime lastLoginAt;

  const SavedAccount({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.centerName,
    this.password,
    required this.lastLoginAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role,
    'avatarUrl': avatarUrl,
    'centerName': centerName,
    'password': password,
    'lastLoginAt': lastLoginAt.toIso8601String(),
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    role: json['role'] as String? ?? 'student',
    avatarUrl: json['avatarUrl'] as String?,
    centerName: json['centerName'] as String?,
    password: json['password'] as String?,
    lastLoginAt: json['lastLoginAt'] != null
        ? DateTime.tryParse(json['lastLoginAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  SavedAccount copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? avatarUrl,
    String? centerName,
    String? password,
    DateTime? lastLoginAt,
  }) {
    return SavedAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      centerName: centerName ?? this.centerName,
      password: password ?? this.password,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

/// Persistent service managing saved accounts on the device for fast one-tap login.
class SavedAccountsService {
  static const _storageKey = 'brivio_saved_user_accounts_v1';

  /// Retrieves all accounts saved on this device, sorted by most recent login.
  static Future<List<SavedAccount>> getSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final accounts = decoded
          .map((item) => SavedAccount.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      accounts.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
      return accounts;
    } catch (_) {
      return [];
    }
  }

  /// Saves or updates a user account in the saved list.
  static Future<void> saveAccount(SavedAccount account) async {
    try {
      final accounts = await getSavedAccounts();

      // Remove any prior matching entry by email or ID
      accounts.removeWhere(
        (a) =>
            a.email.toLowerCase() == account.email.toLowerCase() ||
            (account.id.isNotEmpty && a.id == account.id),
      );

      // Insert at the front (most recent)
      accounts.insert(0, account);

      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, serialized);
    } catch (_) {}
  }

  /// Removes an account from the saved list.
  static Future<void> removeAccount(String idOrEmail) async {
    try {
      final accounts = await getSavedAccounts();
      final target = idOrEmail.toLowerCase().trim();

      accounts.removeWhere(
        (a) => a.id == idOrEmail || a.email.toLowerCase().trim() == target,
      );

      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, serialized);
    } catch (_) {}
  }

  /// Checks if an account with this email is already saved.
  static Future<bool> isAccountSaved(String email) async {
    final accounts = await getSavedAccounts();
    final target = email.toLowerCase().trim();
    return accounts.any((a) => a.email.toLowerCase().trim() == target);
  }

  /// Clears all saved accounts.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
