import '../entities/profile_entity.dart';

abstract class ProfileRepository {
  /// Fetches the profile of the employee. If [forceRefresh] is true, queries the remote API.
  /// Otherwise, returns the cached profile if valid or falls back to remote.
  Future<ProfileEntity> getProfile({
    required String empId,
    required String secure,
    bool forceRefresh = false,
  });

  /// Persists the updated profile to local cache
  Future<void> saveLocalProfile(ProfileEntity profile);

  /// Retrieves the locally cached profile if available
  Future<ProfileEntity?> getCachedProfile();

  /// Updates profile details (name, email, contact_number) on the remote server
  /// and updates the local storage cache
  Future<ProfileEntity> updateRemoteProfile({
    required String name,
    required String email,
    required String contactNumber,
  });
}
