import 'package:citizen_registry/core/database/app_database.dart';
import 'package:citizen_registry/core/error/failures.dart';
import 'package:citizen_registry/features/address/data/address_data.dart';
import 'package:citizen_registry/features/address/domain/address.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late StubServer server;
  late AddressRepositoryImpl repository;

  setUp(() async {
    db = await memoryDb();
    server = StubServer();
    server.routes['/ws/57035000/json/'] = (_) => json(fixture('viacep_57035000.json'));
    server.routes['/ws/99999999/json/'] = (_) => {'erro': 'true'};
    server.routes['/api/v1/localidades/estados/AL/municipios'] = (_) => [
          {
            'id': 2700102,
            'nome': 'Água Branca',
            'microrregiao': {'id': 27001}
          },
          {
            'id': 2704302,
            'nome': 'Maceió',
            'microrregiao': {'id': 27011}
          },
        ];
    final dio = stubDio(server);
    repository = AddressRepositoryImpl(ViaCepDataSource(dio), IbgeDataSource(dio), AddressCache(db.db));
  });

  tearDown(() => db.db.close());

  test('maps the real ViaCEP payload, including the IBGE code', () async {
    final result = await FindAddressByCep(repository)('57035-000');
    final address = result.when(ok: (a) => a, err: (_) => null)!;
    expect(address.city, 'Maceió');
    expect(address.uf, 'AL');
    expect(address.ibgeCode, '2704302');
    expect(address.cep, '57035000');
  });

  test('validates CEP before calling the service', () async {
    final result = await FindAddressByCep(repository)('5703');
    expect(result.when(ok: (_) => null, err: (f) => f), isA<ValidationFailure>());
    expect(server.calls, isEmpty);
  });

  test('ViaCEP "erro" answer becomes NotFoundFailure', () async {
    final result = await repository.byCep('99999999');
    expect(result.when(ok: (_) => null, err: (f) => f), const NotFoundFailure('CEP não encontrado'));
  });

  test('caches lookups and serves stale cache when offline', () async {
    await repository.byCep('57035000');
    await repository.byCep('57035000');
    expect(server.calls['/ws/57035000/json/'], 1);

    final expiredCache = AddressRepositoryImpl(
        ViaCepDataSource(stubDio(server)), IbgeDataSource(stubDio(server)), AddressCache(db.db, ttl: Duration.zero));
    server.offline = true;
    final offline = await expiredCache.byCep('57035000');
    expect(offline.when(ok: (a) => a.city, err: (_) => null), 'Maceió');
  });

  test('IBGE municipalities are cached slimmed down', () async {
    final first = await repository.citiesOf('al');
    await repository.citiesOf('AL');
    expect(first.when(ok: (c) => c, err: (_) => <City>[]), contains(const City(ibgeCode: '2704302', name: 'Maceió')));
    expect(server.calls['/api/v1/localidades/estados/AL/municipios'], 1);
    final row = await db.db.query('cities_cache');
    expect(row.single['json'], isNot(contains('microrregiao')));
  });
}
