import '../entities/auth_entity.dart';

abstract class AuthRepository {
  /// Authenticates user against backend API, returning domain AuthEntity
  Future<AuthEntity> login(String email, String password);

  /// Clears user session and stored tokens
  Future<void> logout();

  /// Retrieves the currently authenticated user if a valid session exists
  Future<AuthEntity?> getCurrentUser();

  /// Checks if a valid auth token is present
  Future<bool> isAuthenticated();

  /// Fetches latest profile details from the server and updates local storage
  Future<AuthEntity?> refreshProfile();
}
