import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/cash_transaction_model.dart';

class CashService {
  static final CashService instance = CashService._internal();
  CashService._internal();

  // Mock / offline / optimistic cache
  final Map<String, double> _mockPendingAmounts = {};
  final Map<String, List<CashTransactionModel>> _mockCashTransactions = {};

  final StreamController<Map<String, double>> _mockPendingStream =
      StreamController<Map<String, double>>.broadcast();
  final StreamController<Map<String, List<CashTransactionModel>>> _mockTxStream =
      StreamController<Map<String, List<CashTransactionModel>>>.broadcast();

  double getCachedPendingAmount(String groupId) => _mockPendingAmounts[groupId] ?? 0.0;
  List<CashTransactionModel> getCachedTransactions(String groupId) =>
      List.unmodifiable(_mockCashTransactions[groupId] ?? []);

  // Stream current pending cash amount for a group/room
  Stream<double> streamPendingAmount(String groupId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('cash')
            .doc('summary')
            .snapshots()
            .map((doc) {
          if (doc.exists && doc.data() != null) {
            final val = doc.data()?['pendingAmount'];
            if (val is num) {
              final amt = val.toDouble();
              _mockPendingAmounts[groupId] = amt;
              return amt;
            }
          }
          return _mockPendingAmounts[groupId] ?? 0.0;
        }).handleError((e) {
          debugPrint('Cash summary stream error (using cache): $e');
          return _mockPendingAmounts[groupId] ?? 0.0;
        });
      } catch (e) {
        debugPrint('Failed to attach Firestore cash summary stream: $e');
      }
    }

    return _mockPendingStream.stream.map((map) => map[groupId] ?? 0.0);
  }

  // Stream all cash transactions (deposits & withdrawals)
  Stream<List<CashTransactionModel>> streamCashTransactions(String groupId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('cash_transactions')
            .orderBy('date', descending: true)
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CashTransactionModel.fromMap(doc.id, doc.data()))
              .toList();
          list.sort((a, b) {
            final dateComp = b.date.compareTo(a.date);
            if (dateComp != 0) return dateComp;
            return b.createdAt.compareTo(a.createdAt);
          });
          _mockCashTransactions[groupId] = list;
          return list;
        }).handleError((e) {
          debugPrint('Cash transactions stream error (using cache): $e');
          return _mockCashTransactions[groupId] ?? <CashTransactionModel>[];
        });
      } catch (e) {
        debugPrint('Failed to attach Firestore cash transactions stream: $e');
      }
    }

    return _mockTxStream.stream.map((map) {
      final list = map[groupId] ?? [];
      list.sort((a, b) {
        final dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  // Add Cash Deposit or Withdrawal
  Future<void> addCashTransaction({
    required String groupId,
    required String type, // 'deposit' | 'withdraw'
    required double amount,
    required String description,
    required DateTime date,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final signedDiff = type == 'deposit' ? amount : -amount;

    // 1. Optimistic local update
    final list = _mockCashTransactions.putIfAbsent(groupId, () => []);
    final localId = 'cash_${DateTime.now().millisecondsSinceEpoch}';
    final localTx = CashTransactionModel(
      id: localId,
      type: type,
      amount: amount,
      description: description.trim(),
      date: date,
      createdBy: createdBy,
      createdAt: now,
    );
    list.insert(0, localTx);

    double newPending = 0.0;
    for (final item in list) {
      newPending += item.signedAmount;
    }
    _mockPendingAmounts[groupId] = newPending;
    _mockPendingStream.add(Map.from(_mockPendingAmounts));
    _mockTxStream.add(Map.from(_mockCashTransactions));

    // 2. Persist to Firestore if available
    if (Firebase.apps.isNotEmpty) {
      try {
        final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
        final summaryRef = groupRef.collection('cash').doc('summary');
        final txRef = groupRef.collection('cash_transactions').doc();

        final tx = CashTransactionModel(
          id: txRef.id,
          type: type,
          amount: amount,
          description: description.trim(),
          date: date,
          createdBy: createdBy,
          createdAt: now,
        );

        await FirebaseFirestore.instance.runTransaction((t) async {
          final summarySnap = await t.get(summaryRef);
          final currentPending = (summarySnap.data()?['pendingAmount'] as num?)?.toDouble() ?? 0.0;
          final updatedPending = currentPending + signedDiff;

          t.set(txRef, tx.toMap());
          t.set(summaryRef, {
            'pendingAmount': updatedPending,
            'updatedAt': Timestamp.fromDate(now),
          }, SetOptions(merge: true));
        });

        // Replace local placeholder id with firestore document id
        final idx = list.indexWhere((item) => item.id == localId);
        if (idx != -1) {
          list[idx] = tx;
          _mockTxStream.add(Map.from(_mockCashTransactions));
        }
      } catch (e) {
        debugPrint('Firestore cash write error (kept in local cache): $e');
      }
    }
  }

  // Update an existing cash transaction
  Future<void> updateCashTransaction({
    required String groupId,
    required CashTransactionModel oldTransaction,
    required String type,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final oldSigned = oldTransaction.signedAmount;
    final newSigned = type == 'deposit' ? amount : -amount;
    final diff = newSigned - oldSigned;

    // 1. Optimistic update
    final list = _mockCashTransactions[groupId] ?? [];
    final idx = list.indexWhere((t) => t.id == oldTransaction.id);
    if (idx != -1) {
      list[idx] = CashTransactionModel(
        id: oldTransaction.id,
        type: type,
        amount: amount,
        description: description.trim(),
        date: date,
        createdBy: oldTransaction.createdBy,
        createdAt: oldTransaction.createdAt,
      );
    }

    double newPending = 0.0;
    for (final item in list) {
      newPending += item.signedAmount;
    }
    _mockPendingAmounts[groupId] = newPending;
    _mockPendingStream.add(Map.from(_mockPendingAmounts));
    _mockTxStream.add(Map.from(_mockCashTransactions));

    // 2. Persist to Firestore
    if (Firebase.apps.isNotEmpty) {
      try {
        final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
        final summaryRef = groupRef.collection('cash').doc('summary');
        final txRef = groupRef.collection('cash_transactions').doc(oldTransaction.id);

        await FirebaseFirestore.instance.runTransaction((t) async {
          final summarySnap = await t.get(summaryRef);
          final currentPending = (summarySnap.data()?['pendingAmount'] as num?)?.toDouble() ?? 0.0;
          final updatedPending = currentPending + diff;

          t.update(txRef, {
            'type': type,
            'amount': amount,
            'description': description.trim(),
            'date': Timestamp.fromDate(date),
          });

          t.set(summaryRef, {
            'pendingAmount': updatedPending,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true));
        });
      } catch (e) {
        debugPrint('Firestore cash update error: $e');
      }
    }
  }

  // Delete a cash transaction
  Future<void> deleteCashTransaction({
    required String groupId,
    required CashTransactionModel transaction,
  }) async {
    final diff = -transaction.signedAmount;

    // 1. Optimistic local delete
    final list = _mockCashTransactions[groupId] ?? [];
    list.removeWhere((t) => t.id == transaction.id);

    double newPending = 0.0;
    for (final item in list) {
      newPending += item.signedAmount;
    }
    _mockPendingAmounts[groupId] = newPending;
    _mockPendingStream.add(Map.from(_mockPendingAmounts));
    _mockTxStream.add(Map.from(_mockCashTransactions));

    // 2. Persist to Firestore
    if (Firebase.apps.isNotEmpty) {
      try {
        final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
        final summaryRef = groupRef.collection('cash').doc('summary');
        final txRef = groupRef.collection('cash_transactions').doc(transaction.id);

        await FirebaseFirestore.instance.runTransaction((t) async {
          final summarySnap = await t.get(summaryRef);
          final currentPending = (summarySnap.data()?['pendingAmount'] as num?)?.toDouble() ?? 0.0;
          final updatedPending = currentPending + diff;

          t.delete(txRef);
          t.set(summaryRef, {
            'pendingAmount': updatedPending,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true));
        });
      } catch (e) {
        debugPrint('Firestore cash delete error: $e');
      }
    }
  }

  Future<void> syncPendingAmount({
    required String groupId,
    required double amount,
  }) async {
    if ((getCachedPendingAmount(groupId) - amount).abs() > 0.001) {
      _mockPendingAmounts[groupId] = amount;
      _mockPendingStream.add(Map.from(_mockPendingAmounts));
    }
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('cash')
            .doc('summary')
            .set({
          'pendingAmount': amount,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore cash sync error: $e');
      }
    }
  }
}
