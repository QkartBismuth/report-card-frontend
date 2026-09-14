class KtcBranch {
  final int id;
  final String title;
  KtcBranch({required this.id, required this.title});
  factory KtcBranch.fromJson(Map<String, dynamic> json) => KtcBranch(
        id: json['id'],
        title: json['title'] ?? '',
      );
}

class KtcGroup {
  final int id;
  final String title;
  KtcGroup({required this.id, required this.title});
  factory KtcGroup.fromJson(Map<String, dynamic> json) => KtcGroup(
        id: json['id'],
        title: json['title'] ?? '',
      );
}

class KtcCourse {
  final int course;
  final List<KtcGroup> groups;
  KtcCourse({required this.course, required this.groups});
  factory KtcCourse.fromJson(Map<String, dynamic> json) => KtcCourse(
        course: json['course'],
        groups: (json['groups'] as List? ?? [])
            .map((e) => KtcGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class KtcTeacher {
  final int id;
  final String name;
  KtcTeacher({required this.id, required this.name});
  factory KtcTeacher.fromJson(Map<String, dynamic> json) => KtcTeacher(
        id: json['id'],
        name: json['name'] ?? '',
      );
}

class ScheduleEntry {
  final int id;
  final int groupId;
  final int dayOfWeek; // 1=Пн..7=Вс
  final int pairNumber;
  final int? subjectId;
  final String? subjectName;
  final int? teacherId;
  final String? teacherName;
  final String? teacherFullName;
  final String? classroom;
  final String? timeStart;
  final String? timeEnd;
  final bool cancelled;

  const ScheduleEntry({
    required this.id,
    required this.groupId,
    required this.dayOfWeek,
    required this.pairNumber,
    this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
    this.teacherFullName,
    this.classroom,
    this.timeStart,
    this.timeEnd,
    this.cancelled = false,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        id: json['id'],
        groupId: json['group_id'],
        dayOfWeek: json['day_of_week'],
        pairNumber: json['pair_number'],
        subjectId: json['subject_id'],
        subjectName: json['subject_name'],
        teacherId: json['teacher_id'],
        teacherName: json['teacher_name'],
        teacherFullName: json['teacher_full_name'] ?? json['teacher_name'],
        classroom: json['classroom'],
        timeStart: json['time_start'],
        timeEnd: json['time_end'],
        cancelled: json['cancelled'] ?? false,
      );
}

class CreateSessionsResult {
  final int groupId;
  final DateTime date;
  final List<int> created;
  final List<Map<String, dynamic>> skipped;
  final int createdCount;
  final int skippedCount;

  const CreateSessionsResult({
    required this.groupId,
    required this.date,
    required this.created,
    required this.skipped,
    required this.createdCount,
    required this.skippedCount,
  });

  factory CreateSessionsResult.fromJson(Map<String, dynamic> json) =>
      CreateSessionsResult(
        groupId: json['group_id'],
        date: DateTime.parse(json['date']),
        created: (json['created'] as List? ?? []).cast<int>(),
        skipped: (json['skipped'] as List? ?? [])
            .cast<Map<String, dynamic>>(),
        createdCount: json['created_count'] ?? 0,
        skippedCount: json['skipped_count'] ?? 0,
      );
}

const kDayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String dayName(int dayOfWeek) =>
    dayOfWeek >= 1 && dayOfWeek <= 7 ? kDayNames[dayOfWeek] : '?';