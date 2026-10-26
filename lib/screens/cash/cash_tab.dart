import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cash_transaction_model.dart';
import '../../models/group_model.dart';
import '../../services/cash_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/monthly_total.dart';
import 'add_cash_dialog.dart';

class CashTab extends StatelessWidget {
  final GroupModel group;

  const CashTab({super.key, required this.group});

  void _showAddDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (_) => AddCashDialog(
        groupId: group.id,
        initialType: type,
      ),
    );
  }

  void _showEditOrDeleteOptions(BuildContext context, CashTransactionModel tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description.isNotEmpty
                                ? tx.description
                                : (tx.isDeposit ? 'Cash Deposit' : 'Cash Withdrawal'),
                            style: const TextStyle(
                              fontSize: 17.0,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            tx.fullDateString,
                            style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      tx.formattedSignedAmount,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: tx.isDeposit
                            ? const Color(0xFF15803D)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF0F172A)),
                title: const Text('Edit Entry', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => AddCashDialog(
                      groupId: group.id,
                      initialType: tx.type,
                      transaction: tx,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                title: const Text(
                  'Delete Entry',
                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete Cash Entry?'),
                      content: Text(
                        'Are you sure you want to delete ${tx.formattedSignedAmount} (${tx.description})?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await CashService.instance.deleteCashTransaction(
                      groupId: group.id,
                      transaction: tx,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pending Cash Amount Display at Top
        StreamBuilder<double>(
          stream: CashService.instance.streamPendingAmount(group.id),
          initialData: CashService.instance.getCachedPendingAmount(group.id),
          builder: (context, snapshot) {
            final pending = snapshot.data ?? CashService.instance.getCachedPendingAmount(group.id);
            final formatter = NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: pending.truncateToDouble() == pending ? 0 : 2,
            );
            final formatted = formatter.format(pending);

            return MonthlyTotal(
              monthTitle: 'PENDING AMOUNT',
              formattedTotal: formatted,
              subtitle: '',
            );
          },
        ),

        // Cash transactions list (deposits & withdrawals)
        Expanded(
          child: StreamBuilder<List<CashTransactionModel>>(
            stream: CashService.instance.streamCashTransactions(group.id),
            initialData: CashService.instance.getCachedTransactions(group.id),
            builder: (context, snapshot) {
              final transactions = snapshot.data ?? CashService.instance.getCachedTransactions(group.id);

              if (transactions.isEmpty) {
                return const EmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No cash transactions yet',
                  subtitle:
                      'Tap [+ DEPOSIT] to add cash or [- WITHDRAW] to take out cash from this room.',
                );
              }

              // Group by date
              final Map<String, List<CashTransactionModel>> grouped = {};
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
                      // Date header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
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
                      // Transaction items
                      ...txList.map((tx) {
                        final isDeposit = tx.isDeposit;
                        final color = isDeposit
                            ? const Color(0xFF15803D)
                            : const Color(0xFFDC2626);

                        return Dismissible(
                          key: Key(tx.id),
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
                                title: const Text('Delete Cash Entry?'),
                                content: Text(
                                  'Are you sure you want to delete ${tx.formattedSignedAmount} (${tx.description})?',
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
                            CashService.instance.deleteCashTransaction(
                              groupId: group.id,
                              transaction: tx,
                            );
                          },
                          child: InkWell(
                            onTap: () => _showEditOrDeleteOptions(context, tx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 14.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: isDeposit
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Icon(
                                      isDeposit
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      size: 16.0,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.description.isNotEmpty
                                              ? tx.description
                                              : (isDeposit ? 'Deposit' : 'Withdrawal'),
                                          style: const TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          isDeposit ? 'Deposit to cash pool' : 'Withdrawn from cash pool',
                                          style: TextStyle(
                                            fontSize: 11.0,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    tx.formattedSignedAmount,
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // Bottom Action Bar: [+ DEPOSIT] and [- WITHDRAW]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'DEPOSIT',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                    ),
                    onPressed: () => _showAddDialog(context, 'deposit'),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text(
                      'WITHDRAW',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                    ),
                    onPressed: () => _showAddDialog(context, 'withdraw'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
