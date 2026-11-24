import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/models.dart';

/// Hosted API (Vercel). Replace with your deployment's URL, including `/api`.
const String kHostedApiUrl = 'https://deal-on-wheels-api.vercel.app/api';

/// Optional override for local development only:
///   flutter run --dart-define=API_BASE_URL=http://localhost:4000/api
const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

String resolveBaseUrl() => _envBaseUrl.isNotEmpty ? _envBaseUrl : kHostedApiUrl;

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiException(this.message, {this.statusCode, this.details});

  /// Message plus per-field validation errors from zod, if any.
  String get friendly {
    final d = details;
    if (d == null || d.isEmpty) return message;
    final lines = d.entries.map((e) {
      final v = e.value;
      return '${e.key}: ${v is List ? v.join(', ') : v}';
    });
    return '$message\n${lines.join('\n')}';
  }

  @override
  String toString() => friendly;
}

/// An image picked on the device, already read into memory.
class PickedImage {
  final String name;
  final Uint8List bytes;
  const PickedImage(this.name, this.bytes);
}

/// The API only accepts JPEG, PNG and WebP. Detect from magic bytes so we do
/// not depend on file extensions.
String? sniffImageMime(Uint8List b) {
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return 'jpeg';
  if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return 'png';
  }
  if (b.length > 12 &&
      b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && // RIFF
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) { // WEBP
    return 'webp';
  }
  return null;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final String baseUrl = resolveBaseUrl();
  final http.Client _client = http.Client();

  String? token;

  /// Called when an authenticated request comes back 401 (expired token).
  VoidCallback? onUnauthorized;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isNotEmpty) q[k] = s;
    });
    return Uri.parse('$baseUrl$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  // ------------------------------------------------------------ plumbing

  Future<dynamic> _send(
    Future<http.Response> Function() call, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    http.Response res;
    try {
      res = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException('The request timed out. Please try again.');
    } catch (_) {
      throw ApiException('Cannot reach the server at $baseUrl');
    }

    dynamic body;
    String raw = '';
    if (res.bodyBytes.isNotEmpty) {
      raw = utf8.decode(res.bodyBytes, allowMalformed: true);
      try {
        body = jsonDecode(raw);
      } catch (_) {
        body = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    if (res.statusCode == 401 && token != null) onUnauthorized?.call();

    debugPrint('API error ${res.statusCode} ${res.request?.method} ${res.request?.url}: $raw');
    String message;
    if (body is Map && body['error'] is String) {
      message = body['error'] as String;
    } else if (res.statusCode == 413) {
      message = 'The upload is too large for the server (HTTP 413).';
    } else {
      final snippet = raw.trim();
      message = 'Request failed (HTTP ${res.statusCode})'
          '${snippet.isEmpty ? '' : ': ${snippet.length > 160 ? snippet.substring(0, 160) : snippet}'}';
    }
    final details = (body is Map && body['details'] is Map)
        ? Map<String, dynamic>.from(body['details'] as Map)
        : null;
    throw ApiException(message, statusCode: res.statusCode, details: details);
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) =>
      _send(() => _client.get(_uri(path, query), headers: _headers));

  /// POST/PUT/PATCH always send a JSON body (`{}` when empty): Express 5 leaves
  /// `req.body` undefined otherwise and the zod body schemas would reject it.
  Future<dynamic> _json(String method, String path, [Object? body]) => _send(() async {
        final req = http.Request(method, _uri(path));
        req.headers.addAll(_headers);
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body ?? <String, dynamic>{});
        return http.Response.fromStream(await _client.send(req));
      });

  Future<dynamic> _delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  Future<dynamic> _multipart(
    String method,
    String path,
    String field,
    List<PickedImage> files,
  ) =>
      _send(() async {
        final req = http.MultipartRequest(method, _uri(path));
        req.headers.addAll(_headers);
        for (final f in files) {
          final kind = sniffImageMime(f.bytes) ?? 'jpeg';
          req.files.add(http.MultipartFile.fromBytes(
            field,
            f.bytes,
            filename: f.name.isEmpty ? 'upload.$kind' : f.name,
            contentType: MediaType('image', kind),
          ));
        }
        return http.Response.fromStream(await req.send());
      }, timeout: const Duration(seconds: 90));

  // ---------------------------------------------------------------- auth

  Future<AuthResult> login(String email, String password) async {
    final j = await _json('POST', '/auth/login', {'email': email, 'password': password});
    return AuthResult(User.fromJson(Map<String, dynamic>.from(j['user'] as Map)), j['token'] as String);
  }

  Future<AuthResult> register(String username, String email, String password) async {
    final j = await _json('POST', '/auth/register',
        {'username': username, 'email': email, 'password': password});
    return AuthResult(User.fromJson(Map<String, dynamic>.from(j['user'] as Map)), j['token'] as String);
  }

  // --------------------------------------------------------------- users

  Future<User> getMe() async {
    final j = await _get('/users/me');
    return User.fromJson(Map<String, dynamic>.from(j['user'] as Map));
  }

  Future<User> updateProfile(Map<String, dynamic> changes) async {
    final j = await _json('PATCH', '/users/me', changes);
    return User.fromJson(Map<String, dynamic>.from(j['user'] as Map));
  }

  Future<User> setPicture(PickedImage image) async {
    final j = await _multipart('PUT', '/users/me/picture', 'avatar', [image]);
    return User.fromJson(Map<String, dynamic>.from(j['user'] as Map));
  }

  Future<void> removePicture() async {
    await _delete('/users/me/picture');
  }

  // ------------------------------------------------------------ vehicles

  Future<Paged<Vehicle>> listVehicles(VehicleFilters f, {int page = 1, int limit = 20}) async {
    final j = await _get('/vehicles', {...f.toQuery(), 'page': page, 'limit': limit});
    return Paged.fromJson(Map<String, dynamic>.from(j as Map), Vehicle.fromJson);
  }

  Future<Vehicle> getVehicle(String id) async {
    final j = await _get('/vehicles/$id');
    return Vehicle.fromJson(Map<String, dynamic>.from(j['vehicle'] as Map));
  }

  Future<Vehicle> createVehicle(Map<String, dynamic> data) async {
    final j = await _json('POST', '/vehicles', data);
    return Vehicle.fromJson(Map<String, dynamic>.from(j['vehicle'] as Map));
  }

  Future<Vehicle> updateVehicle(String id, Map<String, dynamic> data) async {
    final j = await _json('PATCH', '/vehicles/$id', data);
    return Vehicle.fromJson(Map<String, dynamic>.from(j['vehicle'] as Map));
  }

  Future<void> deleteVehicle(String id) async {
    await _delete('/vehicles/$id');
  }

  /// Uploads one photo per request so a single request never exceeds
  /// serverless body limits (Vercel: ~4.5 MB). Throws if any photo failed,
  /// saying how many made it.
  Future<void> addVehicleImages(String id, List<PickedImage> images) async {
    var ok = 0;
    ApiException? last;
    for (final img in images) {
      try {
        await _multipart('POST', '/vehicles/$id/images', 'images', [img]);
        ok++;
      } on ApiException catch (e) {
        last = e;
      }
    }
    if (last != null) {
      throw ApiException(
        ok == 0
            ? last.friendly
            : 'Only $ok of ${images.length} photos uploaded. ${last.friendly}',
        statusCode: last.statusCode,
      );
    }
  }

  Future<void> deleteVehicleImage(String vehicleId, String imageId) async {
    await _delete('/vehicles/$vehicleId/images/$imageId');
  }

  // -------------------------------------------------------- transactions

  /// Buyer starts a deal. [agreedPrice] defaults to the listed price.
  Future<DealTransaction> createTransaction(String vehicleId, {int? agreedPrice}) async {
    final j = await _json('POST', '/vehicles/$vehicleId/transactions',
        {if (agreedPrice != null) 'agreedPrice': agreedPrice});
    return DealTransaction.fromJson(Map<String, dynamic>.from(j['transaction'] as Map));
  }

  Future<Paged<DealTransaction>> listTransactions({
    String? role,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final j = await _get('/transactions', {
      'role': role,
      'status': status,
      'page': page,
      'limit': limit,
    });
    return Paged.fromJson(Map<String, dynamic>.from(j as Map), DealTransaction.fromJson);
  }

  Future<DealTransaction> getTransaction(String id) async {
    final j = await _get('/transactions/$id');
    return DealTransaction.fromJson(Map<String, dynamic>.from(j['transaction'] as Map));
  }

  /// Seller only: pending -> completed (vehicle becomes sold).
  Future<DealTransaction> completeTransaction(String id) async {
    final j = await _json('POST', '/transactions/$id/complete');
    return DealTransaction.fromJson(Map<String, dynamic>.from(j['transaction'] as Map));
  }

  /// Buyer or seller: pending -> cancelled (vehicle becomes available again).
  Future<DealTransaction> cancelTransaction(String id) async {
    final j = await _json('POST', '/transactions/$id/cancel');
    return DealTransaction.fromJson(Map<String, dynamic>.from(j['transaction'] as Map));
  }
}

final api = ApiService.instance;
