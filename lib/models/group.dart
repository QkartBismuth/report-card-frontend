class Group {
  final int id;
  final String name;
  final int? year;

  Group({required this.id, required this.name, this.year});

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'],
        name: json['name'],
        year: json['year'],
      );
}