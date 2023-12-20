
import 'dart:convert';

import 'package:http/http.dart' as http;

class HTTPClient {
  static final HTTPClient shared = HTTPClient._internal();
  HTTPClient._internal();

  static Future<T?> get<T>(
      String url, {
        Map<String, String>? query,
        T? Function(dynamic json)? modelBuilder,
        int? timeOut = 15,
      }) async {
    return HTTPClient.shared._get(
      url,
      query: query,
      modelBuilder: modelBuilder,
      timeOut: timeOut,
    );
  }

  static Future<T?> post<T>(
      String url, {
        Map<String, String>? query,
        Map<String, dynamic>? params,
        T? Function(dynamic json)? modelBuilder,
        int? timeOut = 15,
      }) async {
    return HTTPClient.shared._post(
      url,
      query: query,
      params: params,
      modelBuilder: modelBuilder,
      timeOut: timeOut,
    );
  }

  Future<T?> _get<T>(
      String url, { 
        Map<String, String>? query, 
        T? Function(dynamic json)? modelBuilder,
        int? timeOut,
      }) async {
    final requestURL = _buildUrlWithQuery(url, query ?? {});
    var request = http.get(Uri.parse(requestURL));
    if (timeOut != null) {
      request = request.timeout(Duration(seconds: timeOut));
    }
    try {
      final response = await request;
      print('[http - get] url: $requestURL, response: ${response.body}');
      if (response.statusCode == 200) {
          final body = response.body;
          final bodyJson = jsonDecode(body);
          return modelBuilder?.call(bodyJson);
      } else {
        return null;
      }
    } catch(e, stackTrace) {
      print('[http - error] url: $url, e: $e, $stackTrace');
      return null;
    }
  }

  Future<T?> _post<T>(
      String url, {
        Map<String, String>? query,
        Map<String, dynamic>? params,
        T? Function(dynamic json)? modelBuilder,
        int? timeOut,
      }) async {
    final requestURL = _buildUrlWithQuery(url, query ?? {});
    try {
      const headers = {
        'Content-type': 'application/json',
        'Accept': 'application/json',
      };
      var request = http.post(
        Uri.parse(requestURL),
        body: jsonEncode(params),
        headers: headers,
      );
      if (timeOut != null) {
        request = request.timeout(Duration(seconds: timeOut));
      }
      final response = await request;
      print('[http - post] url: $requestURL, params: $params, response: ${response.body}');
      if (response.statusCode == 200) {
        return modelBuilder?.call(jsonDecode(response.body));
      } else {
        throw Exception('status: ${response.statusCode}, body: ${response.body}');
      }
    } catch(e, stackTrace) {
      print('[http - error] url: $url, e: $e, $stackTrace');
      return null;
    }
  }

  String _buildUrlWithQuery(String url, Map<String, dynamic> query) {
    if (query.isEmpty) {
      return url;
    }

    final queryString = query.entries.map((entry) {
      final valueEncoded = Uri.encodeComponent(entry.value.toString());
      return '${entry.key}=$valueEncoded';
    }).join('&');

    return url.contains('?') ? '$url&$queryString' : '$url?$queryString';
  }
}