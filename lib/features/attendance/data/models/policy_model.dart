class PolicyCheckResult {
  final bool privacyPolicyRead;
  final bool termsAndConditionsRead;
  final List<String> unreadPolicies;
  final String? rawPrivacyStatus;
  final String? rawTermsStatus;

  const PolicyCheckResult({
    required this.privacyPolicyRead,
    required this.termsAndConditionsRead,
    required this.unreadPolicies,
    this.rawPrivacyStatus,
    this.rawTermsStatus,
  });

  bool get isAllRead => privacyPolicyRead && termsAndConditionsRead;

  factory PolicyCheckResult.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['policies'] is Map<String, dynamic>) {
      data = json['policies'] as Map<String, dynamic>;
    }

    final privacyVal = data['privacy_policy_read'] ??
        data['privacy_policy'] ??
        data['privacyPolicyRead'] ??
        data['privacyPolicy'];

    final termsVal = data['terms_and_conditions'] ??
        data['terms_conditions'] ??
        data['termsAndConditions'] ??
        data['terms_and_conditions_read'];

    final isPrivacyRead = _checkRead(privacyVal);
    final isTermsRead = _checkRead(termsVal);

    final unread = <String>[];
    if (!isPrivacyRead) unread.add('Privacy Policy');
    if (!isTermsRead) unread.add('Terms and Conditions');

    return PolicyCheckResult(
      privacyPolicyRead: isPrivacyRead,
      termsAndConditionsRead: isTermsRead,
      unreadPolicies: unread,
      rawPrivacyStatus: privacyVal?.toString(),
      rawTermsStatus: termsVal?.toString(),
    );
  }

  static bool _checkRead(dynamic val) {
    if (val == null) return true; // Default optimistic if server doesn't enforce
    if (val is bool) return val;
    final s = val.toString().toLowerCase().trim();
    return s == 'read' || s == 'true' || s == '1' || s == 'yes' || s == 'accepted';
  }
}
