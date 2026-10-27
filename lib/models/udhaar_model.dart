import 'package:cloud_firestore/cloud_firestore.dart';

class UdhaarPersonModel {
  final String id;
  final String userId;
  final String name;
  final double total;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UdhaarPersonModel({
    required this.id,
    required this.userId,
    required this.name,
    this.total = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  UdhaarPersonModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? total,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UdhaarPersonModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'total': total,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UdhaarPersonModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawTotal = map['total'];
    double parsedTotal = 0.0;
    if (rawTotal is num) {
      parsedTotal = rawTotal.toDouble();
    }

    return UdhaarPersonModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      total: parsedTotal,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class UdhaarTransactionModel {
  final String id;
  final String personId;
  final String userId;
  final String type; // '+' or '-'
  final double amount;
  final String note;
  final DateTime date;
  final DateTime createdAt;

  const UdhaarTransactionModel({
    required this.id,
    required this.personId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'personId': personId,
      'userId': userId,
      'type': type,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UdhaarTransactionModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    final rawAmount = map['amount'];
    double parsedAmount = 0.0;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    }

    return UdhaarTransactionModel(
      id: id,
      personId: map['personId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? '+',
      amount: parsedAmount,
      note: map['note'] as String? ?? '',
      date: parseDate(map['date']),
      createdAt: parseDate(map['createdAt']),
    );
  }
}
