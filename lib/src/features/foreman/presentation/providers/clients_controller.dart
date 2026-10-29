import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../application/foreman_workflow_progress_controller.dart';
import '../../data/clients_repository.dart';
import '../../domain/entities/foreman_workflow_step.dart';
import '../../domain/entities/client.dart';
export '../../domain/entities/client.dart';

final clientsProvider = AsyncNotifierProvider<ClientsNotifier, List<Client>>(
  ClientsNotifier.new,
);

/// The company's clients. Saves wait for the server and then replace the
/// local copy with what it returned; a failed save throws and leaves the list
/// as it was.
class ClientsNotifier extends AsyncNotifier<List<Client>> {
  ClientsRepository get _repository => ref.read(clientsRepositoryProvider);

  @override
  Future<List<Client>> build() async {
    final repository = ref.watch(clientsRepositoryProvider);
    if (!await watchForemanScope(ref)) return const [];
    return repository.list();
  }

  Future<Client> addClient({
    required String name,
    required int activeProjects,
    required ClientType type,
    required ClientStatus status,
    required ClientContactMethod preferredContactMethod,
    required String notes,
    required String email,
    required String phone,
    required String addressLine1,
    required String city,
    required String stateProvince,
    required String zipCode,
    required String contactPerson,
  }) async {
    final created = await _repository.create(
      Client(
        id: '',
        name: name,
        activeProjects: activeProjects,
        type: type,
        status: status,
        preferredContactMethod: preferredContactMethod,
        notes: notes,
        email: email,
        phone: phone,
        addressLine1: addressLine1,
        city: city,
        state: stateProvince,
        zipCode: zipCode,
        contactPerson: contactPerson,
      ),
    );
    _upsert(created);
    unawaited(
      ref
          .read(foremanWorkflowProgressProvider.notifier)
          .markComplete(ForemanWorkflowStep.addClient),
    );
    return created;
  }

  Future<Client> updateClient({
    required String id,
    required String name,
    required int activeProjects,
    required ClientType type,
    required ClientStatus status,
    required ClientContactMethod preferredContactMethod,
    required String notes,
    required String email,
    required String phone,
    required String addressLine1,
    required String city,
    required String stateProvince,
    required String zipCode,
    required String contactPerson,
  }) async {
    final updated = await _repository.update(
      Client(
        id: id,
        name: name,
        activeProjects: activeProjects,
        type: type,
        status: status,
        preferredContactMethod: preferredContactMethod,
        notes: notes,
        email: email,
        phone: phone,
        addressLine1: addressLine1,
        city: city,
        state: stateProvince,
        zipCode: zipCode,
        contactPerson: contactPerson,
      ),
    );
    _upsert(updated);
    return updated;
  }

  /// Puts [client] into the list in place of the one with its id. If the list
  /// has not loaded yet, reloads it instead; the reload includes [client].
  void _upsert(Client client) {
    final current = state.value;
    if (current == null) return ref.invalidateSelf();
    final index = current.indexWhere((c) => c.id == client.id);
    state = AsyncData(
      index < 0 ? [...current, client] : ([...current]..[index] = client),
    );
  }

  Client? findById(String id) {
    for (final client in state.value ?? const <Client>[]) {
      if (client.id == id) return client;
    }
    return null;
  }
}
