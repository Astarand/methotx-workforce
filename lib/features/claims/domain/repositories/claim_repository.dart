import 'dart:io';
import '../entities/claim_entity.dart';

abstract class ClaimRepository {
  Future<List<ClaimEntity>> getClaims();

  Future<ClaimEntity> getClaimDetails(String claimId);

  Future<void> submitClaim({
    required DateTime date,
    required String category,
    required double claimAmount,
    required String details,
    required String paymentMethod,
    String? comments,
    File? receipt,
  });
}
