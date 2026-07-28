import '../../auth/application/auth_state.dart';

class ProfileSummary {
  const ProfileSummary({
    required this.displayName,
    required this.email,
    this.phone,
    this.whatsappNo,
    this.address,
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
  });

  final String displayName;
  final String email;
  final String? phone;
  final String? whatsappNo;
  final String? address;
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
