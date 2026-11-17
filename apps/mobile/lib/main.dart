import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom ErrorWidget so release-mode layout issues never render a blank black screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF080B11),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Text(
                'Initialization Note:\n${details.exceptionAsString()}',
                style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  };

  // Launch UI immediately
  runApp(
    const ProviderScope(
      child: PingoApp(),
    ),
  );

  // Initialize notification and FCM engines asynchronously without blocking first frame render
  NotificationService.instance.initialize().catchError((e) {
    debugPrint('[NotificationService] Init error: $e');
  });
  FcmService.instance.initialize().catchError((e) {
    debugPrint('[FcmService] Init error: $e');
  });
}
