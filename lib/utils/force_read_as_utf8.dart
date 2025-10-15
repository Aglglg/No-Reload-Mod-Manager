import 'dart:io';

import 'package:charset_converter/charset_converter.dart';
//"Force lossy convert to utf8");

Future<List<String>> forceReadAsLinesUtf8(File file) async {
  String decoded = await CharsetConverter.decode(
    "utf-8",
    await file.readAsBytes(),
  );

  final lines = decoded.split(RegExp(r'\r?\n'));

  // Remove trailing blank lines
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }

  return lines;
}

Future<String> forceReadAsStringUtf8(File file) async {
  String decoded = await CharsetConverter.decode(
    "utf-8",
    await file.readAsBytes(),
  );
  return decoded;
}
