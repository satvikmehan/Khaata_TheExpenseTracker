import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../models/month_model.dart';
import '../models/transaction_model.dart';

class ExpenseService {
  static final ExpenseService instance = ExpenseService._internal();
  ExpenseService._internal();

  // In-memory fallbacks for demo/local testing
  final Map<String, MonthModel> _mockActiveMonths = {};
  final Map<String, List<MonthModel>> _mockCompletedMonths = {};
  final Map<String, List<TransactionModel>> _mockTransactions = {};

  final StreamController<Map<String, MonthModel>> _mockMonthStream =
      StreamController<Map<String, MonthModel>>.broadcast();
  final StreamController<Map<String, List<TransactionModel>>> _mockTxStream =
      StreamController<Map<String, List<TransactionModel>>>.broadcast();

  String _formatMonthKey(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  // Get or initialize active month for a group
  Future<MonthModel> getOrCreateActiveMonth(String groupId) async {
    final now = DateTime.now();
    final currentKey = _formatMonthKey(now);

    if (Firebase.apps.isNotEmpty) {
      try {
        final monthsRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months');

        // Check if there is an active month
        final activeSnapshot = await monthsRef
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (activeSnapshot.docs.isNotEmpty) {
          final doc = activeSnapshot.docs.first;
          return MonthModel.fromMap(doc.id, doc.data());
        }

        // If no active month exists, create for current calendar month
        final newMonthDoc = monthsRef.doc(currentKey);
        final existingDoc = await newMonthDoc.get();

        if (existingDoc.exists && existingDoc.data() != null) {
          return MonthModel.fromMap(existingDoc.id, existingDoc.data()!);
        }

        final defaultMonthName = DateFormat('MMMM yyyy').format(now);
        final newMonth = MonthModel(
          id: currentKey,
          name: defaultMonthName,
          total: 0.0,
          status: 'active',
          createdAt: now,
        );
        await newMonthDoc.set(newMonth.toMap());
        return newMonth;
      } catch (_) {}
    }

    // Mock fallback
    if (!_mockActiveMonths.containsKey(groupId)) {
      final defaultMonthName = DateFormat('MMMM yyyy').format(now);
      final initialMonth = MonthModel(
        id: currentKey,
        name: defaultMonthName,
        total: 0.0,
        status: 'active',
        createdAt: now,
      );
      _mockActiveMonths[groupId] = initialMonth;
      _mockTransactions['${groupId}_$currentKey'] = [];
      _mockMonthStream.add(Map.from(_mockActiveMonths));
    }
    return _mockActiveMonths[groupId]!;
  }

  // Rename an expense list anytime
  Future<void> renameList({
    required String groupId,
    required String listId,
    required String newName,
  }) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;

    if (Firebase.apps.isNotEmpty) {
      try {
        final listRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .doc(listId);

        await listRef.update({
          'name': cleanName,
        });
      } catch (_) {}
    }

    // Mock fallback
    final active = _mockActiveMonths[groupId];
    if (active != null && active.id == listId) {
      _mockActiveMonths[groupId] = active.copyWith(name: cleanName);
      _mockMonthStream.add(Map.from(_mockActiveMonths));
    } else {
      final history = _mockCompletedMonths[groupId];
      if (history != null) {
        final idx = history.indexWhere((m) => m.id == listId);
        if (idx != -1) {
          history[idx] = history[idx].copyWith(name: cleanName);
        }
      }
    }
  }

  // Stream active month
  Stream<MonthModel?> streamActiveMonth(String groupId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .where('status', isEqualTo: 'active')
            .limit(1)
            .snapshots()
            .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            return MonthModel.fromMap(doc.id, doc.data());
          }
          return null;
        });
      } catch (_) {}
    }

    return _mockMonthStream.stream.map((map) => map[groupId]);
  }

  // Stream transactions for a specific month
  Stream<List<TransactionModel>> streamTransactions(
    String groupId,
    String monthId,
  ) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .doc(monthId)
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromMap(doc.id, doc.data()))
              .toList();
          // Secondary sort newest createdAt first for transactions on the same date
          list.sort((a, b) {
            final dateComp = b.date.compareTo(a.date);
            if (dateComp != 0) return dateComp;
            return b.createdAt.compareTo(a.createdAt);
          });
          return list;
        });
      } catch (_) {}
    }

    final key = '${groupId}_$monthId';
    return _mockTxStream.stream.map((map) {
      final list = map[key] ?? [];
      list.sort((a, b) {
        final dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  // Add transaction and update monthly total
  Future<void> addTransaction({
    required String groupId,
    required String monthId,
    required String name,
    required double amount,
    required String type, // 'expense' | 'withdrawal'
    required DateTime date,
    required String createdBy,
  }) async {
    final now = DateTime.now();

    if (Firebase.apps.isNotEmpty) {
      try {
        final monthRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .doc(monthId);

        final txRef = monthRef.collection('transactions').doc();

        final tx = TransactionModel(
          id: txRef.id,
          name: name.trim(),
          amount: amount,
          type: type,
          date: date,
          createdBy: createdBy,
          createdAt: now,
        );

        // Run batch or transaction to update total accurately
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final monthSnap = await transaction.get(monthRef);
          final currentTotal = (monthSnap.data()?['total'] as num?)?.toDouble() ?? 0.0;
          final diff = type == 'expense' ? amount : -amount;
          final newTotal = currentTotal + diff;

          transaction.set(txRef, tx.toMap());
          transaction.update(monthRef, {'total': newTotal});
        });

        return;
      } catch (_) {}
    }

    // Mock fallback
    final key = '${groupId}_$monthId';
    final txList = _mockTransactions.putIfAbsent(key, () => []);
    final tx = TransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      amount: amount,
      type: type,
      date: date,
      createdBy: createdBy,
      createdAt: now,
    );
    txList.add(tx);

    // Calculate total: sum of expenses - sum of withdrawals
    double newTotal = 0.0;
    for (final item in txList) {
      if (item.isExpense) {
        newTotal += item.amount;
      } else {
        newTotal -= item.amount;
      }
    }

    final currentMonth = _mockActiveMonths[groupId];
    if (currentMonth != null) {
      _mockActiveMonths[groupId] = MonthModel(
        id: currentMonth.id,
        total: newTotal,
        status: currentMonth.status,
        createdAt: currentMonth.createdAt,
        completedAt: currentMonth.completedAt,
      );
      _mockMonthStream.add(Map.from(_mockActiveMonths));
    }
    _mockTxStream.add(Map.from(_mockTransactions));
  }

  // Delete transaction and update monthly total
  Future<void> deleteTransaction({
    required String groupId,
    required String monthId,
    required TransactionModel transaction,
  }) async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final monthRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .doc(monthId);

        final txRef = monthRef.collection('transactions').doc(transaction.id);

        await FirebaseFirestore.instance.runTransaction((t) async {
          final monthSnap = await t.get(monthRef);
          final currentTotal = (monthSnap.data()?['total'] as num?)?.toDouble() ?? 0.0;
          final diff = transaction.isExpense ? -transaction.amount : transaction.amount;
          final newTotal = currentTotal + diff;

          t.delete(txRef);
          t.update(monthRef, {'total': newTotal});
        });
        return;
      } catch (_) {}
    }

    final key = '${groupId}_$monthId';
    final txList = _mockTransactions[key] ?? [];
    txList.removeWhere((t) => t.id == transaction.id);

    double newTotal = 0.0;
    for (final item in txList) {
      newTotal += item.isExpense ? item.amount : -item.amount;
    }

    final currentMonth = _mockActiveMonths[groupId];
    if (currentMonth != null && currentMonth.id == monthId) {
      _mockActiveMonths[groupId] = MonthModel(
        id: currentMonth.id,
        total: newTotal,
        status: currentMonth.status,
        createdAt: currentMonth.createdAt,
        completedAt: currentMonth.completedAt,
      );
      _mockMonthStream.add(Map.from(_mockActiveMonths));
    } else {
      // Check in completed months
      final completedList = _mockCompletedMonths[groupId];
      if (completedList != null) {
        final idx = completedList.indexWhere((m) => m.id == monthId);
        if (idx != -1) {
          final oldM = completedList[idx];
          completedList[idx] = MonthModel(
            id: oldM.id,
            total: newTotal,
            status: oldM.status,
            createdAt: oldM.createdAt,
            completedAt: oldM.completedAt,
          );
        }
      }
    }
    _mockTxStream.add(Map.from(_mockTransactions));
  }

  // Update transaction and re-calculate monthly total
  Future<void> updateTransaction({
    required String groupId,
    required String monthId,
    required TransactionModel oldTransaction,
    required String name,
    required double amount,
    required String type, // 'expense' | 'withdrawal'
    required DateTime date,
  }) async {
    final oldSigned = oldTransaction.signedAmount;
    final newSigned = type == 'expense' ? amount : -amount;
    final diff = newSigned - oldSigned;

    if (Firebase.apps.isNotEmpty) {
      try {
        final monthRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .doc(monthId);

        final txRef = monthRef.collection('transactions').doc(oldTransaction.id);

        await FirebaseFirestore.instance.runTransaction((t) async {
          final monthSnap = await t.get(monthRef);
          final currentTotal = (monthSnap.data()?['total'] as num?)?.toDouble() ?? 0.0;
          final newTotal = currentTotal + diff;

          t.update(txRef, {
            'name': name.trim(),
            'amount': amount,
            'type': type,
            'date': Timestamp.fromDate(date),
          });
          t.update(monthRef, {'total': newTotal});
        });
        return;
      } catch (_) {}
    }

    // Mock fallback
    final key = '${groupId}_$monthId';
    final txList = _mockTransactions[key] ?? [];
    final idx = txList.indexWhere((t) => t.id == oldTransaction.id);
    if (idx != -1) {
      txList[idx] = TransactionModel(
        id: oldTransaction.id,
        name: name.trim(),
        amount: amount,
        type: type,
        date: date,
        createdBy: oldTransaction.createdBy,
        createdAt: oldTransaction.createdAt,
      );
    }

    double newTotal = 0.0;
    for (final item in txList) {
      newTotal += item.isExpense ? item.amount : -item.amount;
    }

    final currentMonth = _mockActiveMonths[groupId];
    if (currentMonth != null && currentMonth.id == monthId) {
      _mockActiveMonths[groupId] = MonthModel(
        id: currentMonth.id,
        total: newTotal,
        status: currentMonth.status,
        createdAt: currentMonth.createdAt,
        completedAt: currentMonth.completedAt,
      );
      _mockMonthStream.add(Map.from(_mockActiveMonths));
    } else {
      final completedList = _mockCompletedMonths[groupId];
      if (completedList != null) {
        final mIdx = completedList.indexWhere((m) => m.id == monthId);
        if (mIdx != -1) {
          final oldM = completedList[mIdx];
          completedList[mIdx] = MonthModel(
            id: oldM.id,
            total: newTotal,
            status: oldM.status,
            createdAt: oldM.createdAt,
            completedAt: oldM.completedAt,
          );
        }
      }
    }
    _mockTxStream.add(Map.from(_mockTransactions));
  }

  // Stream any month document by ID
  Stream<MonthModel?> streamMonth(String groupId, String monthId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .doc(monthId)
            .snapshots()
            .map((doc) => doc.exists && doc.data() != null
                ? MonthModel.fromMap(doc.id, doc.data()!)
                : null);
      } catch (_) {}
    }

    return _mockMonthStream.stream.map((map) {
      if (map[groupId]?.id == monthId) {
        return map[groupId];
      }
      final completed = _mockCompletedMonths[groupId];
      return completed?.firstWhere(
        (m) => m.id == monthId,
        orElse: () => MonthModel(
          id: monthId,
          total: 0.0,
          status: 'done',
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  // Delete a completed month and all its transactions from history
  Future<void> deleteCompletedMonth({
    required String groupId,
    required String monthId,
  }) async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final monthRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .doc(monthId);

        final txSnapshots = await monthRef.collection('transactions').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in txSnapshots.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(monthRef);
        await batch.commit();
        return;
      } catch (_) {}
    }

    _mockCompletedMonths[groupId]?.removeWhere((m) => m.id == monthId);
    _mockTransactions.remove('${groupId}_$monthId');
  }

  // Mark List Done: archives current list and starts a fresh active list with ₹0
  Future<MonthModel> markListDone({
    required String groupId,
    required String currentListId,
    String? nextListName,
  }) async {
    final now = DateTime.now();
    final nextListKey = 'list_${now.millisecondsSinceEpoch}';
    final defaultMonthName = DateFormat('MMMM yyyy').format(now);
    final name = nextListName?.trim().isNotEmpty == true ? nextListName!.trim() : defaultMonthName;

    if (Firebase.apps.isNotEmpty) {
      try {
        final monthsCollection = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months');

        final currentListRef = monthsCollection.doc(currentListId);
        final nextListRef = monthsCollection.doc(nextListKey);

        final batch = FirebaseFirestore.instance.batch();

        // 1. Mark current list as done
        batch.update(currentListRef, {
          'status': 'done',
          'completedAt': Timestamp.fromDate(now),
        });

        // 2. Create fresh active list with total 0
        final nextList = MonthModel(
          id: nextListKey,
          name: name,
          total: 0.0,
          status: 'active',
          createdAt: now,
        );
        batch.set(nextListRef, nextList.toMap());

        await batch.commit();
        return nextList;
      } catch (_) {}
    }

    // Mock fallback
    final active = _mockActiveMonths[groupId];
    if (active != null) {
      final completed = MonthModel(
        id: active.id,
        name: active.name,
        total: active.total,
        status: 'done',
        createdAt: active.createdAt,
        completedAt: now,
      );
      final history = _mockCompletedMonths.putIfAbsent(groupId, () => []);
      history.insert(0, completed);

      final nextList = MonthModel(
        id: nextListKey,
        name: name,
        total: 0.0,
        status: 'active',
        createdAt: now,
      );
      _mockActiveMonths[groupId] = nextList;
      _mockTransactions['${groupId}_$nextListKey'] = [];

      _mockMonthStream.add(Map.from(_mockActiveMonths));
      _mockTxStream.add(Map.from(_mockTransactions));
      return nextList;
    }

    return MonthModel(
      id: nextListKey,
      name: name,
      total: 0.0,
      status: 'active',
      createdAt: now,
    );
  }

  // Backwards compatibility alias for markListDone
  Future<MonthModel> markMonthDone({
    required String groupId,
    required String currentMonthId,
  }) {
    return markListDone(groupId: groupId, currentListId: currentMonthId);
  }

  // Stream Previous / Archived Lists (status: 'done')
  Stream<List<MonthModel>> streamPreviousMonths(String groupId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months')
            .where('status', isEqualTo: 'done')
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => MonthModel.fromMap(doc.id, doc.data()))
              .toList();
          list.sort((a, b) {
            final aComp = a.completedAt ?? a.createdAt;
            final bComp = b.completedAt ?? b.createdAt;
            return bComp.compareTo(aComp);
          });
          return list;
        });
      } catch (_) {}
    }

    return Stream.value(_mockCompletedMonths[groupId] ?? []);
  }

  // Restore an archived list back to the active front screen.
  // First makes the current front list go into archive (save front list first),
  // then restores the archive list in front.
  Future<void> restoreArchivedMonth({
    required String groupId,
    required String archivedMonthId,
  }) async {
    final now = DateTime.now();

    if (Firebase.apps.isNotEmpty) {
      try {
        final monthsCollection = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months');

        final archivedMonthRef = monthsCollection.doc(archivedMonthId);

        // 1. Find currently active front list(s)
        final activeSnapshot = await monthsCollection
            .where('status', isEqualTo: 'active')
            .get();

        final batch = FirebaseFirestore.instance.batch();

        // 2. Put the front list into archive first (save front list first)
        for (final doc in activeSnapshot.docs) {
          if (doc.id != archivedMonthId) {
            batch.update(doc.reference, {
              'status': 'done',
              'completedAt': Timestamp.fromDate(now),
            });
          }
        }

        // 3. Restore the chosen archived list to front screen (status: 'active')
        batch.update(archivedMonthRef, {
          'status': 'active',
          'completedAt': FieldValue.delete(),
        });

        await batch.commit();
        return;
      } catch (_) {}
    }

    // Mock fallback
    final history = _mockCompletedMonths.putIfAbsent(groupId, () => []);

    // 1. Save current front list into archive first
    final currentFront = _mockActiveMonths[groupId];
    if (currentFront != null && currentFront.id != archivedMonthId) {
      final archivedFront = currentFront.copyWith(
        status: 'done',
        completedAt: now,
      );
      history.insert(0, archivedFront);
    }

    // 2. Restore chosen archive list to front
    final idx = history.indexWhere((m) => m.id == archivedMonthId);
    if (idx != -1) {
      final oldM = history.removeAt(idx);
      final restored = oldM.copyWith(
        status: 'active',
        completedAt: null,
      );
      _mockActiveMonths[groupId] = restored;
      _mockMonthStream.add(Map.from(_mockActiveMonths));
    }
  }

  // Merge all entries of an archived month directly into current active month
  Future<void> mergeArchivedMonthEntriesIntoActive({
    required String groupId,
    required String sourceMonthId,
  }) async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final activeMonth = await getOrCreateActiveMonth(groupId);
        final targetMonthId = activeMonth.id;
        if (targetMonthId == sourceMonthId) {
          await restoreArchivedMonth(groupId: groupId, archivedMonthId: sourceMonthId);
          return;
        }

        final monthsCollection = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('months');

        final sourceRef = monthsCollection.doc(sourceMonthId);
        final targetRef = monthsCollection.doc(targetMonthId);

        final sourceTxs = await sourceRef.collection('transactions').get();

        final batch = FirebaseFirestore.instance.batch();
        double transferredDiff = 0.0;

        for (final doc in sourceTxs.docs) {
          final data = doc.data();
          final tx = TransactionModel.fromMap(doc.id, data);
          transferredDiff += tx.signedAmount;

          final newTxRef = targetRef.collection('transactions').doc();
          batch.set(newTxRef, data);
          batch.delete(doc.reference);
        }

        batch.delete(sourceRef);
        await batch.commit();

        final targetSnap = await targetRef.get();
        final currentTotal = (targetSnap.data()?['total'] as num?)?.toDouble() ?? 0.0;
        await targetRef.update({'total': currentTotal + transferredDiff});
        return;
      } catch (_) {}
    }

    // Mock fallback
    final history = _mockCompletedMonths[groupId] ?? [];
    final idx = history.indexWhere((m) => m.id == sourceMonthId);
    if (idx != -1) {
      history.removeAt(idx);
      final active = _mockActiveMonths[groupId];
      if (active != null) {
        final sourceKey = '${groupId}_$sourceMonthId';
        final targetKey = '${groupId}_${active.id}';
        final sourceList = _mockTransactions[sourceKey] ?? [];
        final targetList = _mockTransactions.putIfAbsent(targetKey, () => []);

        targetList.addAll(sourceList);
        _mockTransactions.remove(sourceKey);

        double newTotal = 0.0;
        for (final item in targetList) {
          newTotal += item.isExpense ? item.amount : -item.amount;
        }

        _mockActiveMonths[groupId] = MonthModel(
          id: active.id,
          total: newTotal,
          status: 'active',
          createdAt: active.createdAt,
        );
        _mockMonthStream.add(Map.from(_mockActiveMonths));
        _mockTxStream.add(Map.from(_mockTransactions));
      }
    }
  }
}
