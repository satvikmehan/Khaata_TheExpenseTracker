import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MonthModel {
  final String id;
  final String name; // Custom name of the list, e.g. "Expenses", "Trip to Goa"
  final double total;
  final String status; // 'active' | 'done'
  final DateTime createdAt;
  final DateTime? completedAt;

  const MonthModel({
    required this.id,
    this.name = '',
    required this.total,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  bool get isActive => status == 'active';
  bool get isDone => status == 'done';

  // Display custom name if set, otherwise default to month with year in which list was created
  String get displayTitle {
    if (name.trim().isNotEmpty && name.trim().toLowerCase() != 'expenses') {
      return name.trim();
    }
    try {
      final parts = id.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final date = DateTime(year, month);
        return DateFormat('MMMM yyyy').format(date);
      }
    } catch (_) {}
    return DateFormat('MMMM yyyy').format(createdAt);
  }

  // Format currency helper
  String get formattedTotal {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: total.truncateToDouble() == total ? 0 : 2,
    );
    return formatter.format(total);
  }

  MonthModel copyWith({
    String? id,
    String? name,
    double? total,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return MonthModel(
      id: id ?? this.id,
      name: name ?? this.name,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim().isNotEmpty ? name.trim() : displayTitle,
      'total': total,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  factory MonthModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawTotal = map['total'];
    double parsedTotal = 0.0;
    if (rawTotal is num) {
      parsedTotal = rawTotal.toDouble();
    }

    final parsedName = map['name'] as String? ?? (map['title'] as String? ?? '');

    return MonthModel(
      id: id,
      name: parsedName,
      total: parsedTotal,
      status: map['status'] as String? ?? 'active',
      createdAt: parseDate(map['createdAt']),
      completedAt: parseNullableDate(map['completedAt']),
    );
  }
}
