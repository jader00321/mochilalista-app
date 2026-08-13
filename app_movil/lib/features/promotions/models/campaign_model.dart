class CampaignModel {
  final int id;
  final int negocioId;
  final String nombre;
  final String? tipoEstrategia;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool activo;
  final String? etiquetaEscasez;

  CampaignModel({
    required this.id,
    required this.negocioId,
    required this.nombre,
    this.tipoEstrategia,
    this.fechaInicio,
    this.fechaFin,
    this.activo = true,
    this.etiquetaEscasez,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] as int,
      negocioId: json['negocio_id'] as int,
      nombre: json['nombre'] as String,
      tipoEstrategia: json['tipo_estrategia'] as String?,
      fechaInicio: json['fecha_inicio'] != null ? DateTime.parse(json['fecha_inicio'] as String) : null,
      fechaFin: json['fecha_fin'] != null ? DateTime.parse(json['fecha_fin'] as String) : null,
      activo: (json['activo'] as int?) == 1,
      etiquetaEscasez: json['etiqueta_escasez'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'negocio_id': negocioId,
      'nombre': nombre,
      'tipo_estrategia': tipoEstrategia,
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'activo': activo ? 1 : 0,
      'etiqueta_escasez': etiquetaEscasez,
    };
  }
}
