import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/supply_entity.dart';

abstract class SupplyRepository {
  Future<List<SupplyEntity>> getSupplyList();

  Future<SupplyEntity> getSupplyDetails(String requisitionId);

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
  });
}

final supplyRepositoryProvider = Provider<SupplyRepository>((ref) {
  throw UnimplementedError('supplyRepositoryProvider must be initialized');
});
