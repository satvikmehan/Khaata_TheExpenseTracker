import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CashTransactionModel {
  final String id;
  final String type; // 'deposit' | 'withdraw'
  final double amount;
  final String description;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;

  const CashTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isDeposit => type == 'deposit';
  bool get isWithdraw => type == 'withdraw';

  double get signedAmount => isDeposit ? amount : -amount;

  String get formattedSignedAmount {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount.truncateToDouble() == amount ? 0 : 2,
    );
    final formatted = formatter.format(amount);
    return isDeposit ? '+$formatted' : '-$formatted';
  }

  String get dateGroupKey {
    return DateFormat('d MMM').format(date);
  }

  String get fullDateString {
    return DateFormat('d MMM yyyy').format(date);
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CashTransactionModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawAmount = map['amount'];
    double parsedAmount = 0.0;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    }

    return CashTransactionModel(
      id: id,
      type: map['type'] as String? ?? 'deposit',
      amount: parsedAmount,
      description: map['description'] as String? ?? '',
      date: parseDate(map['date']),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }
}
