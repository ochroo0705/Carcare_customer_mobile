import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:dio/dio.dart';

/// Customer API-ийн нийтлэг HTTP давхарга.
///
/// Bearer token-ийг хүсэлт бүрийн өмнө secure session-оос уншина. 401 ирвэл
/// session-ийг цэвэрлэх callback дуудагдана — token-д `exp` байхгүй тул
/// хугацаа дууссан эсэхийг client талд таахгүй, server-ийн 401-г үнэн зөв
/// дохио гэж үзнэ. Бусад HTTP/network алдааг UI-д тохирох [AppFailure]
/// төрөлд нэг дор хөрвүүлнэ.
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

  /// JSON object буцаадаг GET endpoint дуудна.
  /// API-ийн хариу object биш байвал partial data-г цааш дамжуулахгүй.
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

  /// JSON object body-той POST endpoint дуудна.
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

  /// JSON object буцаадаг DELETE endpoint дуудна.
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

  /// Хүсэлт бүр дээр session token-ийг хамгийн сүүлийн утгаар нь авна.
  /// Token байхгүй public endpoint-д Authorization header нэмэхгүй.
  Future<Options?> _options() async {
    final token = await accessTokenProvider?.call();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Зөвхөн server 401 өгсөн үед session устгана.
  /// Network тасарсан эсвэл өөр статусыг logout гэж буруу үзэж болохгүй.
  Future<void> _handleUnauthorized(DioException error) async {
    if (error.response?.statusCode == 401 && accessTokenProvider != null) {
      await onUnauthorized?.call();
    }
  }
}

/// Base URL-г нэг хэлбэрт оруулж, хүсэлт эхлэхээс өмнө буруу тохиргоог барина.
String _normalizeBaseUrl(String value) {
  final trimmed = value.trim().replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Invalid API base URL');
  }
  return trimmed;
}

/// Backend-ийн `{ "error": "..." }` гэрээгээр хүний унших message-г
/// хадгална; танихгүй response бол аюулгүй ерөнхий мессеж рүү унана.
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
