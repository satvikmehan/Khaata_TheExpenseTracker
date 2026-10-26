import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String phoneNumber;
  final List<String> groupOrder;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.groupOrder = const [],
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    List<String>? groupOrder,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      groupOrder: groupOrder ?? this.groupOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'groupOrder': groupOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final phone = map['phoneNumber'] as String? ?? map['email'] as String? ?? '';
    final name = map['name'] as String? ?? '';

    final rawOrder = map['groupOrder'];
    final List<String> groupOrderList = [];
    if (rawOrder is List) {
      for (final item in rawOrder) {
        if (item != null) groupOrderList.add(item.toString());
      }
    }

    return UserModel(
      id: id,
      name: name.isNotEmpty ? name : phone,
      phoneNumber: phone,
      groupOrder: groupOrderList,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
