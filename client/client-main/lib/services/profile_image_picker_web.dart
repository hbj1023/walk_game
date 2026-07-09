// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class ProfileImagePicker {
  static const _maxBytes = 1536 * 1024;

  static Future<String?> pickProfileImageDataUrl() {
    final input = html.FileUploadInputElement()
      ..accept = 'image/png,image/jpeg,image/webp'
      ..multiple = false;
    final completer = Completer<String?>();

    input.onChange.first.then((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.first;
      if (!file.type.startsWith('image/')) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('이미지 파일만 선택할 수 있습니다.'));
        }
        return;
      }
      if (file.type != 'image/png' &&
          file.type != 'image/jpeg' &&
          file.type != 'image/webp') {
        if (!completer.isCompleted) {
          completer.completeError(Exception('PNG, JPG, WEBP 이미지만 사용할 수 있습니다.'));
        }
        return;
      }
      if (file.size > _maxBytes) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('프로필 이미지는 1.5MB 이하만 사용할 수 있습니다.'));
        }
        return;
      }

      final reader = html.FileReader();
      reader.onLoad.first.then((_) {
        if (!completer.isCompleted) {
          completer.complete(reader.result?.toString());
        }
      });
      reader.onError.first.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('이미지를 불러오지 못했습니다.'));
        }
      });
      reader.readAsDataUrl(file);
    });

    input.click();
    return completer.future.timeout(
      const Duration(minutes: 1),
      onTimeout: () => null,
    );
  }
}
