import 'dart:async';

import 'package:capstone_app/services/activity_recognition_permission_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cap1/activity_permission');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() async {
    ActivityRecognitionPermissionService.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('startup permission check is reused by later tracking starts', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls += 1;
          expect(call.method, 'checkActivityRecognitionPermission');
          return true;
        });

    expect(
      await ActivityRecognitionPermissionService.checkGranted(force: true),
      isTrue,
    );
    expect(await ActivityRecognitionPermissionService.ensureGranted(), isTrue);
    expect(calls, 1);
  });

  test('simultaneous permission requests share one native request', () async {
    var calls = 0;
    final response = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls += 1;
          expect(call.method, 'ensureActivityRecognitionPermission');
          return response.future;
        });

    final first = ActivityRecognitionPermissionService.ensureGranted();
    final second = ActivityRecognitionPermissionService.ensureGranted();
    response.complete(true);

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(calls, 1);
  });
}
