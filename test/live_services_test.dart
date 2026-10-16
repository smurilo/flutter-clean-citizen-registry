@Tags(['live'])
library;

import 'package:citizen_registry/core/network/http.dart';
import 'package:citizen_registry/features/address/data/address_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Contract tests against the real public web services: detect breaking API changes early.
void main() {
  test('ViaCEP real lookup', () async {
    final db = await memoryDb();
    final repo = AddressRepositoryImpl(
      ViaCepDataSource(buildDio('https://viacep.com.br')),
      IbgeDataSource(buildDio('https://servicodados.ibge.gov.br')),
      AddressCache(db.db),
    );
    final address = await repo.byCep('57035000');
    expect(address.when(ok: (a) => '${a.city}/${a.uf}', err: (f) => f.message), 'Maceió/AL');

    final cities = await repo.citiesOf('AL');
    expect(cities.when(ok: (c) => c.length, err: (_) => 0), 102); // Alagoas has 102 municipalities
  });
}
