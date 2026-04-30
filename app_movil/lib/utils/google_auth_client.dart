import 'package:http/http.dart' as http;

/// Cliente HTTP personalizado que inyecta los Headers de autenticación 
/// de Google Sign In en cada petición hacia la API de Google Drive.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}