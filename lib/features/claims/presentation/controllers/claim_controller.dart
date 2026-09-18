import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/claim_entity.dart';
import '../../domain/repositories/claim_repository.dart';
import '../../data/repositories/claim_repository_impl.dart';

const Object _sentinel = Object();

class ClaimState {
  final List<ClaimEntity> claims;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final ClaimStatus? selectedStatusFilter; // null means 'All'
  final Map<String, ClaimEntity> cachedDetails;

  const ClaimState({
    this.claims = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.selectedStatusFilter,
    this.cachedDetails = const {},
  });

  ClaimState copyWith({
    List<ClaimEntity>? claims,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    Object? selectedStatusFilter = _sentinel,
    Map<String, ClaimEntity>? cachedDetails,
  }) {
    return ClaimState(
      claims: claims ?? this.claims,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      selectedStatusFilter: selectedStatusFilter == _sentinel
          ? this.selectedStatusFilter
          : (selectedStatusFilter as ClaimStatus?),
      cachedDetails: cachedDetails ?? this.cachedDetails,
    );
  }

  List<ClaimEntity> get filteredClaims {
    if (selectedStatusFilter == null) return claims;
    return claims.where((c) => c.status == selectedStatusFilter).toList();
  }

  int get totalClaims => claims.length;
  int get pendingCount => claims.where((c) => c.status == ClaimStatus.pending).length;
  int get approvedCount => claims.where((c) => c.status == ClaimStatus.approved).length;
  int get rejectedCount => claims.where((c) => c.status == ClaimStatus.rejected).length;
}

class ClaimController extends StateNotifier<ClaimState> {
  final ClaimRepository _repository;

  ClaimController(this._repository) : super(const ClaimState()) {
    loadClaims();
  }

  void setFilter(ClaimStatus? status) {
    if (state.selectedStatusFilter == status) return;
    state = state.copyWith(selectedStatusFilter: status);
  }

  Future<void> loadClaims() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final claims = await _repository.getClaims();
      state = state.copyWith(
        claims: claims,
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

  Future<ClaimEntity?> getClaimDetails(String claimId, {bool forceRefresh = true}) async {
    if (!forceRefresh && state.cachedDetails.containsKey(claimId)) {
      return state.cachedDetails[claimId];
    }
    try {
      final details = await _repository.getClaimDetails(claimId);
      final updatedMap = Map<String, ClaimEntity>.from(state.cachedDetails);
      updatedMap[claimId] = details;
      state = state.copyWith(cachedDetails: updatedMap);
      return details;
    } catch (_) {
      return state.claims.cast<ClaimEntity?>().firstWhere(
            (c) => c?.id == claimId,
            orElse: () => null,
          );
    }
  }

  Future<bool> submitClaim({
    required DateTime date,
    required String category,
    required double claimAmount,
    required String details,
    required String paymentMethod,
    String? comments,
    File? receipt,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _repository.submitClaim(
        date: date,
        category: category,
        claimAmount: claimAmount,
        details: details,
        paymentMethod: paymentMethod,
        comments: comments,
        receipt: receipt,
      );
      state = state.copyWith(isSubmitting: false);
      await loadClaims();
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }
}

final claimControllerProvider =
    StateNotifierProvider<ClaimController, ClaimState>((ref) {
  final repository = ref.watch(claimRepositoryProvider);
  return ClaimController(repository);
});
