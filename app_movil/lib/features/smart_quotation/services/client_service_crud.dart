part of 'client_service.dart';

mixin _ClientServiceCrudMixin on _ClientServiceBase {
  @override
  Future<ClientModel?> getClientById(int id) async {
    try {
      final clientDataRaw = await _repository.getClientRawById(id);
      if (clientDataRaw != null) {
        final salesRows = await _repository.getClientSales(id);
        final paymentsRows = await _repository.getClientPayments(id);

        Map<String, dynamic> clientData = Map.from(clientDataRaw);
        clientData['ultimas_ventas'] = salesRows;
        clientData['ultimos_pagos'] = paymentsRows;
        return ClientModel.fromJson(clientData);
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('ClientService.getClientById', e, stack);
      return null;
    }
  }

  Future<List<ClientModel>> searchClients(String query, int negocioId) async {
    try {
      final rows = await _repository.searchClientsRaw(query, negocioId);
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e, stack) {
      AppLogger.error('ClientService.searchClients', e, stack);
      return [];
    }
  }

  Future<List<ClientModel>> getRecentClients(
    int negocioId, {
    int limit = 5,
  }) async {
    try {
      final rows = await _repository.getRecentClientsRaw(
        negocioId,
        limit: limit,
      );
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e, stack) {
      AppLogger.error('ClientService.getRecentClients', e, stack);
      return [];
    }
  }

  Future<ClientModel> createClient(
    Map<String, dynamic> clientData,
    int negocioId,
    int usuarioId,
  ) async {
    try {
      Map<String, dynamic> insertData = {
        'negocio_id': negocioId,
        'creado_por_usuario_id': usuarioId,
        'nombre_completo': clientData['nombre_completo'],
        'telefono': clientData['telefono'] ?? '',
        'dni_ruc': clientData['dni_ruc'],
        'direccion': clientData['direccion'],
        'correo': clientData['correo'],
        'notas': clientData['notas'],
        'etiquetas': jsonEncode(clientData['etiquetas'] ?? []),
        'nivel_confianza': clientData['nivel_confianza'] ?? 'bueno',
        'puntos_actuales': clientData['puntos_actuales'] ?? 0,
        'puntos_historicos': clientData['puntos_historicos'] ?? 0,
        'racha_pagos_puntuales': clientData['racha_pagos_puntuales'] ?? 0,
        'score_reputacion': clientData['score_reputacion'] ?? 500,
        'nivel_reputacion': clientData['nivel_reputacion'] ?? 'PLATA',
        'deuda_total': 0.0,
        'saldo_a_favor': 0.0,
        'entregas_pendientes': 0,
        'fecha_registro': DateTime.now().toIso8601String(),
      };
      int id = await _repository.insertClient(insertData);
      return (await getClientById(id))!;
    } catch (e) {
      throw Exception("Error creando cliente localmente: $e");
    }
  }

  Future<ClientModel> updateClient(
    int id,
    Map<String, dynamic> clientData,
  ) async {
    try {
      Map<String, dynamic> updateData = Map.from(clientData);
      if (updateData.containsKey('etiquetas') &&
          updateData['etiquetas'] is List) {
        updateData['etiquetas'] = jsonEncode(updateData['etiquetas']);
      }
      await _repository.updateClient(id, updateData);
      return (await getClientById(id))!;
    } catch (e) {
      throw Exception("Error actualizando cliente localmente: $e");
    }
  }

  Future<bool> deleteClient(int id) async {
    return await _repository.deleteClient(id);
  }

  Future<List<ClientModel>> getTrackingClients(
    int negocioId, {
    bool debtorsOnly = false,
  }) async {
    try {
      final rows = await _repository.getTrackingClientsRaw(
        negocioId,
        debtorsOnly: debtorsOnly,
      );
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ClientModel>> getAllClients(int negocioId) async {
    try {
      final rows = await _repository.getAllClientsRaw(negocioId);

      List<ClientModel> clients = [];
      for (var row in rows) {
        Map<String, dynamic> clientData = Map.from(row);
        int clientId = clientData['id'] as int;

        clientData['ultimas_ventas'] = await _repository.getClientSales(
          clientId,
        );
        clientData['ultimos_pagos'] = await _repository.getClientPayments(
          clientId,
        );

        clients.add(ClientModel.fromJson(clientData));
      }
      return clients;
    } catch (e) {
      return [];
    }
  }
}
