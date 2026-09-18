import '../../../payslip/data/models/company_details_model.dart';
import '../entities/hr_letter_entity.dart';

abstract class HrLetterRepository {
  /// Fetches the list of official HR letters for the authenticated user
  Future<List<HrLetterEntity>> getLetterList();

  /// Fetches or retrieves cached company corporate details for letterhead branding
  Future<CompanyDetailsModel?> getCompanyDetails();

  /// Marks a specific letter as read in local session memory
  void markLetterAsRead(String letterId);
}
