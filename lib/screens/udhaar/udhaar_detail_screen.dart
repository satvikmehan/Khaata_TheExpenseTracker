import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/udhaar_model.dart';
import '../../services/auth_service.dart';
import '../../services/udhaar_service.dart';

class UdhaarDetailScreen extends StatefulWidget {
  final UdhaarPersonModel person;

  const UdhaarDetailScreen({super.key, required this.person});

  @override
  State<UdhaarDetailScreen> createState() => _UdhaarDetailScreenState();
}

class _UdhaarDetailScreenState extends State<UdhaarDetailScreen> {
  late UdhaarPersonModel _person;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
  }

  String _formatCurrency(double amount) {
    final absAmt = amount.abs();
    final formatted = absAmt.truncateToDouble() == absAmt
        ? absAmt.toInt().toString()
        : absAmt.toStringAsFixed(2);
    if (amount > 0) return '₹$formatted';
    if (amount < 0) return '-₹$formatted';
    return '₹0';
  }

  Color _getAmountColor(double amount) {
    if (amount > 0) return const Color(0xFF16A34A); // Green
    if (amount < 0) return const Color(0xFFDC2626); // Red
    return const Color(0xFF0F172A); // Black for zero
  }

  Future<void> _confirmDeletePerson() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_person.name}?'),
        content: const Text('This will remove this person and all their transaction history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
        await UdhaarService.instance.deletePerson(
          userId: currentUser.id,
          personId: _person.id,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _confirmDeleteTransaction(UdhaarTransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete this ${tx.type == '+' ? 'added' : 'deducted'} entry of ₹${tx.amount.toStringAsFixed(tx.amount.truncateToDouble() == tx.amount ? 0 : 2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
        await UdhaarService.instance.deleteTransaction(
          userId: currentUser.id,
          personId: _person.id,
          transactionId: tx.id,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return StreamBuilder<List<UdhaarPersonModel>>(
      stream: UdhaarService.instance.streamPersons(currentUser.id),
      initialData: UdhaarService.instance.getCachedPersons(currentUser.id),
      builder: (context, personSnapshot) {
        final persons = personSnapshot.data ?? [];
        final updatedPerson = persons.firstWhere(
          (p) => p.id == _person.id,
          orElse: () => _person,
        );
        _person = updatedPerson;

        final currentTotal = _person.total;
        final totalColor = _getAmountColor(currentTotal);
        final totalText = _formatCurrency(currentTotal);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(_person.name),
            actions: [
              IconButton(
                tooltip: 'Delete Person',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: _confirmDeletePerson,
              ),
            ],
          ),
          body: StreamBuilder<List<UdhaarTransactionModel>>(
            stream: UdhaarService.instance.streamTransactions(currentUser.id, _person.id),
            initialData: UdhaarService.instance.getCachedTransactions(_person.id),
            builder: (context, txSnapshot) {
              final transactions = txSnapshot.data ?? [];

              double totalGiven = 0.0;
              double totalReceived = 0.0;
              for (final t in transactions) {
                if (t.type == '+') {
                  totalGiven += t.amount;
                } else {
                  totalReceived += t.amount;
                }
              }

              return Column(
                children: [
                  // Top Summary Card
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          currentTotal > 0
                              ? 'YOU WILL GET (NET)'
                              : (currentTotal < 0 ? 'YOU WILL PAY (NET)' : 'NET BALANCE'),
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          totalText,
                          style: TextStyle(
                            fontSize: 34.0,
                            fontWeight: FontWeight.w800,
                            color: totalColor,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Debt Given (+)',
                                  style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  '+₹${totalGiven.toStringAsFixed(totalGiven.truncateToDouble() == totalGiven ? 0 : 2)}',
                                  style: const TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.shade200),
                            Column(
                              children: [
                                Text(
                                  'Debt Taken / Received (-)',
                                  style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  '-₹${totalReceived.toStringAsFixed(totalReceived.truncateToDouble() == totalReceived ? 0 : 2)}',
                                  style: const TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),

                  const SizedBox(height: 12.0),

                  // Section Header: History of Transactions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const Text(
                          'History of Transactions',
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${transactions.length} entries',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transactions List
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12.0),
                                  Text(
                                    'No transactions recorded yet',
                                    style: TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    'Use the + or - buttons above to add entries for ${_person.name}.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: transactions.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8.0),
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              final isPlus = tx.type == '+';
                              final sign = isPlus ? '+' : '-';
                              final color = isPlus ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                              final formattedAmt = tx.amount.truncateToDouble() == tx.amount
                                  ? tx.amount.toInt().toString()
                                  : tx.amount.toStringAsFixed(2);

                              return Container(
                                padding: const EdgeInsets.all(14.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isPlus ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPlus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                        size: 18,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.note.isNotEmpty ? tx.note : (isPlus ? 'Debt Given' : 'Debt Received / Taken'),
                                            style: const TextStyle(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 3.0),
                                          Text(
                                            DateFormat('dd MMM yyyy').format(tx.date),
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '$sign₹$formattedAmt',
                                      style: TextStyle(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                                      onPressed: () => _confirmDeleteTransaction(tx),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
