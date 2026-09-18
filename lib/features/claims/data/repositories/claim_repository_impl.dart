import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/claim_entity.dart';
import '../../domain/repositories/claim_repository.dart';
import '../datasources/claim_remote_data_source.dart';

class ClaimRepositoryImpl implements ClaimRepository {
  final ClaimRemoteDataSource remoteDataSource;
  final StorageService storageService;

  ClaimRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  Future<String> _getEmpId() async {
    return await storageService.getSecure(ApiConstants.storageEmpIdKey) ??
        await storageService.getString(ApiConstants.storageEmpIdKey) ??
        '';
  }

  Future<String> _getSecure() async {
    return await storageService.getSecure(ApiConstants.storageSecureKey) ??
        await storageService.getString(ApiConstants.storageSecureKey) ??
        '';
  }

  @override
  Future<List<ClaimEntity>> getClaims() async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    final models = await remoteDataSource.getClaimList(
      empId: empId,
      secure: secure,
    );

    // Sort by date descending (newest claims first)
    models.sort((a, b) => b.date.compareTo(a.date));

    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<ClaimEntity> getClaimDetails(String claimId) async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    final model = await remoteDataSource.getClaimDetails(
      empId: empId,
      claimId: claimId,
      secure: secure,
    );

    return model.toEntity();
  }

  @override
  Future<void> submitClaim({
    required DateTime date,
    required String category,
    required double claimAmount,
    required String details,
    required String paymentMethod,
    String? comments,
    File? receipt,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    await remoteDataSource.submitClaim(
      empId: empId,
      secure: secure,
      date: date,
      category: category,
      claimAmount: claimAmount,
      details: details,
      paymentMethod: paymentMethod,
      comments: comments,
      receipt: receipt,
    );
  }
}

final claimRepositoryProvider = Provider<ClaimRepository>((ref) {
  final remoteDataSource = ref.watch(claimRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return ClaimRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
