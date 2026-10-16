import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/address/data/address_data.dart';
import '../features/address/domain/address.dart';
import '../features/citizen/data/citizen_data.dart';
import '../features/citizen/domain/citizen.dart';
import 'database/app_database.dart';
import 'network/fake_government_api.dart';
import 'network/http.dart';

// Dependency graph. Every provider can be overridden in tests (ProviderScope overrides).

/// Opened in main() and injected with `overrideWithValue`.
final databaseProvider = Provider<AppDatabase>((_) => throw UnimplementedError('override in main'));

final viaCepDioProvider = Provider<Dio>((_) => buildDio('https://viacep.com.br'));
final ibgeDioProvider = Provider<Dio>((_) => buildDio('https://servicodados.ibge.gov.br'));
final governmentDioProvider =
    Provider<Dio>((_) => buildDio('https://api.cadastro-exemplo.gov.br', interceptors: [FakeGovernmentApi()]));

final addressRepositoryProvider = Provider<AddressRepository>((ref) => AddressRepositoryImpl(
      ViaCepDataSource(ref.watch(viaCepDioProvider)),
      IbgeDataSource(ref.watch(ibgeDioProvider)),
      AddressCache(ref.watch(databaseProvider).db),
    ));

final citizenRepositoryProvider = Provider<CitizenRepository>((ref) => CitizenRepositoryImpl(
      CitizenLocalDataSource(ref.watch(databaseProvider).db),
      CitizenRemoteDataSource(ref.watch(governmentDioProvider)),
    ));

final findAddressProvider = Provider((ref) => FindAddressByCep(ref.watch(addressRepositoryProvider)));

final registerCitizenProvider =
    Provider((ref) => RegisterCitizen(ref.watch(citizenRepositoryProvider), idGenerator: _uuid));

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
