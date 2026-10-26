import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/group_model.dart';
import '../models/month_model.dart';
import '../models/transaction_model.dart';

class ExportService {
  static final ExportService instance = ExportService._internal();
  ExportService._internal();

  // Generate CSV content for a month's history
  String generateCsv({
    required GroupModel group,
    required MonthModel month,
    required List<TransactionModel> transactions,
  }) {
    final buffer = StringBuffer();

    // Header info
    buffer.writeln('"Group Name","${group.name.replaceAll('"', '""')}"');
    buffer.writeln('"Month","${month.displayTitle}"');
    buffer.writeln('"Status","${month.status.toUpperCase()}"');
    buffer.writeln('"Total (INR)","${month.formattedTotal}"');
    buffer.writeln('"Exported At","${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}"');
    buffer.writeln('');

    // Column headers
    buffer.writeln('"Date","Transaction Name","Type","Amount (INR)","Signed Amount (INR)"');

    double totalExpenses = 0.0;
    double totalWithdrawals = 0.0;

    for (final tx in transactions) {
      if (tx.isExpense) {
        totalExpenses += tx.amount;
      } else {
        totalWithdrawals += tx.amount;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      final safeName = tx.name.replaceAll('"', '""');
      final typeStr = tx.isExpense ? 'Expense (+)' : 'Withdrawal (-)';
      final signedStr = tx.isExpense ? '+${tx.amount.toStringAsFixed(2)}' : '-${tx.amount.toStringAsFixed(2)}';

      buffer.writeln('"$dateStr","$safeName","$typeStr",${tx.amount.toStringAsFixed(2)},"$signedStr"');
    }

    buffer.writeln('');
    buffer.writeln('"--- SUMMARY ---"');
    buffer.writeln('"Total Expenses",${totalExpenses.toStringAsFixed(2)}');
    buffer.writeln('"Total Withdrawals",${totalWithdrawals.toStringAsFixed(2)}');
    buffer.writeln('"Net Monthly Total",${month.total.toStringAsFixed(2)}');

    return buffer.toString();
  }

  // Generate clean text summary suitable for WhatsApp / SMS / notes
  String generateTextSummary({
    required GroupModel group,
    required MonthModel month,
    required List<TransactionModel> transactions,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📊 *${group.name} — ${month.displayTitle}*');
    buffer.writeln('Total: *${month.formattedTotal}*');
    buffer.writeln('Status: ${month.isDone ? 'Completed' : 'Active'}');
    buffer.writeln('────────────────────');

    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in transactions) {
      grouped.putIfAbsent(tx.dateGroupKey, () => []).add(tx);
    }

    for (final dateKey in grouped.keys) {
      buffer.writeln('📅 $dateKey:');
      for (final tx in grouped[dateKey]!) {
        buffer.writeln('  • ${tx.name}: ${tx.formattedSignedAmount}');
      }
    }

    buffer.writeln('────────────────────');
    buffer.writeln('Exported from Expense tracker');
    return buffer.toString();
  }

  // Share CSV file via system share sheet or file download
  Future<void> shareMonthHistoryFile({
    required GroupModel group,
    required MonthModel month,
    required List<TransactionModel> transactions,
  }) async {
    final csvContent = generateCsv(
      group: group,
      month: month,
      transactions: transactions,
    );

    final cleanMonthName = month.id.replaceAll(RegExp(r'\D'), '_');
    final fileName = '${group.name.replaceAll(RegExp(r'\W+'), '_')}_$cleanMonthName.csv';

    if (kIsWeb) {
      // On Web, use ShareXFiles with bytes
      final bytes = utf8.encode(csvContent);
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: fileName,
        mimeType: 'text/csv',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Expense tracker history for ${month.displayTitle}',
        ),
      );
      return;
    }

    // On mobile / desktop, write to temp file and share
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(csvContent);

    final xFile = XFile(file.path, mimeType: 'text/csv', name: fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: '${group.name} - ${month.displayTitle} Expense History',
      ),
    );
  }
}
