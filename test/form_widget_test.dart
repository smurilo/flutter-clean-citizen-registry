import 'package:citizen_registry/core/error/result.dart';
import 'package:citizen_registry/core/providers.dart';
import 'package:citizen_registry/features/address/domain/address.dart';
import 'package:citizen_registry/features/citizen/presentation/citizen_controllers.dart';
import 'package:citizen_registry/features/citizen/presentation/citizen_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

class _FakeAddresses implements AddressRepository {
  @override
  Future<Result<Address>> byCep(String cep) async => const Ok(Address(
      cep: '57035000',
      street: 'Av. Eng. Mário de Gusmão',
      district: 'Ponta Verde',
      city: 'Maceió',
      uf: 'AL',
      ibgeCode: '2704302'));

  @override
  Future<Result<List<City>>> citiesOf(String uf) async => const Ok([]);
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('CEP autocompletes the address and validation messages appear inline', (tester) async {
    final db = await tester.runAsync(memoryDb);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db!),
        addressRepositoryProvider.overrideWithValue(_FakeAddresses()),
        connectivityProvider.overrideWithValue(const Stream.empty()),
      ],
      child: const MaterialApp(home: CitizenListPage()),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum cidadão'), findsOneWidget);

    await tester.tap(find.text('Novo cadastro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'CEP'), '57035000');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Av. Eng. Mário de Gusmão'), findsOneWidget);
    expect(find.textContaining('IBGE 2704302'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'CPF'), '11111111111');
    await tester.dragUntilVisible(find.byType(FilledButton), find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Informe o número (ou S/N)'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('CPF inválido'), findsOneWidget);
    expect(find.text('Informe nome e sobrenome'), findsOneWidget);
    expect(find.text('Informe a data de nascimento'), findsOneWidget);
  });
}
