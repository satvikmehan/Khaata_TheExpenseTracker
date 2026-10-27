import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/splitwise_model.dart';
import '../../services/auth_service.dart';
import '../../services/splitwise_service.dart';
import 'splitwise_group_screen.dart';

class SplitwiseHomeScreen extends StatefulWidget {
  const SplitwiseHomeScreen({super.key});

  @override
  State<SplitwiseHomeScreen> createState() => _SplitwiseHomeScreenState();
}

class _SplitwiseHomeScreenState extends State<SplitwiseHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    final absAmt = amount.abs();
    return absAmt.truncateToDouble() == absAmt
        ? absAmt.toInt().toString()
        : absAmt.toStringAsFixed(2);
  }

  Future<void> _showCreateGroupDialog() async {
    final nameController = TextEditingController();
    final memberController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final List<String> members = [];

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
                        const Text(
                          'New Splitwise Group',
                          style: TextStyle(
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
                    const SizedBox(height: 12.0),

                    // Group Name Input
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Group / Party Name *',
                        hintText: 'e.g. Goa Trip, Dinner, Office Party',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                    ),
                    const SizedBox(height: 14.0),

                    // Date selector (defaults to today)
                    const Text(
                      'Date (Default: Today)',
                      style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6.0),
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
                              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
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
                    const SizedBox(height: 14.0),

                    // People present input
                    const Text(
                      'People Present in this Party:',
                      style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: memberController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Enter name (e.g. Rahul)',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                            ),
                            onSubmitted: (val) {
                              final trimmed = val.trim();
                              if (trimmed.isNotEmpty && !members.contains(trimmed)) {
                                setModalState(() {
                                  members.add(trimmed);
                                  memberController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () {
                            final trimmed = memberController.text.trim();
                            if (trimmed.isNotEmpty && !members.contains(trimmed)) {
                              setModalState(() {
                                members.add(trimmed);
                                memberController.clear();
                              });
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (members.isNotEmpty) ...[
                      const SizedBox(height: 10.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: members.map((m) {
                          return Chip(
                            label: Text(m),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setModalState(() {
                                members.remove(m);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20.0),

                    // Create Button
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
                          final groupName = nameController.text.trim();
                          if (groupName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a group name')),
                            );
                            return;
                          }

                          // Include pending member in text field if any
                          final pendingMem = memberController.text.trim();
                          if (pendingMem.isNotEmpty && !members.contains(pendingMem)) {
                            members.add(pendingMem);
                          }

                          final currentUser = AuthService.instance.currentUser;
                          if (currentUser == null) return;

                          Navigator.pop(ctx);

                          final created = await SplitwiseService.instance.createGroup(
                            userId: currentUser.id,
                            name: groupName,
                            date: selectedDate,
                            members: members,
                          );

                          if (mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SplitwiseGroupScreen(group: created),
                              ),
                            );
                          }
                        },
                        child: const Text('Create Group', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
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

  Future<void> _confirmDeleteGroup(SplitwiseGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${group.name}?'),
        content: const Text('This will delete this party and all associated expenses permanently.'),
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

  Widget _buildGroupCard(SplitwiseGroupModel group) {
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
                      color: group.isDone ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      group.isDone ? 'COMPLETED' : 'ACTIVE',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        color: group.isDone ? const Color(0xFF475569) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                    onPressed: () => _confirmDeleteGroup(group),
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

  Widget _buildGroupList(List<SplitwiseGroupModel> groups, {required bool isHistory}) {
    if (groups.isEmpty) {
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
                  color: isHistory ? Colors.grey.shade100 : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHistory ? Icons.history_outlined : Icons.call_split_rounded,
                  size: 34,
                  color: isHistory ? Colors.grey.shade500 : Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                isHistory ? 'No Completed Parties Yet' : 'No Active Splitwise Groups',
                style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8.0),
              Text(
                isHistory
                    ? 'When a party is finished, click "Done" inside the group to store it in History.'
                    : 'Create a Splitwise group for a party, trip, or dinner to split expenses effortlessly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.0, color: Colors.grey.shade600),
              ),
              if (!isHistory) ...[
                const SizedBox(height: 20.0),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Splitwise Group'),
                  onPressed: _showCreateGroupDialog,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12.0),
      itemBuilder: (context, index) {
        return _buildGroupCard(groups[index]);
      },
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
        title: const Text('Splitwise'),
        actions: [
          IconButton(
            tooltip: 'New Group',
            icon: const Icon(Icons.group_add_outlined, size: 22),
            onPressed: _showCreateGroupDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: const Color(0xFF0F172A),
          tabs: const [
            Tab(text: 'Active Parties'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder<List<SplitwiseGroupModel>>(
        stream: SplitwiseService.instance.streamGroups(currentUser.id),
        initialData: SplitwiseService.instance.getCachedGroups(currentUser.id),
        builder: (context, snapshot) {
          final allGroups = snapshot.data ?? [];
          final activeGroups = allGroups.where((g) => !g.isDone).toList();
          final historyGroups = allGroups.where((g) => g.isDone).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildGroupList(activeGroups, isHistory: false),
              _buildGroupList(historyGroups, isHistory: true),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        onPressed: _showCreateGroupDialog,
      ),
    );
  }
}
