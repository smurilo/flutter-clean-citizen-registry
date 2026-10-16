import 'package:equatable/equatable.dart';

import '../../../core/error/failures.dart';
import '../../../core/error/result.dart';

class Address extends Equatable {
  const Address({
    required this.cep,
    required this.street,
    required this.district,
    required this.city,
    required this.uf,
    required this.ibgeCode,
  });

  final String cep;
  final String street;
  final String district;
  final String city;
  final String uf;

  /// IBGE municipality code: the official key used by public-sector systems.
  final String ibgeCode;

  @override
  List<Object?> get props => [cep, street, district, city, uf, ibgeCode];
}

class City extends Equatable {
  const City({required this.ibgeCode, required this.name});

  final String ibgeCode;
  final String name;

  @override
  List<Object?> get props => [ibgeCode, name];
}

abstract interface class AddressRepository {
  Future<Result<Address>> byCep(String cep);
  Future<Result<List<City>>> citiesOf(String uf);
}

/// Validates and normalises the CEP before hitting the network.
class FindAddressByCep {
  const FindAddressByCep(this._repository);

  final AddressRepository _repository;

  Future<Result<Address>> call(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return Future.value(const Err(ValidationFailure({'cep': 'CEP deve ter 8 dígitos'})));
    return _repository.byCep(digits);
  }
}
