import 'dart:io';
import 'dart:typed_data';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.build);
  final DioException Function(RequestOptions options) build;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw build(options);

  @override
  void close({bool force = false}) {}
}

ApiClient _client(DioException Function(RequestOptions) build) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
    ..httpClientAdapter = _ThrowingAdapter(build);
  return ApiClient(baseUrl: 'https://example.test/api', dio: dio);
}

Future<Object> _failureFor(DioExceptionType type, {Object? error}) async {
  final client = _client(
    (o) => DioException(requestOptions: o, type: type, error: error),
  );
  try {
    await client.getJson('/x');
  } on Object catch (e) {
    return e;
  }
  throw StateError('expected a failure');
}

void main() {
  group('ApiClient failure mapping', () {
    test('timeouts and connection errors map to NetworkFailure', () async {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        expect(await _failureFor(type), isA<NetworkFailure>(), reason: '$type');
      }
    });

    test('badCertificate maps to NetworkFailure', () async {
      expect(
        await _failureFor(DioExceptionType.badCertificate),
        isA<NetworkFailure>(),
      );
    });

    test('unknown wrapping SocketException maps to NetworkFailure', () async {
      expect(
        await _failureFor(
          DioExceptionType.unknown,
          error: const SocketException('down'),
        ),
        isA<NetworkFailure>(),
      );
    });

    test('unknown with other error stays ServerFailure', () async {
      expect(
        await _failureFor(DioExceptionType.unknown, error: StateError('x')),
        isA<ServerFailure>(),
      );
    });

    test('cancel maps to RequestCancelledFailure, not ServerFailure', () async {
      final failure = await _failureFor(DioExceptionType.cancel);
      expect(failure, isA<RequestCancelledFailure>());
      expect(failure, isNot(isA<ServerFailure>()));
    });

    test('all four verbs share the mapping', () async {
      final client = _client(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(client.getJson('/x'), throwsA(isA<NetworkFailure>()));
      await expectLater(
        client.postJson('/x', {}),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        client.patchJson('/x', {}),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        client.deleteJson('/x'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
