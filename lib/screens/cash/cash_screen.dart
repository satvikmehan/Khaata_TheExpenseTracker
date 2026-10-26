import 'package:flutter/material.dart';
import '../../models/group_model.dart';
import 'cash_tab.dart';

class CashScreen extends StatelessWidget {
  final GroupModel group;

  const CashScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cash'),
      ),
      body: CashTab(group: group),
    );
  }
}
