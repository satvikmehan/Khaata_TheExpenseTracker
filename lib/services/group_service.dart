import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';
import '../models/month_model.dart';
import 'auth_service.dart';

class GroupService {
  static final GroupService instance = GroupService._internal();
  GroupService._internal();

  SharedPreferences? _prefs;

  // In-memory fallback for local demo/testing
  final List<GroupModel> _mockGroups = [];
  final Map<String, List<String>> _mockUserGroupOrders = {};
  final StreamController<List<GroupModel>> _mockStreamController =
      StreamController<List<GroupModel>>.broadcast();

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  List<GroupModel> sortGroupsByOrder(List<GroupModel> groups, List<String> order) {
    if (order.isEmpty) {
      final list = List<GroupModel>.from(groups);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    final orderIndex = <String, int>{};
    for (int i = 0; i < order.length; i++) {
      orderIndex[order[i]] = i;
    }

    final sorted = List<GroupModel>.from(groups);
    sorted.sort((a, b) {
      final idxA = orderIndex[a.id];
      final idxB = orderIndex[b.id];
      if (idxA != null && idxB != null) {
        return idxA.compareTo(idxB);
      }
      if (idxA == null && idxB != null) return -1;
      if (idxA != null && idxB == null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  List<String> getCachedUserGroupOrder(String userId) {
    if (_mockUserGroupOrders.containsKey(userId) && _mockUserGroupOrders[userId]!.isNotEmpty) {
      return _mockUserGroupOrders[userId]!;
    }
    final current = AuthService.instance.currentUser;
    if (current?.id == userId && current!.groupOrder.isNotEmpty) {
      return current.groupOrder;
    }
    final fromPrefs = _prefs?.getStringList('user_group_order_$userId') ??
        AuthService.instance.prefs?.getStringList('user_group_order_$userId');
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _mockUserGroupOrders[userId] = List.from(fromPrefs);
      return fromPrefs;
    }
    return [];
  }

  List<GroupModel> getCachedUserGroups(String userId) {
    final userGroups = _mockGroups.where((g) => g.members.contains(userId)).toList();
    final order = getCachedUserGroupOrder(userId);
    return sortGroupsByOrder(userGroups, order);
  }

  Future<void> saveUserGroupOrder(String userId, List<String> groupIds) async {
    _mockUserGroupOrders[userId] = List.from(groupIds);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setStringList('user_group_order_$userId', groupIds);
    await AuthService.instance.updateGroupOrder(groupIds);
    if (_mockGroups.isNotEmpty) {
      _mockStreamController.add(List.from(_mockGroups));
    }
  }

  Stream<List<GroupModel>> streamUserGroups(String userId) {
    if (Firebase.apps.isNotEmpty) {
      try {
        return FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: userId)
            .snapshots()
            .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
              .toList();
          final order = getCachedUserGroupOrder(userId);
          return sortGroupsByOrder(groups, order);
        });
      } catch (_) {}
    }

    // Return in-memory stream filtered by user
    return _mockStreamController.stream.map((list) {
      final uGroups = list.where((g) => g.members.contains(userId)).toList();
      final ord = getCachedUserGroupOrder(userId);
      return sortGroupsByOrder(uGroups, ord);
    });
  }

  Future<GroupModel> createGroup({
    required String name,
    required String userId,
    String? userName,
    int maxMembers = 2,
  }) async {
    final inviteCode = _generateInviteCode();
    final now = DateTime.now();
    final clampedMax = maxMembers.clamp(1, 10);
    final creatorName = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : (AuthService.instance.currentUser?.name ?? 'User');

    if (Firebase.apps.isNotEmpty) {
      try {
        final docRef = FirebaseFirestore.instance.collection('groups').doc();
        final group = GroupModel(
          id: docRef.id,
          name: name.trim(),
          inviteCode: inviteCode,
          members: [userId],
          memberNames: {userId: creatorName},
          maxMembers: clampedMax,
          createdAt: now,
        );

        await docRef.set(group.toMap());

        // Automatically initialize the current calendar month (YYYY-MM)
        final currentMonthKey = DateFormat('yyyy-MM').format(now);
        final initialMonth = MonthModel(
          id: currentMonthKey,
          total: 0.0,
          status: 'active',
          createdAt: now,
        );

        await docRef
            .collection('months')
            .doc(currentMonthKey)
            .set(initialMonth.toMap());

        return group;
      } catch (_) {
        // Fall back to mock if Firestore is unreachable
      }
    }

    final mockGroup = GroupModel(
      id: 'grp_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}',
      name: name.trim(),
      inviteCode: inviteCode,
      members: [userId],
      memberNames: {userId: creatorName},
      maxMembers: clampedMax,
      createdAt: now,
    );
    _mockGroups.insert(0, mockGroup);
    _mockStreamController.add(List.from(_mockGroups));
    return mockGroup;
  }

  Future<GroupModel> joinGroupByCode({
    required String inviteCode,
    required String userId,
    String? userName,
  }) async {
    final cleanCode = inviteCode.trim().toUpperCase();
    final joiningName = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : (AuthService.instance.currentUser?.name ?? 'Member');

    if (Firebase.apps.isNotEmpty) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('groups')
            .where('inviteCode', isEqualTo: cleanCode)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          throw Exception('No group found with invite code "$cleanCode".');
        }

        final doc = query.docs.first;
        final group = GroupModel.fromMap(doc.id, doc.data());

        if (group.members.contains(userId)) {
          throw Exception('You are already a member of this group.');
        }

        if (group.isFull) {
          throw Exception(
              'This room is full (maximum ${group.maxMembers} members reached).');
        }

        await doc.reference.update({
          'members': FieldValue.arrayUnion([userId]),
          'memberNames.$userId': joiningName,
        });

        final updatedNames = Map<String, String>.from(group.memberNames);
        updatedNames[userId] = joiningName;

        return GroupModel(
          id: group.id,
          name: group.name,
          inviteCode: group.inviteCode,
          members: [...group.members, userId],
          memberNames: updatedNames,
          maxMembers: group.maxMembers,
          createdAt: group.createdAt,
        );
      } catch (e) {
        if (e is Exception && !e.toString().contains('FirebaseException')) {
          rethrow;
        }
      }
    }

    // Mock search
    final index = _mockGroups.indexWhere(
      (g) => g.inviteCode.toUpperCase() == cleanCode,
    );
    if (index == -1) {
      throw Exception('No group found with invite code "$cleanCode".');
    }

    final group = _mockGroups[index];
    if (group.members.contains(userId)) {
      throw Exception('You are already a member of this group.');
    }
    if (group.isFull) {
      throw Exception('This room is full (maximum ${group.maxMembers} members reached).');
    }

    final updatedNames = Map<String, String>.from(group.memberNames);
    updatedNames[userId] = joiningName;

    final updated = GroupModel(
      id: group.id,
      name: group.name,
      inviteCode: group.inviteCode,
      members: [...group.members, userId],
      memberNames: updatedNames,
      maxMembers: group.maxMembers,
      createdAt: group.createdAt,
    );
    _mockGroups[index] = updated;
    _mockStreamController.add(List.from(_mockGroups));
    return updated;
  }

  // Delete a room/group and its associated records
  Future<void> deleteGroup(String groupId) async {
    if (Firebase.apps.isNotEmpty) {
      try {
        final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);

        // Delete months and their transactions
        final monthsSnap = await groupRef.collection('months').get().timeout(const Duration(seconds: 2));
        for (final mDoc in monthsSnap.docs) {
          final txSnap = await mDoc.reference.collection('transactions').get().timeout(const Duration(seconds: 2));
          final batch = FirebaseFirestore.instance.batch();
          for (final tDoc in txSnap.docs) {
            batch.delete(tDoc.reference);
          }
          batch.delete(mDoc.reference);
          await batch.commit().timeout(const Duration(seconds: 2));
        }

        // Delete cash transactions
        final cashTxSnap = await groupRef.collection('cash_transactions').get().timeout(const Duration(seconds: 2));
        if (cashTxSnap.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final cDoc in cashTxSnap.docs) {
            batch.delete(cDoc.reference);
          }
          await batch.commit().timeout(const Duration(seconds: 2));
        }

        // Delete cash summary if any
        try {
          await groupRef.collection('cash').doc('summary').delete().timeout(const Duration(seconds: 1));
        } catch (_) {}

        // Finally delete the group document
        await groupRef.delete().timeout(const Duration(seconds: 2));
      } catch (e) {
        // Fallback: try direct document deletion
        try {
          await FirebaseFirestore.instance.collection('groups').doc(groupId).delete().timeout(const Duration(seconds: 1));
        } catch (_) {}
      }
    }

    _mockGroups.removeWhere((g) => g.id == groupId);
    _mockStreamController.add(List.from(_mockGroups));
  }

  // Sync the current user's name onto a group document so other members can see it
  Future<void> syncCurrentUserNameToGroup(String groupId) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null || currentUser.name.trim().isEmpty) return;

    final cleanName = currentUser.name.trim();

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
          'memberNames.${currentUser.id}': cleanName,
        }).timeout(const Duration(seconds: 3));
      } catch (_) {}
    } else {
      final mockIdx = _mockGroups.indexWhere((g) => g.id == groupId);
      if (mockIdx != -1) {
        final group = _mockGroups[mockIdx];
        final updatedNames = Map<String, String>.from(group.memberNames);
        updatedNames[currentUser.id] = cleanName;
        _mockGroups[mockIdx] = group.copyWith(memberNames: updatedNames);
      }
    }
  }

  // Retrieve names for members of a room
  Future<List<String>> getMemberNames(List<String> memberIds, {Map<String, String>? memberNamesMap}) async {
    final currentUserId = AuthService.instance.currentUser?.id;
    final currentUserName = AuthService.instance.currentUser?.name;
    final List<String> result = [];

    for (int i = 0; i < memberIds.length; i++) {
      final uid = memberIds[i];
      if (uid == currentUserId) {
        final name = (currentUserName != null && currentUserName.isNotEmpty)
            ? currentUserName
            : (memberNamesMap?[uid] ?? 'You');
        result.add('$name (You)');
        continue;
      }

      // 1. Check memberNamesMap on group
      if (memberNamesMap != null &&
          memberNamesMap.containsKey(uid) &&
          memberNamesMap[uid]!.trim().isNotEmpty) {
        result.add(memberNamesMap[uid]!.trim());
        continue;
      }

      // 2. Fallback to user collection lookup
      final user = await AuthService.instance.getUserById(uid);
      if (user != null && user.name.trim().isNotEmpty && !user.name.trim().startsWith('+')) {
        result.add(user.name.trim());
      } else {
        result.add('Member ${i + 1}');
      }
    }

    return result;
  }

  // Retrieve latest member names for group
  Future<List<String>> getGroupMemberNames(String groupId, List<String> fallbackMembers) async {
    List<String> members = fallbackMembers;
    Map<String, String> memberNames = {};
    final currentUserId = AuthService.instance.currentUser?.id;
    final currentUserName = AuthService.instance.currentUser?.name;

    if (Firebase.apps.isNotEmpty) {
      try {
        final groupDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .get()
            .timeout(const Duration(seconds: 3));
        if (groupDoc.exists && groupDoc.data() != null) {
          final group = GroupModel.fromMap(groupDoc.id, groupDoc.data()!);
          members = group.members;
          memberNames = Map<String, String>.from(group.memberNames);

          // Self-heal: If current user's name is not in memberNames or is outdated, save it!
          if (currentUserId != null &&
              currentUserName != null &&
              currentUserName.isNotEmpty &&
              memberNames[currentUserId] != currentUserName) {
            memberNames[currentUserId] = currentUserName;
            try {
              await groupDoc.reference.update({
                'memberNames.$currentUserId': currentUserName,
              }).timeout(const Duration(seconds: 2));
            } catch (_) {}
          }
        }
      } catch (_) {}
    } else {
      final mockIdx = _mockGroups.indexWhere((g) => g.id == groupId);
      if (mockIdx != -1) {
        members = _mockGroups[mockIdx].members;
        memberNames = Map<String, String>.from(_mockGroups[mockIdx].memberNames);
        if (currentUserId != null && currentUserName != null && currentUserName.isNotEmpty) {
          memberNames[currentUserId] = currentUserName;
          _mockGroups[mockIdx] = _mockGroups[mockIdx].copyWith(memberNames: memberNames);
        }
      }
    }

    // Resolve each member's display name
    final List<String> result = [];
    final Map<String, String> missingFound = {};

    for (int i = 0; i < members.length; i++) {
      final uid = members[i];
      if (uid == currentUserId) {
        final name = (currentUserName != null && currentUserName.isNotEmpty)
            ? currentUserName
            : (memberNames[uid] ?? 'You');
        result.add('$name (You)');
        continue;
      }

      // Check memberNames on group
      if (memberNames.containsKey(uid) && memberNames[uid]!.trim().isNotEmpty) {
        result.add(memberNames[uid]!.trim());
        continue;
      }

      // Fallback: check users collection
      final user = await AuthService.instance.getUserById(uid);
      if (user != null && user.name.trim().isNotEmpty && !user.name.trim().startsWith('+')) {
        final resolvedName = user.name.trim();
        result.add(resolvedName);
        missingFound[uid] = resolvedName;
      } else {
        result.add('Member ${i + 1}');
      }
    }

    // If any missing names were found from users collection, cache them on group doc
    if (missingFound.isNotEmpty && Firebase.apps.isNotEmpty) {
      try {
        final updates = <String, dynamic>{};
        missingFound.forEach((uid, name) {
          updates['memberNames.$uid'] = name;
        });
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update(updates)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    return result;
  }
}
