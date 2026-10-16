import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão. Verifique sua internet.']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Serviço temporariamente indisponível.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(this.errors) : super('Dados inválidos');

  /// field → message
  final Map<String, String> errors;

  @override
  List<Object?> get props => [errors];
}

/// Thrown by data sources, converted into [Failure] by repositories.
class DataException implements Exception {
  const DataException(this.failure);
  final Failure failure;
}
