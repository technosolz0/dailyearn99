import 'dart:async';

class AdminNotificationItem {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  AdminNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
  });
}

class NotificationLog {
  static final List<AdminNotificationItem> _logs = [];
  
  static final StreamController<List<AdminNotificationItem>> _streamController = 
      StreamController<List<AdminNotificationItem>>.broadcast();

  static List<AdminNotificationItem> get logs => List.unmodifiable(_logs);
  static Stream<List<AdminNotificationItem>> get stream => _streamController.stream;

  static void addLog(String title, String body, Map<String, dynamic> data) {
    final newItem = AdminNotificationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      data: data,
      receivedAt: DateTime.now(),
    );
    _logs.insert(0, newItem);
    if (_logs.length > 100) {
      _logs.removeLast(); // Limit to 100 entries
    }
    _streamController.add(List.unmodifiable(_logs));
  }

  static void clearLogs() {
    _logs.clear();
    _streamController.add(List.unmodifiable(_logs));
  }
}
