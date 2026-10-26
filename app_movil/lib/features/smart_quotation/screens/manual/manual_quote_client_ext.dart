part of '../manual_quotation_screen.dart';

extension _ManualQuoteClientExt on _ManualQuotationScreenState {

  void _selectClient(ClientModel client) {
    updateState(() {
      _selectedClient = client;
      _updateClientData = true; 
      _clientNameCtrl.text = client.fullName;
      _clientPhoneCtrl.text = client.phone;
      _clientDniCtrl.text = client.docNumber ?? "";
      _clientAddressCtrl.text = client.address ?? "";
      _clientEmailCtrl.text = client.email ?? "";
      _clientNotesCtrl.text = client.notes ?? "";
      _hasUnsavedChanges = true;
    });

    _generateDynamicName(force: true);
  }

  void _clearClient() {
    updateState(() {
      _selectedClient = null; _updateClientData = true; 
      _clientNameCtrl.clear(); _clientPhoneCtrl.clear(); _clientDniCtrl.clear();
      _clientAddressCtrl.clear(); _clientEmailCtrl.clear(); _clientNotesCtrl.clear();
      _hasUnsavedChanges = true;
    });
    _generateDynamicName(force: true);
  }

  void _showClientSearch() {
    ClientSearchModal.show(
      context,
      onClientSelected: (client) => _selectClient(client),
    );
  }

}

