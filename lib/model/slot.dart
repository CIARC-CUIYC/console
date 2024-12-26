class Slot {
  final int id;
  final DateTime start;
  final DateTime end;
  bool booked;

  Slot({required this.id, required this.start, required this.end, required this.booked});
}
