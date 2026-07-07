class ProfileSummary {
  const ProfileSummary({
    required this.displayName,
    required this.email,
    this.phone,
    this.customerType,
    this.cnic,
    this.ntn,
    this.companyName,
    this.approvalStatus,
    this.status,
    this.canAccessInternalWorkspace = false,
  });

  final String displayName;
  final String email;
  final String? phone;
  final String? customerType;
  final String? cnic;
  final String? ntn;
  final String? companyName;
  final String? approvalStatus;
  final String? status;
  final bool canAccessInternalWorkspace;

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
