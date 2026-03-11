import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final int roleLevel;
  final bool isActive;
  final bool isVerified;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? loanStats;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? assignedTo;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.roleLevel,
    required this.isActive,
    required this.isVerified,
    this.profile,
    this.loanStats,
    this.lastLogin,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.assignedTo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'borrower',
      roleLevel: json['roleLevel'] ?? 0,
      isActive: json['isActive'] ?? true,
      isVerified: json['isVerified'] ?? false,
      profile: json['profile'],
      loanStats: json['loanStats'],
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      createdBy: json['createdBy']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'roleLevel': roleLevel,
      'isActive': isActive,
      'isVerified': isVerified,
      'profile': profile,
      'loanStats': loanStats,
      'lastLogin': lastLogin?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'assignedTo': assignedTo,
    };
  }

  // ==================== ROLE CHECKS ====================

  bool get isBorrower => role == 'borrower';
  bool get isGuarantor => role == 'guarantor';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isLoanOfficer => role == 'loan_officer';
  bool get isSuperAdmin => role == 'super_admin';

  // ==================== PROFILE HELPERS ====================

  String? get profilePicture => profile?['profilePicture'] as String?;
  String? get address => profile?['address'] as String?;
  String? get city => profile?['city'] as String?;
  String? get country => profile?['country'] as String? ?? 'Somalia';
  String? get occupation => profile?['occupation'] as String?;
  double? get income => (profile?['income'] as num?)?.toDouble();
  String? get idNumber => profile?['idNumber'] as String?;
  String? get idType => profile?['idType'] as String?;
  String? get businessName => profile?['businessName'] as String?;
  String? get businessType => profile?['businessType'] as String?;

  String get fullAddress {
    if (address == null && city == null) return 'Not provided';
    if (address != null && city != null) return '$address, $city';
    return address ?? city ?? 'Not provided';
  }

  // ==================== LOAN STATS HELPERS ====================

  int get totalLoans => loanStats?['totalLoans'] as int? ?? 0;
  int get activeLoans => loanStats?['activeLoans'] as int? ?? 0;
  int get completedLoans => loanStats?['completedLoans'] as int? ?? 0;
  int get defaultedLoans => loanStats?['defaultedLoans'] as int? ?? 0;
  double get totalBorrowed => (loanStats?['totalBorrowed'] as num?)?.toDouble() ?? 0.0;
  double get totalRepaid => (loanStats?['totalRepaid'] as num?)?.toDouble() ?? 0.0;

  double get outstandingBalance => totalBorrowed - totalRepaid;

  double get repaymentRate {
    if (totalBorrowed == 0) return 0;
    return (totalRepaid / totalBorrowed) * 100;
  }

  // ==================== FORMATTING HELPERS ====================

  String get initials {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get roleDisplay {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'loan_officer':
        return 'Loan Officer';
      case 'borrower':
        return 'Borrower';
      case 'guarantor':
        return 'Guarantor';
      default:
        return role;
    }
  }

  Color get roleColor {
    switch (role) {
      case 'super_admin':
        return Colors.red;
      case 'admin':
        return Colors.purple;
      case 'loan_officer':
        return Colors.orange;
      case 'borrower':
        return Colors.green;
      case 'guarantor':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String get statusDisplay => isActive ? 'Active' : 'Inactive';

  Color get statusColor => isActive ? Colors.green : Colors.red;

  String get verificationDisplay => isVerified ? 'Verified' : 'Unverified';

  Color get verificationColor => isVerified ? Colors.green : Colors.orange;

  // ==================== DATE FORMATTING ====================

  String get formattedJoinDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'Joined $years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'Joined $months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return 'Joined ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return 'Joined ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Joined today';
    }
  }

  String get formattedLastLogin {
    if (lastLogin == null) return 'Never logged in';

    final now = DateTime.now();
    final difference = now.difference(lastLogin!);

    if (difference.inDays > 7) {
      return 'Last login ${lastLogin!.day}/${lastLogin!.month}/${lastLogin!.year}';
    } else if (difference.inDays > 0) {
      return 'Last login ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return 'Last login ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Online now';
    }
  }

  // ==================== VALIDATION ====================

  bool get hasCompleteProfile {
    return name.isNotEmpty &&
        email.isNotEmpty &&
        phone.isNotEmpty &&
        profile != null &&
        (profile?['idNumber'] != null || role == 'guarantor'); // Guarantors might not need ID
  }

  bool get canApplyForLoan {
    return isActive && isVerified && hasCompleteProfile;
  }

  bool get canBeGuarantor {
    return isActive && isVerified && role != 'borrower'; // Borrowers can't be guarantors for themselves
  }
}