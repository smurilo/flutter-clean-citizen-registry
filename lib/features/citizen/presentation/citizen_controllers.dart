import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers.dart';
import '../domain/citizen.dart';

final citizensProvider = StreamProvider<List<Citizen>>((ref) => ref.watch(citizenRepositoryProvider).watchAll());

final pendingCountProvider = Provider<int>(
    (ref) => ref.watch(citizensProvider).valueOrNull?.where((c) => c.syncStatus != SyncStatus.synced).length ?? 0);

/// Result of the last form submission.
sealed class SubmitState {
  const SubmitState();
}

class SubmitIdle extends SubmitState {
  const SubmitIdle();
}

class SubmitSaving extends SubmitState {
  const SubmitSaving();
}

class SubmitDone extends SubmitState {
  const SubmitDone(this.citizen);
  final Citizen citizen;
}

class SubmitInvalid extends SubmitState {
  const SubmitInvalid(this.errors);
  final Map<String, String> errors;
}

class RegisterController extends AutoDisposeNotifier<SubmitState> {
  @override
  SubmitState build() => const SubmitIdle();

  Future<void> submit(CitizenDraft draft) async {
    if (state is SubmitSaving) return;
    state = const SubmitSaving();
    final result = await ref.read(registerCitizenProvider)(draft);
    state = result.when(
      ok: SubmitDone.new,
      err: (f) => f is ValidationFailure ? SubmitInvalid(f.errors) : SubmitInvalid({'form': f.message}),
    );
    if (state is SubmitDone) ref.read(syncControllerProvider.notifier).sync();
  }
}

final registerControllerProvider = AutoDisposeNotifierProvider<RegisterController, SubmitState>(RegisterController.new);

/// Runs the sync queue on demand and automatically when connectivity comes back.
class SyncController extends Notifier<AsyncValue<SyncReport?>> {
  @override
  AsyncValue<SyncReport?> build() {
    final subscription = ref.watch(connectivityProvider).listen((status) {
      if (!status.contains(ConnectivityResult.none)) sync();
    });
    ref.onDispose(subscription.cancel);
    return const AsyncData(null);
  }

  Future<void> sync() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(citizenRepositoryProvider).syncPending());
  }
}

final connectivityProvider = Provider<Stream<List<ConnectivityResult>>>((_) => Connectivity().onConnectivityChanged);

final syncControllerProvider = NotifierProvider<SyncController, AsyncValue<SyncReport?>>(SyncController.new);
