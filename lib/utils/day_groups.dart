import '../models/session.dart';

class DayGroup {
  final DateTime date;
  final List<SessionInfo> sessions;

  DayGroup({required this.date, required this.sessions});
}

List<DayGroup> groupByDay(List<SessionInfo> sessions) {
  final map = <DateTime, List<SessionInfo>>{};
  for (final s in sessions) {
    final day = DateTime(s.date.year, s.date.month, s.date.day);
    map.putIfAbsent(day, () => []).add(s);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      DayGroup(
        date: d,
        sessions: (map[d]!..sort((a, b) => a.pairNumber.compareTo(b.pairNumber))),
      ),
  ];
}