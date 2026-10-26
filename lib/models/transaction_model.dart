import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionModel {
  final String id;
  final String name;
  final double amount;
  final String type; // 'expense' | 'withdrawal'
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isExpense => type == 'expense';
  bool get isWithdrawal => type == 'withdrawal';

  double get signedAmount => isExpense ? amount : -amount;

  String get formattedSignedAmount {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount.truncateToDouble() == amount ? 0 : 2,
    );
    final formatted = formatter.format(amount);
    return isExpense ? '+$formatted' : '-$formatted';
  }

  // E.g. "26 Oct"
  String get dateGroupKey {
    return DateFormat('d MMM').format(date);
  }

  // Exact date string e.g. "26 Oct 2026"
  String get fullDateString {
    return DateFormat('d MMM yyyy').format(date);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'type': type,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
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

    return TransactionModel(
      id: id,
      name: map['name'] as String? ?? '',
      amount: parsedAmount,
      type: map['type'] as String? ?? 'expense',
      date: parseDate(map['date']),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }
}
