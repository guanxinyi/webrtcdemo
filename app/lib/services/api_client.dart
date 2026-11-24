import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class JoinCredentials {
  const JoinCredentials({
    required this.token,
    required this.url,
    required this.room,
    required this.identity,
    required this.name,
  });

  /// LiveKit JWT.
  final String token;

  /// LiveKit WebSocket URL returned by the backend.
  final String url;
  final String room;
  final String identity;
  final String name;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the token API in `server/`.
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Future<JoinCredentials> join({required String room, required String name}) async {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$base/api/token');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiException('后端服务地址无效，请填写形如 http://192.168.1.10:8080 的地址');
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'room': room, 'name': name}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException('连接后端服务超时，请检查地址与网络');
    } catch (error) {
      throw ApiException('无法连接后端服务：$error');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('后端返回了无法解析的数据（HTTP ${response.statusCode}）');
    }

    if (response.statusCode != 200) {
      throw ApiException(body['error']?.toString() ?? '获取房间凭证失败（HTTP ${response.statusCode}）');
    }

    final token = body['token'] as String?;
    final url = body['url'] as String?;
    if (token == null || url == null) {
      throw const ApiException('后端返回的数据缺少 token 或 url');
    }

    return JoinCredentials(
      token: token,
      url: url,
      room: body['room'] as String? ?? room,
      identity: body['identity'] as String? ?? '',
      name: body['name'] as String? ?? name,
    );
  }
}
