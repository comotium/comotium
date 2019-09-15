class Field {
  final String id;
  final String type;
  final List<dynamic> position;
  final String prompt;

  Field({ this.id, this.type, this.position, this.prompt });

  factory Field.fromJson(Map<String, dynamic> json) {
    return Field(
      id: json['id'],
      type: json['type'],
      position: json['position'],
      prompt: json['prompt'],
    );
  }
}
