import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/splitwise_model.dart';

class SplitwiseService {
  static final SplitwiseService instance = SplitwiseService._internal();
  SplitwiseService._internal();

  // In-memory mock & local cache
  final Map<String, List<SplitwiseGroupModel>> _mockGroupsByUser = {};
  final Map<String, List<SplitwiseExpenseModel>> _mockExpensesByGroup = {};

  final StreamController<Map<String, List<SplitwiseGroupModel>>> _groupsStreamController =
      StreamController<Map<String, List<SplitwiseGroupModel>>>.broadcast();
  final StreamController<Map<String, List<SplitwiseExpenseModel>>> _expensesStreamController =
      StreamController<Map<String, List<SplitwiseExpenseModel>>>.broadcast();

  Future<void> initialize() async {
    // Initializer hook for SplitwiseService
  }

  void clearMockData() {
    _mockGroupsByUser.clear();
    _mockExpensesByGroup.clear();
    _groupsStreamController.add({});
    _expensesStreamController.add({});
  }

  List<SplitwiseGroupModel> getCachedGroups(String userId, {String? status}) {
    final list = List<SplitwiseGroupModel>.from(_mockGroupsByUser[userId] ?? []);
    _sortGroups(list);
    if (status != null) {
      return list.where((g) => g.status == status).toList();
    }
    return list;
  }

  List<SplitwiseExpenseModel> getCachedExpenses(String groupId) {
    return List.unmodifiable(_mockExpensesByGroup[groupId] ?? []);
  }

  void _sortGroups(List<SplitwiseGroupModel> list) {
    list.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Stream<List<SplitwiseGroupModel>> streamGroups(String userId, {String? status}) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => SplitwiseGroupModel.fromMap(doc.id, doc.data()))
              .toList();
          _sortGroups(list);
          _mockGroupsByUser[userId] = list;
          if (status != null) {
            return list.where((g) => g.status == status).toList();
          }
          return list;
        }).handleError((e) {
          debugPrint('Splitwise groups stream error (using cache): $e');
          final list = getCachedGroups(userId, status: status);
          return list;
        });
      } catch (e) {
        debugPrint('Failed to attach Firestore splitwise groups stream: $e');
      }
    }

    return _groupsStreamController.stream.map((map) {
      final list = List<SplitwiseGroupModel>.from(map[userId] ?? []);
      _sortGroups(list);
      if (status != null) {
        return list.where((g) => g.status == status).toList();
      }
      return list;
    });
  }

  Stream<List<SplitwiseExpenseModel>> streamExpenses(String userId, String groupId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .doc(groupId)
            .collection('expenses')
            .orderBy('date', descending: true)
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => SplitwiseExpenseModel.fromMap(doc.id, doc.data()))
              .toList();
          list.sort((a, b) {
            final dateComp = b.date.compareTo(a.date);
            if (dateComp != 0) return dateComp;
            return b.createdAt.compareTo(a.createdAt);
          });
          _mockExpensesByGroup[groupId] = list;
          return list;
        }).handleError((e) {
          debugPrint('Splitwise expenses stream error (using cache): $e');
          return _mockExpensesByGroup[groupId] ?? <SplitwiseExpenseModel>[];
        });
      } catch (e) {
        debugPrint('Failed to attach Firestore splitwise expenses stream: $e');
      }
    }

    return _expensesStreamController.stream.map((map) {
      final list = List<SplitwiseExpenseModel>.from(map[groupId] ?? []);
      list.sort((a, b) {
        final dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<SplitwiseGroupModel> createGroup({
    required String userId,
    required String name,
    required DateTime date,
    required List<String> members,
  }) async {
    final now = DateTime.now();
    final randomSuffix = Random().nextInt(900000) + 100000;
    final groupId = 'splitwise_${now.microsecondsSinceEpoch}_$randomSuffix';

    // Ensure member names are trimmed and unique
    final cleanMembers = members
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();

    final group = SplitwiseGroupModel(
      id: groupId,
      userId: userId,
      name: name.trim(),
      date: date,
      members: cleanMembers,
      status: 'active',
      totalExpense: 0.0,
      createdAt: now,
      updatedAt: now,
    );

    final currentList = _mockGroupsByUser[userId] ?? [];
    _mockGroupsByUser[userId] = [group, ...currentList];
    _mockExpensesByGroup[groupId] = [];
    _groupsStreamController.add(Map.from(_mockGroupsByUser));
    _expensesStreamController.add(Map.from(_mockExpensesByGroup));

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .doc(groupId)
            .set(group.toMap());
      } catch (e) {
        debugPrint('Error saving splitwise group to Firestore: $e');
      }
    }

    return group;
  }

  Future<void> addMembers({
    required String userId,
    required String groupId,
    required List<String> newMembers,
  }) async {
    final now = DateTime.now();
    final currentList = _mockGroupsByUser[userId] ?? [];
    final idx = currentList.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final existing = currentList[idx].members.toSet();
      for (final m in newMembers) {
        final clean = m.trim();
        if (clean.isNotEmpty) existing.add(clean);
      }
      final updated = currentList[idx].copyWith(
        members: existing.toList(),
        updatedAt: now,
      );
      currentList[idx] = updated;
      _mockGroupsByUser[userId] = List.from(currentList);
      _groupsStreamController.add(Map.from(_mockGroupsByUser));

      if (Firebase.apps.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('splitwise_groups')
              .doc(groupId)
              .update({
            'members': existing.toList(),
            'updatedAt': Timestamp.fromDate(now),
          });
        } catch (e) {
          debugPrint('Error updating splitwise members: $e');
        }
      }
    }
  }

  Future<void> removeMember({
    required String userId,
    required String groupId,
    required String memberName,
  }) async {
    final now = DateTime.now();
    final currentList = _mockGroupsByUser[userId] ?? [];
    final idx = currentList.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final existing = List<String>.from(currentList[idx].members);
      existing.remove(memberName);
      final updated = currentList[idx].copyWith(
        members: existing,
        updatedAt: now,
      );
      currentList[idx] = updated;
      _mockGroupsByUser[userId] = List.from(currentList);

      // Clean up any expenses where memberName is in involvedMembers
      final expList = _mockExpensesByGroup[groupId] ?? [];
      bool expensesChanged = false;
      final updatedExpenses = expList.map((exp) {
        if (exp.involvedMembers.contains(memberName)) {
          expensesChanged = true;
          final newInvolved = exp.involvedMembers.where((m) => m != memberName).toList();
          return exp.copyWith(involvedMembers: newInvolved);
        }
        return exp;
      }).toList();

      if (expensesChanged) {
        _mockExpensesByGroup[groupId] = updatedExpenses;
        _expensesStreamController.add(Map.from(_mockExpensesByGroup));
      }

      _groupsStreamController.add(Map.from(_mockGroupsByUser));

      if (Firebase.apps.isNotEmpty) {
        try {
          final groupDoc = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('splitwise_groups')
              .doc(groupId);

          await groupDoc.update({
            'members': existing,
            'updatedAt': Timestamp.fromDate(now),
          });

          if (expensesChanged) {
            for (final exp in updatedExpenses) {
              final original = expList.firstWhere((e) => e.id == exp.id, orElse: () => exp);
              if (original.involvedMembers.contains(memberName)) {
                await groupDoc.collection('expenses').doc(exp.id).update({
                  'involvedMembers': exp.involvedMembers,
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Error removing splitwise member: $e');
        }
      }
    }
  }

  Future<void> markGroupDone({
    required String userId,
    required String groupId,
  }) async {
    final now = DateTime.now();
    final currentList = _mockGroupsByUser[userId] ?? [];
    final idx = currentList.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final updated = currentList[idx].copyWith(status: 'done', updatedAt: now);
      currentList[idx] = updated;
      _mockGroupsByUser[userId] = List.from(currentList);
      _groupsStreamController.add(Map.from(_mockGroupsByUser));

      if (Firebase.apps.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('splitwise_groups')
              .doc(groupId)
              .update({
            'status': 'done',
            'updatedAt': Timestamp.fromDate(now),
          });
        } catch (e) {
          debugPrint('Error marking splitwise group done: $e');
        }
      }
    }
  }

  Future<void> reopenGroup({
    required String userId,
    required String groupId,
  }) async {
    final now = DateTime.now();
    final currentList = _mockGroupsByUser[userId] ?? [];
    final idx = currentList.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final updated = currentList[idx].copyWith(status: 'active', updatedAt: now);
      currentList[idx] = updated;
      _mockGroupsByUser[userId] = List.from(currentList);
      _groupsStreamController.add(Map.from(_mockGroupsByUser));

      if (Firebase.apps.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('splitwise_groups')
              .doc(groupId)
              .update({
            'status': 'active',
            'updatedAt': Timestamp.fromDate(now),
          });
        } catch (e) {
          debugPrint('Error reopening splitwise group: $e');
        }
      }
    }
  }

  Future<void> deleteGroup({
    required String userId,
    required String groupId,
  }) async {
    final currentList = _mockGroupsByUser[userId] ?? [];
    _mockGroupsByUser[userId] = currentList.where((g) => g.id != groupId).toList();
    _mockExpensesByGroup.remove(groupId);
    _groupsStreamController.add(Map.from(_mockGroupsByUser));
    _expensesStreamController.add(Map.from(_mockExpensesByGroup));

    if (Firebase.apps.isNotEmpty) {
      try {
        final groupDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .doc(groupId);

        final expDocs = await groupDoc.collection('expenses').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in expDocs.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(groupDoc);
        await batch.commit();
      } catch (e) {
        debugPrint('Error deleting splitwise group: $e');
      }
    }
  }

  Future<SplitwiseExpenseModel> addExpense({
    required String userId,
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required List<String> involvedMembers,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final randomSuffix = Random().nextInt(900000) + 100000;
    final expId = 'exp_${now.microsecondsSinceEpoch}_$randomSuffix';

    final expense = SplitwiseExpenseModel(
      id: expId,
      groupId: groupId,
      userId: userId,
      description: description.trim(),
      amount: amount.abs(),
      paidBy: paidBy.trim(),
      involvedMembers: involvedMembers.map((m) => m.trim()).toList(),
      date: date,
      createdAt: now,
    );

    final expList = _mockExpensesByGroup[groupId] ?? [];
    final updatedList = [expense, ...expList];
    updatedList.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return b.createdAt.compareTo(a.createdAt);
    });
    _mockExpensesByGroup[groupId] = updatedList;

    // Recalculate total expense for the group
    final newTotal = updatedList.fold(0.0, (acc, e) => acc + e.amount);

    final groups = _mockGroupsByUser[userId] ?? [];
    final gIdx = groups.indexWhere((g) => g.id == groupId);
    if (gIdx != -1) {
      groups[gIdx] = groups[gIdx].copyWith(totalExpense: newTotal, updatedAt: now);
      _mockGroupsByUser[userId] = List.from(groups);
    }

    _expensesStreamController.add(Map.from(_mockExpensesByGroup));
    _groupsStreamController.add(Map.from(_mockGroupsByUser));

    if (Firebase.apps.isNotEmpty) {
      try {
        final groupDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .doc(groupId);

        await groupDoc.collection('expenses').doc(expId).set(expense.toMap());

        // Fetch all expenses to compute exact mathematical total
        final allDocs = await groupDoc.collection('expenses').get();
        final allExp = allDocs.docs.map((d) => SplitwiseExpenseModel.fromMap(d.id, d.data())).toList();
        final exactTotal = allExp.fold(0.0, (acc, e) => acc + e.amount);

        final groups = _mockGroupsByUser[userId] ?? [];
        final gIdx = groups.indexWhere((g) => g.id == groupId);
        if (gIdx != -1) {
          groups[gIdx] = groups[gIdx].copyWith(totalExpense: exactTotal, updatedAt: now);
          _mockGroupsByUser[userId] = List.from(groups);
        }
        _groupsStreamController.add(Map.from(_mockGroupsByUser));

        await groupDoc.update({
          'totalExpense': exactTotal,
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (e) {
        debugPrint('Error saving splitwise expense to Firestore: $e');
      }
    }

    return expense;
  }

  Future<SplitwiseExpenseModel> updateExpense({
    required String userId,
    required String groupId,
    required String expenseId,
    required String description,
    required double amount,
    required String paidBy,
    required List<String> involvedMembers,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final expList = _mockExpensesByGroup[groupId] ?? [];
    final idx = expList.indexWhere((e) => e.id == expenseId);
    if (idx == -1) {
      throw Exception('Expense not found');
    }
    final existing = expList[idx];
    final updated = existing.copyWith(
      description: description.trim(),
      amount: amount.abs(),
      paidBy: paidBy.trim(),
      involvedMembers: involvedMembers.map((m) => m.trim()).toList(),
      date: date,
    );

    final updatedList = List<SplitwiseExpenseModel>.from(expList);
    updatedList[idx] = updated;
    updatedList.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return b.createdAt.compareTo(a.createdAt);
    });
    _mockExpensesByGroup[groupId] = updatedList;

    final newTotal = updatedList.fold(0.0, (acc, e) => acc + e.amount);

    final groups = _mockGroupsByUser[userId] ?? [];
    final gIdx = groups.indexWhere((g) => g.id == groupId);
    if (gIdx != -1) {
      groups[gIdx] = groups[gIdx].copyWith(totalExpense: newTotal, updatedAt: now);
      _mockGroupsByUser[userId] = List.from(groups);
    }

    _expensesStreamController.add(Map.from(_mockExpensesByGroup));
    _groupsStreamController.add(Map.from(_mockGroupsByUser));

    if (Firebase.apps.isNotEmpty) {
      try {
        final groupDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .doc(groupId);

        await groupDoc.collection('expenses').doc(expenseId).update(updated.toMap());

        final allDocs = await groupDoc.collection('expenses').get();
        final allExp = allDocs.docs.map((d) => SplitwiseExpenseModel.fromMap(d.id, d.data())).toList();
        final exactTotal = allExp.fold(0.0, (acc, e) => acc + e.amount);

        final groups = _mockGroupsByUser[userId] ?? [];
        final gIdx = groups.indexWhere((g) => g.id == groupId);
        if (gIdx != -1) {
          groups[gIdx] = groups[gIdx].copyWith(totalExpense: exactTotal, updatedAt: now);
          _mockGroupsByUser[userId] = List.from(groups);
        }
        _groupsStreamController.add(Map.from(_mockGroupsByUser));

        await groupDoc.update({
          'totalExpense': exactTotal,
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (e) {
        debugPrint('Error updating splitwise expense in Firestore: $e');
      }
    }

    return updated;
  }

  Future<void> deleteExpense({
    required String userId,
    required String groupId,
    required String expenseId,
  }) async {
    final now = DateTime.now();
    final expList = _mockExpensesByGroup[groupId] ?? [];
    final updatedList = expList.where((e) => e.id != expenseId).toList();
    _mockExpensesByGroup[groupId] = updatedList;

    final newTotal = updatedList.fold(0.0, (acc, e) => acc + e.amount);

    final groups = _mockGroupsByUser[userId] ?? [];
    final gIdx = groups.indexWhere((g) => g.id == groupId);
    if (gIdx != -1) {
      groups[gIdx] = groups[gIdx].copyWith(totalExpense: newTotal, updatedAt: now);
      _mockGroupsByUser[userId] = List.from(groups);
    }

    _expensesStreamController.add(Map.from(_mockExpensesByGroup));
    _groupsStreamController.add(Map.from(_mockGroupsByUser));

    if (Firebase.apps.isNotEmpty) {
      try {
        final groupDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .doc(groupId);

        await groupDoc.collection('expenses').doc(expenseId).delete();

        final allDocs = await groupDoc.collection('expenses').get();
        final allExp = allDocs.docs.map((d) => SplitwiseExpenseModel.fromMap(d.id, d.data())).toList();
        final exactTotal = allExp.fold(0.0, (acc, e) => acc + e.amount);

        final groups = _mockGroupsByUser[userId] ?? [];
        final gIdx = groups.indexWhere((g) => g.id == groupId);
        if (gIdx != -1) {
          groups[gIdx] = groups[gIdx].copyWith(totalExpense: exactTotal, updatedAt: now);
          _mockGroupsByUser[userId] = List.from(groups);
        }
        _groupsStreamController.add(Map.from(_mockGroupsByUser));

        await groupDoc.update({
          'totalExpense': exactTotal,
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (e) {
        debugPrint('Error deleting splitwise expense from Firestore: $e');
      }
    }
  }

  Future<void> syncGroupTotal({
    required String userId,
    required String groupId,
    required double total,
  }) async {
    final now = DateTime.now();
    final groups = _mockGroupsByUser[userId] ?? [];
    final gIdx = groups.indexWhere((g) => g.id == groupId);
    if (gIdx != -1 && (groups[gIdx].totalExpense - total).abs() > 0.001) {
      groups[gIdx] = groups[gIdx].copyWith(totalExpense: total, updatedAt: now);
      _mockGroupsByUser[userId] = List.from(groups);
      _groupsStreamController.add(Map.from(_mockGroupsByUser));
    }

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('splitwise_groups')
            .doc(groupId)
            .update({
          'totalExpense': total,
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (e) {
        debugPrint('Error syncing splitwise group total: $e');
      }
    }
  }

  /// Calculates the net balance for each person in the group:
  /// Net = (Total Paid by Person) - (Total Share Owed by Person)
  /// Positive: Gets back / receives (Green)
  /// Negative: Owes / gives (Red)
  /// Zero: Settled (Black)
  Map<String, double> calculateNetBalances({
    required List<String> members,
    required List<SplitwiseExpenseModel> expenses,
  }) {
    final Map<String, double> balances = {};
    for (final m in members) {
      balances[m] = 0.0;
    }

    for (final expense in expenses) {
      final payer = expense.paidBy;
      final amount = expense.amount;
      final involved = expense.involvedMembers.isEmpty ? members : expense.involvedMembers;

      if (!balances.containsKey(payer)) {
        balances[payer] = 0.0;
      }
      // Payer gets credited full amount paid
      balances[payer] = (balances[payer] ?? 0.0) + amount;

      // Each involved person gets debited their equal share
      if (involved.isNotEmpty) {
        final share = amount / involved.length;
        for (final person in involved) {
          if (!balances.containsKey(person)) {
            balances[person] = 0.0;
          }
          balances[person] = (balances[person] ?? 0.0) - share;
        }
      }
    }

    return balances;
  }
}
