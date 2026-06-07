import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final int statusCode;
  final String message;
  final Object? body;

  BackendApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  @override
  String toString() => 'BackendApiException($statusCode): $message';
}

class BackendApi {
  final Uri _baseUri;
  final http.Client _client;
  String? _accessToken;

  BackendApi({
    required String baseUrl,
    String? accessToken,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl),
       _client = client ?? http.Client(),
       _accessToken = accessToken?.trim().isEmpty == true
           ? null
           : accessToken?.trim();

  bool get hasAuth => _accessToken != null && _accessToken!.isNotEmpty;

  void setAccessToken(String? token) {
    final trimmed = token?.trim();
    _accessToken = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Uri resolveUrl(String relativeOrAbsolute) {
    final parsed = Uri.tryParse(relativeOrAbsolute);
    if (parsed != null && parsed.hasScheme) return parsed;
    return _baseUri.resolve(relativeOrAbsolute);
  }

  Future<List<int>> downloadBytes(String relativeOrAbsolute) async {
    final uri = resolveUrl(relativeOrAbsolute);
    final headers = <String, String>{};
    if (hasAuth) {
      headers['Authorization'] = 'Bearer ${_accessToken!}';
    }

    final response = await _client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw BackendApiException(
        statusCode: response.statusCode,
        message: 'Failed to download file',
        body: response.body,
      );
    }
    return response.bodyBytes;
  }

  void dispose() => _client.close();

  Future<Map<String, dynamic>> health() async {
    final data = await _request('GET', '/');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return _asMap(data);
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final map = _asMap(data);
    final token = map['access_token'] as String? ?? '';
    if (token.isNotEmpty) {
      _accessToken = token;
    }
    return token;
  }

  Future<String> refreshToken({String? token}) async {
    final current = token ?? _accessToken;
    if (current == null || current.isEmpty) {
      throw BackendApiException(
        statusCode: 401,
        message: 'No token available for refresh',
      );
    }
    final data = await _request(
      'POST',
      '/auth/refresh',
      body: {'access_token': current},
    );
    final map = _asMap(data);
    final refreshed = map['access_token'] as String? ?? '';
    if (refreshed.isNotEmpty) {
      _accessToken = refreshed;
    }
    return refreshed;
  }

  Future<Map<String, dynamic>> me() async {
    final data = await _request('GET', '/auth/me', authRequired: true);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> patchMe({String? name, String? about}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (about != null) body['about'] = about;
    final data = await _request(
      'PATCH',
      '/auth/me',
      authRequired: true,
      body: body,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> uploadMyAvatar(String filePath) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw BackendApiException(
        statusCode: 401,
        message: 'Missing access token',
      );
    }

    final uri = _baseUri.resolve('/auth/me/avatar');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('avatar', filePath));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final parsed = _parseBody(response.body);

    if (response.statusCode != 200) {
      throw BackendApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(parsed, response.body),
        body: parsed,
      );
    }
    return _asMap(parsed);
  }

  Future<List<Map<String, dynamic>>> getMethods() async {
    final data = await _request('GET', '/methods', authRequired: true);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> createMethod(String name) async {
    final data = await _request(
      'POST',
      '/methods',
      authRequired: true,
      body: {'name': name},
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getMyBelievers() async {
    final data = await _request('GET', '/believers/my', authRequired: true);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> createBeliever(
    Map<String, dynamic> believerPayload,
  ) async {
    final data = await _request(
      'POST',
      '/believers',
      authRequired: true,
      body: believerPayload,
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> patchBeliever(
    int believerId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _request(
      'PATCH',
      '/believers/$believerId',
      authRequired: true,
      body: payload,
    );
    return _asMap(data);
  }

  Future<void> deleteBeliever(int believerId) async {
    await _request(
      'DELETE',
      '/believers/$believerId',
      authRequired: true,
      expectedCodes: const {204},
    );
  }

  Future<List<Map<String, dynamic>>> getAllBelievers() async {
    final data = await _request('GET', '/believers/all');
    return _asListOfMap(data);
  }

  Future<List<Map<String, dynamic>>> getLatestBelievers({
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;
    final data = await _request('GET', '/believers/latest', query: query);
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> getTestimonyOfDay({String? day}) async {
    final query = <String, String>{};
    if (day != null && day.isNotEmpty) query['day'] = day;
    final data = await _request(
      'GET',
      '/believers/testimony-of-day',
      query: query,
    );
    return _asMap(data);
  }

  Future<int> getAcceptedJesusCount() async {
    final data = await _request('GET', '/believers/stats/accepted-jesus-count');
    final map = _asMap(data);
    final count = map['count'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return 0;
  }

  Future<Object?> _request(
    String method,
    String path, {
    bool authRequired = false,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Set<int> expectedCodes = const {200, 201},
  }) async {
    final uri = _baseUri.resolve(path).replace(queryParameters: query);
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authRequired) {
      final token = _accessToken;
      if (token == null || token.isEmpty) {
        throw BackendApiException(
          statusCode: 401,
          message: 'Missing access token',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    } else if (hasAuth) {
      headers['Authorization'] = 'Bearer ${_accessToken!}';
    }

    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final parsed = _parseBody(response.body);

    if (!expectedCodes.contains(response.statusCode)) {
      throw BackendApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(parsed, response.body),
        body: parsed,
      );
    }
    return parsed;
  }

  Object? _parseBody(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String _extractErrorMessage(Object? parsed, String raw) {
    if (parsed is Map<String, dynamic>) {
      final detail = parsed['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      final message = parsed['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return raw.isNotEmpty ? raw : 'Backend request failed';
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw BackendApiException(
      statusCode: 500,
      message: 'Unexpected response format: expected JSON object',
      body: data,
    );
  }

  List<Map<String, dynamic>> _asListOfMap(Object? data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw BackendApiException(
      statusCode: 500,
      message: 'Unexpected response format: expected JSON array',
      body: data,
    );
  }

  // ── Outreach Statistics ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllOutreachStatistics({
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;

    final data = await _request(
      'GET',
      '/outreach-statistics/all',
      query: query,
    );
    return _asListOfMap(data);
  }

  Future<List<Map<String, dynamic>>> getMyOutreachStatistics({
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;

    final data = await _request(
      'GET',
      '/outreach-statistics/me',
      authRequired: true,
      query: query,
    );
    return _asListOfMap(data);
  }

  Future<Map<String, dynamic>> createOutreachStatistics({
    required String outreachDate,
    int gospelsTold = 0,
    int salvationPrayedUnreachable = 0,
    int scripturesDistributed = 0,
    int healingsDeliverances = 0,
    String? note,
  }) async {
    final data = await _request(
      'POST',
      '/outreach-statistics',
      authRequired: true,
      body: {
        'outreach_date': outreachDate,
        'gospels_told': gospelsTold,
        'salvation_prayed_unreachable': salvationPrayedUnreachable,
        'scriptures_distributed': scripturesDistributed,
        'healings_deliverances': healingsDeliverances,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> patchOutreachStatistics(
    int statisticsId, {
    String? outreachDate,
    int? gospelsTold,
    int? salvationPrayedUnreachable,
    int? scripturesDistributed,
    int? healingsDeliverances,
    String? note,
  }) async {
    final body = <String, dynamic>{};
    if (outreachDate != null && outreachDate.isNotEmpty) {
      body['outreach_date'] = outreachDate;
    }
    if (gospelsTold != null) body['gospels_told'] = gospelsTold;
    if (salvationPrayedUnreachable != null) {
      body['salvation_prayed_unreachable'] = salvationPrayedUnreachable;
    }
    if (scripturesDistributed != null) {
      body['scriptures_distributed'] = scripturesDistributed;
    }
    if (healingsDeliverances != null) {
      body['healings_deliverances'] = healingsDeliverances;
    }
    if (note != null) body['note'] = note.trim();

    final data = await _request(
      'PATCH',
      '/outreach-statistics/$statisticsId',
      authRequired: true,
      body: body,
    );
    return _asMap(data);
  }

  Future<void> deleteOutreachStatistics(int statisticsId) async {
    await _request(
      'DELETE',
      '/outreach-statistics/$statisticsId',
      authRequired: true,
      expectedCodes: const {204},
    );
  }
}
