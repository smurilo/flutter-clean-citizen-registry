import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/citizen.dart';
import 'citizen_controllers.dart';
import 'citizen_form_page.dart';

class CitizenListPage extends ConsumerWidget {
  const CitizenListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citizens = ref.watch(citizensProvider);
    final pending = ref.watch(pendingCountProvider);
    final sync = ref.watch(syncControllerProvider);

    ref.listen(syncControllerProvider, (_, next) {
      final report = next.valueOrNull;
      if (report != null && report.synced + report.failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${report.synced} enviados${report.failed > 0 ? ', ${report.failed} serão reenviados' : ''}'),
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro do Cidadão'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar ($pending pendentes)',
            onPressed: pending == 0 || sync.isLoading ? null : () => ref.read(syncControllerProvider.notifier).sync(),
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: sync.isLoading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CitizenFormPage())),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo cadastro'),
      ),
      body: citizens.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao ler cadastros: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Text('Nenhum cidadão cadastrado.\nFunciona mesmo sem internet.', textAlign: TextAlign.center))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _CitizenTile(list[i]),
              ),
      ),
    );
  }
}

class _CitizenTile extends StatelessWidget {
  const _CitizenTile(this.citizen);

  final Citizen citizen;

  @override
  Widget build(BuildContext context) {
    final cpf =
        citizen.cpf.replaceAllMapped(RegExp(r'^(\d{3})(\d{3})(\d{3})(\d{2})$'), (m) => '${m[1]}.***.***-${m[4]}');
    final (icon, color, label) = switch (citizen.syncStatus) {
      SyncStatus.synced => (Icons.cloud_done, Colors.green, 'Enviado'),
      SyncStatus.pending => (Icons.schedule, Colors.orange, 'Pendente'),
      SyncStatus.failed => (Icons.sync_problem, Colors.red, 'Falhou, será reenviado'),
    };
    return ListTile(
      title: Text(citizen.name),
      subtitle: Text(
          '$cpf • ${citizen.address.city}/${citizen.address.uf} • ${DateFormat('dd/MM/yyyy').format(citizen.birthDate)}'),
      trailing: Tooltip(message: label, child: Icon(icon, color: color, semanticLabel: label)),
    );
  }
}
