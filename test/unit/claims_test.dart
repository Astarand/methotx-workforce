import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/claims/data/models/claim_model.dart';
import 'package:methotx_workforce/features/claims/data/repositories/claim_repository_impl.dart';
import 'package:methotx_workforce/features/claims/domain/entities/claim_entity.dart';
import 'package:methotx_workforce/features/claims/domain/repositories/claim_repository.dart';
import 'package:methotx_workforce/features/claims/presentation/controllers/claim_controller.dart';
import 'package:methotx_workforce/features/claims/presentation/screens/claim_details_screen.dart';
import 'package:methotx_workforce/features/claims/presentation/screens/claims_list_screen.dart';
import 'package:methotx_workforce/features/claims/presentation/screens/apply_claim_screen.dart';

class FakeClaimRepository implements ClaimRepository {
  List<ClaimEntity> mockClaims = [];
  bool shouldThrow = false;
  String errorMessage = 'Server connection failed';

  @override
  Future<List<ClaimEntity>> getClaims() async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockClaims;
  }

  @override
  Future<ClaimEntity> getClaimDetails(String claimId) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockClaims.firstWhere(
      (c) => c.id == claimId,
      orElse: () => throw Exception('Claim not found'),
    );
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
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    final newClaim = ClaimEntity(
      id: '${mockClaims.length + 1}',
      employeeId: 'EMP001',
      date: date,
      category: category,
      amount: claimAmount,
      paymentMethod: paymentMethod,
      details: details,
      status: ClaimStatus.pending,
      comments: comments,
      receipt: receipt?.path,
    );
    mockClaims = [newClaim, ...mockClaims];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClaimModel & ClaimEntity Unit Tests', () {
    test('ClaimModel.fromJson parses complete API payload accurately', () {
      final json = {
        'id': 123,
        'employee_id': 'EMP001',
        'date': '2026-08-30',
        'category': 'travel',
        'claim_amount': '1250.00',
        'payment_method': 'card',
        'details': 'Airport to office transport',
        'status': 'approved',
        'comments': 'Client meeting travel',
        'receipt': 'storage/receipts/bill_123.jpg',
      };

      final model = ClaimModel.fromJson(json);
      expect(model.id, '123');
      expect(model.employeeId, 'EMP001');
      expect(model.date.year, 2026);
      expect(model.date.month, 8);
      expect(model.date.day, 30);
      expect(model.category, 'travel');
      expect(model.amount, 1250.0);
      expect(model.paymentMethod, 'card');
      expect(model.details, 'Airport to office transport');
      expect(model.status, ClaimStatus.approved);
      expect(model.comments, 'Client meeting travel');
      expect(model.receipt, 'storage/receipts/bill_123.jpg');

      final entity = model.toEntity();
      expect(entity.formattedDate, '30 Aug 2026');
      expect(entity.formattedAmount, contains('1,250.00'));
      expect(entity.categoryTitle, 'Travel & Conveyance');
      expect(entity.paymentMethodTitle, 'Debit / Credit Card');
      expect(entity.hasReceipt, true);
      expect(entity.isImageReceipt, true);
      expect(entity.isPdfReceipt, false);
      expect(entity.status.label, 'Approved');
      expect(entity.status.textColor, const Color(0xFF166534));
    });

    test('Status mapping handles approved, rejected, and defaults to pending', () {
      final approved = ClaimModel.fromJson({'status': 'approved'}).status;
      final rejected = ClaimModel.fromJson({'status': 'rejected'}).status;
      final pending = ClaimModel.fromJson({'status': 'pending'}).status;
      final unknown = ClaimModel.fromJson({'status': 'under_review'}).status;
      final empty = ClaimModel.fromJson({'status': null}).status;

      expect(approved, ClaimStatus.approved);
      expect(rejected, ClaimStatus.rejected);
      expect(pending, ClaimStatus.pending);
      expect(unknown, ClaimStatus.pending);
      expect(empty, ClaimStatus.pending);
    });

    test('Identifies PDF receipts and safe double amount parsing', () {
      final json = {
        'id': '99',
        'amount': '2,499.50',
        'receipt': 'invoice.pdf',
      };

      final entity = ClaimModel.fromJson(json).toEntity();
      expect(entity.amount, 2499.50);
      expect(entity.isPdfReceipt, true);
      expect(entity.isImageReceipt, false);
    });

    test('ClaimState status filtering works accurately', () {
      final c1 = ClaimEntity(
        id: '1',
        employeeId: 'E1',
        date: DateTime(2026, 8, 30),
        category: 'travel',
        amount: 500,
        paymentMethod: 'cash',
        details: 'Cab',
        status: ClaimStatus.pending,
      );
      final c2 = ClaimEntity(
        id: '2',
        employeeId: 'E1',
        date: DateTime(2026, 8, 29),
        category: 'meals',
        amount: 350,
        paymentMethod: 'upi',
        details: 'Lunch',
        status: ClaimStatus.approved,
      );

      final state = ClaimState(claims: [c1, c2]);
      expect(state.totalClaims, 2);
      expect(state.pendingCount, 1);
      expect(state.approvedCount, 1);
      expect(state.rejectedCount, 0);

      final pendingOnly = state.copyWith(selectedStatusFilter: ClaimStatus.pending);
      expect(pendingOnly.filteredClaims.length, 1);
      expect(pendingOnly.filteredClaims.first.id, '1');

      final approvedOnly = state.copyWith(selectedStatusFilter: ClaimStatus.approved);
      expect(approvedOnly.filteredClaims.length, 1);
      expect(approvedOnly.filteredClaims.first.id, '2');
    });
  });

  group('Expenditure Claims Presentation & Widget Tests', () {
    late FakeClaimRepository fakeRepo;

    final sampleClaim = ClaimEntity(
      id: '101',
      employeeId: 'EMP001',
      date: DateTime(2026, 8, 30),
      category: 'travel',
      amount: 1250.0,
      paymentMethod: 'card',
      details: 'Airport to office transport for client audit',
      status: ClaimStatus.approved,
      comments: 'Verified against travel policy ticket',
      receipt: 'storage/receipts/cab_bill.jpg',
    );

    setUp(() {
      fakeRepo = FakeClaimRepository();
    });

    testWidgets('Renders empty state when claim list is empty', (tester) async {
      fakeRepo.mockClaims = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            claimRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ClaimsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Expenditure Claims'), findsOneWidget);
      expect(find.text('No claims yet'), findsOneWidget);
      expect(find.textContaining('Tap Apply to submit a new reimbursement claim'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('Renders error state when repository throws', (tester) async {
      fakeRepo.shouldThrow = true;
      fakeRepo.errorMessage = 'Network timeout occurred';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            claimRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ClaimsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Claims'), findsOneWidget);
      expect(find.text('Network timeout occurred'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Renders claim card accurately with status, category, amount, and date', (tester) async {
      fakeRepo.mockClaims = [sampleClaim];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            claimRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ClaimsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Travel & Conveyance'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      expect(find.textContaining('1,250.00'), findsOneWidget);
      expect(find.text('Debit / Credit Card'), findsOneWidget);
      expect(find.text('30 Aug 2026'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('Filter chips switch displayed claims by status', (tester) async {
      final pendingClaim = ClaimEntity(
        id: '102',
        employeeId: 'EMP001',
        date: DateTime(2026, 8, 25),
        category: 'meals',
        amount: 450.0,
        paymentMethod: 'cash',
        details: 'Team dinner',
        status: ClaimStatus.pending,
      );

      fakeRepo.mockClaims = [sampleClaim, pendingClaim];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            claimRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ClaimsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Travel & Conveyance'), findsOneWidget);
      expect(find.text('Meals & Dining'), findsOneWidget);

      // Tap Pending chip
      await tester.tap(find.text('Pending (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Meals & Dining'), findsOneWidget);
      expect(find.text('Travel & Conveyance'), findsNothing);

      // Tap Approved chip
      await tester.tap(find.text('Approved (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Travel & Conveyance'), findsOneWidget);
      expect(find.text('Meals & Dining'), findsNothing);
    });

    testWidgets('ClaimDetailsScreen renders status banner, details, amount, and remarks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            claimRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: ClaimDetailsScreen(claim: sampleClaim),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Claim Details'), findsOneWidget);
      expect(find.text('Claim Status: Approved'), findsOneWidget);
      expect(find.textContaining('1,250.00'), findsOneWidget);
      expect(find.text('Travel & Conveyance'), findsOneWidget);
      expect(find.text('Airport to office transport for client audit'), findsOneWidget);
      expect(find.text('Manager Feedback / Remarks'), findsOneWidget);
      expect(find.text('Verified against travel policy ticket'), findsOneWidget);
      expect(find.text('Receipt Attachment'), findsOneWidget);
    });

    testWidgets('ApplyClaimScreen renders form fields and validates inputs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            claimRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ApplyClaimScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Apply for Claim'), findsOneWidget);
      expect(find.text('Expense Category *'), findsOneWidget);
      expect(find.text('Payment Method *'), findsOneWidget);
      expect(find.text('Claim Date *'), findsOneWidget);
      expect(find.text('Claim Amount (INR) *'), findsOneWidget);
      expect(find.text('Purpose / Explanation *'), findsOneWidget);
      expect(find.text('Submit Claim Request'), findsOneWidget);

      // Scroll to and tap submit with empty fields
      await tester.ensureVisible(find.text('Submit Claim Request'));
      await tester.tap(find.text('Submit Claim Request'));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Please explain the expenditure purpose'), findsOneWidget);

      // Enter valid fields
      await tester.enterText(find.byType(TextFormField).at(0), '750');
      await tester.enterText(find.byType(TextFormField).at(1), 'Client taxi reimbursement');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Submit Claim Request'));
      await tester.tap(find.text('Submit Claim Request'));
      await tester.pumpAndSettle();

      expect(fakeRepo.mockClaims.length, 1);
      expect(fakeRepo.mockClaims.first.amount, 750.0);
      expect(fakeRepo.mockClaims.first.details, 'Client taxi reimbursement');
    });
  });
}
