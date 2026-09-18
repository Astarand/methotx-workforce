class ApiConstants {
  ApiConstants._();

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // HTTP Headers
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String bearerPrefix = 'Bearer ';
  static const String applicationJson = 'application/json';

  // Common Payload Keys
  static const String keyEmpId = 'empId';
  static const String keySecure = 'secure';

  // Storage Keys for Tokens and Employee Credentials
  static const String storageTokenKey = 'auth_token';
  static const String storageEmpIdKey = 'emp_id';
  static const String storageSecureKey = 'secure_key';
  static const String storagePasscodeHashKey = 'app_passcode_hash';
}

