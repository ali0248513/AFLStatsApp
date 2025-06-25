import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

Future<void> shareCsvFile(
  String fileName,
  String csvContent, {
  String? shareText,
  BuildContext? context,
}) async {
  try {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvContent);
    await Share.shareXFiles([XFile(file.path)], text: shareText ?? '');
  } catch (e) {
    if (context != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing match data: $e')));
    }
  }
}
