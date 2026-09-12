import 'package:flutter/material.dart';

import '../marks.dart';

class StudentMarkTile extends StatelessWidget {
  final int index;
  final String fullName;
  final String mark;
  final VoidCallback? onNext;
  final VoidCallback? onReset;

  const StudentMarkTile({
    super.key,
    required this.index,
    required this.fullName,
    required this.mark,
    this.onNext,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final m = Marks.byValue(mark);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Text(
            '${index + 1}',
            style: TextStyle(fontSize: 14, color: scheme.onSecondaryContainer),
          ),
        ),
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Tooltip(
          message: m.tooltip ?? '',
          child: InkWell(
            onTap: onNext,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 56,
              height: 44,
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: m.color, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                m.label,
                style: TextStyle(
                  color: m.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        onTap: onNext,
      ),
    );
  }
}