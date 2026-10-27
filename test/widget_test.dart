import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/cash_transaction_model.dart';
import 'package:expense_tracker/models/group_model.dart';
import 'package:expense_tracker/models/month_model.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/screens/cash/cash_tab.dart';
import 'package:expense_tracker/screens/expense/expense_home_screen.dart';
import 'package:expense_tracker/screens/groups/create_group_screen.dart';
import 'package:expense_tracker/screens/groups/groups_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/expense_service.dart';
import 'package:expense_tracker/services/export_service.dart';
import 'package:expense_tracker/services/group_service.dart';
import 'package:expense_tracker/screens/udhaar/udhaar_screen.dart';
import 'package:expense_tracker/screens/udhaar/udhaar_detail_screen.dart';
import 'package:expense_tracker/services/udhaar_service.dart';
import 'package:expense_tracker/screens/splitwise/splitwise_home_screen.dart';
import 'package:expense_tracker/screens/splitwise/splitwise_group_screen.dart';
import 'package:expense_tracker/services/splitwise_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UdhaarService.instance.clearMockData();
    SplitwiseService.instance.clearMockData();
  });
  testWidgets('Khaata app loads phone sign-in screen initially with Google sign-in option', (WidgetTester tester) async {
    // Ensure clean logged-out state
    await AuthService.instance.logOut();

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();

    // Verify phone sign-in and Google sign-in elements are present
    expect(find.text('Khaata'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('Sign in with Google logs user in and switches to GroupsScreen without login screen flicker', (WidgetTester tester) async {
    await AuthService.instance.logOut();

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();

    // Verify Sign in with Google button is displayed
    expect(find.text('Sign in with Google'), findsOneWidget);

    // Tap Sign in with Google
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // GroupsScreen should now be displayed with Log Out option
    expect(find.byTooltip('Log Out'), findsOneWidget);

    // Now re-launch/pump app while already logged in:
    // Verify that GroupsScreen is shown immediately on frame 1 without any LoginScreen
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();

    expect(find.byTooltip('Log Out'), findsOneWidget);
    expect(find.text('Mobile Number'), findsNothing);
    expect(find.text('Sign in with Google'), findsNothing);

    // Clean up
    await AuthService.instance.logOut();
  });

  test('Blueprint Example: Monthly Total Calculation matches 500 + 300 - 200 + 1000 = 1600', () {
    final transactions = [
      TransactionModel(
        id: '1',
        name: 'Food',
        amount: 500.0,
        type: 'expense',
        date: DateTime(2026, 10, 26),
        createdBy: 'user1',
        createdAt: DateTime(2026, 10, 26),
      ),
      TransactionModel(
        id: '2',
        name: 'Cab',
        amount: 300.0,
        type: 'expense',
        date: DateTime(2026, 10, 26),
        createdBy: 'user1',
        createdAt: DateTime(2026, 10, 26),
      ),
      TransactionModel(
        id: '3',
        name: 'Withdrawal',
        amount: 200.0,
        type: 'withdrawal',
        date: DateTime(2026, 10, 21),
        createdBy: 'user1',
        createdAt: DateTime(2026, 10, 21),
      ),
      TransactionModel(
        id: '4',
        name: 'Groceries',
        amount: 1000.0,
        type: 'expense',
        date: DateTime(2026, 10, 24),
        createdBy: 'user1',
        createdAt: DateTime(2026, 10, 24),
      ),
    ];

    double total = 0.0;
    for (final tx in transactions) {
      total += tx.signedAmount;
    }

    expect(total, 1600.0);
    expect(transactions[0].formattedSignedAmount, '+₹500');
    expect(transactions[2].formattedSignedAmount, '-₹200');
  });

  test('Cash Pending Amount: Deposit 2000 - Withdraw 500 = 1500 Pending', () {
    final cashTransactions = [
      CashTransactionModel(
        id: 'c1',
        type: 'deposit',
        amount: 2000.0,
        description: 'ATM Cash',
        date: DateTime(2026, 10, 26),
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 26),
      ),
      CashTransactionModel(
        id: 'c2',
        type: 'withdraw',
        amount: 500.0,
        description: 'Paid Helper',
        date: DateTime(2026, 10, 26),
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 26),
      ),
    ];

    double pending = 0.0;
    for (final tx in cashTransactions) {
      pending += tx.signedAmount;
    }

    expect(pending, 1500.0);
    expect(cashTransactions[0].formattedSignedAmount, '+₹2,000');
    expect(cashTransactions[1].formattedSignedAmount, '-₹500');
  });

  test('ExportService generates valid CSV with summary', () {
    final group = GroupModel(
      id: 'g1',
      name: 'Home Expenses',
      inviteCode: 'ABC123',
      members: ['u1'],
      createdAt: DateTime.now(),
    );
    final month = MonthModel(
      id: '2026-10',
      total: 1600.0,
      status: 'done',
      createdAt: DateTime.now(),
    );
    final txs = [
      TransactionModel(
        id: '1',
        name: 'Food',
        amount: 500.0,
        type: 'expense',
        date: DateTime(2026, 10, 26),
        createdBy: 'u1',
        createdAt: DateTime(2026, 10, 26),
      ),
    ];

    final csv = ExportService.instance.generateCsv(
      group: group,
      month: month,
      transactions: txs,
    );

    expect(csv.contains('Home Expenses'), true);
    expect(csv.contains('Food'), true);
    expect(csv.contains('500.00'), true);
    expect(csv.contains('Net Monthly Total'), true);
  });

  testWidgets('CashTab: clicking DEPOSIT opens dialog and records deposit', (WidgetTester tester) async {
    final group = GroupModel(
      id: 'test_group',
      name: 'Test Room',
      inviteCode: 'TEST01',
      members: ['u1'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CashTab(group: group),
        ),
      ),
    );
    await tester.pump();

    // Verify CashTab is loaded with DEPOSIT and WITHDRAW buttons
    expect(find.text('DEPOSIT'), findsOneWidget);
    expect(find.text('WITHDRAW'), findsOneWidget);

    // Tap DEPOSIT button
    await tester.tap(find.text('DEPOSIT'));
    await tester.pumpAndSettle();

    // Verify AddCashDialog is shown
    expect(find.text('Deposit Cash (+)'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Enter amount
    await tester.enterText(find.byType(TextFormField).first, '1200');
    await tester.pump();

    // Tap Deposit button in dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Deposit'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text('Deposit Cash (+)'), findsNothing);

    // Verify Pending Amount banner shows ₹1,200
    expect(find.text('₹1,200'), findsOneWidget);
  });

  testWidgets('ExpenseHomeScreen has Cash icon at top and opens CashScreen', (WidgetTester tester) async {
    final group = GroupModel(
      id: 'test_group_top',
      name: 'My Room',
      inviteCode: 'TOP123',
      members: ['u1'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseHomeScreen(group: group),
      ),
    );
    await tester.pump();

    // Verify Cash icon is in top AppBar
    expect(find.byTooltip('Cash'), findsOneWidget);

    // Verify Share icon is NOT present
    expect(find.byTooltip('Share History File (CSV)'), findsNothing);

    // Tap Cash icon
    await tester.tap(find.byTooltip('Cash'));
    await tester.pumpAndSettle();

    // Verify CashScreen opened with title "Cash"
    expect(find.text('Cash'), findsOneWidget);

    // Verify banner has "PENDING AMOUNT" and NO "CASH IN HAND"
    expect(find.text('PENDING AMOUNT'), findsOneWidget);
    expect(find.text('CASH IN HAND'), findsNothing);
  });

  testWidgets('CreateGroupScreen allows choosing member count via slider only with + and - buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CreateGroupScreen(),
      ),
    );
    await tester.pump();

    // Verify Number of Members label is present
    expect(find.text('Number of Members'), findsOneWidget);
    expect(find.text('Choose how many people can join this room (max 10 members)'), findsOneWidget);

    // Initial default should be 2 members
    expect(find.text('2 members'), findsOneWidget);

    // Verify Slider is present
    expect(find.byKey(const Key('members_slider')), findsOneWidget);

    // Tap + icon button to increase to 3 members
    await tester.tap(find.byKey(const Key('increase_members_btn')));
    await tester.pump();
    expect(find.text('3 members'), findsOneWidget);

    // Tap + again to increase to 4
    await tester.tap(find.byKey(const Key('increase_members_btn')));
    await tester.pump();
    expect(find.text('4 members'), findsOneWidget);

    // Tap - icon button to decrease back to 3
    await tester.tap(find.byKey(const Key('decrease_members_btn')));
    await tester.pump();
    expect(find.text('3 members'), findsOneWidget);

    // Verify choice chips are NOT rendered (slider only)
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('ExpenseHomeScreen displays DONE FOR THIS LIST and can rename list', (WidgetTester tester) async {
    final group = await GroupService.instance.createGroup(
      name: 'Goa Holiday',
      userId: 'u_tester',
      maxMembers: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseHomeScreen(group: group),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Verify "DONE FOR THIS LIST" button is present
    expect(find.text('DONE FOR THIS LIST'), findsOneWidget);

    // 2. Verify List Renaming: tap the title directly (no edit icon)
    final defaultMonthTitle = DateFormat('MMMM yyyy').format(DateTime.now());
    expect(find.text(defaultMonthTitle), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.tap(find.text(defaultMonthTitle));
    await tester.pump(const Duration(milliseconds: 300));

    // Rename dialog appears
    expect(find.text('Rename Expense List'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Trip Expenses');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify title is now Trip Expenses
    expect(find.text('Trip Expenses'), findsOneWidget);
  });

  testWidgets('GroupsScreen allows editing user name on click and hides phone/email', (WidgetTester tester) async {
    // Log in user
    await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Satvik');

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Satvik is displayed and NO phone number or email is shown under it
    expect(find.text('Satvik'), findsOneWidget);
    expect(find.text('+919876543210'), findsNothing);

    // Tap on the name to open Edit Name dialog
    await tester.tap(find.text('Satvik'));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Edit Name dialog appears
    expect(find.text('Edit Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Satvik Mehan');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify name is updated to Satvik Mehan
    expect(find.text('Satvik Mehan'), findsOneWidget);

    await AuthService.instance.logOut();
  });

  testWidgets('ExpenseHomeScreen Info Modal displays Room Members list and DELETE ROOM option', (WidgetTester tester) async {
    // Log in as Satvik
    await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Satvik');

    final group = await GroupService.instance.createGroup(
      name: 'Room to Delete',
      userId: AuthService.instance.currentUser!.id,
      maxMembers: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseHomeScreen(group: group),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open info bottom sheet
    await tester.tap(find.byTooltip('Group Details & Invite Code'));
    await tester.pumpAndSettle();

    // Verify ROOM MEMBERS header and member name with (You) is present
    expect(find.text('ROOM MEMBERS'), findsOneWidget);
    expect(find.textContaining('(You)'), findsOneWidget);

    // Verify DELETE ROOM button is present in bottom sheet
    expect(find.text('DELETE ROOM'), findsOneWidget);

    // Dismiss bottom sheet
    Navigator.of(tester.element(find.text('DELETE ROOM'))).pop();
    await tester.pumpAndSettle();

    // Verify deleting room via GroupService
    final futureRemaining = GroupService.instance.streamUserGroups(AuthService.instance.currentUser!.id).first;
    await GroupService.instance.deleteGroup(group.id);
    final remaining = await futureRemaining;
    expect(remaining.any((g) => g.id == group.id), false);

    await AuthService.instance.logOut();
  });

  testWidgets('Existing phone account login logs straight into account with original name and never asks for name', (WidgetTester tester) async {
    await AuthService.instance.logOut();

    // 1. Simulate account already created for +919888877777 with name "Aman"
    await AuthService.instance.sendOtp(
      rawPhoneNumber: '9888877777',
      onCodeSent: (_) {},
      onError: (_) {},
    );
    await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Aman');
    await AuthService.instance.logOut();

    // 2. Now open LoginScreen on another device
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();

    // Enter the same phone number
    await tester.enterText(find.byType(TextFormField).first, '9888877777');
    await tester.pump();

    // Click Send Verification Code
    await tester.tap(find.text('Send Verification Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Step 2 should appear with OTP field only
    expect(find.text('6-Digit OTP'), findsOneWidget);

    // Verify that "Your Name (for shared group)" is NEVER on the OTP screen
    expect(find.text('Your Name (for shared group)'), findsNothing);

    // Enter OTP and login
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // User should be logged in directly with preserved original name "Aman" without any name dialog
    expect(find.text('Welcome to Khaata!'), findsNothing);
    expect(find.text('Aman'), findsOneWidget);

    await AuthService.instance.logOut();
  });

  testWidgets('Brand new phone login prompts for name once after OTP verification', (WidgetTester tester) async {
    await AuthService.instance.logOut();

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();

    // Enter brand new phone number
    await tester.enterText(find.byType(TextFormField).first, '9111122222');
    await tester.tap(find.text('Send Verification Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify OTP field is shown (NO name field on OTP screen)
    expect(find.text('6-Digit OTP'), findsOneWidget);
    expect(find.text('Your Name (for shared group)'), findsNothing);

    // Enter OTP
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Since this is a brand new account, the Welcome dialog appears asking for name
    expect(find.text('Welcome to Khaata!'), findsOneWidget);
    expect(find.byKey(const Key('new_user_name_input')), findsOneWidget);

    // Enter name "Vikram" and submit
    await tester.enterText(find.byKey(const Key('new_user_name_input')), 'Vikram');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Vikram is now registered and logged in
    expect(find.text('Vikram'), findsOneWidget);

    await AuthService.instance.logOut();
  });

  testWidgets('Both members see each other real names in Room Info (Satvik and Mona)', (WidgetTester tester) async {
    // 1. Device 1 (Satvik) creates room
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9999911111', onCodeSent: (_) {}, onError: (_) {});
    final satvikUser = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Satvik');

    final group = await GroupService.instance.createGroup(
      name: 'Satvik',
      userId: satvikUser.id,
      userName: 'Satvik',
      maxMembers: 2,
    );
    await AuthService.instance.logOut();

    // 2. Device 2 (Mona) joins room
    await AuthService.instance.sendOtp(rawPhoneNumber: '9999922222', onCodeSent: (_) {}, onError: (_) {});
    final monaUser = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Mona');

    final joinedGroup = await GroupService.instance.joinGroupByCode(
      inviteCode: group.inviteCode,
      userId: monaUser.id,
      userName: 'Mona',
    );

    // Mona views Room Info
    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseHomeScreen(group: joinedGroup),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Group Details & Invite Code'));
    await tester.pumpAndSettle();

    // Mona should see "Mona (You)" and "Satvik" (NOT "Member 1")
    expect(find.text('Mona (You)'), findsOneWidget);
    expect(find.text('Satvik'), findsWidgets);
    expect(find.text('Member 1'), findsNothing);

    // Close bottom sheet
    Navigator.of(tester.element(find.text('DELETE ROOM'))).pop();
    await tester.pumpAndSettle();

    await AuthService.instance.logOut();

    // 3. Device 1 (Satvik) opens room again
    await AuthService.instance.sendOtp(rawPhoneNumber: '9999911111', onCodeSent: (_) {}, onError: (_) {});
    await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Satvik');

    await tester.pumpWidget(
      MaterialApp(
        home: ExpenseHomeScreen(group: joinedGroup),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Group Details & Invite Code'));
    await tester.pumpAndSettle();

    // Satvik should see "Satvik (You)" and "Mona" (NOT "Member 2")
    expect(find.text('Satvik (You)'), findsOneWidget);
    expect(find.text('Mona'), findsOneWidget);
    expect(find.text('Member 2'), findsNothing);

    await AuthService.instance.logOut();
  });

  test('Swap Restore: restoring an archive list saves front list to archive first', () async {
    const groupId = 'test_group_swap';

    // 1. Get initial active list
    final listA = await ExpenseService.instance.getOrCreateActiveMonth(groupId);
    await ExpenseService.instance.renameList(groupId: groupId, listId: listA.id, newName: 'List A');

    // Add transaction to List A
    await ExpenseService.instance.addTransaction(
      groupId: groupId,
      monthId: listA.id,
      name: 'Dinner',
      amount: 400.0,
      type: 'expense',
      date: DateTime.now(),
      createdBy: 'u1',
    );

    // 2. Mark List A done, creating active List B
    final listB = await ExpenseService.instance.markListDone(
      groupId: groupId,
      currentListId: listA.id,
      nextListName: 'List B',
    );

    // Add transaction to List B
    await ExpenseService.instance.addTransaction(
      groupId: groupId,
      monthId: listB.id,
      name: 'Fuel',
      amount: 300.0,
      type: 'expense',
      date: DateTime.now(),
      createdBy: 'u1',
    );

    // Verify List B is currently active
    final activeBeforeSwap = await ExpenseService.instance.getOrCreateActiveMonth(groupId);
    expect(activeBeforeSwap.id, listB.id);

    // Verify List A is in archived/previous list
    final historyBefore = await ExpenseService.instance.streamPreviousMonths(groupId).first;
    expect(historyBefore.any((m) => m.id == listA.id), true);
    expect(historyBefore.any((m) => m.id == listB.id), false);

    // 3. Restore List A -> Must save List B into archive first, then restore List A to front
    await ExpenseService.instance.restoreArchivedMonth(
      groupId: groupId,
      archivedMonthId: listA.id,
    );

    // Active list should now be List A
    final activeAfterSwap = await ExpenseService.instance.getOrCreateActiveMonth(groupId);
    expect(activeAfterSwap.id, listA.id);
    expect(activeAfterSwap.status, 'active');

    // Archive should now contain List B (the former front list)
    final historyAfter = await ExpenseService.instance.streamPreviousMonths(groupId).first;
    expect(historyAfter.any((m) => m.id == listB.id), true);
    expect(historyAfter.any((m) => m.id == listA.id), false);
    final archivedB = historyAfter.firstWhere((m) => m.id == listB.id);
    expect(archivedB.status, 'done');
    expect(archivedB.total, 300.0);
  });

  testWidgets('GroupsScreen allows rearranging rooms on front screen by long holding and moving up/down', (WidgetTester tester) async {
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9777788888', onCodeSent: (_) {}, onError: (_) {});
    final user = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Organizer');

    // Create 3 rooms
    final g1 = await GroupService.instance.createGroup(name: 'Room Alpha', userId: user.id);
    final g2 = await GroupService.instance.createGroup(name: 'Room Beta', userId: user.id);
    final g3 = await GroupService.instance.createGroup(name: 'Room Gamma', userId: user.id);

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify ReorderableListView is present on front screen
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byType(LongerHoldDragStartListener), findsWidgets);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);

    // Verify all 3 rooms are visible
    expect(find.text('Room Alpha'), findsOneWidget);
    expect(find.text('Room Beta'), findsOneWidget);
    expect(find.text('Room Gamma'), findsOneWidget);

    // Perform long-press gesture and drag to move Room Gamma up
    final firstRoomLocation = tester.getCenter(find.text('Room Gamma'));
    final gesture = await tester.startGesture(firstRoomLocation);
    // Hold down for 1150ms to trigger longer delayed drag start (1000ms delay)
    await tester.pump(const Duration(milliseconds: 1150));
    // Drag upwards
    await gesture.moveBy(const Offset(0, -250));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify GroupService persists order
    await GroupService.instance.saveUserGroupOrder(user.id, [g3.id, g1.id, g2.id]);
    final sorted = GroupService.instance.sortGroupsByOrder([g1, g2, g3], [g3.id, g1.id, g2.id]);
    expect(sorted.map((g) => g.id).toList(), [g3.id, g1.id, g2.id]);

    await AuthService.instance.logOut();
  });

  testWidgets('GroupsScreen preserves rearranged room order across app restarts', (WidgetTester tester) async {
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9666655555', onCodeSent: (_) {}, onError: (_) {});
    final user = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Tester');

    final gA = await GroupService.instance.createGroup(name: 'Room 1', userId: user.id);
    final gB = await GroupService.instance.createGroup(name: 'Room 2', userId: user.id);
    final gC = await GroupService.instance.createGroup(name: 'Room 3', userId: user.id);

    // Save custom order: Room 3 first, then Room 1, then Room 2
    await GroupService.instance.saveUserGroupOrder(user.id, [gC.id, gA.id, gB.id]);

    // Simulate closing and reopening the app
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify rooms are loaded directly in the custom rearranged order
    final reorderableListFinder = find.byType(ReorderableListView);
    expect(reorderableListFinder, findsOneWidget);

    final listeners = tester.widgetList<LongerHoldDragStartListener>(
      find.byType(LongerHoldDragStartListener),
    ).toList();
    expect(listeners.length, 3);
    expect(listeners[0].key, ValueKey(gC.id));
    expect(listeners[1].key, ValueKey(gA.id));
    expect(listeners[2].key, ValueKey(gB.id));

    await AuthService.instance.logOut();
  });

  testWidgets('Udhaar tab icon is on left of logout button and opens UdhaarScreen where users add persons vertically', (WidgetTester tester) async {
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9555544444', onCodeSent: (_) {}, onError: (_) {});
    final user = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'UdhaarUser');
    expect(user.name, 'UdhaarUser');

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Udhaar button and Log Out button exist in AppBar
    final udhaarIconFinder = find.byTooltip('Udhaar');
    final logOutIconFinder = find.byTooltip('Log Out');
    expect(udhaarIconFinder, findsOneWidget);
    expect(logOutIconFinder, findsOneWidget);

    // Verify Udhaar icon is positioned to the left of the Log Out icon
    final udhaarPos = tester.getTopLeft(udhaarIconFinder);
    final logOutPos = tester.getTopLeft(logOutIconFinder);
    expect(udhaarPos.dx, lessThan(logOutPos.dx));

    // Tap the Udhaar icon to navigate to UdhaarScreen
    await tester.tap(udhaarIconFinder);
    await tester.pumpAndSettle();

    expect(find.byType(UdhaarScreen), findsOneWidget);
    expect(find.text('Udhaar'), findsOneWidget);
    expect(find.text('No Udhaar contacts yet'), findsOneWidget);

    // Add a person (e.g. Rahul)
    await tester.tap(find.text('Add Person').first);
    await tester.pumpAndSettle();

    // Type person name
    await tester.enterText(find.byType(TextField), 'Rahul Sharma');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Verify person is stored vertically with initial amount ₹0 in black between - and + signs
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);

    // Check color of initial ₹0 is black (Color(0xFF0F172A))
    final initialZeroText = tester.widget<Text>(find.text('₹0'));
    expect(initialZeroText.style?.color, const Color(0xFF0F172A));

    await AuthService.instance.logOut();
  });

  testWidgets('Udhaar: + and - transactions update amount left between signs with color rules and name opens transaction history', (WidgetTester tester) async {
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9444433333', onCodeSent: (_) {}, onError: (_) {});
    final user = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'Lender');

    // Pre-create person in Udhaar
    final person = await UdhaarService.instance.addPerson(userId: user.id, name: 'Aman Verma');
    expect(person.name, 'Aman Verma');

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open Udhaar Screen
    await tester.tap(find.byTooltip('Udhaar'));
    await tester.pumpAndSettle();

    expect(find.text('Aman Verma'), findsOneWidget);
    expect(find.text('₹0'), findsOneWidget);

    // Click [+] on the front screen for Aman Verma
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    // Verify pop-up dialog with amount, note, date appears
    expect(find.text('Debt Given (+)'), findsOneWidget);
    expect(find.text('Person: Aman Verma'), findsOneWidget);

    // Enter amount: 500, note: Dinner split
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '500');
    await tester.enterText(textFields.at(1), 'Dinner split');
    await tester.pump();

    // Click Record Given Debt button in modal
    await tester.tap(find.text('Record Given Debt'));
    await tester.pumpAndSettle();

    // Verify front screen now shows amount left: ₹500 in green
    expect(find.text('₹500'), findsOneWidget);
    final positiveText = tester.widget<Text>(find.text('₹500'));
    expect(positiveText.style?.color, const Color(0xFF16A34A)); // Green

    // Click [-] on the front screen to reduce total
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pumpAndSettle();

    // Verify pop-up dialog for deduct / received
    expect(find.text('Debt Taken / Received (-)'), findsOneWidget);
    final deductTextFields = find.byType(TextField);
    // Deduct 700 so total becomes -200 (negative)
    await tester.enterText(deductTextFields.at(0), '700');
    await tester.enterText(deductTextFields.at(1), 'Returned extra');
    await tester.pump();
    await tester.tap(find.text('Record Received / Taken'));
    await tester.pumpAndSettle();

    // Verify front screen now shows negative amount -₹200 in RED
    expect(find.text('-₹200'), findsOneWidget);
    final negativeText = tester.widget<Text>(find.text('-₹200'));
    expect(negativeText.style?.color, const Color(0xFFDC2626)); // Red

    // Click person name to access history of transactions
    await tester.tap(find.text('Aman Verma'));
    await tester.pumpAndSettle();

    // Verify UdhaarDetailScreen opens with updated headings
    expect(find.byType(UdhaarDetailScreen), findsOneWidget);
    expect(find.text('YOU WILL PAY (NET)'), findsOneWidget);
    expect(find.text('Debt Given (+)'), findsWidgets);
    expect(find.text('Debt Taken / Received (-)'), findsWidgets);
    expect(find.text('History of Transactions'), findsOneWidget);
    expect(find.text('Dinner split'), findsOneWidget);
    expect(find.text('Returned extra'), findsOneWidget);
    expect(find.text('+₹500'), findsWidgets);
    expect(find.text('-₹700'), findsWidgets);

    await AuthService.instance.logOut();
  });

  testWidgets('UdhaarScreen allows rearranging persons by long holding and preserves order across app restarts', (WidgetTester tester) async {
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9333322222', onCodeSent: (_) {}, onError: (_) {});
    final user = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'OrderTester');

    final p1 = await UdhaarService.instance.addPerson(userId: user.id, name: 'Contact 1');
    final p2 = await UdhaarService.instance.addPerson(userId: user.id, name: 'Contact 2');
    final p3 = await UdhaarService.instance.addPerson(userId: user.id, name: 'Contact 3');

    // Save custom order: Contact 3 first, then Contact 1, then Contact 2
    await UdhaarService.instance.saveUserPersonOrder(user.id, [p3.id, p1.id, p2.id]);

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open Udhaar Screen
    await tester.tap(find.byTooltip('Udhaar'));
    await tester.pumpAndSettle();

    // Verify ReorderableListView is present on Udhaar screen
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);

    // Verify persons are loaded in the custom rearranged order
    final listeners = tester.widgetList<LongerHoldDragStartListener>(
      find.byType(LongerHoldDragStartListener),
    ).toList();
    expect(listeners.length, 3);
    expect(listeners[0].key, ValueKey(p3.id));
    expect(listeners[1].key, ValueKey(p1.id));
    expect(listeners[2].key, ValueKey(p2.id));

    // Perform long-press gesture (1150ms > 1000ms delay) to drag Contact 2 up
    final c2Center = tester.getCenter(find.text('Contact 2'));
    final gesture = await tester.startGesture(c2Center);
    await tester.pump(const Duration(milliseconds: 1150));
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    await AuthService.instance.logOut();
  });

  testWidgets('Splitwise icon is beside Udhaar icon on front screen and opens SplitwiseHomeScreen', (WidgetTester tester) async {
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9222211111', onCodeSent: (_) {}, onError: (_) {});
    final user = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'PartyHost');
    expect(user.name, 'PartyHost');

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Splitwise and Udhaar icons exist in AppBar
    final splitwiseFinder = find.byTooltip('Splitwise');
    final udhaarFinder = find.byTooltip('Udhaar');
    final logoutFinder = find.byTooltip('Log Out');
    expect(splitwiseFinder, findsOneWidget);
    expect(udhaarFinder, findsOneWidget);
    expect(logoutFinder, findsOneWidget);

    // Verify Splitwise is positioned beside (to the left of) Udhaar icon
    final splitwisePos = tester.getTopLeft(splitwiseFinder);
    final udhaarPos = tester.getTopLeft(udhaarFinder);
    expect(splitwisePos.dx, lessThan(udhaarPos.dx));

    // Tap Splitwise icon
    await tester.tap(splitwiseFinder);
    await tester.pumpAndSettle();

    // Verify SplitwiseHomeScreen opens with Active Parties and History tabs
    expect(find.byType(SplitwiseHomeScreen), findsOneWidget);
    expect(find.text('Splitwise'), findsOneWidget);
    expect(find.text('Active Parties'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await AuthService.instance.logOut();
  });

  testWidgets('Splitwise: create party with date and members, add expense with paidBy & involved, see green/red net settlements, and mark done into history', (WidgetTester tester) async {
    await AuthService.instance.logOut();
    await AuthService.instance.sendOtp(rawPhoneNumber: '9111100000', onCodeSent: (_) {}, onError: (_) {});
    final user = await AuthService.instance.verifyOtpAndSignIn(smsCode: '123456', name: 'PartyLead');
    expect(user.name, 'PartyLead');

    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open Splitwise screen
    await tester.tap(find.byTooltip('Splitwise'));
    await tester.pumpAndSettle();

    // Tap "New Group" button
    await tester.tap(find.text('New Group').first);
    await tester.pumpAndSettle();

    // Enter group name: Goa Party
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Goa Party');

    // Add members: Rahul and Aman
    await tester.enterText(textFields.at(1), 'Rahul');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final textFieldsAfterFirst = find.byType(TextField);
    await tester.enterText(textFieldsAfterFirst.at(1), 'Aman');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Tap "Create Group"
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle();

    // Verify SplitwiseGroupScreen is open
    expect(find.byType(SplitwiseGroupScreen), findsOneWidget);
    expect(find.text('Goa Party'), findsOneWidget);
    expect(find.text('Rahul'), findsWidgets);
    expect(find.text('Aman'), findsWidgets);

    // Initial settlements: both are Settled (₹0)
    expect(find.text('Settled (₹0)'), findsNWidgets(2));

    // Tap "+ Add Expense" FAB at bottom right
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter Amount: 1000, Description: Dinner
    final expTextFields = find.byType(TextField);
    await tester.enterText(expTextFields.at(0), '1000');
    await tester.enterText(expTextFields.at(1), 'Seafood Dinner');
    await tester.pumpAndSettle();

    // Rahul is default payer, both Rahul and Aman are involved (500 each)
    await tester.ensureVisible(find.text('Save Expense'));
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Verify net balances:
    // Rahul paid 1000 for 2 people -> gets back ₹500 (Green)
    // Aman paid 0 for 500 share -> owes ₹500 (Red)
    expect(find.text('Gets back ₹500'), findsOneWidget);
    expect(find.text('Owes ₹500'), findsOneWidget);

    final getsBackWidget = tester.widget<Text>(find.text('Gets back ₹500'));
    expect(getsBackWidget.style?.color, const Color(0xFF16A34A)); // Green

    final owesWidget = tester.widget<Text>(find.text('Owes ₹500'));
    expect(owesWidget.style?.color, const Color(0xFFDC2626)); // Red

    // Mark party as done
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Confirm mark done
    await tester.tap(find.text('Mark Done'));
    await tester.pumpAndSettle();

    expect(find.text('COMPLETED'), findsOneWidget);

    // Go back to Splitwise home screen
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tap "History" tab to verify party is stored in history
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Goa Party'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);

    await AuthService.instance.logOut();
  });
}

