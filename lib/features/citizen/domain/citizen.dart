import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';
import '../../address/domain/address.dart';

enum SyncStatus { pending, synced, failed }

class Citizen extends Equatable {
  const Citizen({
    required this.id,
    required this.name,
    required this.cpf,
    required this.birthDate,
    required this.address,
    required this.number,
    required this.createdAt,
    this.phone,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String name;
  final String cpf;
  final DateTime birthDate;
  final String? phone;
  final Address address;
  final String number;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  @override
  List<Object?> get props => [id, name, cpf, birthDate, phone, address, number, createdAt, syncStatus];
}

/// Raw form input; validated by [CitizenValidator] before becoming a [Citizen].
class CitizenDraft {
  const CitizenDraft(
      {required this.name, required this.cpf, required this.birthDate, required this.number, this.phone, this.address});

  final String name;
  final String cpf;
  final DateTime? birthDate;
  final String number;
  final String? phone;
  final Address? address;
}

abstract final class CitizenValidator {
  static Map<String, String> validate(CitizenDraft d, {required DateTime today}) {
    final errors = <String, String>{};
    final name = d.name.trim();
    if (name.split(RegExp(r'\s+')).length < 2 || name.length < 5) errors['name'] = 'Informe nome e sobrenome';
    if (!isValidCpf(d.cpf)) errors['cpf'] = 'CPF inválido';
    final birth = d.birthDate;
    if (birth == null) {
      errors['birthDate'] = 'Informe a data de nascimento';
    } else if (birth.isAfter(today) || today.year - birth.year > 130) {
      errors['birthDate'] = 'Data de nascimento inválida';
    }
    final phone = d.phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (phone.isNotEmpty && phone.length != 10 && phone.length != 11) errors['phone'] = 'Telefone inválido';
    if (d.address == null) errors['cep'] = 'Busque um CEP válido';
    if (d.number.trim().isEmpty) errors['number'] = 'Informe o número (ou S/N)';
    return errors;
  }

  static bool isValidCpf(String input) {
    final n = input.replaceAll(RegExp(r'\D'), '').split('').map(int.parse).toList();
    if (n.length != 11 || n.toSet().length == 1) return false;
    int dv(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += n[i] * (len + 1 - i);
      }
      final r = (sum * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return dv(9) == n[9] && dv(10) == n[10];
  }
}

abstract interface class CitizenRepository {
  Stream<List<Citizen>> watchAll();
  Future<bool> cpfExists(String cpf);
  Future<void> save(Citizen citizen);
  Future<SyncReport> syncPending();
}

class SyncReport extends Equatable {
  const SyncReport({required this.synced, required this.failed});
  final int synced;
  final int failed;

  @override
  List<Object?> get props => [synced, failed];
}

/// Saves locally first (works offline); synchronisation happens later.
class RegisterCitizen {
  RegisterCitizen(this._repository, {required String Function() idGenerator, DateTime Function()? clock})
      : _newId = idGenerator,
        _now = clock ?? DateTime.now;

  final CitizenRepository _repository;
  final String Function() _newId;
  final DateTime Function() _now;

  Future<Result<Citizen>> call(CitizenDraft draft) async {
    final now = _now();
    final errors = CitizenValidator.validate(draft, today: now);
    final cpf = draft.cpf.replaceAll(RegExp(r'\D'), '');
    if (errors.isEmpty && await _repository.cpfExists(cpf)) errors['cpf'] = 'CPF já cadastrado';
    if (errors.isNotEmpty) return Err(ValidationFailure(errors));

    final citizen = Citizen(
      id: _newId(),
      name: draft.name.trim(),
      cpf: cpf,
      birthDate: draft.birthDate!,
      phone: draft.phone?.replaceAll(RegExp(r'\D'), '').nullIfEmpty,
      address: draft.address!,
      number: draft.number.trim(),
      createdAt: now,
    );
    await _repository.save(citizen);
    return Ok(citizen);
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
