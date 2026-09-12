class Subject {
  final int id;
  final String name;
  final int? teacherId;
  final String? teacherName;

  Subject({
    required this.id,
    required this.name,
    this.teacherId,
    this.teacherName,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'],
        name: json['name'],
        teacherId: json['teacher_id'],
        teacherName: json['teacher_name'],
      );
}