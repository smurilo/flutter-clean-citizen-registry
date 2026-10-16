import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../../address/domain/address.dart';
import '../domain/citizen.dart';

class CitizenLocalDataSource {
  CitizenLocalDataSource(this._db);

  final Database _db;
  final _changes = StreamController<void>.broadcast();

  /// Emits the full list now and after every write (simple reactive query).
  Stream<List<Citizen>> watchAll() {
    late final StreamController<List<Citizen>> controller;
    StreamSubscription<void>? changes;
    Future<void> push() async {
      final list = await all();
      if (!controller.isClosed) controller.add(list);
    }

    controller = StreamController<List<Citizen>>(
      onListen: () {
        push();
        changes = _changes.stream.listen((_) => push());
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  Future<List<Citizen>> all() async => (await _db.query('citizens', orderBy: 'created_at DESC')).map(_fromRow).toList();

  Future<bool> cpfExists(String cpf) async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM citizens WHERE cpf = ?', [cpf]))! > 0;

  Future<void> insert(Citizen c) async {
    await _db.insert('citizens', _toRow(c));
    _changes.add(null);
  }

  Future<List<Citizen>> pending({int maxAttempts = 5}) async => (await _db.query(
        'citizens',
        where: "sync_status != 'synced' AND sync_attempts < ?",
        whereArgs: [maxAttempts],
        orderBy: 'created_at',
      ))
          .map(_fromRow)
          .toList();

  Future<void> mark(String id, SyncStatus status) async {
    await _db.rawUpdate(
      'UPDATE citizens SET sync_status = ?, sync_attempts = sync_attempts + 1 WHERE id = ?',
      [status.name, id],
    );
    _changes.add(null);
  }

  Map<String, Object?> _toRow(Citizen c) => {
        'id': c.id,
        'name': c.name,
        'cpf': c.cpf,
        'birth_date': c.birthDate.toIso8601String(),
        'phone': c.phone,
        'cep': c.address.cep,
        'street': c.address.street,
        'number': c.number,
        'district': c.address.district,
        'city': c.address.city,
        'uf': c.address.uf,
        'ibge_code': c.address.ibgeCode,
        'created_at': c.createdAt.toIso8601String(),
        'sync_status': c.syncStatus.name,
      };

  Citizen _fromRow(Map<String, Object?> r) => Citizen(
        id: r['id']! as String,
        name: r['name']! as String,
        cpf: r['cpf']! as String,
        birthDate: DateTime.parse(r['birth_date']! as String),
        phone: r['phone'] as String?,
        number: r['number']! as String,
        createdAt: DateTime.parse(r['created_at']! as String),
        syncStatus: SyncStatus.values.byName(r['sync_status']! as String),
        address: Address(
          cep: r['cep']! as String,
          street: r['street']! as String,
          district: r['district']! as String,
          city: r['city']! as String,
          uf: r['uf']! as String,
          ibgeCode: r['ibge_code']! as String,
        ),
      );
}

/// Government backend. PUT by client-generated id makes the upload idempotent on retries.
class CitizenRemoteDataSource {
  const CitizenRemoteDataSource(this._dio);

  final Dio _dio;

  Future<void> upload(Citizen c) => _dio.put<void>('/v1/cidadaos/${c.id}', data: {
        'nome': c.name,
        'cpf': c.cpf,
        'nascimento': c.birthDate.toIso8601String().substring(0, 10),
        'telefone': c.phone,
        'endereco': {
          'cep': c.address.cep,
          'logradouro': c.address.street,
          'numero': c.number,
          'bairro': c.address.district,
          'codigoIbge': c.address.ibgeCode,
          'uf': c.address.uf,
        },
      });
}

class CitizenRepositoryImpl implements CitizenRepository {
  CitizenRepositoryImpl(this._local, this._remote);

  final CitizenLocalDataSource _local;
  final CitizenRemoteDataSource _remote;
  bool _syncing = false;

  @override
  Stream<List<Citizen>> watchAll() => _local.watchAll();

  @override
  Future<bool> cpfExists(String cpf) => _local.cpfExists(cpf);

  @override
  Future<void> save(Citizen citizen) => _local.insert(citizen);

  /// Uploads one by one; a failing record is marked and retried later without blocking the rest.
  @override
  Future<SyncReport> syncPending() async {
    if (_syncing) return const SyncReport(synced: 0, failed: 0);
    _syncing = true;
    var synced = 0;
    var failed = 0;
    try {
      for (final c in await _local.pending()) {
        try {
          await _remote.upload(c);
          await _local.mark(c.id, SyncStatus.synced);
          synced++;
        } catch (_) {
          await _local.mark(c.id, SyncStatus.failed);
          failed++;
        }
      }
    } finally {
      _syncing = false;
    }
    return SyncReport(synced: synced, failed: failed);
  }
}
