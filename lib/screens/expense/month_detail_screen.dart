import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../models/month_model.dart';
import '../../models/transaction_model.dart';
import '../../services/expense_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/monthly_total.dart';
import '../../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class MonthDetailScreen extends StatelessWidget {
  final GroupModel group;
  final MonthModel month;

  const MonthDetailScreen({
    super.key,
    required this.group,
    required this.month,
  });

  Future<void> _confirmRestoreMonth(BuildContext context, MonthModel currentMonth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore to Front Screen?'),
        content: Text(
          'The current front list will be saved to archive first, and "${currentMonth.displayTitle}" will become the active front list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore to Front Screen'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);

      await ExpenseService.instance.restoreArchivedMonth(
        groupId: group.id,
        archivedMonthId: currentMonth.id,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('"${currentMonth.displayTitle}" restored to front screen (front list archived)!'),
          duration: const Duration(seconds: 3),
        ),
      );
      // Navigate back and signal restored
      nav.pop(true);
    }
  }

  Future<void> _showRenameDialog(BuildContext context, MonthModel currentMonth) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: currentMonth.displayTitle);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename List'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'List Name',
              hintText: 'e.g., Goa Trip, October 2026',
            ),
            onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && context.mounted) {
      await ExpenseService.instance.renameList(
        groupId: group.id,
        listId: currentMonth.id,
        newName: newName,
      );
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('List renamed to "$newName"')),
        );
      }
    }
  }

  Future<void> _confirmDeleteMonth(BuildContext context, MonthModel currentMonth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Archived List?'),
        content: Text(
          'Are you sure you want to permanently delete "${currentMonth.displayTitle}" and all its entries from history? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete List'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);

      await ExpenseService.instance.deleteCompletedMonth(
        groupId: group.id,
        monthId: currentMonth.id,
      );

      messenger.showSnackBar(
        SnackBar(content: Text('"${currentMonth.displayTitle}" deleted from history.')),
      );
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MonthModel?>(
      stream: ExpenseService.instance.streamMonth(group.id, month.id),
      initialData: month,
      builder: (context, monthSnapshot) {
        final currentMonth = monthSnapshot.data ?? month;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(currentMonth.displayTitle),
            actions: [
              IconButton(
                tooltip: 'Restore to Front Screen',
                icon: const Icon(Icons.unarchive_outlined, size: 22),
                onPressed: () => _confirmRestoreMonth(context, currentMonth),
              ),
              IconButton(
                tooltip: 'Rename List',
                icon: const Icon(Icons.edit_outlined, size: 22),
                onPressed: () => _showRenameDialog(context, currentMonth),
              ),
              IconButton(
                tooltip: 'Add Entry',
                icon: const Icon(Icons.add, size: 22),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(
                        groupId: group.id,
                        monthId: currentMonth.id,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Delete Archived List',
                icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
                onPressed: () => _confirmDeleteMonth(context, currentMonth),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Prominent Top Total
                MonthlyTotal(
                  monthTitle: currentMonth.displayTitle,
                  formattedTotal: currentMonth.formattedTotal,
                  subtitle: 'TOTAL • ARCHIVED LIST',
                  onTitleTap: () => _showRenameDialog(context, currentMonth),
                ),

                // Restore banner button to undo archive
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  color: const Color(0xFFF1F5F9),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 18.0, color: Color(0xFF475569)),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          'Archived list',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.unarchive_outlined, size: 16),
                        label: const Text('Bring to Front Screen'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        ),
                        onPressed: () => _confirmRestoreMonth(context, currentMonth),
                      ),
                    ],
                  ),
                ),

                // Transactions list with Edit & Delete options
                Expanded(
                  child: StreamBuilder<List<TransactionModel>>(
                    stream: ExpenseService.instance.streamTransactions(
                      group.id,
                      currentMonth.id,
                    ),
                    initialData: const [],
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final transactions = snapshot.data ?? [];

                      if (transactions.isEmpty) {
                        return const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No entries for this list',
                          subtitle: 'All entries for this list were deleted or none were recorded.',
                        );
                      }

                      // Group by date
                      final Map<String, List<TransactionModel>> grouped = {};
                      for (final tx in transactions) {
                        grouped.putIfAbsent(tx.dateGroupKey, () => []).add(tx);
                      }

                      final dateKeys = grouped.keys.toList();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: dateKeys.length,
                        itemBuilder: (context, index) {
                          final dateKey = dateKeys[index];
                          final txList = grouped[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                  vertical: 10.0,
                                ),
                                color: const Color(0xFFF8FAFC),
                                child: Text(
                                  dateKey,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              ...txList.map(
                                (tx) => TransactionTile(
                                  transaction: tx,
                                  onEdit: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AddTransactionScreen(
                                          groupId: group.id,
                                          monthId: currentMonth.id,
                                          transaction: tx,
                                        ),
                                      ),
                                    );
                                  },
                                  onDelete: () {
                                    ExpenseService.instance.deleteTransaction(
                                      groupId: group.id,
                                      monthId: currentMonth.id,
                                      transaction: tx,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
