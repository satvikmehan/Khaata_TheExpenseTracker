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

  Future<void> _showTransactionDialog({required String type}) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final isPlus = type == '+';
    final actionTitle = isPlus ? 'Debt Given (+)' : 'Debt Taken / Received (-)';
    final saveButtonLabel = isPlus ? 'Record Given Debt' : 'Record Received / Taken';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: bottomInset + 20.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          actionTitle,
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: isPlus
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Person: ${_person.name}',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Amount input
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Amount (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Note input
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Note (Reason/Description)',
                        hintText: isPlus ? 'e.g. Lunch split, Cash given' : 'e.g. Paid via UPI',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Date selector
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18.0, color: Color(0xFF0F172A)),
                            const SizedBox(width: 10.0),
                            Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlus
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () async {
                          final amtText = amountController.text.trim();
                          final amt = double.tryParse(amtText);
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid amount greater than 0')),
                            );
                            return;
                          }

                          final currentUser = AuthService.instance.currentUser;
                          if (currentUser == null) return;

                          Navigator.pop(ctx);

                          await UdhaarService.instance.addTransaction(
                            userId: currentUser.id,
                            personId: _person.id,
                            type: type,
                            amount: amt,
                            note: noteController.text.trim(),
                            date: selectedDate,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isPlus
                                      ? 'Recorded ₹$amtText given to ${_person.name}'
                                      : 'Recorded ₹$amtText received/taken from ${_person.name}',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Text(
                          saveButtonLabel,
                          style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                        const SizedBox(height: 18.0),

                        // Action buttons row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.remove, size: 18, color: Color(0xFFDC2626)),
                                label: const Text('Received / Taken (-)'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                                onPressed: () => _showTransactionDialog(type: '-'),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Debt Given (+)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                ),
                                onPressed: () => _showTransactionDialog(type: '+'),
                              ),
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
