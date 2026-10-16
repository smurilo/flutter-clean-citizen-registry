import 'package:citizen_registry/core/database/app_database.dart';
import 'package:citizen_registry/core/error/failures.dart';
import 'package:citizen_registry/features/address/domain/address.dart';
import 'package:citizen_registry/features/citizen/data/citizen_data.dart';
import 'package:citizen_registry/features/citizen/domain/citizen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _address = Address(
    cep: '57035000',
    street: 'Av. Eng. Mário de Gusmão',
    district: 'Ponta Verde',
    city: 'Maceió',
    uf: 'AL',
    ibgeCode: '2704302');

CitizenDraft draft(
        {String name = 'Maria da Silva',
        String cpf = '529.982.247-25',
        DateTime? birth,
        String number = '100',
        String phone = ''}) =>
    CitizenDraft(
        name: name,
        cpf: cpf,
        birthDate: birth ?? DateTime(1985, 5, 20),
        number: number,
        phone: phone,
        address: _address);

void main() {
  final today = DateTime(2026, 3, 2);

  group('validation rules', () {
    test('accepts a complete record', () {
      expect(CitizenValidator.validate(draft(phone: '(82) 99999-0000'), today: today), isEmpty);
    });

    test('reports every invalid field at once', () {
      final errors = CitizenValidator.validate(
        CitizenDraft(name: 'Ana', cpf: '111.111.111-11', birthDate: DateTime(2030), number: ' ', phone: '123'),
        today: today,
      );
      expect(errors.keys, containsAll(['name', 'cpf', 'birthDate', 'number', 'phone', 'cep']));
    });
  });

  group('register and sync', () {
    late AppDatabase db;
    late CitizenRepositoryImpl repository;
    late StubServer server;
    var id = 0;

    setUp(() async {
      id = 0;
      db = await memoryDb();
      server = StubServer();
      repository = CitizenRepositoryImpl(CitizenLocalDataSource(db.db), CitizenRemoteDataSource(stubDio(server)));
    });

    tearDown(() => db.db.close());

    RegisterCitizen register() => RegisterCitizen(repository, idGenerator: () => 'id-${id++}', clock: () => today);

    test('saves locally as pending and rejects duplicated CPF', () async {
      final first = await register()(draft());
      expect(first.when(ok: (c) => c.syncStatus, err: (_) => null), SyncStatus.pending);

      final duplicated = await register()(draft(name: 'Outra Pessoa'));
      expect(duplicated.when(ok: (_) => null, err: (f) => (f as ValidationFailure).errors['cpf']), 'CPF já cadastrado');
    });

    test('sync uploads pending records; failures stay queued without blocking others', () async {
      await register()(draft());
      await register()(draft(cpf: '111.444.777-35', name: 'João Pereira'));
      var call = 0;
      server.routes['/v1/cidadaos/id-0'] = (_) => null;
      server.routes['/v1/cidadaos/id-1'] = (_) {
        if (call++ == 0) throw Exception('timeout');
        return null;
      };

      expect(await repository.syncPending(), const SyncReport(synced: 1, failed: 1));
      expect(await repository.syncPending(), const SyncReport(synced: 1, failed: 0));
      expect(await repository.syncPending(), const SyncReport(synced: 0, failed: 0));

      final statuses = (await CitizenLocalDataSource(db.db).all()).map((c) => c.syncStatus).toSet();
      expect(statuses, {SyncStatus.synced});
    });

    test('watchAll emits again after each new record', () async {
      final emissions = <int>[];
      final sub = repository.watchAll().listen((l) => emissions.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await register()(draft());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions, [0, 1]);
    });
  });
}
