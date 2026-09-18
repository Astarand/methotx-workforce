import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_exceptions.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/supply_entity.dart';
import '../../domain/repositories/supply_repository.dart';
import '../datasources/supply_remote_data_source.dart';

class SupplyRepositoryImpl implements SupplyRepository {
  final SupplyRemoteDataSource remoteDataSource;
  final StorageService storageService;

  SupplyRepositoryImpl({
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
  Future<List<SupplyEntity>> getSupplyList() async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    final models = await remoteDataSource.getSupplyList(
      empId: empId,
      secure: secure,
    );

    // Sort newest requisitions first
    models.sort((a, b) => b.date.compareTo(a.date));

    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<SupplyEntity> getSupplyDetails(String requisitionId) async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    final model = await remoteDataSource.getSupplyDetails(
      empId: empId,
      requisitionId: requisitionId,
      secure: secure,
    );

    return model.toEntity();
  }

  @override
  Future<void> submitSupplyRequisition({
    required DateTime date,
    required String category,
    required String details,
    required String quantity,
    required double amount,
    required SupplyPriority priority,
    String? returnExchange,
    String? comments,
    File? attachment,
  }) async {
    final empId = await _getEmpId();
    final secure = await _getSecure();

    if (empId.isEmpty || secure.isEmpty) {
      throw const UnauthorizedException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    }

    await remoteDataSource.submitSupplyRequisition(
      empId: empId,
      secure: secure,
      date: date,
      category: category,
      details: details,
      quantity: quantity,
      amount: amount,
      priority: priority,
      returnExchange: returnExchange,
      comments: comments,
      attachment: attachment,
    );
  }
}

final supplyRepositoryImplProvider = Provider<SupplyRepository>((ref) {
  final remoteDataSource = ref.watch(supplyRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return SupplyRepositoryImpl(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
  );
});
