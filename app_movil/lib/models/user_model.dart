class BusinessModel {
  final int id;
  final String commercialName;
  final String? ruc;
  final String? address; 
  final String? logoUrl;
  final String? printerConfig; 
  final String? paymentInfo; 
  final double? latitud;  
  final double? longitud; 

  BusinessModel({
    required this.id,
    required this.commercialName,
    this.ruc,
    this.address,
    this.logoUrl,
    this.printerConfig,
    this.paymentInfo,
    this.latitud,
    this.longitud,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'],
      commercialName: json['nombre_comercial'] ?? "Negocio Sin Nombre",
      ruc: json['ruc'],
      address: json['direccion'],
      logoUrl: json['logo_url'],
      printerConfig: json['configuracion_impresora'], 
      paymentInfo: json['informacion_pago'], 
      latitud: json['latitud'] != null ? double.parse(json['latitud'].toString()) : null,
      longitud: json['longitud'] != null ? double.parse(json['longitud'].toString()) : null,
    );
  }
}

class UserModel {
  final int id;
  final String? codigoUnicoUsuario; // 🔥 FASE 3: Añadido para el Radar
  final String email;
  final String fullName;
  final String? phone;
  // 🔥 FASE 3: 'role' eliminado como propiedad global. 
  // Ahora el rol se obtiene del WorkspaceModel o del JWT decodificado en AuthProvider.
  final bool isActive;
  final BusinessModel? business; 

  UserModel({
    required this.id,
    this.codigoUnicoUsuario,
    required this.email,
    required this.fullName,
    this.phone,
    required this.isActive,
    this.business,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      codigoUnicoUsuario: json['codigo_unico_usuario'], // 🔥 Mapeado
      email: json['email'],
      fullName: json['nombre_completo'] ?? "Usuario",
      phone: json['telefono'],
      isActive: json['activo'] ?? true,
      business: json['negocio_data'] != null 
          ? BusinessModel.fromJson(json['negocio_data']) 
          : null,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'nombre_completo': fullName,
      'telefono': phone,
    };
  }
}