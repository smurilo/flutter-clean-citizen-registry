import 'dart:math';

import 'package:dio/dio.dart';

/// Stand-in for the government registration API (not public). ViaCEP and IBGE are real.
/// Fails ~30% of uploads to demonstrate the offline sync queue.
class FakeGovernmentApi extends Interceptor {
  FakeGovernmentApi({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!options.path.startsWith('/v1/cidadaos/')) return handler.next(options);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_random.nextDouble() < 0.3) {
      return handler
          .reject(DioException.connectionTimeout(timeout: const Duration(seconds: 8), requestOptions: options));
    }
    handler.resolve(Response(requestOptions: options, statusCode: 204));
  }
}
