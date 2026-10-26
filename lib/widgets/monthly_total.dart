import 'package:flutter/material.dart';

class MonthlyTotal extends StatelessWidget {
  final String monthTitle; // e.g. "Expenses" or "Trip to Goa"
  final String formattedTotal; // e.g. "₹12,450"
  final String subtitle; // e.g. "TOTAL"
  final VoidCallback? onTitleTap; // If provided, shows edit icon and allows renaming

  const MonthlyTotal({
    super.key,
    required this.monthTitle,
    required this.formattedTotal,
    this.subtitle = 'TOTAL',
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onTitleTap != null)
            InkWell(
              onTap: onTitleTap,
              borderRadius: BorderRadius.circular(4.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                child: Text(
                  monthTitle,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            )
          else
            Text(
              monthTitle,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.grey.shade600,
              ),
            ),
          const SizedBox(height: 6.0),
          Text(
            formattedTotal,
            style: const TextStyle(
              fontSize: 38.0,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Color(0xFF1E293B),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4.0),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
