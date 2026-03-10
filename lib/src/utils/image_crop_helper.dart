import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// 이미지 선택 + 원형 크롭을 제공하는 헬퍼
class ImageCropHelper {
  static final _picker = ImagePicker();

  /// 갤러리에서 이미지를 선택하고 원형 크롭 UI를 표시합니다.
  /// 크롭 완료 시 [File]을 반환하고, 취소 시 null을 반환합니다.
  static Future<File?> pickAndCropImage(BuildContext context) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (pickedFile == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '',
          toolbarColor: Colors.white,
          toolbarWidgetColor: Colors.black,
          activeControlsWidgetColor: const Color(0xFFFF9A42),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: '',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }
}
