class Group {
  final int id;
  final String name;
  final int? year;
  final int? curatorId;
  final String? curatorName;
  final int? departmentHeadId;
  final String? departmentHeadName;

  Group({
    required this.id,
    required this.name,
    this.year,
    this.curatorId,
    this.curatorName,
    this.departmentHeadId,
    this.departmentHeadName,
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'],
        name: json['name'],
        year: json['year'],
        curatorId: json['curator_id'] ?? json['teacher_id'],
        curatorName: json['curator_name'],
        departmentHeadId: json['department_head_id'],
        departmentHeadName: json['department_head_name'],
      );
}