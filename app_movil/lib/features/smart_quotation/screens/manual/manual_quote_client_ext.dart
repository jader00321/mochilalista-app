part of '../manual_quotation_screen.dart';

extension _ManualQuoteClientExt on _ManualQuotationScreenState {

  void _selectClient(ClientModel client) async {
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

    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final newName = await prov.generateDynamicQuoteName(client, client.fullName, isClientRole: auth.isCommunityClient, clientUserName: auth.user?.fullName, type: 'manual');
    if (mounted) _quoteTitleCtrl.text = newName;
  }

  void _clearClient() {
    updateState(() {
      _selectedClient = null; _updateClientData = true; 
      _clientNameCtrl.clear(); _clientPhoneCtrl.clear(); _clientDniCtrl.clear();
      _clientAddressCtrl.clear(); _clientEmailCtrl.clear(); _clientNotesCtrl.clear();
      _hasUnsavedChanges = true;
    });
    _generateDynamicName();
  }

  void _showClientSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClientSearchModal(
        onClientSelected: (client) => _selectClient(client),
      ),
    );
  }

}

