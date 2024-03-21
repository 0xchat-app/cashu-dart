
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'response.dart';

export 'response.dart';

class HTTPClient {
  static final HTTPClient shared = HTTPClient._internal();
  HTTPClient._internal();

  static Future<CashuResponse<T>> get<T>(
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

  static Future<CashuResponse<T>> post<T>(
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

  Future<CashuResponse<T>> _get<T>(
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
      debugPrint('[http - get] url: $requestURL, response: ${response.body}, status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final bodyJson = jsonDecode(response.body);
        final data = modelBuilder?.call(bodyJson);
        if (data != null) {
          return CashuResponse(
            code: ResponseCode.success,
            data: data,
          );
        }
      } else if (response.statusCode == 400) {
        final bodyJson = jsonDecode(response.body);
        if (bodyJson is Map) {
          final code = bodyJson['code'];
          final detail = bodyJson['detail'];
          if (code != null) {
            return CashuResponse.fromErrorMap(bodyJson);
          } else if (detail != null) {
            final code = ResponseCodeEx.tryGetCodeWithErrorMsg(detail);
            if (code != null) {
              return CashuResponse(
                code: code,
                errorMsg: detail,
              );
            }
          }
        }
      }

      return CashuResponse.generalError();
    } catch(e, stackTrace) {
      debugPrint('[http - error] url: $url, e: $e, $stackTrace');
      return CashuResponse.generalError();
    }
  }

  Future<CashuResponse<T>> _post<T>(
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
      debugPrint('[http - post] url: $requestURL, params: $params, response: ${response.body}, status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final bodyJson = jsonDecode(response.body);
        final data = modelBuilder?.call(bodyJson);
        if (data != null) {
          return CashuResponse(
            code: ResponseCode.success,
            data: data,
          );
        }
      } else if (response.statusCode == 400) {
        final bodyJson = jsonDecode(response.body);
        if (bodyJson is Map) {
          final code = bodyJson['code'];
          final detail = bodyJson['detail'];
          if (code != null) {
            return CashuResponse.fromErrorMap(bodyJson);
          } else if (detail != null) {
            final code = ResponseCodeEx.tryGetCodeWithErrorMsg(detail);
            if (code != null) {
              return CashuResponse(
                code: code,
                errorMsg: detail,
              );
            }
          }
        }
      }

      return CashuResponse.generalError();
    } catch(e, stackTrace) {
      debugPrint('[http - error] url: $url, e: $e, $stackTrace');
      return CashuResponse.generalError();
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