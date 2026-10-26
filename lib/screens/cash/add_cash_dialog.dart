import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cash_transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/cash_service.dart';

class AddCashDialog extends StatefulWidget {
  final String groupId;
  final String initialType; // 'deposit' | 'withdraw'
  final CashTransactionModel? transaction; // If editing

  const AddCashDialog({
    super.key,
    required this.groupId,
    this.initialType = 'deposit',
    this.transaction,
  });

  @override
  State<AddCashDialog> createState() => _AddCashDialogState();
}

class _AddCashDialogState extends State<AddCashDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late String _type;
  late DateTime _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _type = tx.type;
      final amtStr = tx.amount.truncateToDouble() == tx.amount
          ? tx.amount.toInt().toString()
          : tx.amount.toString();
      _amountController = TextEditingController(text: amtStr);
      _descriptionController = TextEditingController(text: tx.description);
      _selectedDate = tx.date;
    } else {
      _type = widget.initialType;
      _amountController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid positive amount');
      return;
    }

    final currentUser = AuthService.instance.currentUser;
    final userId = currentUser?.id ??
        (Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser?.uid : null) ??
        'user_1';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        await CashService.instance.updateCashTransaction(
          groupId: widget.groupId,
          oldTransaction: widget.transaction!,
          type: _type,
          amount: parsedAmount,
          description: _descriptionController.text.trim(),
          date: _selectedDate,
        );
      } else {
        await CashService.instance.addCashTransaction(
          groupId: widget.groupId,
          type: _type,
          amount: parsedAmount,
          description: _descriptionController.text.trim(),
          date: _selectedDate,
          createdBy: userId,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == 'deposit'
                  ? 'Cash deposit of ₹${parsedAmount.toStringAsFixed(parsedAmount.truncateToDouble() == parsedAmount ? 0 : 2)} recorded'
                  : 'Cash withdrawal of ₹${parsedAmount.toStringAsFixed(parsedAmount.truncateToDouble() == parsedAmount ? 0 : 2)} recorded',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = _type == 'deposit';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEditing
                        ? 'Edit Cash Entry'
                        : (isDeposit ? 'Deposit Cash (+)' : 'Withdraw Cash (-)'),
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      color: isDeposit ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    isDeposit
                        ? 'Add money into the room cash pool'
                        : 'Take out money from the room cash pool',
                    style: TextStyle(fontSize: 13.0, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20.0),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13.0),
                      ),
                    ),
                  ],

                  // Type toggle selector
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _type = 'deposit'),
                          borderRadius: BorderRadius.circular(4.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            decoration: BoxDecoration(
                              color: isDeposit ? const Color(0xFF15803D) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: isDeposit ? const Color(0xFF15803D) : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Deposit (+)',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: isDeposit ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _type = 'withdraw'),
                          borderRadius: BorderRadius.circular(4.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            decoration: BoxDecoration(
                              color: !isDeposit ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: !isDeposit ? const Color(0xFFDC2626) : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Withdraw (-)',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: !isDeposit ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18.0),

                  // Amount
                  Text(
                    'Amount',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 6.0),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          isDeposit ? '+ ₹' : '- ₹',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: isDeposit ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter an amount';
                      final numVal = double.tryParse(v.trim());
                      if (numVal == null || numVal <= 0) return 'Enter a valid positive number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // Description / Source / Reason
                  Text(
                    'Description / Note',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 6.0),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: isDeposit ? 'e.g. ATM Cash, Contribution' : 'e.g. Paid helper, Groceries cash',
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // Date
                  Text(
                    'Date',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 6.0),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 16.0),
                          const SizedBox(width: 8.0),
                          Text(
                            DateFormat('d MMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text('Change', style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDeposit ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _handleSave,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18.0,
                                  height: 18.0,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_isEditing ? 'Save' : (isDeposit ? 'Deposit' : 'Withdraw')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
