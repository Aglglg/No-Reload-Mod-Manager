import 'package:http/http.dart' as http;

class CloudData {
  Future<String> loadTextFromCloud(String url, String textOnError) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.body;
      } else {
        return textOnError;
      }
    } catch (_) {
      return textOnError;
    }
  }
}
