class SessionInfo {
  final int id;
  final int groupId;
  final String? groupName;
  final int? subjectId;
  final String? subjectName;
  final DateTime date;
  final int pairNumber;
  final bool confirmed;
  final DateTime? confirmedAt;

  SessionInfo({
    required this.id,
    required this.groupId,
    this.groupName,
    this.subjectId,
    this.subjectName,
    required this.date,
    required this.pairNumber,
    required this.confirmed,
    this.confirmedAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        id: json['id'],
        groupId: json['group_id'],
        groupName: json['group_name'],
        subjectId: json['subject_id'],
        subjectName: json['subject_name'],
        date: DateTime.parse(json['date']),
        pairNumber: json['pair_number'],
        confirmed: json['confirmed'],
        confirmedAt: json['confirmed_at'] != null
            ? DateTime.tryParse(json['confirmed_at'])
            : null,
      );
}

class RecordInfo {
  final int id;
  final int sessionId;
  final int studentId;
  final String mark;
  final String? comment;

  RecordInfo({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.mark,
    this.comment,
  });

  factory RecordInfo.fromJson(Map<String, dynamic> json) => RecordInfo(
        id: json['id'],
        sessionId: json['session_id'],
        studentId: json['student_id'],
        mark: json['mark'],
        comment: json['comment'],
      );
}

class SessionDetail {
  final SessionInfo session;
  final List<RecordInfo> records;

  SessionDetail({required this.session, required this.records});

  factory SessionDetail.fromJson(Map<String, dynamic> json) => SessionDetail(
        session: SessionInfo.fromJson(json),
        records: (json['records'] as List)
            .map((e) => RecordInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}