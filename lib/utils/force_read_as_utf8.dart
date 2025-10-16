import 'dart:io';

import 'package:charset_converter/charset_converter.dart';
//"Force lossy convert to utf8");

Future<List<String>> forceReadAsLinesUtf8(File file) async {
  String decoded = "";
  try {
    decoded = await CharsetConverter.decode("utf-8", await file.readAsBytes());
  } catch (e) {
    if (e.toString().contains("Missing extension byte")) {
      //could be an empty ini file, skip
    } else {
      rethrow;
    }
  }

  final lines = decoded.split(RegExp(r'\r?\n'));

  // Remove trailing blank lines
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }

  return lines;
}

Future<String> forceReadAsStringUtf8(File file) async {
  String decoded = "";
  try {
    decoded = await CharsetConverter.decode("utf-8", await file.readAsBytes());
  } catch (e) {
    if (e.toString().contains("Missing extension byte")) {
      //could be an empty ini file, skip
    } else {
      rethrow;
    }
  }
  return decoded;
}
