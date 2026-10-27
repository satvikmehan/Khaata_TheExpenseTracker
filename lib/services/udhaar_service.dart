import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/udhaar_model.dart';

class UdhaarService {
  static final UdhaarService instance = UdhaarService._internal();
  UdhaarService._internal();

  SharedPreferences? _prefs;

  // In-memory mock & local cache
  final Map<String, List<UdhaarPersonModel>> _mockPersonsByUser = {};
  final Map<String, List<UdhaarTransactionModel>> _mockTxByPerson = {};
  final Map<String, List<String>> _mockUserPersonOrders = {};

  final StreamController<Map<String, List<UdhaarPersonModel>>> _personsStreamController =
      StreamController<Map<String, List<UdhaarPersonModel>>>.broadcast();
  final StreamController<Map<String, List<UdhaarTransactionModel>>> _txStreamController =
      StreamController<Map<String, List<UdhaarTransactionModel>>>.broadcast();

  Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences init note in UdhaarService: $e');
    }
  }

  void clearMockData() {
    _mockPersonsByUser.clear();
    _mockTxByPerson.clear();
    _mockUserPersonOrders.clear();
    _personsStreamController.add({});
    _txStreamController.add({});
  }

  List<UdhaarPersonModel> sortPersonsByOrder(List<UdhaarPersonModel> persons, [List<String>? order]) {
    final sorted = List<UdhaarPersonModel>.from(persons);
    sorted.sort((a, b) {
      // 1. Primary sort: Mod of amount debt or owe (|total|) in descending order
      final modA = a.total.abs();
      final modB = b.total.abs();
      final modDiff = modB.compareTo(modA);
      if (modDiff != 0) {
        return modDiff;
      }

      // 2. Secondary sort: Most recently updated
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return sorted;
  }

  List<String> getCachedUserPersonOrder(String userId) {
    if (_mockUserPersonOrders.containsKey(userId) && _mockUserPersonOrders[userId]!.isNotEmpty) {
      return _mockUserPersonOrders[userId]!;
    }
    final fromPrefs = _prefs?.getStringList('user_udhaar_order_$userId');
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _mockUserPersonOrders[userId] = List.from(fromPrefs);
      return fromPrefs;
    }
    return [];
  }

  Future<void> saveUserPersonOrder(String userId, List<String> personIds) async {
    _mockUserPersonOrders[userId] = List.from(personIds);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setStringList('user_udhaar_order_$userId', personIds);
    } catch (_) {}

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'udhaarOrder': personIds}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving udhaar order to Firestore: $e');
      }
    }
  }

  List<UdhaarPersonModel> getCachedPersons(String userId) {
    final list = _mockPersonsByUser[userId] ?? [];
    final order = getCachedUserPersonOrder(userId);
    return sortPersonsByOrder(list, order);
  }

  List<UdhaarTransactionModel> getCachedTransactions(String personId) {
    return List.unmodifiable(_mockTxByPerson[personId] ?? []);
  }

  Stream<List<UdhaarPersonModel>> streamPersons(String userId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => UdhaarPersonModel.fromMap(doc.id, doc.data()))
              .toList();
          final order = getCachedUserPersonOrder(userId);
          final sorted = sortPersonsByOrder(list, order);
          _mockPersonsByUser[userId] = sorted;
          return sorted;
        }).handleError((e) {
          debugPrint('Udhaar persons stream error (using cache): $e');
          final fallback = _mockPersonsByUser[userId] ?? <UdhaarPersonModel>[];
          final order = getCachedUserPersonOrder(userId);
          return sortPersonsByOrder(fallback, order);
        });
      } catch (e) {
        debugPrint('Failed to attach Firestore udhaar persons stream: $e');
      }
    }

    return _personsStreamController.stream.map((map) {
      final list = List<UdhaarPersonModel>.from(map[userId] ?? []);
      final order = getCachedUserPersonOrder(userId);
      return sortPersonsByOrder(list, order);
    });
  }

  Stream<List<UdhaarTransactionModel>> streamTransactions(String userId, String personId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .doc(personId)
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots()
            .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => UdhaarTransactionModel.fromMap(doc.id, doc.data()))
              .toList();
          list.sort((a, b) {
            final dateComp = b.date.compareTo(a.date);
            if (dateComp != 0) return dateComp;
            return b.createdAt.compareTo(a.createdAt);
          });
          _mockTxByPerson[personId] = list;
          return list;
        }).handleError((e) {
          debugPrint('Udhaar tx stream error (using cache): $e');
          return _mockTxByPerson[personId] ?? <UdhaarTransactionModel>[];
        });
      } catch (e) {
        debugPrint('Failed to attach Firestore udhaar tx stream: $e');
      }
    }

    return _txStreamController.stream.map((map) {
      final list = List<UdhaarTransactionModel>.from(map[personId] ?? []);
      list.sort((a, b) {
        final dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<UdhaarPersonModel> addPerson({
    required String userId,
    required String name,
  }) async {
    final now = DateTime.now();
    final randomSuffix = Random().nextInt(900000) + 100000;
    final personId = 'person_${now.microsecondsSinceEpoch}_$randomSuffix';

    final person = UdhaarPersonModel(
      id: personId,
      userId: userId,
      name: name.trim(),
      total: 0.0,
      createdAt: now,
      updatedAt: now,
    );

    // Update in-memory mock
    final currentList = _mockPersonsByUser[userId] ?? [];
    _mockPersonsByUser[userId] = [person, ...currentList];
    _mockTxByPerson[personId] = [];

    // Prepend to order list if custom order exists
    final currentOrder = getCachedUserPersonOrder(userId);
    if (currentOrder.isNotEmpty) {
      final updatedOrder = [personId, ...currentOrder.where((id) => id != personId)];
      saveUserPersonOrder(userId, updatedOrder);
    }

    _personsStreamController.add(Map.from(_mockPersonsByUser));
    _txStreamController.add(Map.from(_mockTxByPerson));

    // Persist to Firestore if available
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .doc(personId)
            .set(person.toMap());
      } catch (e) {
        debugPrint('Error saving udhaar person to Firestore: $e');
      }
    }

    return person;
  }

  Future<void> deletePerson({
    required String userId,
    required String personId,
  }) async {
    // Remove from mock
    final currentList = _mockPersonsByUser[userId] ?? [];
    _mockPersonsByUser[userId] = currentList.where((p) => p.id != personId).toList();
    _mockTxByPerson.remove(personId);

    final currentOrder = getCachedUserPersonOrder(userId);
    if (currentOrder.contains(personId)) {
      final updatedOrder = currentOrder.where((id) => id != personId).toList();
      saveUserPersonOrder(userId, updatedOrder);
    }
    _personsStreamController.add(Map.from(_mockPersonsByUser));
    _txStreamController.add(Map.from(_mockTxByPerson));

    if (Firebase.apps.isNotEmpty) {
      try {
        final personDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .doc(personId);

        // Delete subcollection transactions
        final txDocs = await personDoc.collection('transactions').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in txDocs.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(personDoc);
        await batch.commit();
      } catch (e) {
        debugPrint('Error deleting udhaar person from Firestore: $e');
      }
    }
  }

  Future<void> updatePersonName({
    required String userId,
    required String personId,
    required String newName,
  }) async {
    final now = DateTime.now();
    final currentList = _mockPersonsByUser[userId] ?? [];
    final idx = currentList.indexWhere((p) => p.id == personId);
    if (idx != -1) {
      final updated = currentList[idx].copyWith(name: newName.trim(), updatedAt: now);
      currentList[idx] = updated;
      _mockPersonsByUser[userId] = List.from(currentList);
      _personsStreamController.add(Map.from(_mockPersonsByUser));
    }

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .doc(personId)
            .update({
          'name': newName.trim(),
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (e) {
        debugPrint('Error updating udhaar person name: $e');
      }
    }
  }

  Future<UdhaarTransactionModel> addTransaction({
    required String userId,
    required String personId,
    required String type, // '+' or '-'
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final randomSuffix = Random().nextInt(900000) + 100000;
    final txId = 'tx_${now.microsecondsSinceEpoch}_$randomSuffix';

    final tx = UdhaarTransactionModel(
      id: txId,
      personId: personId,
      userId: userId,
      type: type == '-' ? '-' : '+',
      amount: amount.abs(),
      note: note.trim(),
      date: date,
      createdAt: now,
    );

    // Update in-memory transactions
    final txList = _mockTxByPerson[personId] ?? [];
    final updatedTxList = [tx, ...txList];
    updatedTxList.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return b.createdAt.compareTo(a.createdAt);
    });
    _mockTxByPerson[personId] = updatedTxList;

    // Recalculate person total
    final personList = _mockPersonsByUser[userId] ?? [];
    final pIdx = personList.indexWhere((p) => p.id == personId);
    final double newTotal;
    if (txList.isNotEmpty) {
      newTotal = _calculateTotal(updatedTxList);
    } else if (pIdx != -1) {
      final delta = (type == '-' ? -amount.abs() : amount.abs());
      newTotal = personList[pIdx].total + delta;
    } else {
      newTotal = _calculateTotal(updatedTxList);
    }

    // Update person model in mock
    if (pIdx != -1) {
      personList[pIdx] = personList[pIdx].copyWith(
        total: newTotal,
        updatedAt: now,
      );
      _mockPersonsByUser[userId] = List.from(personList);
    }

    _txStreamController.add(Map.from(_mockTxByPerson));
    _personsStreamController.add(Map.from(_mockPersonsByUser));

    // Persist to Firestore if available
    if (Firebase.apps.isNotEmpty) {
      try {
        final personDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .doc(personId);

        await personDoc.collection('transactions').doc(txId).set(tx.toMap());

        // Fetch all transactions from Firestore to compute exact total
        final allDocs = await personDoc.collection('transactions').get();
        final allTx = allDocs.docs
            .map((d) => UdhaarTransactionModel.fromMap(d.id, d.data()))
            .toList();
        allTx.sort((a, b) {
          final dateComp = b.date.compareTo(a.date);
          if (dateComp != 0) return dateComp;
          return b.createdAt.compareTo(a.createdAt);
        });

        _mockTxByPerson[personId] = allTx;
        final exactTotal = _calculateTotal(allTx);

        final personList = _mockPersonsByUser[userId] ?? [];
        final pIdx = personList.indexWhere((p) => p.id == personId);
        if (pIdx != -1) {
          personList[pIdx] = personList[pIdx].copyWith(
            total: exactTotal,
            updatedAt: now,
          );
          _mockPersonsByUser[userId] = List.from(personList);
        }

        _txStreamController.add(Map.from(_mockTxByPerson));
        _personsStreamController.add(Map.from(_mockPersonsByUser));

        await personDoc.update({
          'total': exactTotal,
          'updatedAt': Timestamp.fromDate(now),
        });

        return tx;
      } catch (e) {
        debugPrint('Error saving udhaar transaction to Firestore: $e');
      }
    }

    return tx;
  }

  Future<void> deleteTransaction({
    required String userId,
    required String personId,
    required String transactionId,
  }) async {
    final now = DateTime.now();
    final txList = _mockTxByPerson[personId] ?? [];
    final updatedTxList = txList.where((t) => t.id != transactionId).toList();
    _mockTxByPerson[personId] = updatedTxList;

    final newTotal = _calculateTotal(updatedTxList);

    final personList = _mockPersonsByUser[userId] ?? [];
    final pIdx = personList.indexWhere((p) => p.id == personId);
    if (pIdx != -1) {
      personList[pIdx] = personList[pIdx].copyWith(
        total: newTotal,
        updatedAt: now,
      );
      _mockPersonsByUser[userId] = List.from(personList);
    }

    _txStreamController.add(Map.from(_mockTxByPerson));
    _personsStreamController.add(Map.from(_mockPersonsByUser));

    if (Firebase.apps.isNotEmpty) {
      try {
        final personDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .doc(personId);

        await personDoc.collection('transactions').doc(transactionId).delete();

        // Fetch all remaining transactions from Firestore to compute exact total
        final allDocs = await personDoc.collection('transactions').get();
        final allTx = allDocs.docs
            .map((d) => UdhaarTransactionModel.fromMap(d.id, d.data()))
            .toList();
        allTx.sort((a, b) {
          final dateComp = b.date.compareTo(a.date);
          if (dateComp != 0) return dateComp;
          return b.createdAt.compareTo(a.createdAt);
        });

        _mockTxByPerson[personId] = allTx;
        final exactTotal = _calculateTotal(allTx);

        final pList = _mockPersonsByUser[userId] ?? [];
        final idx = pList.indexWhere((p) => p.id == personId);
        if (idx != -1) {
          pList[idx] = pList[idx].copyWith(
            total: exactTotal,
            updatedAt: now,
          );
          _mockPersonsByUser[userId] = List.from(pList);
        }

        _txStreamController.add(Map.from(_mockTxByPerson));
        _personsStreamController.add(Map.from(_mockPersonsByUser));

        await personDoc.update({
          'total': exactTotal,
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (e) {
        debugPrint('Error deleting udhaar transaction: $e');
      }
    }
  }

  Future<void> syncPersonTotal({
    required String userId,
    required String personId,
    required double total,
  }) async {
    final now = DateTime.now();
    final personList = _mockPersonsByUser[userId] ?? [];
    final pIdx = personList.indexWhere((p) => p.id == personId);
    if (pIdx != -1 && (personList[pIdx].total - total).abs() > 0.001) {
      personList[pIdx] = personList[pIdx].copyWith(total: total, updatedAt: now);
      _mockPersonsByUser[userId] = List.from(personList);
      _personsStreamController.add(Map.from(_mockPersonsByUser));
    }

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('udhaar_persons')
            .doc(personId)
            .update({
          'total': total,
          'updatedAt': Timestamp.fromDate(now),
        });
      } catch (e) {
        debugPrint('Error syncing udhaar person total: $e');
      }
    }
  }

  double _calculateTotal(List<UdhaarTransactionModel> transactions) {
    double total = 0.0;
    for (final tx in transactions) {
      if (tx.type == '+') {
        total += tx.amount;
      } else {
        total -= tx.amount;
      }
    }
    return total;
  }
}
