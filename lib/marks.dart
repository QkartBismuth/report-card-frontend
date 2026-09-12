import 'package:flutter/material.dart';

class Mark {
  final String value;
  final String label;
  final Color color;
  final String? tooltip;

  const Mark({
    required this.value,
    required this.label,
    required this.color,
    this.tooltip,
  });
}

class Marks {
  static const present = Mark(
    value: 'present',
    label: '✓',
    color: Color(0xFF4CAF50),
    tooltip: 'Присутствует',
  );
  static const late = Mark(
    value: 'late',
    label: 'н',
    color: Color(0xFFFFB300),
    tooltip: 'Опоздание',
  );
  static const absent = Mark(
    value: 'absent',
    label: 'нн',
    color: Color(0xFFE53935),
    tooltip: 'Не пришёл',
  );
  static const excused = Mark(
    value: 'excused',
    label: 'у',
    color: Color(0xFF9E9E9E),
    tooltip: 'Уважительная причина',
  );

  static const all = [present, late, absent, excused];

  static Mark byValue(String value) => all.firstWhere(
        (m) => m.value == value,
        orElse: () => present,
      );

  /// Следующее состояние при нажатии: present -> late -> absent -> excused -> present
  static Mark next(Mark current) {
    final idx = all.indexOf(current);
    return all[(idx + 1) % all.length];
  }
}