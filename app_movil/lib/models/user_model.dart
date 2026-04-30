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

  Map<String, dynamic> toSqlite(int idDueno) {
    return {
      'id': id == 0 ? null : id,
      'nombre_comercial': commercialName,
      'ruc': ruc,
      'direccion': address,
      'logo_url': logoUrl,
      'configuracion_impresora': printerConfig,
      'informacion_pago': paymentInfo,
      'latitud': latitud,
      'longitud': longitud,
      'id_dueno': idDueno,
      'fecha_creacion': DateTime.now().toIso8601String(),
    };
  }
}

class UserModel {
  final int id;
  final String? codigoUnicoUsuario; 
  final String email;
  final String fullName;
  final String? phone;
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
      codigoUnicoUsuario: json['codigo_unico_usuario'], 
      email: json['email'],
      fullName: json['nombre_completo'] ?? "Usuario",
      phone: json['telefono'],
      isActive: json['activo'] == 1 || json['activo'] == true, // Soporte SQLite
      business: json['negocio_data'] != null 
          ? BusinessModel.fromJson(json['negocio_data']) 
          : null,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id == 0 ? null : id,
      'codigo_unico_usuario': codigoUnicoUsuario,
      'nombre_completo': fullName,
      'email': email,
      'telefono': phone,
      'activo': isActive ? 1 : 0, // Soporte SQLite
      'fecha_creacion': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'nombre_completo': fullName,
      'telefono': phone,
    };
  }
}