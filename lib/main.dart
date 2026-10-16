import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'features/citizen/presentation/citizen_list_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final database = await AppDatabase.open();
  runApp(ProviderScope(overrides: [databaseProvider.overrideWithValue(database)], child: const CitizenRegistryApp()));
}

class CitizenRegistryApp extends StatelessWidget {
  const CitizenRegistryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cadastro do Cidadão',
        theme: ThemeData(
            colorSchemeSeed: const Color(0xFF00695C),
            useMaterial3: true,
            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const CitizenListPage(),
      );
}
