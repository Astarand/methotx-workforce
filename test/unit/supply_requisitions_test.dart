import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:methotx_workforce/features/supply/data/models/supply_model.dart';
import 'package:methotx_workforce/features/supply/data/repositories/supply_repository_impl.dart';
import 'package:methotx_workforce/features/supply/domain/entities/supply_entity.dart';
import 'package:methotx_workforce/features/supply/domain/repositories/supply_repository.dart';
import 'package:methotx_workforce/features/supply/presentation/controllers/supply_controller.dart';
import 'package:methotx_workforce/features/supply/presentation/screens/apply_supply_screen.dart';
import 'package:methotx_workforce/features/supply/presentation/screens/supply_details_screen.dart';
import 'package:methotx_workforce/features/supply/presentation/screens/supply_list_screen.dart';

class FakeSupplyRepository implements SupplyRepository {
  List<SupplyEntity> mockSupplies = [];
  bool shouldThrow = false;
  String errorMessage = 'Failed to fetch requisitions';

  @override
  Future<List<SupplyEntity>> getSupplyList() async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return List.from(mockSupplies);
  }

  @override
  Future<SupplyEntity> getSupplyDetails(String requisitionId) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockSupplies.firstWhere(
      (s) => s.id == requisitionId,
      orElse: () => SupplyEntity(
        id: requisitionId,
        employeeId: 'EMP001',
        date: DateTime(2026, 9, 1),
        category: 'office_supplies',
        details: 'Printer toner',
        quantity: '2',
        amount: 3200.0,
        priority: SupplyPriority.normal,
        status: SupplyStatus.pending,
      ),
    );
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
    if (shouldThrow) {
      throw Exception(errorMessage);
    }

    mockSupplies.insert(
      0,
      SupplyEntity(
        id: (mockSupplies.length + 1).toString(),
        employeeId: 'EMP001',
        date: date,
        category: category,
        details: details,
        quantity: quantity,
        amount: amount,
        priority: priority,
        returnExchange: returnExchange,
        status: SupplyStatus.pending,
        comments: comments,
        attachment: attachment?.path,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupplyModel & SupplyEntity Unit Tests', () {
    test('SupplyModel.fromJson parses complete API payload accurately', () {
      final json = {
        'id': 'REQ501',
        'employee_id': 'EMP001',
        'date': '2026-09-02',
        'category': 'technology',
        'details': 'Ergonomic wireless mouse and mechanical keyboard',
        'quantity': '2',
        'amount': '4500.50',
        'priority': 'Top Priority',
        'return_exchange': 'Return defective membrane keyboard',
        'status': 'Approved',
        'comments': 'Approved under IT hardware refresh budget',
        'attachment': 'storage/requisitions/quote_123.pdf',
      };

      final model = SupplyModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.id, 'REQ501');
      expect(entity.employeeId, 'EMP001');
      expect(entity.category, 'technology');
      expect(entity.categoryTitle, 'Technology & IT');
      expect(entity.details, 'Ergonomic wireless mouse and mechanical keyboard');
      expect(entity.quantity, '2');
      expect(entity.amount, 4500.50);
      expect(entity.priority, SupplyPriority.top);
      expect(entity.returnExchange, 'Return defective membrane keyboard');
      expect(entity.status, SupplyStatus.approved);
      expect(entity.comments, 'Approved under IT hardware refresh budget');
      expect(entity.hasAttachment, isTrue);
      expect(entity.isPdfAttachment, isTrue);
      expect(entity.formattedAmount, '₹4,500.50');
      expect(entity.formattedDate, '02 Sep 2026');
    });

    test('SupplyModel parses developer specific attachment_url payload accurately', () {
      final json = {
        "status": "success",
        "data": {
          "id": 6,
          "employee_id": "emp26-00003",
          "requisition_date": "2026-09-08",
          "category": "Office Supplies",
          "details": "Test data",
          "quantity": "1",
          "amount": "111.00",
          "priority": "Top Priority",
          "return_exchange": "ghjg",
          "attachment": "6a9fc1a6685b9_942f1032f503b7175e0d4f4e6e431d9d.jpeg",
          "comments": "Data done",
          "status": "Pending",
          "added_by": 26,
          "u_type": "2",
          "created_at": "2026-09-08T08:04:54.000000Z",
          "updated_at": "2026-09-08T08:04:54.000000Z",
          "attachment_url": "http://127.0.0.1:8000/api/users/expenditure-claims/supply-attachment/emp26-00003/6"
        }
      };

      final model = SupplyModel.fromJson(json['data'] as Map<String, dynamic>);
      final entity = model.toEntity();

      expect(entity.id, '6');
      expect(entity.employeeId, 'emp26-00003');
      expect(entity.category, 'Office Supplies');
      expect(entity.categoryTitle, 'Office supplies');
      expect(entity.details, 'Test data');
      expect(entity.quantity, '1');
      expect(entity.amount, 111.00);
      expect(entity.priority, SupplyPriority.top);
      expect(entity.returnExchange, 'ghjg');
      expect(entity.comments, 'Data done');
      expect(entity.status, SupplyStatus.pending);
      expect(entity.attachment, '6a9fc1a6685b9_942f1032f503b7175e0d4f4e6e431d9d.jpeg');
      expect(entity.attachmentUrl, 'http://127.0.0.1:8000/api/users/expenditure-claims/supply-attachment/emp26-00003/6');
      expect(entity.hasAttachment, isTrue);
      expect(entity.isPdfAttachment, isFalse);
      expect(entity.resolvedAttachmentUrl, contains('/api/users/expenditure-claims/supply-attachment/emp26-00003/6'));
    });

    test('Status mapping handles variations (approved, accepted, 1, rejected, declined, 2)', () {
      expect(SupplyModel.fromJson({'status': 'approved'}).status, SupplyStatus.approved);
      expect(SupplyModel.fromJson({'status': 'Accepted'}).status, SupplyStatus.approved);
      expect(SupplyModel.fromJson({'status': 'accept'}).status, SupplyStatus.approved);
      expect(SupplyModel.fromJson({'status': 1}).status, SupplyStatus.approved);
      expect(SupplyModel.fromJson({'status': '1'}).status, SupplyStatus.approved);

      expect(SupplyModel.fromJson({'status': 'rejected'}).status, SupplyStatus.rejected);
      expect(SupplyModel.fromJson({'status': 'Declined'}).status, SupplyStatus.rejected);
      expect(SupplyModel.fromJson({'status': 'reject'}).status, SupplyStatus.rejected);
      expect(SupplyModel.fromJson({'status': 2}).status, SupplyStatus.rejected);
      expect(SupplyModel.fromJson({'status': '2'}).status, SupplyStatus.rejected);

      expect(SupplyModel.fromJson({'status': 'pending'}).status, SupplyStatus.pending);
      expect(SupplyModel.fromJson({'status': null}).status, SupplyStatus.pending);
      expect(SupplyModel.fromJson({'status': 'unknown'}).status, SupplyStatus.pending);
    });

    test('SupplyPriority.fromString accurately parses priorities', () {
      expect(SupplyPriority.fromString('Top Priority'), SupplyPriority.top);
      expect(SupplyPriority.fromString('top'), SupplyPriority.top);
      expect(SupplyPriority.fromString('URGENT'), SupplyPriority.top);
      expect(SupplyPriority.fromString('Normal Priority'), SupplyPriority.normal);
      expect(SupplyPriority.fromString(null), SupplyPriority.normal);
    });

    test('SupplyState status filtering and counters work accurately', () {
      final s1 = SupplyEntity(
        id: '1',
        employeeId: 'EMP001',
        date: DateTime(2026, 9, 1),
        category: 'office_supplies',
        details: 'A4 paper bundle',
        quantity: '5',
        amount: 1500.0,
        priority: SupplyPriority.normal,
        status: SupplyStatus.pending,
      );

      final s2 = SupplyEntity(
        id: '2',
        employeeId: 'EMP001',
        date: DateTime(2026, 9, 2),
        category: 'stationery',
        details: 'Whiteboard markers',
        quantity: '10',
        amount: 800.0,
        priority: SupplyPriority.normal,
        status: SupplyStatus.approved,
      );

      final s3 = SupplyEntity(
        id: '3',
        employeeId: 'EMP001',
        date: DateTime(2026, 9, 3),
        category: 'furniture',
        details: 'Office desk chair',
        quantity: '1',
        amount: 8500.0,
        priority: SupplyPriority.top,
        status: SupplyStatus.rejected,
      );

      final state = SupplyState(supplies: [s1, s2, s3]);
      expect(state.totalSupplies, 3);
      expect(state.pendingCount, 1);
      expect(state.approvedCount, 1);
      expect(state.rejectedCount, 1);

      final pendingOnly = state.copyWith(selectedStatusFilter: SupplyStatus.pending);
      expect(pendingOnly.filteredSupplies.length, 1);
      expect(pendingOnly.filteredSupplies.first.id, '1');

      final approvedOnly = state.copyWith(selectedStatusFilter: SupplyStatus.approved);
      expect(approvedOnly.filteredSupplies.length, 1);
      expect(approvedOnly.filteredSupplies.first.id, '2');

      final rejectedOnly = state.copyWith(selectedStatusFilter: SupplyStatus.rejected);
      expect(rejectedOnly.filteredSupplies.length, 1);
      expect(rejectedOnly.filteredSupplies.first.id, '3');
    });
  });

  group('Supply Requisitions Presentation & Widget Tests', () {
    late FakeSupplyRepository fakeRepo;

    final sampleRequisition = SupplyEntity(
      id: 'REQ101',
      employeeId: 'EMP001',
      date: DateTime(2026, 9, 5),
      category: 'technology',
      details: 'USB-C Docking Station for client demo laptops',
      quantity: '2',
      amount: 6500.0,
      priority: SupplyPriority.top,
      returnExchange: 'Return older USB-A hub',
      status: SupplyStatus.approved,
      comments: 'Approved by IT Admin for Q3 field engagements',
      attachment: 'storage/requisitions/dock_specs.pdf',
    );

    setUp(() {
      fakeRepo = FakeSupplyRepository();
    });

    testWidgets('Renders empty state when requisition list is empty', (tester) async {
      fakeRepo.mockSupplies = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supplyRepositoryImplProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SupplyListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Supply Requisitions'), findsOneWidget);
      expect(find.text('No requisitions yet'), findsOneWidget);
      expect(find.textContaining('Tap Apply to submit a new requisition'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('Renders error state when repository throws', (tester) async {
      fakeRepo.shouldThrow = true;
      fakeRepo.errorMessage = 'Connection timeout with server';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supplyRepositoryImplProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SupplyListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Requisitions'), findsOneWidget);
      expect(find.text('Connection timeout with server'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Renders requisition card with category, date, priority, quantity, and amount', (tester) async {
      fakeRepo.mockSupplies = [sampleRequisition];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supplyRepositoryImplProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SupplyListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Technology & IT'), findsOneWidget);
      expect(find.text('Top Priority'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('05 Sep 2026'), findsOneWidget);
      expect(find.text('Qty: 2'), findsOneWidget);
      expect(find.textContaining('6,500.00'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('Filter chips switch displayed requisitions by status', (tester) async {
      final pendingRequisition = SupplyEntity(
        id: 'REQ102',
        employeeId: 'EMP001',
        date: DateTime(2026, 9, 3),
        category: 'stationery',
        details: 'Spiral notebooks and sticky notes',
        quantity: '15',
        amount: 750.0,
        priority: SupplyPriority.normal,
        status: SupplyStatus.pending,
      );

      fakeRepo.mockSupplies = [sampleRequisition, pendingRequisition];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supplyRepositoryImplProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SupplyListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Technology & IT'), findsOneWidget);
      expect(find.text('Stationery'), findsOneWidget);

      // Tap Pending chip
      await tester.tap(find.text('Pending (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Stationery'), findsOneWidget);
      expect(find.text('Technology & IT'), findsNothing);

      // Tap Approved chip
      await tester.tap(find.text('Approved (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Technology & IT'), findsOneWidget);
      expect(find.text('Stationery'), findsNothing);
    });

    testWidgets('SupplyDetailsScreen renders status banner, specifications, details, and attachment', (tester) async {
      fakeRepo.mockSupplies = [sampleRequisition];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supplyRepositoryImplProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SupplyDetailsScreen(requisition: sampleRequisition),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Requisition Details'), findsOneWidget);
      expect(find.text('Requisition Status: Approved'), findsOneWidget);
      expect(find.textContaining('6,500.00'), findsOneWidget);
      expect(find.text('Technology & IT'), findsOneWidget);
      expect(find.text('Requisition Specifications'), findsOneWidget);
      expect(find.text('05 Sep 2026'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Return older USB-A hub'), findsOneWidget);
      expect(find.text('USB-C Docking Station for client demo laptops'), findsOneWidget);
      expect(find.text('Comments / Remarks'), findsOneWidget);
      expect(find.text('Approved by IT Admin for Q3 field engagements'), findsOneWidget);
      expect(find.text('Attachment Document'), findsOneWidget);
    });

    testWidgets('ApplySupplyScreen renders form and validates required fields', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supplyRepositoryImplProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ApplySupplyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Apply for Requisition'), findsOneWidget);
      expect(find.text('Supply Category *'), findsOneWidget);
      expect(find.text('Requisition Date *'), findsOneWidget);
      expect(find.text('Quantity *'), findsOneWidget);
      expect(find.text('Estimated Amount (INR) *'), findsOneWidget);
      expect(find.text('Priority *'), findsOneWidget);
      expect(find.text('Requirement Details *'), findsOneWidget);

      final submitBtn = find.text('Submit Requisition Request');
      await tester.ensureVisible(submitBtn);
      expect(submitBtn, findsOneWidget);

      // Submit with empty amount and details
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Please explain the requisition purpose and items'), findsOneWidget);

      // Enter valid fields
      await tester.enterText(find.byType(TextFormField).at(1), '1200');
      await tester.enterText(find.byType(TextFormField).at(3), 'Whiteboard markers and duster for training room');
      await tester.pumpAndSettle();

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.mockSupplies.length, 1);
      expect(fakeRepo.mockSupplies.first.amount, 1200.0);
      expect(fakeRepo.mockSupplies.first.details, 'Whiteboard markers and duster for training room');
    });
  });
}
