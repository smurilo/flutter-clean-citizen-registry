import 'dart:io';

import 'package:dio/dio.dart';

import '../error/failures.dart';

/// One configured Dio per external service: base URL, timeouts and a retry for flaky mobile networks.
Dio buildDio(String baseUrl, {List<Interceptor> interceptors = const []}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    responseType: ResponseType.json,
  ));
  dio.interceptors
    ..add(RetryInterceptor(dio))
    ..addAll(interceptors);
  return dio;
}

/// Retries idempotent GETs on network errors with exponential backoff (300ms, 600ms).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.retries = 2});

  final Dio _dio;
  final int retries;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['attempt'] as int?) ?? 0;
    final retriable = err.requestOptions.method == 'GET' &&
        (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout);
    if (!retriable || attempt >= retries) return handler.next(err);
    await Future<void>.delayed(Duration(milliseconds: 300 * (1 << attempt)));
    try {
      final options = err.requestOptions..extra['attempt'] = attempt + 1;
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

Failure mapDioError(Object error) {
  if (error is DataException) return error.failure;
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.error is SocketException) {
      return const NetworkFailure();
    }
    return const ServerFailure();
  }
  return const ServerFailure();
}
