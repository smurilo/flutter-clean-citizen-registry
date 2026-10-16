import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../../core/network/http.dart';
import '../domain/address.dart';

/// ViaCEP public web service: https://viacep.com.br/ws/{cep}/json/
class ViaCepDataSource {
  const ViaCepDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetch(String cep) async {
    final response = await _dio.get<Map<String, dynamic>>('/ws/$cep/json/');
    final json = response.data!;
    // ViaCEP answers HTTP 200 with {"erro": true} (or "true") for unknown CEPs.
    if (json['erro'] == true || json['erro'] == 'true') {
      throw const DataException(NotFoundFailure('CEP não encontrado'));
    }
    return json;
  }
}

/// IBGE Localidades API: https://servicodados.ibge.gov.br/api/v1/localidades/estados/{UF}/municipios
class IbgeDataSource {
  const IbgeDataSource(this._dio);

  final Dio _dio;

  Future<List<dynamic>> municipalities(String uf) async {
    final response = await _dio
        .get<List<dynamic>>('/api/v1/localidades/estados/$uf/municipios', queryParameters: {'orderBy': 'nome'});
    return response.data!;
  }
}

/// SQLite cache: addresses rarely change, and field agents often work without signal.
class AddressCache {
  const AddressCache(this._db, {this.ttl = const Duration(days: 30)});

  final Database _db;
  final Duration ttl;

  Future<String?> read(String table, String keyColumn, String key, {DateTime? now, bool ignoreTtl = false}) async {
    final rows = await _db.query(table, where: '$keyColumn = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    final fetchedAt = DateTime.parse(rows.first['fetched_at']! as String);
    if (!ignoreTtl && (now ?? DateTime.now()).difference(fetchedAt) > ttl) return null;
    return rows.first['json']! as String;
  }

  Future<void> write(String table, String keyColumn, String key, String json, {DateTime? now}) => _db.insert(
        table,
        {keyColumn: key, 'json': json, 'fetched_at': (now ?? DateTime.now()).toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}

class AddressRepositoryImpl implements AddressRepository {
  AddressRepositoryImpl(this._viaCep, this._ibge, this._cache);

  final ViaCepDataSource _viaCep;
  final IbgeDataSource _ibge;
  final AddressCache _cache;

  @override
  Future<Result<Address>> byCep(String cep) async {
    final fresh = await _cache.read('cep_cache', 'cep', cep);
    if (fresh != null) return Ok(_toAddress(jsonDecode(fresh) as Map<String, dynamic>));
    try {
      final json = await _viaCep.fetch(cep);
      await _cache.write('cep_cache', 'cep', cep, jsonEncode(json));
      return Ok(_toAddress(json));
    } catch (e) {
      final failure = mapDioError(e);
      // Stale cache beats no answer when offline.
      final stale = failure is NetworkFailure ? await _cache.read('cep_cache', 'cep', cep, ignoreTtl: true) : null;
      return stale != null ? Ok(_toAddress(jsonDecode(stale) as Map<String, dynamic>)) : Err(failure);
    }
  }

  @override
  Future<Result<List<City>>> citiesOf(String uf) async {
    final key = uf.toUpperCase();
    final cached = await _cache.read('cities_cache', 'uf', key);
    if (cached != null) return Ok(_toCities(jsonDecode(cached) as List<dynamic>));
    try {
      final json = await _ibge.municipalities(key);
      // Store only what we use: the full IBGE payload is ~1 MB for large states.
      final slim = [
        for (final m in json) {'id': (m as Map)['id'], 'nome': m['nome']}
      ];
      await _cache.write('cities_cache', 'uf', key, jsonEncode(slim));
      return Ok(_toCities(slim));
    } catch (e) {
      return Err(mapDioError(e));
    }
  }

  static Address _toAddress(Map<String, dynamic> j) => Address(
        cep: (j['cep'] as String).replaceAll('-', ''),
        street: j['logradouro'] as String? ?? '',
        district: j['bairro'] as String? ?? '',
        city: j['localidade'] as String,
        uf: j['uf'] as String,
        ibgeCode: j['ibge'] as String,
      );

  static List<City> _toCities(List<dynamic> json) =>
      [for (final m in json) City(ibgeCode: '${(m as Map)['id']}', name: m['nome'] as String)];
}
