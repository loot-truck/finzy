import 'dart:convert';
import 'dart:io';

/// Talks to the Go gateway. Every backend call goes through here so auth
/// headers, base URL and error handling live in one place.
///
/// Uses `dart:io` HttpClient rather than package:http to keep the scaffold
/// dependency-free; swap it for `http` or `dio` when you add packages.
class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? const String.fromEnvironment(
          'API_BASE_URL',
          // Android emulators reach the host machine on 10.0.2.2.
          defaultValue: 'http://10.0.2.2:8080',
        );

  final String baseUrl;
  String? _accessToken;

  bool get isAuthenticated => _accessToken != null;

  /// Registers an account. Throws [ApiException] if the email is taken.
  Future<void> register(String email, String password) async {
    await _send('POST', '/api/v1/auth/register', {
      'email': email,
      'password': password,
    });
  }

  /// Logs in and stores the token for subsequent calls.
  Future<void> login(String email, String password) async {
    final body = await _send('POST', '/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    _accessToken = body['access_token'] as String;
  }

  void logout() => _accessToken = null;

  Future<Map<String, dynamic>> profile(String userId) =>
      _send('GET', '/api/v1/users/profiles/$userId', null);

  Future<Map<String, dynamic>> saveProfile(
    String userId, {
    required String name,
    required String currency,
  }) =>
      _send('PUT', '/api/v1/users/profiles/$userId', {
        'name': name,
        'currency': currency,
      });

  /// Asks the Rust AI service which spending category a description falls into.
  Future<Map<String, dynamic>> classify(String description) =>
      _sendRaw('POST', '/api/v1/ai/classify', utf8.encode(description));

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) =>
      _sendRaw(
        method,
        path,
        body == null ? null : utf8.encode(jsonEncode(body)),
        contentType: 'application/json',
      );

  Future<Map<String, dynamic>> _sendRaw(
    String method,
    String path,
    List<int>? body, {
    String contentType = 'text/plain',
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      if (_accessToken != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_accessToken');
      }
      if (body != null) {
        request.headers.contentType = ContentType.parse(contentType);
        request.add(body);
      }

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      final decoded = text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        throw ApiException(
          response.statusCode,
          decoded['error'] as String? ?? 'request failed',
        );
      }
      return decoded;
    } on SocketException catch (e) {
      // Surfaced separately: this is almost always "the backend isn't running".
      throw ApiException(0, 'cannot reach $baseUrl (${e.osError?.message ?? e.message})');
    } finally {
      client.close();
    }
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
