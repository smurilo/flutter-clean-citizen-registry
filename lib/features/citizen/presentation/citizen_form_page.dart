import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../address/presentation/address_lookup.dart';
import '../domain/citizen.dart';
import 'citizen_controllers.dart';

class CitizenFormPage extends ConsumerStatefulWidget {
  const CitizenFormPage({super.key});

  @override
  ConsumerState<CitizenFormPage> createState() => _CitizenFormPageState();
}

class _CitizenFormPageState extends ConsumerState<CitizenFormPage> {
  final _name = TextEditingController();
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _cep = TextEditingController();
  final _number = TextEditingController();
  DateTime? _birthDate;

  @override
  void dispose() {
    for (final c in [_name, _cpf, _phone, _cep, _number]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(addressLookupProvider);
    final submit = ref.watch(registerControllerProvider);
    final errors = submit is SubmitInvalid ? submit.errors : const <String, String>{};

    ref.listen(registerControllerProvider, (_, next) {
      if (next is SubmitDone) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${next.citizen.name} cadastrado(a).')));
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Novo cadastro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              decoration: InputDecoration(labelText: 'Nome completo', errorText: errors['name']),
              textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          TextField(
            controller: _cpf,
            decoration: InputDecoration(labelText: 'CPF', errorText: errors['cpf']),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: 'Data de nascimento', errorText: errors['birthDate']),
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  initialDate: _birthDate ?? DateTime(1990),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
              child: Text(_birthDate == null ? 'Selecionar' : DateFormat('dd/MM/yyyy').format(_birthDate!)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: InputDecoration(labelText: 'Telefone (opcional)', errorText: errors['phone']),
            keyboardType: TextInputType.phone,
          ),
          const Divider(height: 32),
          TextField(
            controller: _cep,
            decoration: InputDecoration(
              labelText: 'CEP',
              errorText: errors['cep'] ?? (address.hasError ? '${address.error}' : null),
              suffixIcon: address.isLoading
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            // Searches ViaCEP as soon as the 8th digit is typed.
            onChanged: (v) => v.length == 8
                ? ref.read(addressLookupProvider.notifier).search(v)
                : ref.read(addressLookupProvider.notifier).clear(),
          ),
          if (address.valueOrNull case final a?)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: ListTile(
                leading: const Icon(Icons.place),
                title: Text(a.street.isEmpty ? 'CEP geral de ${a.city}' : a.street),
                subtitle: Text('${a.district} • ${a.city}/${a.uf} • IBGE ${a.ibgeCode}'),
              ),
            ),
          TextField(controller: _number, decoration: InputDecoration(labelText: 'Número', errorText: errors['number'])),
          if (errors['form'] != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(errors['form']!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: submit is SubmitSaving
                ? null
                : () => ref.read(registerControllerProvider.notifier).submit(CitizenDraft(
                      name: _name.text,
                      cpf: _cpf.text,
                      birthDate: _birthDate,
                      phone: _phone.text,
                      number: _number.text,
                      address: address.valueOrNull,
                    )),
            icon: const Icon(Icons.save),
            label: const Text('Salvar (funciona offline)'),
          ),
        ],
      ),
    );
  }
}
