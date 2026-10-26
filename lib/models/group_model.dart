import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String inviteCode;
  final List<String> members;
  final Map<String, String> memberNames;
  final int maxMembers;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
    this.memberNames = const {},
    this.maxMembers = 2,
    required this.createdAt,
  });

  bool get isFull => members.length >= maxMembers;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'members': members,
      'memberNames': memberNames,
      'maxMembers': maxMembers,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawMembers = map['members'];
    final List<String> membersList = [];
    if (rawMembers is List) {
      for (final item in rawMembers) {
        if (item != null) membersList.add(item.toString());
      }
    }

    final rawNames = map['memberNames'];
    final Map<String, String> memberNamesMap = {};
    if (rawNames is Map) {
      rawNames.forEach((key, value) {
        if (key != null && value != null) {
          memberNamesMap[key.toString()] = value.toString();
        }
      });
    }

    final maxMem = (map['maxMembers'] as num?)?.toInt() ?? 2;

    return GroupModel(
      id: id,
      name: map['name'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      members: membersList,
      memberNames: memberNamesMap,
      maxMembers: maxMem.clamp(2, 10),
      createdAt: parseDate(map['createdAt']),
    );
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? inviteCode,
    List<String>? members,
    Map<String, String>? memberNames,
    int? maxMembers,
    DateTime? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
      memberNames: memberNames ?? this.memberNames,
      maxMembers: maxMembers ?? this.maxMembers,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
