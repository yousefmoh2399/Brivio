import 'package:equatable/equatable.dart';

class EducationalCenter extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? phoneNumber;
  final String? address;
  final String governorate;
  final String? logoUrl;
  final String subscriptionStatus;
  final String subscriptionTier;

  const EducationalCenter({
    required this.id,
    required this.name,
    required this.code,
    this.phoneNumber,
    this.address,
    this.governorate = 'Cairo',
    this.logoUrl,
    this.subscriptionStatus = 'active',
    this.subscriptionTier = 'trial',
  });

  factory EducationalCenter.fromJson(Map<String, dynamic> json) {
    return EducationalCenter(
      id: json['id'] as String? ?? json['center_id'] as String? ?? '',
      name: json['name'] as String? ?? json['center_name'] as String? ?? '',
      code: json['code'] as String? ?? json['center_code'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      address: json['address'] as String?,
      governorate: json['governorate'] as String? ?? 'Cairo',
      logoUrl: json['logo_url'] as String?,
      subscriptionStatus: json['subscription_status'] as String? ?? 'active',
      subscriptionTier: json['subscription_tier'] as String? ?? 'trial',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'phone_number': phoneNumber,
    'address': address,
    'governorate': governorate,
    'logo_url': logoUrl,
    'subscription_status': subscriptionStatus,
    'subscription_tier': subscriptionTier,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    code,
    phoneNumber,
    address,
    governorate,
    logoUrl,
    subscriptionStatus,
    subscriptionTier,
  ];
}

class UserCenterMembership extends Equatable {
  final String centerId;
  final String centerName;
  final String centerCode;
  final String? logoUrl;
  final String? governorate;
  final String role;
  final bool isPrimary;

  const UserCenterMembership({
    required this.centerId,
    required this.centerName,
    required this.centerCode,
    this.logoUrl,
    this.governorate,
    required this.role,
    this.isPrimary = false,
  });

  factory UserCenterMembership.fromJson(Map<String, dynamic> json) {
    return UserCenterMembership(
      centerId: json['center_id'] as String? ?? '',
      centerName: json['center_name'] as String? ?? '',
      centerCode: json['center_code'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      governorate: json['governorate'] as String?,
      role: json['role'] as String? ?? 'student',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    centerId,
    centerName,
    centerCode,
    logoUrl,
    governorate,
    role,
    isPrimary,
  ];
}

class CenterPartnership extends Equatable {
  final String id;
  final bool isRequester;
  final String partnerCenterId;
  final String partnerCenterName;
  final String partnerCenterCode;
  final String? partnerPhone;
  final String? partnerGovernorate;
  final String status; // 'pending', 'approved', 'rejected', 'terminated'
  final bool sharedTeachersEnabled;
  final String? notes;
  final DateTime createdAt;

  const CenterPartnership({
    required this.id,
    required this.isRequester,
    required this.partnerCenterId,
    required this.partnerCenterName,
    required this.partnerCenterCode,
    this.partnerPhone,
    this.partnerGovernorate,
    required this.status,
    this.sharedTeachersEnabled = true,
    this.notes,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory CenterPartnership.fromJson(Map<String, dynamic> json) {
    return CenterPartnership(
      id: json['partnership_id'] as String? ?? json['id'] as String? ?? '',
      isRequester: json['is_requester'] as bool? ?? false,
      partnerCenterId: json['partner_center_id'] as String? ?? '',
      partnerCenterName: json['partner_center_name'] as String? ?? '',
      partnerCenterCode: json['partner_center_code'] as String? ?? '',
      partnerPhone: json['partner_phone'] as String?,
      partnerGovernorate: json['partner_governorate'] as String?,
      status: json['status'] as String? ?? 'pending',
      sharedTeachersEnabled: json['shared_teachers_enabled'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    isRequester,
    partnerCenterId,
    partnerCenterName,
    partnerCenterCode,
    partnerPhone,
    partnerGovernorate,
    status,
    sharedTeachersEnabled,
    notes,
    createdAt,
  ];
}

class CenterStats extends Equatable {
  final String centerId;
  final String centerName;
  final String centerCode;
  final String governorate;
  final String? phoneNumber;
  final String subscriptionTier;
  final String subscriptionStatus;
  final int branchesCount;
  final int studentsCount;
  final int teachersCount;
  final int groupsCount;
  final int partnershipsCount;

  const CenterStats({
    required this.centerId,
    required this.centerName,
    required this.centerCode,
    required this.governorate,
    this.phoneNumber,
    required this.subscriptionTier,
    required this.subscriptionStatus,
    required this.branchesCount,
    required this.studentsCount,
    required this.teachersCount,
    required this.groupsCount,
    required this.partnershipsCount,
  });

  factory CenterStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    return CenterStats(
      centerId: json['center_id'] as String? ?? '',
      centerName: json['center_name'] as String? ?? '',
      centerCode: json['center_code'] as String? ?? '',
      governorate: json['governorate'] as String? ?? 'Cairo',
      phoneNumber: json['phone_number'] as String?,
      subscriptionTier: json['subscription_tier'] as String? ?? 'trial',
      subscriptionStatus: json['subscription_status'] as String? ?? 'active',
      branchesCount: (stats['branches_count'] as num?)?.toInt() ?? 0,
      studentsCount: (stats['students_count'] as num?)?.toInt() ?? 0,
      teachersCount: (stats['teachers_count'] as num?)?.toInt() ?? 0,
      groupsCount: (stats['groups_count'] as num?)?.toInt() ?? 0,
      partnershipsCount: (stats['partnerships_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    centerId,
    centerName,
    centerCode,
    governorate,
    phoneNumber,
    subscriptionTier,
    subscriptionStatus,
    branchesCount,
    studentsCount,
    teachersCount,
    groupsCount,
    partnershipsCount,
  ];
}
