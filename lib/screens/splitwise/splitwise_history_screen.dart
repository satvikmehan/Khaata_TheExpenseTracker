import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/splitwise_model.dart';
import '../../services/auth_service.dart';
import '../../services/splitwise_service.dart';
import 'splitwise_group_screen.dart';

class SplitwiseHistoryScreen extends StatelessWidget {
  const SplitwiseHistoryScreen({super.key});

  String _formatAmount(double amount) {
    final absAmt = amount.abs();
    return absAmt.truncateToDouble() == absAmt
        ? absAmt.toInt().toString()
        : absAmt.toStringAsFixed(2);
  }

  Future<void> _confirmDeleteGroup(BuildContext context, SplitwiseGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${group.name}?'),
        content: const Text('This will delete this completed party and all associated expenses permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await SplitwiseService.instance.deleteGroup(userId: currentUser.id, groupId: group.id);
      }
    }
  }

  Widget _buildGroupCard(BuildContext context, SplitwiseGroupModel group) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SplitwiseGroupScreen(group: group),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3.0),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 13.0, color: Colors.grey.shade500),
                            const SizedBox(width: 4.0),
                            Text(
                              DateFormat('dd MMM yyyy').format(group.date),
                              style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text(
                      'COMPLETED',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                    onPressed: () => _confirmDeleteGroup(context, group),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${group.members.length} people present',
                    style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                  ),
                  Text(
                    'Total: ₹${_formatAmount(group.totalExpense)}',
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (group.members.isNotEmpty) ...[
                const SizedBox(height: 6.0),
                Text(
                  group.members.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.0, color: Colors.grey.shade400),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Splitwise History'),
      ),
      body: StreamBuilder<List<SplitwiseGroupModel>>(
        stream: SplitwiseService.instance.streamGroups(currentUser.id),
        initialData: SplitwiseService.instance.getCachedGroups(currentUser.id),
        builder: (context, snapshot) {
          final allGroups = snapshot.data ?? [];
          final historyGroups = allGroups.where((g) => g.isDone).toList();

          if (historyGroups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_outlined,
                        size: 34,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'No Completed Parties Yet',
                      style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'When a party is finished, click "Done" inside the group to store it in History.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.0, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: historyGroups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12.0),
            itemBuilder: (context, index) {
              return _buildGroupCard(context, historyGroups[index]);
            },
          );
        },
      ),
    );
  }
}
