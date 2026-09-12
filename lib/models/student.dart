class Student {
  final int id;
  final int groupId;
  final String fullName;

  Student({required this.id, required this.groupId, required this.fullName});

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'],
        groupId: json['group_id'],
        fullName: json['full_name'],
      );
}