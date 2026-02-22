import 'package:http/http.dart' as http;

final httpClient = _AppHttpClient._instance;

class _AppHttpClient {
  _AppHttpClient._();
  static final _AppHttpClient _instance = _AppHttpClient._();

  final http.Client client = http.Client();
}

class CloudData {
  Future<String> loadTextFromCloud(String url, String textOnError) async {
    try {
      final response = await httpClient.client.get(Uri.parse(url));
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
