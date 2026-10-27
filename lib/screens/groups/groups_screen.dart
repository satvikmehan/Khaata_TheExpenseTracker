import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../widgets/empty_state.dart';
import '../expense/expense_home_screen.dart';
import 'create_group_screen.dart';
import 'join_group_screen.dart';
import '../udhaar/udhaar_screen.dart';

import '../../widgets/longer_hold_drag_start_listener.dart';
export '../../widgets/longer_hold_drag_start_listener.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupModel>? _localGroups;
  String? _lastFingerprint;
  bool _hasPromptedName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewUserName();
    });
  }

  bool _isNewUserWithoutName(UserModel user) {
    final cleanName = user.name.trim();
    final cleanPhone = user.phoneNumber.trim();
    if (cleanName.isEmpty) return true;
    if (cleanName == 'User') return true;
    if (cleanPhone.isNotEmpty && cleanName == cleanPhone) return true;
    if (cleanName.startsWith('+')) return true;
    if (RegExp(r'^\+?[0-9\s\-]+$').hasMatch(cleanName)) return true;
    return false;
  }

  void _checkNewUserName() {
    if (!mounted || _hasPromptedName) return;
    final user = AuthService.instance.currentUser;
    if (user != null && _isNewUserWithoutName(user)) {
      _hasPromptedName = true;
      _showWelcomeNameDialog(context, user);
    }
  }

  Future<void> _showWelcomeNameDialog(BuildContext context, UserModel user) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final enteredName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Welcome to Khaata!',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please enter your name so other room members know who you are:',
                style: TextStyle(fontSize: 13.0, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                key: const Key('new_user_name_input'),
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'e.g. Alex',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (enteredName != null && enteredName.trim().isNotEmpty) {
      await AuthService.instance.updateUserName(enteredName.trim());
    }
  }

  Future<void> _showEditNameDialog(BuildContext context, UserModel currentUser) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: currentUser.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              hintText: 'Enter your name',
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

    if (newName != null && newName.isNotEmpty) {
      await AuthService.instance.updateUserName(newName);
      messenger.showSnackBar(
        SnackBar(content: Text('Name updated to "$newName"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, userSnapshot) {
        final currentUser = userSnapshot.data ?? AuthService.instance.currentUser;
        if (currentUser == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Khaata'),
            actions: [
              IconButton(
                tooltip: 'Udhaar',
                icon: const Icon(Icons.menu_book_rounded, size: 21),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UdhaarScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Log Out',
                icon: const Icon(Icons.logout_outlined, size: 20),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log Out'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AuthService.instance.logOut();
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // User greeting banner (aligned, click to edit name, no phone or email)
                InkWell(
                  onTap: () => _showEditNameDialog(context, currentUser),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                    color: Colors.white,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            currentUser.name.isNotEmpty
                                ? currentUser.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.0,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14.0),
                        Expanded(
                          child: Text(
                            currentUser.name.isNotEmpty ? currentUser.name : 'User',
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

            // Groups List
            Expanded(
              child: StreamBuilder<List<GroupModel>>(
                initialData: GroupService.instance.getCachedUserGroups(currentUser.id),
                stream: GroupService.instance.streamUserGroups(currentUser.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final streamGroups = snapshot.data ?? [];

                  if (streamGroups.isEmpty) {
                    _localGroups = null;
                    _lastFingerprint = null;
                    return const EmptyState(
                      icon: Icons.group_outlined,
                      title: 'No shared groups yet',
                      subtitle:
                          'Create a group to track expenses with your partner,\nor enter a 6-character code to join an existing group.',
                    );
                  }

                  final savedOrder = GroupService.instance.getCachedUserGroupOrder(currentUser.id);

                  // Check if the stream groups changed (added, removed, or properties updated)
                  final currentFingerprint = streamGroups
                      .map((g) => '${g.id}:${g.name}:${g.members.length}:${g.maxMembers}')
                      .join('|');

                  if (_localGroups == null || _localGroups!.isEmpty) {
                    _lastFingerprint = currentFingerprint;
                    _localGroups = GroupService.instance.sortGroupsByOrder(streamGroups, savedOrder);
                  } else if (_lastFingerprint != currentFingerprint) {
                    _lastFingerprint = currentFingerprint;
                    final currentLocalOrder = _localGroups!.map((g) => g.id).toList();
                    _localGroups = GroupService.instance.sortGroupsByOrder(streamGroups, currentLocalOrder);
                  }

                  final displayGroups = _localGroups ?? streamGroups;

                  return Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.transparent,
                    ),
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: displayGroups.length,
                      buildDefaultDragHandles: false,
                      proxyDecorator: (Widget child, int index, Animation<double> animation) {
                        return Material(
                          elevation: 6.0,
                          color: Colors.transparent,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(4.0),
                          child: child,
                        );
                      },
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = _localGroups!.removeAt(oldIndex);
                          _localGroups!.insert(newIndex, item);
                        });
                        final orderedIds = _localGroups!.map((g) => g.id).toList();
                        GroupService.instance.saveUserGroupOrder(currentUser.id, orderedIds);
                      },
                      itemBuilder: (context, index) {
                        final group = displayGroups[index];
                        return LongerHoldDragStartListener(
                          key: ValueKey(group.id),
                          index: index,
                          delay: const Duration(milliseconds: 1000),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildGroupCard(context, group),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Bottom Actions: Create Group / Join Group
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text('Join Group'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JoinGroupScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Group'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
}

  Widget _buildGroupCard(BuildContext context, GroupModel group) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExpenseHomeScreen(group: group),
          ),
        );
      },
      borderRadius: BorderRadius.circular(4.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 17.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: group.isFull
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    '${group.members.length}/${group.maxMembers} members',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: group.isFull
                          ? const Color(0xFF475569)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 20.0,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Text(
                  'Invite Code: ',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  group.inviteCode,
                  style: const TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8.0),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: group.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invite code "${group.inviteCode}" copied!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14.0,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Open Tracker →',
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
