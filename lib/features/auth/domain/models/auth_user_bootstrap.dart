import 'package:equatable/equatable.dart';
import '../../../../core/security/permission.dart';
import '../../../academy/domain/models/educational_center.dart';
import 'user_profile.dart';
import 'user_role.dart';

enum AccountStatus {
  active,
  inactive,
  suspended;

  static AccountStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'active':
        return AccountStatus.active;
      case 'inactive':
        return AccountStatus.inactive;
      case 'suspended':
        return AccountStatus.suspended;
      default:
        return AccountStatus.inactive;
    }
  }
}

class AuthUserBootstrap extends Equatable {
  final UserProfile profile;
  final UserRole role;
  final String? primaryBranchId;
  final AccountStatus accountStatus;
  final List<Permission> effectivePermissions;
  final String? studentId;
  final String? parentId;
  final String? teacherId;
  final EducationalCenter? activeCenter;
  final List<UserCenterMembership> availableCenters;

  const AuthUserBootstrap({
    required this.profile,
    required this.role,
    this.primaryBranchId,
    required this.accountStatus,
    required this.effectivePermissions,
    this.studentId,
    this.parentId,
    this.teacherId,
    this.activeCenter,
    this.availableCenters = const [],
  });

  bool hasPermission(Permission permission) {
    if (accountStatus != AccountStatus.active) return false;
    if (role == UserRole.superAdmin) return true;
    return effectivePermissions.contains(permission);
  }

  factory AuthUserBootstrap.fromJson(Map<String, dynamic> json) {
    final profJson = json['profile'] as Map<String, dynamic>;
    final profile = UserProfile.fromJson(profJson);
    final role = UserRole.fromString(json['canonical_role'] as String? ?? '');
    final status = AccountStatus.fromString(
      json['account_status'] as String? ?? 'active',
    );

    final rawPerms = json['effective_permissions'] as List<dynamic>? ?? [];
    final permissions = rawPerms
        .map((p) => Permission.fromCode(p as String))
        .whereType<Permission>()
        .toList();

    final domainId = json['domain_identity'] as Map<String, dynamic>? ?? {};

    EducationalCenter? activeCenter;
    if (json['active_center'] != null) {
      activeCenter = EducationalCenter.fromJson(
        Map<String, dynamic>.from(json['active_center'] as Map),
      );
    }

    final rawCenters = json['available_centers'] as List<dynamic>? ?? [];
    final availableCenters = rawCenters
        .map(
          (c) => UserCenterMembership.fromJson(
            Map<String, dynamic>.from(c as Map),
          ),
        )
        .toList();

    return AuthUserBootstrap(
      profile: profile,
      role: role,
      primaryBranchId: json['primary_branch_id'] as String?,
      accountStatus: status,
      effectivePermissions: permissions,
      studentId: domainId['student_id'] as String?,
      parentId: domainId['parent_id'] as String?,
      teacherId: domainId['teacher_id'] as String?,
      activeCenter: activeCenter,
      availableCenters: availableCenters,
    );
  }

  @override
  List<Object?> get props => [
    profile,
    role,
    primaryBranchId,
    accountStatus,
    effectivePermissions,
    studentId,
    parentId,
    teacherId,
    activeCenter,
    availableCenters,
  ];
}
