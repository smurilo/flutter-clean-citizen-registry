import 'dart:convert';
import 'dart:io';

import 'package:citizen_registry/core/database/app_database.dart';
import 'package:dio/dio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> memoryDb() {
  sqfliteFfiInit();
  return AppDatabase.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
}

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Programmable HTTP stub: path → handler. Counts calls to assert caching.
class StubServer extends Interceptor {
  final Map<String, Object? Function(RequestOptions)> routes = {};
  final Map<String, int> calls = {};
  bool offline = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls.update(options.path, (v) => v + 1, ifAbsent: () => 1);
    if (offline) {
      return handler.reject(DioException.connectionError(requestOptions: options, reason: 'offline'), true);
    }
    final route = routes[options.path];
    if (route == null) {
      return handler.reject(
          DioException.badResponse(
              statusCode: 404, requestOptions: options, response: Response(requestOptions: options, statusCode: 404)),
          true);
    }
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: route(options)));
  }
}

Dio stubDio(StubServer server) => Dio(BaseOptions(baseUrl: 'https://stub'))..interceptors.add(server);

Object? json(String text) => jsonDecode(text);
