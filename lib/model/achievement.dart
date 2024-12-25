class Achievement {
  final String name;
  final bool done;
  final int points;
  final String description;
  final (dynamic threshold, dynamic scored) goalParameter;

  Achievement({
    required this.name,
    required this.done,
    required this.points,
    required this.description,
    required this.goalParameter,
  });

  @override
  String toString() {
    return "$name - $done - $points - $description";
  }
}
