import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../expense/expense_home_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _maxMembers = 2; // Default to 2 members, configurable up to 10
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newGroup = await GroupService.instance.createGroup(
        name: _nameController.text,
        userId: currentUser.id,
        userName: currentUser.name,
        maxMembers: _maxMembers,
      );

      if (mounted) {
        // Replace current screen with ExpenseHomeScreen for the new group
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ExpenseHomeScreen(group: newGroup),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Room'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Name your room',
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'An invite code will be automatically generated so other members can join.',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        margin: const EdgeInsets.only(bottom: 20.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6.0),
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

                    Text(
                      'Room Name',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Home Expenses, Apartment 4B',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name for the room';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24.0),

                    // Number of Members: Slider with - and + at both ends only
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Number of Members',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '$_maxMembers ${_maxMembers == 1 ? "member" : "members"}',
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'Choose how many people can join this room (max 10 members)',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Slider with - and + at both ends only
                    Row(
                      children: [
                        IconButton(
                          key: const Key('decrease_members_btn'),
                          tooltip: 'Decrease',
                          icon: const Icon(Icons.remove_circle_outline, size: 26),
                          color: _maxMembers > 1 ? const Color(0xFF0F172A) : Colors.grey.shade300,
                          onPressed: _maxMembers > 1
                              ? () => setState(() => _maxMembers--)
                              : null,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF0F172A),
                              inactiveTrackColor: Colors.grey.shade200,
                              thumbColor: const Color(0xFF0F172A),
                              overlayColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
                              valueIndicatorColor: const Color(0xFF0F172A),
                              trackHeight: 4.0,
                            ),
                            child: Slider(
                              key: const Key('members_slider'),
                              value: _maxMembers.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: '$_maxMembers',
                              onChanged: (val) {
                                setState(() => _maxMembers = val.round());
                              },
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('increase_members_btn'),
                          tooltip: 'Increase',
                          icon: const Icon(Icons.add_circle_outline, size: 26),
                          color: _maxMembers < 10 ? const Color(0xFF0F172A) : Colors.grey.shade300,
                          onPressed: _maxMembers < 10
                              ? () => setState(() => _maxMembers++)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32.0),

                    SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleCreateGroup,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create & Continue'),
                      ),
                    ),
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
