import 'package:flutter/material.dart';
import 'dart:io';

class ImageHelper {
  static ImageProvider? getImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }

    // Check if it's a network URL
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return NetworkImage(photoUrl);
    }

    // Check if it's a local file path
    try {
      final file = File(photoUrl);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (e) {
      // Invalid path
    }

    return null;
  }

  static Widget buildAvatar({
    required String? photoUrl,
    required String displayName,
    required double radius,
    Color? backgroundColor,
    TextStyle? textStyle,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: getImageProvider(photoUrl),
      child: getImageProvider(photoUrl) == null
          ? Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: textStyle,
            )
          : null,
    );
  }
}
