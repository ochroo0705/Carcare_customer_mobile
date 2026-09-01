import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    Dio? dio,
    this.accessTokenProvider,
    this.onUnauthorized,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: _normalizeBaseUrl(baseUrl),
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
               headers: const {'Accept': 'application/json'},
             ),
           );

  final Dio _dio;
  final Future<String?> Function()? accessTokenProvider;
  final Future<void> Function()? onUnauthorized;

  Future<Map<String, dynamic>> getJson(String path) async {
    try {
      final response = await _dio.get<Object?>(path, options: await _options());
      final data = response.data;
      if (data is! Map) throw const UnexpectedFailure();
      return Map<String, dynamic>.from(data);
    } on DioException catch (error) {
      await _handleUnauthorized(error);
      throw _mapDioFailure(error);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        options: await _options(),
      );
      final data = response.data;
      if (data is! Map) throw const UnexpectedFailure();
      return Map<String, dynamic>.from(data);
    } on DioException catch (error) {
      await _handleUnauthorized(error);
      throw _mapDioFailure(error);
    }
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    try {
      final response = await _dio.delete<Object?>(
        path,
        options: await _options(),
      );
      final data = response.data;
      if (data is! Map) throw const UnexpectedFailure();
      return Map<String, dynamic>.from(data);
    } on DioException catch (error) {
      await _handleUnauthorized(error);
      throw _mapDioFailure(error);
    }
  }

  Future<Options?> _options() async {
    final token = await accessTokenProvider?.call();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _handleUnauthorized(DioException error) async {
    if (error.response?.statusCode == 401 && accessTokenProvider != null) {
      await onUnauthorized?.call();
    }
  }
}

String _normalizeBaseUrl(String value) {
  final trimmed = value.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Invalid API base URL');
  }
  return trimmed;
}

AppFailure _mapDioFailure(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return const NetworkFailure();
  }
  final status = error.response?.statusCode;
  final body = error.response?.data;
  final message = body is Map && body['error'] is String
      ? body['error'] as String
      : null;
  return switch (status) {
    400 => ValidationFailure(message ?? 'Оруулсан мэдээллээ шалгана уу.'),
    401 => UnauthenticatedFailure(message ?? 'Нэвтрэх шаардлагатай.'),
    403 => ForbiddenFailure(message ?? 'Энэ үйлдлийг хийх боломжгүй байна.'),
    404 => NotFoundFailure(message ?? 'Мэдээлэл олдсонгүй.'),
    409 => ConflictFailure(message ?? 'Мэдээлэл давхардсан байна.'),
    429 => RateLimitFailure(message ?? 'Түр хүлээгээд дахин оролдоно уу.'),
    502 => ExternalServiceFailure(
      message ?? 'Гадаад үйлчилгээтэй холбогдож чадсангүй.',
    ),
    _ => ServerFailure(message ?? 'Серверийн алдаа гарлаа.'),
  };
}
