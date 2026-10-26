import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import '../../models/month_model.dart';
import '../../services/expense_service.dart';
import '../../widgets/empty_state.dart';
import 'month_detail_screen.dart';

class PreviousMonthsScreen extends StatelessWidget {
  final GroupModel group;

  const PreviousMonthsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Archived Lists'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MonthModel>>(
          stream: ExpenseService.instance.streamPreviousMonths(group.id),
          initialData: const [],
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final months = snapshot.data ?? [];

            if (months.isEmpty) {
              return const EmptyState(
                icon: Icons.history,
                title: 'No archived lists yet',
                subtitle:
                    'When a list is completed, tap [DONE FOR THIS LIST] on the dashboard to save it to this history.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              itemCount: months.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8.0),
              itemBuilder: (context, index) {
                final month = months[index];
                return Dismissible(
                  key: Key(month.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: const Color(0xFFDC2626),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Archived List?'),
                        content: Text(
                          'Are you sure you want to delete "${month.displayTitle}" and all its entries from history?',
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
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    ExpenseService.instance.deleteCompletedMonth(
                      groupId: group.id,
                      monthId: month.id,
                    );
                  },
                  child: InkWell(
                    onTap: () async {
                      final restored = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => MonthDetailScreen(
                            group: group,
                            month: month,
                          ),
                        ),
                      );
                      if (restored == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    borderRadius: BorderRadius.circular(4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 14.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          // List Title e.g. "Expenses" or "Goa Trip"
                          Expanded(
                            child: Text(
                              month.displayTitle,
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          // Total e.g. "₹12,450"
                          Text(
                            month.formattedTotal,
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          // Status badge: Archived
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(3.0),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Text(
                              'Archived',
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          IconButton(
                            tooltip: 'Restore to Front Screen',
                            icon: const Icon(Icons.unarchive_outlined, size: 20, color: Color(0xFF0F172A)),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Restore to Front Screen?'),
                                  content: Text(
                                    'The current front list will be saved to archive first, and "${month.displayTitle}" will become the active front list.',
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
                                      child: const Text('Restore to Front'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && context.mounted) {
                                await ExpenseService.instance.restoreArchivedMonth(
                                  groupId: group.id,
                                  archivedMonthId: month.id,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('"${month.displayTitle}" restored to front screen (front list archived)!')),
                                  );
                                  Navigator.pop(context, true);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
