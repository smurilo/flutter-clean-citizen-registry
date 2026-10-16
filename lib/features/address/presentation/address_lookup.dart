import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/address.dart';

/// Async state of the CEP lookup shown in the form.
class AddressLookupNotifier extends AutoDisposeNotifier<AsyncValue<Address?>> {
  int _request = 0;

  @override
  AsyncValue<Address?> build() => const AsyncData(null);

  Future<void> search(String cep) async {
    final request = ++_request;
    state = const AsyncLoading();
    final result = await ref.read(findAddressProvider)(cep);
    if (request != _request) return; // a newer search superseded this one
    state = result.when(ok: AsyncData.new, err: (f) => AsyncError(f.message, StackTrace.current));
  }

  void clear() => state = const AsyncData(null);
}

final addressLookupProvider =
    AutoDisposeNotifierProvider<AddressLookupNotifier, AsyncValue<Address?>>(AddressLookupNotifier.new);

final citiesProvider = FutureProvider.autoDispose.family<List<City>, String>((ref, uf) async {
  final result = await ref.watch(addressRepositoryProvider).citiesOf(uf);
  return result.when(ok: (c) => c, err: (f) => throw f.message);
});
