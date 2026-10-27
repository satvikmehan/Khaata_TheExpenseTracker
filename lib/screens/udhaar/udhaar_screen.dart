import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/udhaar_model.dart';
import '../../services/auth_service.dart';
import '../../services/udhaar_service.dart';
import 'udhaar_detail_screen.dart';

import '../../widgets/longer_hold_drag_start_listener.dart';

class UdhaarScreen extends StatefulWidget {
  const UdhaarScreen({super.key});

  @override
  State<UdhaarScreen> createState() => _UdhaarScreenState();
}

class _UdhaarScreenState extends State<UdhaarScreen> {
  List<UdhaarPersonModel>? _localPersons;
  String? _lastFingerprint;

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
    if (amount > 0) return const Color(0xFF16A34A); // Green for positive
    if (amount < 0) return const Color(0xFFDC2626); // Red for negative
    return const Color(0xFF0F172A); // Black for zero
  }

  Future<void> _showAddPersonDialog() async {
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Person'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Person Name *',
            hintText: 'e.g. Rahul, Aman, Sharma ji',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = nameController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await UdhaarService.instance.addPerson(
          userId: currentUser.id,
          name: name,
        );
      }
    }
  }

  Future<void> _showTransactionDialog({
    required UdhaarPersonModel person,
    required String type, // '+' or '-'
  }) async {
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
                      'Person: ${person.name}',
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

                    // Save action button
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
                            personId: person.id,
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
                                      ? 'Recorded ₹$amtText given to ${person.name}'
                                      : 'Recorded ₹$amtText received/taken from ${person.name}',
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

  Widget _buildPersonCard(BuildContext context, UdhaarPersonModel person) {
    final amountColor = _getAmountColor(person.total);
    final amountText = _formatCurrency(person.total);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            // Left side: Person Name (clickable to open history/details)
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UdhaarDetailScreen(person: person),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Tap to view history',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right side: [-] Amount [+] and drag indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minus button (-)
                Material(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6.0),
                    onTap: () => _showTransactionDialog(person: person, type: '-'),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.remove,
                        size: 18.0,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),

                // Amount left display between - and +
                Container(
                  constraints: const BoxConstraints(minWidth: 70),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    amountText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                ),

                // Plus button (+)
                Material(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6.0),
                    onTap: () => _showTransactionDialog(person: person, type: '+'),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.add,
                        size: 18.0,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Udhaar'),
        actions: [
          IconButton(
            tooltip: 'Add Person',
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
            onPressed: _showAddPersonDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<UdhaarPersonModel>>(
        stream: UdhaarService.instance.streamPersons(currentUser.id),
        initialData: UdhaarService.instance.getCachedPersons(currentUser.id),
        builder: (context, snapshot) {
          final streamPersons = snapshot.data ?? [];

          if (streamPersons.isEmpty) {
            _localPersons = null;
            _lastFingerprint = null;
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
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.menu_book_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'No Udhaar contacts yet',
                      style: TextStyle(
                        fontSize: 17.0,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Keep track of debt given or received with friends, flatmates, and family.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Person'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _showAddPersonDialog,
                    ),
                  ],
                ),
              ),
            );
          }

          final savedOrder = UdhaarService.instance.getCachedUserPersonOrder(currentUser.id);
          final currentFingerprint = streamPersons
              .map((p) => '${p.id}:${p.name}:${p.total}')
              .join('|');

          if (_localPersons == null || _localPersons!.isEmpty) {
            _lastFingerprint = currentFingerprint;
            _localPersons = UdhaarService.instance.sortPersonsByOrder(streamPersons, savedOrder);
          } else if (_lastFingerprint != currentFingerprint) {
            _lastFingerprint = currentFingerprint;
            final currentLocalOrder = _localPersons!.map((p) => p.id).toList();
            _localPersons = UdhaarService.instance.sortPersonsByOrder(streamPersons, currentLocalOrder);
          }

          final displayPersons = _localPersons ?? streamPersons;

          return Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.transparent,
            ),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: displayPersons.length,
              buildDefaultDragHandles: false,
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                return Material(
                  elevation: 6.0,
                  color: Colors.transparent,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(8.0),
                  child: child,
                );
              },
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _localPersons!.removeAt(oldIndex);
                  _localPersons!.insert(newIndex, item);
                });
                final orderedIds = _localPersons!.map((p) => p.id).toList();
                UdhaarService.instance.saveUserPersonOrder(currentUser.id, orderedIds);
              },
              itemBuilder: (context, index) {
                final person = displayPersons[index];
                return LongerHoldDragStartListener(
                  key: ValueKey(person.id),
                  index: index,
                  delay: const Duration(milliseconds: 1000),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: _buildPersonCard(context, person),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
