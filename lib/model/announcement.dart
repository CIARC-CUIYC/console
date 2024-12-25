enum AnnouncementSeverity { error, info }

class Announcement {
  final DateTime timestamp;
  final AnnouncementSeverity severity;
  final String message;

  Announcement(this.timestamp, this.severity, this.message);

  @override
  String toString() {
    return "${timestamp.toIso8601String()} - $severity - $message";
  }
}
