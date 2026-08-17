import '../../auth/application/auth_state.dart';

import 'work_address.dart';

enum ProfileEditMode { add, correct, locked, unavailable }

class ProfileFieldEditPolicy {
  const ProfileFieldEditPolicy({required this.canEdit, required this.mode});

  const ProfileFieldEditPolicy.unavailable()
    : canEdit = false,
      mode = ProfileEditMode.unavailable;

  final bool canEdit;
  final ProfileEditMode mode;

  factory ProfileFieldEditPolicy.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const ProfileFieldEditPolicy.unavailable();
    }

    final canEditValue = raw['can_edit'];
    final canEdit =
        canEditValue == true ||
        canEditValue == 1 ||
        canEditValue?.toString().toLowerCase() == 'true';

    final modeValue = raw['mode']?.toString().trim().toLowerCase();

    final mode = switch (modeValue) {
      'add' => ProfileEditMode.add,
      'correct' => ProfileEditMode.correct,
      'locked' => ProfileEditMode.locked,
      _ => ProfileEditMode.unavailable,
    };

    return ProfileFieldEditPolicy(canEdit: canEdit, mode: mode);
  }
}

class ProfileEditPolicy {
  const ProfileEditPolicy({
    required this.email,
    required this.cnic,
    required this.ntn,
    required this.companyName,
  });

  static const unavailable = ProfileEditPolicy(
    email: ProfileFieldEditPolicy.unavailable(),
    cnic: ProfileFieldEditPolicy.unavailable(),
    ntn: ProfileFieldEditPolicy.unavailable(),
    companyName: ProfileFieldEditPolicy.unavailable(),
  );

  final ProfileFieldEditPolicy email;
  final ProfileFieldEditPolicy cnic;
  final ProfileFieldEditPolicy ntn;
  final ProfileFieldEditPolicy companyName;

  factory ProfileEditPolicy.fromJson(dynamic raw) {
    if (raw is! Map) return unavailable;

    return ProfileEditPolicy(
      email: ProfileFieldEditPolicy.fromJson(raw['email']),
      cnic: ProfileFieldEditPolicy.fromJson(raw['cnic']),
      ntn: ProfileFieldEditPolicy.fromJson(raw['ntn']),
      companyName: ProfileFieldEditPolicy.fromJson(raw['company_name']),
    );
  }
}

class ProfileSummary {
  const ProfileSummary({
    required this.displayName,
    required this.email,
    this.phone,
    this.whatsappNo,
    this.address,
    this.workAddress = const WorkAddress.empty(),
    this.customerType,
    this.cnic,
    this.ntn,
    this.companyName,
    this.username,
    this.registerAs,
    this.education,
    this.experience,
    this.remarks,
    this.approvalStatus,
    this.status,
    this.avatarUrl,
    this.canAccessInternalWorkspace = false,
    this.capabilities = AuthCapabilities.guest,
    this.profileEditPolicy = ProfileEditPolicy.unavailable,
  });

  final String displayName;
  final String email;
  final String? phone;
  final String? whatsappNo;
  final String? address;
  final WorkAddress workAddress;
  final String? customerType;
  final String? cnic;
  final String? ntn;
  final String? companyName;
  final String? username;
  final String? registerAs;
  final String? education;
  final String? experience;
  final String? remarks;
  final String? approvalStatus;
  final String? status;
  final String? avatarUrl;
  final bool canAccessInternalWorkspace;
  final AuthCapabilities capabilities;
  final ProfileEditPolicy profileEditPolicy;

  factory ProfileSummary.fromUserId(String? userId) {
    final email = userId?.trim() ?? '';
    final fallbackName = _displayNameFromEmail(email);

    return ProfileSummary(
      displayName: fallbackName.isEmpty ? 'OMC Customer' : fallbackName,
      email: email.isEmpty ? 'Not available' : email,
      status: 'Signed in',
    );
  }

  static String _displayNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return '';

    final cleaned = localPart.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return '';

    return cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
