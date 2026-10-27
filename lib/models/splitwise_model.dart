import 'package:cloud_firestore/cloud_firestore.dart';

class SplitwiseGroupModel {
  final String id;
  final String userId;
  final String name;
  final DateTime date;
  final List<String> members;
  final String status; // 'active' or 'done'
  final double totalExpense;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SplitwiseGroupModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.date,
    required this.members,
    this.status = 'active',
    this.totalExpense = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDone => status == 'done';

  SplitwiseGroupModel copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? date,
    List<String>? members,
    String? status,
    double? totalExpense,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SplitwiseGroupModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      date: date ?? this.date,
      members: members ?? this.members,
      status: status ?? this.status,
      totalExpense: totalExpense ?? this.totalExpense,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'date': Timestamp.fromDate(date),
      'members': members,
      'status': status,
      'totalExpense': totalExpense,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SplitwiseGroupModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawMembers = map['members'];
    final List<String> memberList = [];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m != null) memberList.add(m.toString().trim());
      }
    }

    final rawTotal = map['totalExpense'];
    double parsedTotal = 0.0;
    if (rawTotal is num) {
      parsedTotal = rawTotal.toDouble();
    }

    return SplitwiseGroupModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      date: parseDate(map['date']),
      members: memberList,
      status: map['status'] as String? ?? 'active',
      totalExpense: parsedTotal,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class SplitwiseExpenseModel {
  final String id;
  final String groupId;
  final String userId;
  final String description;
  final double amount;
  final String paidBy;
  final List<String> involvedMembers;
  final DateTime date;
  final DateTime createdAt;

  const SplitwiseExpenseModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.involvedMembers,
    required this.date,
    required this.createdAt,
  });

  SplitwiseExpenseModel copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? description,
    double? amount,
    String? paidBy,
    List<String>? involvedMembers,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return SplitwiseExpenseModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      involvedMembers: involvedMembers ?? this.involvedMembers,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'userId': userId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'involvedMembers': involvedMembers,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SplitwiseExpenseModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawInvolved = map['involvedMembers'];
    final List<String> involvedList = [];
    if (rawInvolved is List) {
      for (final m in rawInvolved) {
        if (m != null) involvedList.add(m.toString().trim());
      }
    }

    final rawAmount = map['amount'];
    double parsedAmount = 0.0;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    }

    return SplitwiseExpenseModel(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      description: map['description'] as String? ?? '',
      amount: parsedAmount,
      paidBy: map['paidBy'] as String? ?? '',
      involvedMembers: involvedList,
      date: parseDate(map['date']),
      createdAt: parseDate(map['createdAt']),
    );
  }
}
