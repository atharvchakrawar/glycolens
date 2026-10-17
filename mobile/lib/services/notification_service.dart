import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class NotificationService {
  /// Request system notification permission on phone browser / PWA
  static Future<void> requestPermission() async {
    if (kIsWeb) {
      try {
        js.context.callMethod('requestPhoneNotificationPermission');
      } catch (e) {
        debugPrint('Notification permission error: $e');
      }
    }
  }

  /// Fire a native system notification to the phone lockscreen / status bar
  static void sendAlert({
    required String title,
    required String body,
    String tag = 'glycolens-hypo-alert',
  }) {
    if (kIsWeb) {
      try {
        js.context.callMethod('sendPhoneNotification', [title, body, tag]);
      } catch (e) {
        debugPrint('Send notification error: $e');
      }
    }
  }
}
