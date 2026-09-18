import 'environment_config.dart';

class ApiEndpoints {
  // Base Getter
  static String get _base => EnvironmentConfig.baseUrl;

  // ---------------- AUTHENTICATION & PROFILE ----------------
  static String get login => '$_base/login';
  static String get logout => '$_base/auth/logout';
  static String get employeeDetails => '$_base/users/employee/details';
  static String get employeeProfile => '$_base/users/employee/profile';
  static String get updateFcmToken => '$_base/users/employee/update-fcm-token';

  // ---------------- ATTENDANCE & SHIFTS ----------------
  static String get punchIn => '$_base/users/employee/punch-in';
  static String get punchOut => '$_base/users/employee/punch-out';
  static String get lunchIn => '$_base/users/employee/lunch-in';
  static String get lunchOut => '$_base/users/employee/lunch-out';
  static String get breakIn => '$_base/users/employee/break-in';
  static String get breakOut => '$_base/users/employee/break-out';
  static String get dailyActivity => '$_base/users/attendance/daily-activity';
  static String get attendanceSummary =>
      '$_base/users/attendance/range-summary';

  // ---------------- POLICIES & COMPLIANCE ----------------
  static String get policyList => '$_base/users/policies/policy-list';
  static String get updatePolicyReadStatus =>
      '$_base/users/policies/update-policy-read-status';

  // ---------------- TASKS ----------------
  static String get taskList => '$_base/users/task/task-list';
  static String get taskDetails => '$_base/users/task/task-details';
  static String get taskStatusUpdate => '$_base/users/task/task-status-update';
  static String get completedTaskList =>
      '$_base/users/task/completed-task-list';

  // ---------------- LEAVES & HOLIDAYS ----------------
  static String get companyHolidays => '$_base/users/company/holidays';
  static String get applyLeave => '$_base/users/employee/apply-leave';
  static String get listOfLeave => '$_base/users/employee/list-of-leave';
  static String get leaveDetails => '$_base/users/employee/leave-details';

  // ---------------- PAYROLL & HR ----------------
  static String get payslipDetails => '$_base/users/payslips/payslip-details';
  static String get hrLetterList => '$_base/users/hr-letters/letter-list';
  static String get companyDetails => '$_base/users/company/details';
  static String get performanceReviewList =>
      '$_base/users/review/employee_review_list';

  // ---------------- EXPENDITURES & CLAIMS ----------------
  static String get claimList => '$_base/users/expenditure-claims/claim-list';
  static String get claimDetails =>
      '$_base/users/expenditure-claims/claim-details';
  static String get submitClaim =>
      '$_base/users/expenditure-claims/submit-claim';

  // ---------------- SUPPLY REQUISITIONS ----------------
  static String get supplyList => '$_base/users/expenditure-claims/supply-list';
  static String get supplyDetails =>
      '$_base/users/expenditure-claims/supply-details';
  static String get submitSupply =>
      '$_base/users/expenditure-claims/submit-Supply';

  // ---------------- MEDIA & IMAGES RESOLVER ----------------
  /// Fetches company logo by company ID (requires Bearer token & Accept: image/*)
  static String companyLogo(dynamic companyId) =>
      '$_base/users/company/logo/$companyId';

  /// Fetches employee profile image by employee ID / code (requires Bearer token & Accept: image/*)
  static String employeeProfileImage(String empId) {
    final cleanId = empId.trim();
    return '$_base/users/employee/profile-image/$cleanId';
  }

  /// Resolves relative profile/attachment paths dynamically using the active environment configuration
  static String? resolveImageUrl(String? path) {
    if (path == null || path.trim().isEmpty || path == 'null') return null;
    var cleanPath = path
        .trim()
        .replaceAll(r'\/', '/')
        .replaceAll(r'\', '/')
        .replaceAll('"', '')
        .replaceAll("'", '');

    // 1. Never treat local asset placeholders or dummy avatars as remote network URLs
    if (cleanPath.startsWith('assets/') ||
        cleanPath.contains('avatar-dummy')) {
      return null;
    }

    final activeDomain = EnvironmentConfig.domainUrl;
    final activeDomainUri = Uri.tryParse(activeDomain);
    final parsedUri = Uri.tryParse(cleanPath);

    // 2. Relative paths (e.g. '/storage/avatar.jpg' or 'api/users/...') -> prepend active environment domain
    if (parsedUri == null || !parsedUri.hasScheme || !parsedUri.hasAuthority) {
      final relative = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
      return '$activeDomain$relative';
    }

    // 3. Absolute URL: If the authority belongs to a previous development/staging environment or localhost,
    // retarget the path to the currently active environment domain dynamically.
    final host = parsedUri.host.toLowerCase();
    final isLocalOrStaging = host == 'localhost' ||
        host == '127.0.0.1' ||
        (activeDomainUri != null && host != activeDomainUri.host && host.contains('methotx'));

    if (isLocalOrStaging && activeDomainUri != null) {
      final query = parsedUri.hasQuery ? '?${parsedUri.query}' : '';
      return '$activeDomain${parsedUri.path}$query';
    }

    // 4. For valid external or current URLs, guarantee secure HTTPS transport
    if (parsedUri.scheme == 'http') {
      return parsedUri.replace(scheme: 'https').toString();
    }

    return parsedUri.toString();
  }
}
