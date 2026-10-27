import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/group_model.dart';
import '../../models/month_model.dart';
import '../../models/transaction_model.dart';
import '../../services/expense_service.dart';
import '../../services/group_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/monthly_total.dart';
import '../../widgets/transaction_tile.dart';
import '../cash/cash_screen.dart';
import 'add_transaction_screen.dart';
import 'previous_months_screen.dart';

class ExpenseHomeScreen extends StatefulWidget {
  final GroupModel group;

  const ExpenseHomeScreen({super.key, required this.group});

  @override
  State<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends State<ExpenseHomeScreen> {
  MonthModel? _activeMonth;
  bool _isLoadingMonth = true;

  @override
  void initState() {
    super.initState();
    _loadActiveMonth();
    GroupService.instance.syncCurrentUserNameToGroup(widget.group.id);
  }

  Future<void> _loadActiveMonth() async {
    setState(() => _isLoadingMonth = true);
    final month = await ExpenseService.instance.getOrCreateActiveMonth(widget.group.id);
    if (mounted) {
      setState(() {
        _activeMonth = month;
        _isLoadingMonth = false;
      });
    }
  }

  Future<void> _confirmMarkListDone(BuildContext context, MonthModel month) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Done for this list?'),
        content: Text(
          'This will save "${month.displayTitle}" to Archived Lists with a final total of ${month.formattedTotal}.\n\nA fresh expense list will begin with a total of ₹0.',
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
            child: const Text('Confirm & Archive List'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoadingMonth = true);
      try {
        final nextList = await ExpenseService.instance.markListDone(
          groupId: widget.group.id,
          currentListId: month.id,
        );
        if (mounted) {
          setState(() {
            _activeMonth = nextList;
            _isLoadingMonth = false;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text('"${month.displayTitle}" saved to archive. Fresh list started!'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingMonth = false);
          messenger.showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showRenameListDialog(BuildContext context, MonthModel month) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: month.displayTitle);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Expense List'),
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

    if (newName != null && newName.isNotEmpty && mounted) {
      await ExpenseService.instance.renameList(
        groupId: widget.group.id,
        listId: month.id,
        newName: newName,
      );
      if (mounted) {
        setState(() {
          if (_activeMonth != null && _activeMonth!.id == month.id) {
            _activeMonth = _activeMonth!.copyWith(name: newName);
          }
        });
        messenger.showSnackBar(
          SnackBar(content: Text('List renamed to "$newName"')),
        );
      }
    }
  }

  Future<void> _confirmDeleteRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text(
          'Are you sure you want to permanently delete "${widget.group.name}" and all its expense lists, entries, and cash records? This action cannot be undone.',
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
            child: const Text('Delete Room'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      try {
        await GroupService.instance.deleteGroup(widget.group.id);
        messenger.showSnackBar(
          SnackBar(content: Text('Room "${widget.group.name}" deleted.')),
        );
        navigator.pop(); // Return to rooms list screen
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error deleting room: $e')),
        );
      }
    }
  }

  void _showGroupDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.group.name,
                        style: const TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),

                // Members List Section
                Text(
                  'ROOM MEMBERS',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8.0),
                FutureBuilder<List<String>>(
                  future: GroupService.instance.getGroupMemberNames(widget.group.id, widget.group.members),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                      );
                    }
                    final names = snapshot.data ?? [];
                    if (names.isEmpty) {
                      return Text(
                        '${widget.group.members.length}/${widget.group.maxMembers} members connected',
                        style: TextStyle(fontSize: 13.0, color: Colors.grey.shade700),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${names.length}/${widget.group.maxMembers} members connected',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: names.map((name) {
                            final isYou = name.contains('(You)');
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                              decoration: BoxDecoration(
                                color: isYou ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20.0),
                                border: Border.all(
                                  color: isYou ? const Color(0xFF0F172A) : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: isYou ? Colors.white : const Color(0xFF0F172A),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isYou ? const Color(0xFF0F172A) : Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                      color: isYou ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20.0),

                // Invite code box
                Container(
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INVITE CODE',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            widget.group.inviteCode,
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invite code "${widget.group.inviteCode}" copied!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
                const Divider(),
                const SizedBox(height: 12.0),
                // Delete Room Option
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text(
                      'DELETE ROOM',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close details modal first
                      _confirmDeleteRoom();
                    },
                  ),
                ),
                const SizedBox(height: 12.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            tooltip: 'Cash',
            icon: const Icon(Icons.payments_outlined, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CashScreen(group: widget.group),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Archived Lists',
            icon: const Icon(Icons.history_rounded, size: 22),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PreviousMonthsScreen(group: widget.group),
                ),
              );
              if (mounted) {
                _loadActiveMonth();
              }
            },
          ),
          IconButton(
            tooltip: 'Group Details & Invite Code',
            icon: const Icon(Icons.info_outline, size: 22),
            onPressed: _showGroupDetails,
          ),
        ],
      ),
      body: _isLoadingMonth
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<MonthModel?>(
              stream: ExpenseService.instance.streamActiveMonth(widget.group.id),
              initialData: _activeMonth,
              builder: (context, monthSnapshot) {
                final month = monthSnapshot.data ?? _activeMonth;
                if (month == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<TransactionModel>>(
                  stream: ExpenseService.instance.streamTransactions(
                    widget.group.id,
                    month.id,
                  ),
                  initialData: const [],
                  builder: (context, txSnapshot) {
                    final transactions = txSnapshot.data ?? [];
                    double liveTotal = 0.0;
                    for (final tx in transactions) {
                      if (tx.isExpense) {
                        liveTotal += tx.amount;
                      } else {
                        liveTotal -= tx.amount;
                      }
                    }

                    final formattedLiveTotal = transactions.isNotEmpty
                        ? '₹${liveTotal.toStringAsFixed(liveTotal.truncateToDouble() == liveTotal ? 0 : 2)}'
                        : month.formattedTotal;

                    // Auto-heal month.total if out of sync
                    if (transactions.isNotEmpty && (month.total - liveTotal).abs() > 0.001) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ExpenseService.instance.syncMonthTotal(
                          groupId: widget.group.id,
                          monthId: month.id,
                          total: liveTotal,
                        );
                      });
                    }

                    return Column(
                      children: [
                        // Large List Total Display at Top (Tap to Rename)
                        MonthlyTotal(
                          monthTitle: month.displayTitle,
                          formattedTotal: formattedLiveTotal,
                          subtitle: 'TOTAL',
                          onTitleTap: () => _showRenameListDialog(context, month),
                        ),

                        // Transactions Stream grouped by date
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              if (txSnapshot.connectionState == ConnectionState.waiting &&
                                  !txSnapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final transactions = txSnapshot.data ?? [];

                          if (transactions.isEmpty) {
                            return const EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                              subtitle:
                                  'Tap [+ ADD] below to record an expense or withdrawal for this list.',
                            );
                          }

                          // Group transactions by dateGroupKey (e.g. "26 Oct")
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
                                  // Date Header (e.g. "26 Oct")
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
                                  // Transactions under this date
                                  ...txList.map(
                                    (tx) => TransactionTile(
                                      transaction: tx,
                                      onEdit: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => AddTransactionScreen(
                                              groupId: widget.group.id,
                                              monthId: month.id,
                                              transaction: tx,
                                            ),
                                          ),
                                        );
                                      },
                                      onDelete: () {
                                        ExpenseService.instance.deleteTransaction(
                                          groupId: widget.group.id,
                                          monthId: month.id,
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

                    // Prominent Bottom Buttons: [+ ADD] and [DONE FOR THIS LIST]
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            // [+ ADD] button
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 48),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionScreen(
                                        groupId: widget.group.id,
                                        monthId: month.id,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  '+ ADD',
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            // [DONE FOR THIS LIST] button
                            Expanded(
                              flex: 4,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(
                                    color: Color(0xFF0F172A),
                                    width: 1.5,
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () => _confirmMarkListDone(context, month),
                                child: const Text(
                                  'DONE FOR THIS LIST',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
    );
  }
}
