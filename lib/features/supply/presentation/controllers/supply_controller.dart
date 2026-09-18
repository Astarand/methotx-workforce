import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/supply_entity.dart';
import '../../domain/repositories/supply_repository.dart';
import '../../data/repositories/supply_repository_impl.dart';

class SupplyState {
  final List<SupplyEntity> supplies;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final SupplyStatus? selectedStatusFilter;
  final Map<String, SupplyEntity> cachedDetails;

  const SupplyState({
    this.supplies = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.selectedStatusFilter,
    this.cachedDetails = const {},
  });

  SupplyState copyWith({
    List<SupplyEntity>? supplies,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    SupplyStatus? selectedStatusFilter,
    Map<String, SupplyEntity>? cachedDetails,
    bool clearFilter = false,
  }) {
    return SupplyState(
      supplies: supplies ?? this.supplies,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      selectedStatusFilter:
          clearFilter ? null : (selectedStatusFilter ?? this.selectedStatusFilter),
      cachedDetails: cachedDetails ?? this.cachedDetails,
    );
  }

  List<SupplyEntity> get filteredSupplies {
    if (selectedStatusFilter == null) return supplies;
    return supplies.where((s) => s.status == selectedStatusFilter).toList();
  }

  int get totalSupplies => supplies.length;
  int get pendingCount => supplies.where((s) => s.status == SupplyStatus.pending).length;
  int get approvedCount => supplies.where((s) => s.status == SupplyStatus.approved).length;
  int get rejectedCount => supplies.where((s) => s.status == SupplyStatus.rejected).length;
}

class SupplyController extends StateNotifier<SupplyState> {
  final SupplyRepository _repository;

  SupplyController(this._repository) : super(const SupplyState()) {
    loadSupply();
  }

  void setFilter(SupplyStatus? status) {
    if (state.selectedStatusFilter == status) return;
    state = state.copyWith(selectedStatusFilter: status);
  }

  Future<void> loadSupply() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getSupplyList();
      state = state.copyWith(
        supplies: list,
        cachedDetails: {},
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
    }
  }

  Future<SupplyEntity?> getSupplyDetails(String requisitionId, {bool forceRefresh = true}) async {
    if (!forceRefresh && state.cachedDetails.containsKey(requisitionId)) {
      return state.cachedDetails[requisitionId];
    }
    try {
      final details = await _repository.getSupplyDetails(requisitionId);
      final updatedMap = Map<String, SupplyEntity>.from(state.cachedDetails);
      updatedMap[requisitionId] = details;
      state = state.copyWith(cachedDetails: updatedMap);
      return details;
    } catch (_) {
      return state.supplies.cast<SupplyEntity?>().firstWhere(
            (s) => s?.id == requisitionId,
            orElse: () => null,
          );
    }
  }

  Future<bool> submitSupplyRequisition({
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
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.submitSupplyRequisition(
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
      state = state.copyWith(isSubmitting: false);
      await loadSupply();
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }
}

final supplyControllerProvider =
    StateNotifierProvider<SupplyController, SupplyState>((ref) {
  final repository = ref.watch(supplyRepositoryImplProvider);
  return SupplyController(repository);
});
