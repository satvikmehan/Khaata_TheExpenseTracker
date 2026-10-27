import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/splitwise_model.dart';
import '../../services/auth_service.dart';
import '../../services/splitwise_service.dart';

class SplitwiseGroupScreen extends StatefulWidget {
  final SplitwiseGroupModel group;

  const SplitwiseGroupScreen({super.key, required this.group});

  @override
  State<SplitwiseGroupScreen> createState() => _SplitwiseGroupScreenState();
}

class _SplitwiseGroupScreenState extends State<SplitwiseGroupScreen> {
  late SplitwiseGroupModel _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    if (_group.members.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddPeopleDialog(isInitial: true);
      });
    }
  }

  String _formatAmount(double amount) {
    final absAmt = amount.abs();
    return absAmt.truncateToDouble() == absAmt
        ? absAmt.toInt().toString()
        : absAmt.toStringAsFixed(2);
  }

  Future<void> _showAddPeopleDialog({bool isInitial = false}) async {
    final nameController = TextEditingController();
    final List<String> enteredNames = [];

    await showDialog(
      context: context,
      barrierDismissible: !isInitial,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(isInitial ? 'Add People in ${_group.name}' : 'Add More People'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter names of all the people present in this group/party.',
                      style: TextStyle(fontSize: 13.0, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Person Name',
                              hintText: 'e.g. Rahul, Priya',
                              isDense: true,
                            ),
                            onSubmitted: (val) {
                              final trimmed = val.trim();
                              if (trimmed.isNotEmpty && !enteredNames.contains(trimmed)) {
                                setDialogState(() {
                                  enteredNames.add(trimmed);
                                  nameController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () {
                            final trimmed = nameController.text.trim();
                            if (trimmed.isNotEmpty && !enteredNames.contains(trimmed)) {
                              setDialogState(() {
                                enteredNames.add(trimmed);
                                nameController.clear();
                              });
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14.0),
                    if (!isInitial && _group.members.isNotEmpty) ...[
                      const Text(
                        'Current members in party (tap to remove):',
                        style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: _group.members.map((name) {
                          return Chip(
                            backgroundColor: const Color(0xFFF1F5F9),
                            label: Text(name),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () async {
                              Navigator.pop(ctx);
                              final expenses = SplitwiseService.instance.getCachedExpenses(_group.id);
                              await _confirmRemovePerson(name, expenses);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14.0),
                    ],
                    if (enteredNames.isNotEmpty) ...[
                      const Text(
                        'People to add:',
                        style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: enteredNames.map((name) {
                          return Chip(
                            label: Text(name),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setDialogState(() {
                                enteredNames.remove(name);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isInitial)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    // Include any text in controller
                    final pending = nameController.text.trim();
                    if (pending.isNotEmpty && !enteredNames.contains(pending)) {
                      enteredNames.add(pending);
                    }
                    if (enteredNames.isEmpty && isInitial) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please add at least one person')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final currentUser = AuthService.instance.currentUser;
                    if (currentUser != null && enteredNames.isNotEmpty) {
                      await SplitwiseService.instance.addMembers(
                        userId: currentUser.id,
                        groupId: _group.id,
                        newMembers: enteredNames,
                      );
                    }
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showExpenseModal({SplitwiseExpenseModel? expense}) async {
    final isEdit = expense != null;
    final amountController = TextEditingController(
      text: isEdit ? _formatAmount(expense.amount) : '',
    );
    final descController = TextEditingController(
      text: isEdit ? expense.description : '',
    );
    DateTime selectedDate = isEdit ? expense.date : DateTime.now();

    final members = _group.members;
    if (members.isEmpty) {
      await _showAddPeopleDialog(isInitial: true);
      return;
    }

    String selectedPayer = (isEdit && members.contains(expense.paidBy))
        ? expense.paidBy
        : members.first;
    final Set<String> selectedInvolved = isEdit
        ? Set.from(expense.involvedMembers.where((m) => members.contains(m)))
        : Set.from(members);

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
            final amountVal = double.tryParse(amountController.text.trim()) ?? 0.0;
            final count = selectedInvolved.isEmpty ? 1 : selectedInvolved.length;
            final perPersonShare = amountVal > 0 ? (amountVal / count) : 0.0;

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
                          isEdit ? 'Edit Expense' : 'Add Expense',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14.0),

                    // Amount Field
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Amount (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                      onChanged: (_) {
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 14.0),

                    // Description Field
                    TextField(
                      controller: descController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        hintText: 'e.g. Dinner, Drinks, Cab, Hotel',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Paid By Selector
                    const Text(
                      'Paid by:',
                      style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPayer,
                          isExpanded: true,
                          items: members.map((m) {
                            return DropdownMenuItem<String>(
                              value: m,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      m.isNotEmpty ? m[0].toUpperCase() : '?',
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedPayer = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // Who all involved (Split Among)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Who all involved:',
                          style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (selectedInvolved.length == members.length) {
                                selectedInvolved.clear();
                              } else {
                                selectedInvolved.addAll(members);
                              }
                            });
                          },
                          child: Text(
                            selectedInvolved.length == members.length ? 'Unselect All' : 'Select All',
                            style: const TextStyle(fontSize: 12.0),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        children: members.map((member) {
                          final isChecked = selectedInvolved.contains(member);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(member, style: const TextStyle(fontSize: 14.0)),
                            value: isChecked,
                            activeColor: const Color(0xFF0F172A),
                            onChanged: (bool? val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedInvolved.add(member);
                                } else {
                                  selectedInvolved.remove(member);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Split preview banner
                    if (amountVal > 0 && selectedInvolved.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                '₹${_formatAmount(amountVal)} split equally among ${selectedInvolved.length} people = ₹${_formatAmount(perPersonShare)} / person',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14.0),

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
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16.0, color: Color(0xFF0F172A)),
                            const SizedBox(width: 10.0),
                            Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
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

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
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

                          final desc = descController.text.trim();
                          if (desc.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an expense description')),
                            );
                            return;
                          }

                          if (selectedInvolved.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select at least one person involved')),
                            );
                            return;
                          }

                          final currentUser = AuthService.instance.currentUser;
                          if (currentUser == null) return;

                          Navigator.pop(ctx);

                          if (isEdit) {
                            await SplitwiseService.instance.updateExpense(
                              userId: currentUser.id,
                              groupId: _group.id,
                              expenseId: expense.id,
                              description: desc,
                              amount: amt,
                              paidBy: selectedPayer,
                              involvedMembers: selectedInvolved.toList(),
                              date: selectedDate,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Updated expense "$desc" of ₹$amtText')),
                              );
                            }
                          } else {
                            await SplitwiseService.instance.addExpense(
                              userId: currentUser.id,
                              groupId: _group.id,
                              description: desc,
                              amount: amt,
                              paidBy: selectedPayer,
                              involvedMembers: selectedInvolved.toList(),
                              date: selectedDate,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added expense "$desc" of ₹$amtText')),
                              );
                            }
                          }
                        },
                        child: Text(isEdit ? 'Update Expense' : 'Save Expense', style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
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

  Future<void> _confirmRemovePerson(String person, List<SplitwiseExpenseModel> expenses) async {
    final paidExpenses = expenses.where((e) => e.paidBy == person).toList();
    if (paidExpenses.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Cannot Remove $person'),
          content: Text(
            '"$person" is recorded as the payer for ${paidExpenses.length} expense(s) '
            '(e.g. "${paidExpenses.first.description}"). Please edit or delete those expenses first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final soloExpenses = expenses.where((e) => e.involvedMembers.length == 1 && e.involvedMembers.contains(person)).toList();
    if (soloExpenses.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Cannot Remove $person'),
          content: Text(
            '"$person" is the only person involved in "${soloExpenses.first.description}". '
            'Please edit or delete that expense first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $person?'),
        content: Text(
          'Are you sure you want to remove "$person" from this party? '
          'They will be excluded from settlements and existing shared expenses.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await SplitwiseService.instance.removeMember(
          userId: currentUser.id,
          groupId: _group.id,
          memberName: person,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed "$person" from this party.')),
          );
        }
      }
    }
  }

  Future<void> _confirmMarkPartyDone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Party Done?'),
        content: const Text('This will mark this party as complete and store it in your History. You can still view settlements anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Done'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await SplitwiseService.instance.markGroupDone(userId: currentUser.id, groupId: _group.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Party marked as done and stored in History!')),
        );
      }
    }
  }

  Future<void> _confirmReopenParty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Party?'),
        content: const Text('Move this party back to Active groups so you can add more expenses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reopen')),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await SplitwiseService.instance.reopenGroup(userId: currentUser.id, groupId: _group.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Party reopened and moved to Active groups.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteExpense(SplitwiseExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${expense.description}" of ₹${_formatAmount(expense.amount)}?'),
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
        await SplitwiseService.instance.deleteExpense(
          userId: currentUser.id,
          groupId: _group.id,
          expenseId: expense.id,
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

    return StreamBuilder<List<SplitwiseGroupModel>>(
      stream: SplitwiseService.instance.streamGroups(currentUser.id),
      initialData: SplitwiseService.instance.getCachedGroups(currentUser.id),
      builder: (context, groupSnapshot) {
        final groups = groupSnapshot.data ?? [];
        final updatedGroup = groups.firstWhere(
          (g) => g.id == _group.id,
          orElse: () => _group,
        );
        _group = updatedGroup;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_group.name, style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700)),
                Text(
                  DateFormat('dd MMM yyyy').format(_group.date),
                  style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              if (!_group.isDone)
                IconButton(
                  tooltip: 'Add People',
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  onPressed: () => _showAddPeopleDialog(isInitial: false),
                ),
              if (!_group.isDone)
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
                  label: const Text('Done', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                  onPressed: _confirmMarkPartyDone,
                )
              else
                IconButton(
                  tooltip: 'Reopen Party',
                  icon: const Icon(Icons.restore_outlined, size: 20),
                  onPressed: _confirmReopenParty,
                ),
            ],
          ),
          body: StreamBuilder<List<SplitwiseExpenseModel>>(
            stream: SplitwiseService.instance.streamExpenses(currentUser.id, _group.id),
            initialData: SplitwiseService.instance.getCachedExpenses(_group.id),
            builder: (context, expenseSnapshot) {
              final expenses = expenseSnapshot.data ?? [];

              // Calculate net balances for each person
              final netBalances = SplitwiseService.instance.calculateNetBalances(
                members: _group.members,
                expenses: expenses,
              );

              final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);

              if (expenses.isNotEmpty && (_group.totalExpense - totalSpent).abs() > 0.001) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  SplitwiseService.instance.syncGroupTotal(
                    userId: currentUser.id,
                    groupId: _group.id,
                    total: totalSpent,
                  );
                });
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 90.0),
                children: [
                  // Top Summary Banner
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL PARTY EXPENSE',
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  '₹${_formatAmount(totalSpent)}',
                                  style: const TextStyle(
                                    fontSize: 28.0,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: _group.isDone ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Text(
                                _group.isDone ? 'COMPLETED' : 'ACTIVE PARTY',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700,
                                  color: _group.isDone ? const Color(0xFF475569) : const Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          '${_group.members.length} People Present: ${_group.members.join(", ")}',
                          style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12.0),

                  // Net Settlements Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Settlements',
                          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Green = Receive | Red = Give',
                          style: TextStyle(fontSize: 11.0, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _group.members.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, idx) {
                        final person = _group.members[idx];
                        final net = netBalances[person] ?? 0.0;
                        final isPositive = net > 0.01;
                        final isNegative = net < -0.01;

                        Color textColor;
                        String statusText;
                        if (isPositive) {
                          textColor = const Color(0xFF16A34A); // Green to receive
                          statusText = 'Gets back ₹${_formatAmount(net)}';
                        } else if (isNegative) {
                          textColor = const Color(0xFFDC2626); // Red to give
                          statusText = 'Owes ₹${_formatAmount(net.abs())}';
                        } else {
                          textColor = const Color(0xFF0F172A); // Black/settled
                          statusText = 'Settled (₹0)';
                        }

                        return InkWell(
                          onTap: _group.isDone ? null : () => _confirmRemovePerson(person, expenses),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isPositive
                                      ? const Color(0xFFDCFCE7)
                                      : (isNegative ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9)),
                                  child: Text(
                                    person.isNotEmpty ? person[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Text(
                                    person,
                                    style: const TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                if (!_group.isDone) ...[
                                  const SizedBox(width: 6.0),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                                    tooltip: 'Remove $person',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmRemovePerson(person, expenses),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18.0),

                  // Recent Expenses Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expenses Breakdown',
                          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          '${expenses.length} entries',
                          style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),

                  // Expenses List
                  if (expenses.isEmpty)
                    Container(
                      margin: const EdgeInsets.all(16.0),
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10.0),
                          const Text(
                            'No expenses added yet',
                            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            _group.isDone
                                ? 'No expenses recorded for this party.'
                                : 'Click "+ Add Expense" at the bottom right to record who paid and who was involved.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: expenses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8.0),
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8.0),
                            onTap: _group.isDone ? null : () => _showExpenseModal(expense: expense),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.receipt_outlined, size: 18, color: Colors.blue.shade700),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.description,
                                          style: const TextStyle(
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3.0),
                                        Text(
                                          'Paid by ${expense.paidBy} • For ${expense.involvedMembers.join(", ")}',
                                          style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(height: 2.0),
                                        Text(
                                          DateFormat('dd MMM yyyy').format(expense.date),
                                          style: TextStyle(fontSize: 11.0, color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${_formatAmount(expense.amount)}',
                                    style: const TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (!_group.isDone) ...[
                                    const SizedBox(width: 4.0),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                                      onPressed: () => _confirmDeleteExpense(expense),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          floatingActionButton: _group.isDone
              ? null
              : FloatingActionButton.extended(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  onPressed: () => _showExpenseModal(),
                ),
        );
      },
    );
  }
}
