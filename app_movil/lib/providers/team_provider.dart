import 'package:flutter/material.dart';
import '../models/team_management_models.dart';
import '../database/local_db.dart';

class TeamProvider with ChangeNotifier {
  int? _negocioId;
  
  bool _isLoading = false;
  String _errorMessage = "";

  List<TeamMemberModel> _teamMembers = [];
  List<AccessCodeModel> _accessCodes = []; 

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<TeamMemberModel> get teamMembers => _teamMembers;
  List<AccessCodeModel> get accessCodes => _accessCodes; 

  Function()? onAuthRevoked;
  final dbHelper = LocalDatabase.instance;

  void updateContext(int? negocioId) {
    _negocioId = negocioId;
  }

  Future<void> fetchTeam(int businessId) async {
    if (_negocioId == null) return;
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final db = await dbHelper.database;
      // Buscar el dueño de este negocio específico
      final negocioRows = await db.query('negocios', where: 'id = ?', whereArgs: [_negocioId], limit: 1);
      
      if (negocioRows.isNotEmpty) {
        int idDueno = negocioRows.first['id_dueno'] as int;
        final users = await db.query('usuarios', where: 'id = ?', whereArgs: [idDueno], limit: 1);
        
        if (users.isNotEmpty) {
          _teamMembers = [
            TeamMemberModel(
              usuarioId: users.first['id'] as int,
              nombre: users.first['nombre_completo'] as String? ?? 'Dueño',
              rol: 'dueno',
              estado: 'activo',
              permisos: {}, 
            )
          ];
        }
      }
    } catch (e) {
      _errorMessage = "Error cargando usuario local.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAccessCodes(int businessId) async {
    _accessCodes = []; 
    notifyListeners();
  }

  Future<AccessCodeModel?> generateAccessCode(int businessId, String role, int maxUses, String? expirationDate) async {
    _errorMessage = "El modo offline no permite invitar a otros usuarios.";
    notifyListeners();
    return null;
  }

  Future<bool> deleteAccessCode(int businessId, int codeId) async => false;

  Future<bool> updateMemberPermissions(int businessId, int userId, Map<String, dynamic> newPermissions, String newStatus, String newRole) async {
    _errorMessage = "No puedes cambiar tus propios permisos de dueño.";
    notifyListeners();
    return false;
  }

  Future<bool> addUserDirectly(int businessId, String userCode, String role) async {
    _errorMessage = "La versión offline es exclusiva para uso en este dispositivo.";
    notifyListeners();
    return false;
  }
}