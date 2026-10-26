import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String groupId;
  final String monthId;
  final TransactionModel? transaction; // If provided, screen operates in Edit mode

  const AddTransactionScreen({
    super.key,
    required this.groupId,
    required this.monthId,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

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
      _nameController = TextEditingController(text: tx.name);
      final amtStr = tx.amount.truncateToDouble() == tx.amount
          ? tx.amount.toInt().toString()
          : tx.amount.toString();
      _amountController = TextEditingController(text: amtStr);
      _type = tx.type;
      _selectedDate = tx.date;
    } else {
      _nameController = TextEditingController();
      _amountController = TextEditingController();
      _type = 'expense';
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSaveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid positive number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        await ExpenseService.instance.updateTransaction(
          groupId: widget.groupId,
          monthId: widget.monthId,
          oldTransaction: widget.transaction!,
          name: _nameController.text.trim(),
          amount: parsedAmount,
          type: _type,
          date: _selectedDate,
        );
      } else {
        await ExpenseService.instance.addTransaction(
          groupId: widget.groupId,
          monthId: widget.monthId,
          name: _nameController.text.trim(),
          amount: parsedAmount,
          type: _type,
          date: _selectedDate,
          createdBy: currentUser.id,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    if (widget.transaction == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Are you sure you want to delete "${widget.transaction!.name}" (${widget.transaction!.formattedSignedAmount})?',
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

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ExpenseService.instance.deleteTransaction(
          groupId: widget.groupId,
          monthId: widget.monthId,
          transaction: widget.transaction!,
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == 'expense';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Entry' : 'Add Transaction'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete Entry',
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              onPressed: _isLoading ? null : _handleDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        margin: const EdgeInsets.only(bottom: 20.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13.0,
                          ),
                        ),
                      ),
                    ],

                    // Type Selector: Expense (+) vs Withdrawal (-)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _type = 'expense'),
                            borderRadius: BorderRadius.circular(4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(
                                  color: isExpense
                                      ? const Color(0xFF15803D)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Expense (+)',
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    color: isExpense ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _type = 'withdrawal'),
                            borderRadius: BorderRadius.circular(4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              decoration: BoxDecoration(
                                color: !isExpense
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(
                                  color: !isExpense
                                      ? const Color(0xFFDC2626)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Withdrawal (-)',
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    color: !isExpense ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),

                    // Expense/Transaction Name
                    Text(
                      'Transaction Name',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      controller: _nameController,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Dinner, Groceries, Cab',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a transaction name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20.0),

                    // Amount
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          child: Text(
                            isExpense ? '+ ₹' : '- ₹',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w700,
                              color: isExpense
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '0',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        final numVal = double.tryParse(value.trim());
                        if (numVal == null || numVal <= 0) {
                          return 'Please enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20.0),

                    // Date Picker Field
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 14.0,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18.0,
                              color: Color(0xFF0F172A),
                            ),
                            const SizedBox(width: 12.0),
                            Text(
                              DateFormat('d MMMM yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),

                    // Submit Button
                    SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _handleSaveTransaction,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing ? 'Save Changes' : 'Add Transaction',
                                style: const TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    if (_isEditing) ...[
                      const SizedBox(height: 12.0),
                      SizedBox(
                        height: 48.0,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 18),
                          label: const Text(
                            'Delete Entry',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                          ),
                          onPressed: _isLoading ? null : _handleDelete,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
