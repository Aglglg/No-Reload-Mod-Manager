import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:path/path.dart' as p;

Future<Map<String, String>> fetchGroupIconData() async {
  try {
    final response = await http.get(Uri.parse(ConstantVar.urlJsonAutoIcon));

    if (response.statusCode == 200) {
      final Map<String, dynamic> raw = json.decode(response.body);
      return raw.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
  } catch (e) {}
  return {};
}

/// Max number of .ini files to process
const int maxIniFiles = 5;

/// Main function to search, match, and download image
Future<bool> tryGetIcon(String rootPath, Map<String, String> iconData) async {
  final iniFiles = <File>[];

  // Step 1: Find up to 5 .ini files under rootPath (recursive)
  await for (final entity in Directory(
    rootPath,
  ).list(recursive: true, followLinks: false)) {
    if (entity is File && p.extension(entity.path).toLowerCase() == '.ini') {
      final fileName = p.basename(entity.path);
      if (!fileName.toLowerCase().startsWith('disabled')) {
        iniFiles.add(entity);
        if (iniFiles.length >= maxIniFiles) break;
      }
    }
  }

  print('Found ${iniFiles.length} .ini files.');

  // Step 2: Process each file and look for matching key
  for (final iniFile in iniFiles) {
    final content = await iniFile.readAsString();

    for (final entry in iconData.entries) {
      if (content.contains(entry.key)) {
        print('Match found in ${iniFile.path} for key "${entry.key}"');

        // Step 3: Download image and save to rootPath/icon.png
        try {
          final response = await http.get(Uri.parse(entry.value));
          if (response.statusCode == 200) {
            final savePath = p.join(rootPath, 'icon.png');
            final imageFile = File(savePath);
            await imageFile.writeAsBytes(response.bodyBytes);
            print('Image downloaded and saved to: $savePath');
          } else {
            print('Failed to download image from ${entry.value}');
          }
        } catch (e) {}

        // Stop processing after first successful match
        return true;
      }
    }
  }

  return false;
}
