import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  void _showOptions(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }

    if (onEdit == null && onDelete == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.name,
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      transaction.formattedSignedAmount,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: transaction.isExpense
                            ? const Color(0xFF15803D)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF0F172A)),
                  title: const Text(
                    'Edit Entry',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit?.call();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  title: const Text(
                    'Delete Entry',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Delete Entry?'),
                        content: Text(
                          'Are you sure you want to delete "${transaction.name}" (${transaction.formattedSignedAmount})?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      onDelete?.call();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final amountColor = isExpense
        ? const Color(0xFF15803D) // Restrained green for +
        : const Color(0xFFDC2626); // Restrained red for -

    return Dismissible(
      key: Key(transaction.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Entry?'),
            content: Text(
              'Are you sure you want to delete "${transaction.name}" (${transaction.formattedSignedAmount})?',
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
      },
      background: Container(
        color: const Color(0xFFDC2626),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) {
        onDelete?.call();
      },
      child: InkWell(
        onTap: (onTap != null || onEdit != null || onDelete != null)
            ? () => _showOptions(context)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              // Transaction Name
              Expanded(
                child: Text(
                  transaction.name,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              // Signed Amount (+₹500 or -₹200)
              Text(
                transaction.formattedSignedAmount,
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
