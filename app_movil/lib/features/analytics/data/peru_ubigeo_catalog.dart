library;

/// Catálogo Geográfico Oficial del Perú y Corredores Logísticos para el Radar Comercial IA
/// Abarca las 25 regiones oficiales (24 departamentos + Provincia Constitucional del Callao)
/// y sus 196 provincias con mapeo de corredores viales/logísticos y distritos sugeridos.

class DepartmentInfo {
  final String name;
  final String mainCorridor;
  final List<ProvinceInfo> provinces;

  const DepartmentInfo({
    required this.name,
    required this.mainCorridor,
    required this.provinces,
  });
}

class ProvinceInfo {
  final String name;
  final List<String> keyDistricts;

  const ProvinceInfo({
    required this.name,
    this.keyDistricts = const [],
  });
}

class PeruUbigeoCatalog {
  static const List<DepartmentInfo> departments = [
    DepartmentInfo(
      name: 'Amazonas',
      mainCorridor: 'Carretera Fernando Belaúnde Terry / Eje Chachapoyas-Bagua',
      provinces: [
        ProvinceInfo(name: 'Chachapoyas', keyDistricts: ['Chachapoyas', 'Huancas', 'Levanto']),
        ProvinceInfo(name: 'Bagua', keyDistricts: ['Bagua', 'Aramango', 'Imaza', 'La Peca']),
        ProvinceInfo(name: 'Bongará', keyDistricts: ['Jumbilla', 'Florida', 'Shipasbamba']),
        ProvinceInfo(name: 'Condorcanqui', keyDistricts: ['Nieva', 'El Cenepa', 'Río Santiago']),
        ProvinceInfo(name: 'Luya', keyDistricts: ['Lámud', 'Camporredondo', 'Ocalli']),
        ProvinceInfo(name: 'Rodríguez de Mendoza', keyDistricts: ['San Nicolás', 'Omia']),
        ProvinceInfo(name: 'Utcubamba', keyDistricts: ['Bagua Grande', 'Cajaruro', 'Lonya Grande']),
      ],
    ),
    DepartmentInfo(
      name: 'Áncash',
      mainCorridor: 'Panamericana Norte / Callejón de Huaylas',
      provinces: [
        ProvinceInfo(name: 'Huaraz', keyDistricts: ['Huaraz', 'Independencia', 'Tarica']),
        ProvinceInfo(name: 'Santa', keyDistricts: ['Chimbote', 'Nuevo Chimbote', 'Coishco', 'Santa', 'Nepeña']),
        ProvinceInfo(name: 'Aija', keyDistricts: ['Aija']),
        ProvinceInfo(name: 'Antonio Raymondi', keyDistricts: ['Llamellín']),
        ProvinceInfo(name: 'Asunción', keyDistricts: ['Chacas']),
        ProvinceInfo(name: 'Bolognesi', keyDistricts: ['Chiquián']),
        ProvinceInfo(name: 'Carhuaz', keyDistricts: ['Carhuaz', 'Marcara']),
        ProvinceInfo(name: 'Carlos Fermín Fitzcarrald', keyDistricts: ['San Luis']),
        ProvinceInfo(name: 'Casma', keyDistricts: ['Casma', 'Comandante Noel']),
        ProvinceInfo(name: 'Corongo', keyDistricts: ['Corongo']),
        ProvinceInfo(name: 'Huari', keyDistricts: ['Huari', 'San Marcos', 'Chavín de Huántar']),
        ProvinceInfo(name: 'Huarmey', keyDistricts: ['Huarmey', 'Culebras']),
        ProvinceInfo(name: 'Huaylas', keyDistricts: ['Caraz', 'Pueblo Libre']),
        ProvinceInfo(name: 'Mariscal Luzuriaga', keyDistricts: ['Piscobamba']),
        ProvinceInfo(name: 'Ocros', keyDistricts: ['Ocros']),
        ProvinceInfo(name: 'Pallasca', keyDistricts: ['Cabana', 'Pallasca']),
        ProvinceInfo(name: 'Pomabamba', keyDistricts: ['Pomabamba']),
        ProvinceInfo(name: 'Recuay', keyDistricts: ['Recuay', 'Ticapampa', 'Catac']),
        ProvinceInfo(name: 'Sihuas', keyDistricts: ['Sihuas']),
        ProvinceInfo(name: 'Yungay', keyDistricts: ['Yungay', 'Mancos', 'Ranrahirca']),
      ],
    ),
    DepartmentInfo(
      name: 'Apurímac',
      mainCorridor: 'Corredor Minero / Eje Abancay-Andahuaylas',
      provinces: [
        ProvinceInfo(name: 'Abancay', keyDistricts: ['Abancay', 'Tamburco']),
        ProvinceInfo(name: 'Andahuaylas', keyDistricts: ['Andahuaylas', 'San Jerónimo', 'Talavera']),
        ProvinceInfo(name: 'Antabamba', keyDistricts: ['Antabamba']),
        ProvinceInfo(name: 'Aymaraes', keyDistricts: ['Chalhuanca']),
        ProvinceInfo(name: 'Cotabambas', keyDistricts: ['Tambobamba', 'Challhuahuacho']),
        ProvinceInfo(name: 'Chincheros', keyDistricts: ['Chincheros', 'Uripa']),
        ProvinceInfo(name: 'Grau', keyDistricts: ['Chuquibambilla']),
      ],
    ),
    DepartmentInfo(
      name: 'Arequipa',
      mainCorridor: 'Panamericana Sur / Interoceánica Sur',
      provinces: [
        ProvinceInfo(
          name: 'Arequipa',
          keyDistricts: [
            'Arequipa', 'Cayma', 'Cerro Colorado', 'Paucarpata', 'Yanahuara',
            'José Luis Bustamante y Rivero', 'Socabaya', 'Miraflores', 'Mariano Melgar',
          ],
        ),
        ProvinceInfo(name: 'Camaná', keyDistricts: ['Camaná', 'José María Quimper', 'Samuel Pastor']),
        ProvinceInfo(name: 'Caravelí', keyDistricts: ['Caravelí', 'Chala', 'Atico']),
        ProvinceInfo(name: 'Castilla', keyDistricts: ['Aplao', 'Orcopampa']),
        ProvinceInfo(name: 'Caylloma', keyDistricts: ['Chivay', 'Majes', 'Cabanaconde']),
        ProvinceInfo(name: 'Condesuyos', keyDistricts: ['Chuquibamba']),
        ProvinceInfo(name: 'Islay', keyDistricts: ['Mollendo', 'Matarani', 'Cocachacra']),
        ProvinceInfo(name: 'La Unión', keyDistricts: ['Cotahuasi']),
      ],
    ),
    DepartmentInfo(
      name: 'Ayacucho',
      mainCorridor: 'Vía Los Libertadores / Longitudinal de la Sierra',
      provinces: [
        ProvinceInfo(name: 'Huamanga', keyDistricts: ['Ayacucho', 'Carmen Alto', 'San Juan Bautista', 'Jesús Nazareno']),
        ProvinceInfo(name: 'Cangallo', keyDistricts: ['Cangallo']),
        ProvinceInfo(name: 'Huanca Sancos', keyDistricts: ['Sancos']),
        ProvinceInfo(name: 'Huanta', keyDistricts: ['Huanta', 'Luricocha', 'Santillana']),
        ProvinceInfo(name: 'La Mar', keyDistricts: ['San Miguel', 'Anco', 'Ayna']),
        ProvinceInfo(name: 'Lucanas', keyDistricts: ['Puquio']),
        ProvinceInfo(name: 'Parinacochas', keyDistricts: ['Coracora']),
        ProvinceInfo(name: 'Páucar del Sara Sara', keyDistricts: ['Pausa']),
        ProvinceInfo(name: 'Sucre', keyDistricts: ['Querobamba']),
        ProvinceInfo(name: 'Víctor Fajardo', keyDistricts: ['Huancapi']),
        ProvinceInfo(name: 'Vilcas Huamán', keyDistricts: ['Vilcas Huamán']),
      ],
    ),
    DepartmentInfo(
      name: 'Cajamarca',
      mainCorridor: 'Longitudinal de la Sierra Norte / Eje Ciudad de Dios-Cajamarca',
      provinces: [
        ProvinceInfo(name: 'Cajamarca', keyDistricts: ['Cajamarca', 'Baños del Inca', 'Los Baños']),
        ProvinceInfo(name: 'Cajabamba', keyDistricts: ['Cajabamba']),
        ProvinceInfo(name: 'Celendín', keyDistricts: ['Celendín', 'Huasmín']),
        ProvinceInfo(name: 'Chota', keyDistricts: ['Chota', 'Lajas', 'Tacabamba']),
        ProvinceInfo(name: 'Contumazá', keyDistricts: ['Contumazá', 'Chilete']),
        ProvinceInfo(name: 'Cutervo', keyDistricts: ['Cutervo']),
        ProvinceInfo(name: 'Hualgayoc', keyDistricts: ['Bambamarca']),
        ProvinceInfo(name: 'Jaén', keyDistricts: ['Jaén', 'Bellavista', 'Pucará']),
        ProvinceInfo(name: 'San Ignacio', keyDistricts: ['San Ignacio', 'Namballe']),
        ProvinceInfo(name: 'San Marcos', keyDistricts: ['Pedro Gálvez']),
        ProvinceInfo(name: 'San Miguel', keyDistricts: ['San Miguel']),
        ProvinceInfo(name: 'San Pablo', keyDistricts: ['San Pablo']),
        ProvinceInfo(name: 'Santa Cruz', keyDistricts: ['Santa Cruz']),
      ],
    ),
    DepartmentInfo(
      name: 'Callao',
      mainCorridor: 'Corredor Portuario / Aeroportuario Jorge Chávez',
      provinces: [
        ProvinceInfo(
          name: 'Callao',
          keyDistricts: ['Ventanilla', 'Callao', 'Bellavista', 'Carmen de la Legua', 'La Perla', 'La Punta', 'Mi Perú'],
        ),
      ],
    ),
    DepartmentInfo(
      name: 'Cusco',
      mainCorridor: 'Corredor Turístico Sur / Longitudinal de la Sierra Sur',
      provinces: [
        ProvinceInfo(name: 'Cusco', keyDistricts: ['Cusco', 'San Sebastián', 'San Jerónimo', 'Santiago', 'Wanchaq']),
        ProvinceInfo(name: 'Acomayo', keyDistricts: ['Acomayo']),
        ProvinceInfo(name: 'Anta', keyDistricts: ['Anta', 'Izcuchaca', 'Zurite']),
        ProvinceInfo(name: 'Calca', keyDistricts: ['Calca', 'Pisac', 'Lamay']),
        ProvinceInfo(name: 'Canas', keyDistricts: ['Yanaoca']),
        ProvinceInfo(name: 'Canchis', keyDistricts: ['Sicuani', 'Combapata', 'Tinta']),
        ProvinceInfo(name: 'Chumbivilcas', keyDistricts: ['Santo Tomás', 'Velille', 'Chamaca']),
        ProvinceInfo(name: 'Espinar', keyDistricts: ['Yauri', 'Condoroma']),
        ProvinceInfo(name: 'La Convención', keyDistricts: ['Quillabamba', 'Santa Ana', 'Echarate', 'Pichari']),
        ProvinceInfo(name: 'Paruro', keyDistricts: ['Paruro']),
        ProvinceInfo(name: 'Paucartambo', keyDistricts: ['Paucartambo', 'Challabamba']),
        ProvinceInfo(name: 'Quispicanchi', keyDistricts: ['Urcos', 'Oropesa', 'Lucre', 'Quiquijana']),
        ProvinceInfo(name: 'Urubamba', keyDistricts: ['Urubamba', 'Ollantaytambo', 'Machupicchu', 'Chinchero']),
      ],
    ),
    DepartmentInfo(
      name: 'Huancavelica',
      mainCorridor: 'Longitudinal de la Sierra Central / Eje Huancayo-Huancavelica',
      provinces: [
        ProvinceInfo(name: 'Huancavelica', keyDistricts: ['Huancavelica', 'Ascensión']),
        ProvinceInfo(name: 'Acobamba', keyDistricts: ['Acobamba']),
        ProvinceInfo(name: 'Angaraes', keyDistricts: ['Lircay']),
        ProvinceInfo(name: 'Castrovirreyna', keyDistricts: ['Castrovirreyna']),
        ProvinceInfo(name: 'Churcampa', keyDistricts: ['Churcampa']),
        ProvinceInfo(name: 'Huaytará', keyDistricts: ['Huaytará']),
        ProvinceInfo(name: 'Tayacaja', keyDistricts: ['Pampas']),
      ],
    ),
    DepartmentInfo(
      name: 'Huánuco',
      mainCorridor: 'Carretera Central / Eje Huánuco-Tingo María',
      provinces: [
        ProvinceInfo(name: 'Huánuco', keyDistricts: ['Huánuco', 'Amarilis', 'Pillco Marca']),
        ProvinceInfo(name: 'Ambo', keyDistricts: ['Ambo']),
        ProvinceInfo(name: 'Dos de Mayo', keyDistricts: ['La Unión']),
        ProvinceInfo(name: 'Huacaybamba', keyDistricts: ['Huacaybamba']),
        ProvinceInfo(name: 'Huamalíes', keyDistricts: ['Llata']),
        ProvinceInfo(name: 'Leoncio Prado', keyDistricts: ['Rupa-Rupa', 'Tingo María', 'Castillo Grande']),
        ProvinceInfo(name: 'Marañón', keyDistricts: ['Huacrachuco']),
        ProvinceInfo(name: 'Pachitea', keyDistricts: ['Panao']),
        ProvinceInfo(name: 'Puerto Inca', keyDistricts: ['Puerto Inca']),
        ProvinceInfo(name: 'Lauricocha', keyDistricts: ['Jesús']),
        ProvinceInfo(name: 'Yarowilca', keyDistricts: ['Chavinillo']),
      ],
    ),
    DepartmentInfo(
      name: 'Ica',
      mainCorridor: 'Panamericana Sur / Eje Pisco-Ica-Nazca',
      provinces: [
        ProvinceInfo(name: 'Ica', keyDistricts: ['Ica', 'La Tinguiña', 'Parcona', 'Subtanjalla', 'Santiago']),
        ProvinceInfo(name: 'Chincha', keyDistricts: ['Chincha Alta', 'Pueblo Nuevo', 'Grocio Prado', 'Sunampe']),
        ProvinceInfo(name: 'Nazca', keyDistricts: ['Nazca', 'Marcona', 'Vista Alegre']),
        ProvinceInfo(name: 'Palpa', keyDistricts: ['Palpa']),
        ProvinceInfo(name: 'Pisco', keyDistricts: ['Pisco', 'San Clemente', 'Paracas', 'Túpac Amaru']),
      ],
    ),
    DepartmentInfo(
      name: 'Junín',
      mainCorridor: 'Carretera Central / Valle del Mantaro',
      provinces: [
        ProvinceInfo(name: 'Huancayo', keyDistricts: ['Huancayo', 'El Tambo', 'Chilca']),
        ProvinceInfo(name: 'Chanchamayo', keyDistricts: ['Chanchamayo', 'La Merced', 'San Ramón', 'Pichanaqui']),
        ProvinceInfo(name: 'Chupaca', keyDistricts: ['Chupaca', 'Ahuac']),
        ProvinceInfo(name: 'Concepción', keyDistricts: ['Concepción']),
        ProvinceInfo(name: 'Jauja', keyDistricts: ['Jauja', 'Yauyos', 'Sausa']),
        ProvinceInfo(name: 'Junín', keyDistricts: ['Junín', 'Carhuamayo']),
        ProvinceInfo(name: 'Satipo', keyDistricts: ['Satipo', 'Mazamari', 'Pangoa']),
        ProvinceInfo(name: 'Tarma', keyDistricts: ['Tarma', 'Acobamba']),
        ProvinceInfo(name: 'Yauli', keyDistricts: ['La Oroya', 'Morococha']),
      ],
    ),
    DepartmentInfo(
      name: 'La Libertad',
      mainCorridor: 'Panamericana Norte / Carretera de Penetración a la Sierra',
      provinces: [
        ProvinceInfo(
          name: 'Trujillo',
          keyDistricts: [
            'Trujillo', 'El Porvenir', 'Florencia de Mora', 'Huanchaco',
            'La Esperanza', 'Laredo', 'Moche', 'Salaverry', 'Víctor Larco Herrera',
          ],
        ),
        ProvinceInfo(name: 'Ascope', keyDistricts: ['Ascope', 'Casa Grande', 'Chicama', 'Paiján']),
        ProvinceInfo(name: 'Bolívar', keyDistricts: ['Bolívar']),
        ProvinceInfo(name: 'Chepén', keyDistricts: ['Chepén', 'Pacanga', 'Pueblo Nuevo']),
        ProvinceInfo(name: 'Julcán', keyDistricts: ['Julcán']),
        ProvinceInfo(name: 'Otuzco', keyDistricts: ['Otuzco', 'Agallpampa']),
        ProvinceInfo(name: 'Pacasmayo', keyDistricts: ['San Pedro de Lloc', 'Pacasmayo', 'Guadalupe']),
        ProvinceInfo(name: 'Pataz', keyDistricts: ['Tayabamba', 'Parcoy']),
        ProvinceInfo(name: 'Sánchez Carrión', keyDistricts: ['Huamachuco', 'Sanagorán']),
        ProvinceInfo(name: 'Santiago de Chuco', keyDistricts: ['Santiago de Chuco', 'Angasmarca']),
        ProvinceInfo(name: 'Gran Chimú', keyDistricts: ['Cascas']),
        ProvinceInfo(name: 'Virú', keyDistricts: ['Virú', 'Chao', 'Guadalupito']),
      ],
    ),
    DepartmentInfo(
      name: 'Lambayeque',
      mainCorridor: 'Panamericana Norte / Interoceánica Norte',
      provinces: [
        ProvinceInfo(name: 'Chiclayo', keyDistricts: ['Chiclayo', 'José Leonardo Ortiz', 'La Victoria', 'Pimentel', 'Monsefú']),
        ProvinceInfo(name: 'Ferreñafe', keyDistricts: ['Ferreñafe', 'Pítipo', 'Incahuasi']),
        ProvinceInfo(name: 'Lambayeque', keyDistricts: ['Lambayeque', 'Mórrope', 'Motupe', 'Olmos', 'Íllimo']),
      ],
    ),
    DepartmentInfo(
      name: 'Lima',
      mainCorridor: 'Panamericana Norte/Sur / Carretera Central',
      provinces: [
        ProvinceInfo(
          name: 'Lima',
          keyDistricts: [
            'San Juan de Lurigancho', 'San Martín de Porres', 'Ate', 'Comas',
            'Villa El Salvador', 'Villa María del Triunfo', 'Los Olivos',
            'Santiago de Surco', 'La Victoria', 'Cercado de Lima', 'Miraflores',
            'San Borja', 'Puente Piedra', 'Chorrillos', 'Carabayllo',
          ],
        ),
        ProvinceInfo(name: 'Barranca', keyDistricts: ['Barranca', 'Paramonga', 'Pativilca', 'Supe']),
        ProvinceInfo(name: 'Cajatambo', keyDistricts: ['Cajatambo']),
        ProvinceInfo(name: 'Canta', keyDistricts: ['Canta', 'Santa Rosa de Quives']),
        ProvinceInfo(name: 'Cañete', keyDistricts: ['San Vicente de Cañete', 'Imperial', 'Mala', 'Chilca', 'Asia']),
        ProvinceInfo(name: 'Huaral', keyDistricts: ['Huaral', 'Chancay', 'Aucallama']),
        ProvinceInfo(name: 'Huarochirí', keyDistricts: ['Matucana', 'Santa Eulalia', 'San Antonio']),
        ProvinceInfo(name: 'Huaura', keyDistricts: ['Huacho', 'Hualmay', 'Sayán', 'Santa María']),
        ProvinceInfo(name: 'Oyón', keyDistricts: ['Oyón']),
        ProvinceInfo(name: 'Yauyos', keyDistricts: ['Yauyos']),
      ],
    ),
    DepartmentInfo(
      name: 'Loreto',
      mainCorridor: 'Ruta Fluvial Amazónica (Ríos Amazonas, Marañón, Ucayali)',
      provinces: [
        ProvinceInfo(name: 'Maynas', keyDistricts: ['Iquitos', 'Punchana', 'Belén', 'San Juan Bautista']),
        ProvinceInfo(name: 'Alto Amazonas', keyDistricts: ['Yurimaguas', 'Balsapuerto', 'Jeberos']),
        ProvinceInfo(name: 'Loreto', keyDistricts: ['Nauta', 'Parinari']),
        ProvinceInfo(name: 'Mariscal Ramón Castilla', keyDistricts: ['Ramón Castilla', 'Caballococha']),
        ProvinceInfo(name: 'Requena', keyDistricts: ['Requena']),
        ProvinceInfo(name: 'Ucayali', keyDistricts: ['Contamana', 'Pampa Hermosa']),
        ProvinceInfo(name: 'Datem del Marañón', keyDistricts: ['Barranca', 'San Lorenzo']),
        ProvinceInfo(name: 'Putumayo', keyDistricts: ['Putumayo']),
      ],
    ),
    DepartmentInfo(
      name: 'Madre de Dios',
      mainCorridor: 'Interoceánica Sur / Eje Puerto Maldonado-Iñapari',
      provinces: [
        ProvinceInfo(name: 'Tambopata', keyDistricts: ['Tambopata', 'Puerto Maldonado', 'Inambari']),
        ProvinceInfo(name: 'Manu', keyDistricts: ['Manu', 'Fitzcarrald', 'Madre de Dios']),
        ProvinceInfo(name: 'Tahuamanu', keyDistricts: ['Iñapari', 'Iberia', 'Tahuamanu']),
      ],
    ),
    DepartmentInfo(
      name: 'Moquegua',
      mainCorridor: 'Panamericana Sur / Costanera Sur',
      provinces: [
        ProvinceInfo(name: 'Mariscal Nieto', keyDistricts: ['Moquegua', 'Samegua', 'Torata']),
        ProvinceInfo(name: 'General Sánchez Cerro', keyDistricts: ['Omate', 'Ichuña']),
        ProvinceInfo(name: 'Ilo', keyDistricts: ['Ilo', 'Pacocha', 'El Algarrobal']),
      ],
    ),
    DepartmentInfo(
      name: 'Pasco',
      mainCorridor: 'Carretera Central / Eje Cerro de Pasco-Oxapampa',
      provinces: [
        ProvinceInfo(name: 'Pasco', keyDistricts: ['Chaupimarca', 'Cerro de Pasco', 'Tinyahuarco']),
        ProvinceInfo(name: 'Daniel Alcides Carrión', keyDistricts: ['Yanahuanca']),
        ProvinceInfo(name: 'Oxapampa', keyDistricts: ['Oxapampa', 'Villa Rica', 'Pozuzo']),
      ],
    ),
    DepartmentInfo(
      name: 'Piura',
      mainCorridor: 'Panamericana Norte / Eje Huancabamba-Ayabaca',
      provinces: [
        ProvinceInfo(name: 'Piura', keyDistricts: ['Piura', 'Castilla', 'Veintiséis de Octubre', 'Catacaos', 'La Unión', 'Tambogrande']),
        ProvinceInfo(name: 'Ayabaca', keyDistricts: ['Ayabaca', 'Frías', 'Paimas', 'Suyo']),
        ProvinceInfo(name: 'Huancabamba', keyDistricts: ['Huancabamba', 'Sondorillo', 'Canchaque', 'El Carmen de la Frontera', 'Sóndor']),
        ProvinceInfo(name: 'Morropón', keyDistricts: ['Chulucanas', 'Morropón', 'Buenos Aires', 'La Matanza']),
        ProvinceInfo(name: 'Paita', keyDistricts: ['Paita', 'Colán', 'Vichayal']),
        ProvinceInfo(name: 'Sullana', keyDistricts: ['Sullana', 'Bellavista', 'Marcavelica', 'Querecotillo', 'Lancones']),
        ProvinceInfo(name: 'Talara', keyDistricts: ['Pariñas', 'Talara', 'Máncora', 'Los Órganos', 'El Alto', 'La Brea']),
        ProvinceInfo(name: 'Sechura', keyDistricts: ['Sechura', 'Bernal', 'Vice']),
      ],
    ),
    DepartmentInfo(
      name: 'Puno',
      mainCorridor: 'Interoceánica Sur / Eje Juliaca-Puno-Desaguadero',
      provinces: [
        ProvinceInfo(name: 'Puno', keyDistricts: ['Puno', 'Acora', 'Chucuito', 'Platería']),
        ProvinceInfo(name: 'San Román', keyDistricts: ['Juliaca', 'Caracoto']),
        ProvinceInfo(name: 'Azángaro', keyDistricts: ['Azángaro', 'Asillo']),
        ProvinceInfo(name: 'Carabaya', keyDistricts: ['Macusani']),
        ProvinceInfo(name: 'Chucuito', keyDistricts: ['Juli', 'Desaguadero']),
        ProvinceInfo(name: 'El Collao', keyDistricts: ['Ilave']),
        ProvinceInfo(name: 'Huancané', keyDistricts: ['Huancané', 'Taraco']),
        ProvinceInfo(name: 'Lampa', keyDistricts: ['Lampa']),
        ProvinceInfo(name: 'Melgar', keyDistricts: ['Ayaviri']),
        ProvinceInfo(name: 'Moho', keyDistricts: ['Moho']),
        ProvinceInfo(name: 'San Antonio de Putina', keyDistricts: ['Putina', 'Ananea']),
        ProvinceInfo(name: 'Sandia', keyDistricts: ['Sandia']),
        ProvinceInfo(name: 'Yunguyo', keyDistricts: ['Yunguyo']),
      ],
    ),
    DepartmentInfo(
      name: 'San Martín',
      mainCorridor: 'Carretera Fernando Belaúnde Terry / Eje Tarapoto-Moyobamba',
      provinces: [
        ProvinceInfo(name: 'Moyobamba', keyDistricts: ['Moyobamba', 'Soritor', 'Yantaló']),
        ProvinceInfo(name: 'Bellavista', keyDistricts: ['Bellavista']),
        ProvinceInfo(name: 'El Dorado', keyDistricts: ['San José de Sisa']),
        ProvinceInfo(name: 'Huallaga', keyDistricts: ['Saposoa']),
        ProvinceInfo(name: 'Lamas', keyDistricts: ['Lamas', 'Tabalosos']),
        ProvinceInfo(name: 'Mariscal Cáceres', keyDistricts: ['Juanjuí']),
        ProvinceInfo(name: 'Picota', keyDistricts: ['Picota']),
        ProvinceInfo(name: 'Rioja', keyDistricts: ['Rioja', 'Nueva Cajamarca', 'Pardo Miguel']),
        ProvinceInfo(name: 'San Martín', keyDistricts: ['Tarapoto', 'Morales', 'La Banda de Shilcayo']),
        ProvinceInfo(name: 'Tocache', keyDistricts: ['Tocache', 'Uchiza']),
      ],
    ),
    DepartmentInfo(
      name: 'Tacna',
      mainCorridor: 'Panamericana Sur / Eje Fronterizo Santa Rosa',
      provinces: [
        ProvinceInfo(name: 'Tacna', keyDistricts: ['Tacna', 'Alto de la Alianza', 'Ciudad Nueva', 'Coronel Gregorio Albarracín']),
        ProvinceInfo(name: 'Candarave', keyDistricts: ['Candarave']),
        ProvinceInfo(name: 'Jorge Basadre', keyDistricts: ['Locumba', 'Ilabaya']),
        ProvinceInfo(name: 'Tarata', keyDistricts: ['Tarata']),
      ],
    ),
    DepartmentInfo(
      name: 'Tumbes',
      mainCorridor: 'Panamericana Norte / Eje Fronterizo Zarumilla',
      provinces: [
        ProvinceInfo(name: 'Tumbes', keyDistricts: ['Tumbes', 'Corrales', 'La Cruz', 'Pampas de Hospital', 'San Jacinto']),
        ProvinceInfo(name: 'Contralmirante Villar', keyDistricts: ['Zorritos', 'Canoas de Punta Sal']),
        ProvinceInfo(name: 'Zarumilla', keyDistricts: ['Zarumilla', 'Aguas Verdes', 'Matapalo', 'Papayal']),
      ],
    ),
    DepartmentInfo(
      name: 'Ucayali',
      mainCorridor: 'Carretera Federico Basadre / Eje Pucallpa-Tingo María',
      provinces: [
        ProvinceInfo(name: 'Coronel Portillo', keyDistricts: ['Pucallpa', 'Callería', 'Manantay', 'Yarinacocha']),
        ProvinceInfo(name: 'Atalaya', keyDistricts: ['Atalaya', 'Raymondi', 'Tahuanía']),
        ProvinceInfo(name: 'Padre Abad', keyDistricts: ['Aguaytía', 'Irazola', 'Alexander von Humboldt']),
        ProvinceInfo(name: 'Purús', keyDistricts: ['Purús']),
      ],
    ),
  ];

  /// Busca el departamento correspondiente a una provincia dada
  static DepartmentInfo? findDepartmentByProvince(String provinceName) {
    final clean = provinceName.trim().toLowerCase();
    for (final dept in departments) {
      for (final prov in dept.provinces) {
        if (prov.name.toLowerCase() == clean) {
          return dept;
        }
      }
    }
    return null;
  }

  /// Busca una provincia en cualquier departamento
  static ProvinceInfo? findProvince(String provinceName) {
    final clean = provinceName.trim().toLowerCase();
    for (final dept in departments) {
      for (final prov in dept.provinces) {
        if (prov.name.toLowerCase() == clean) {
          return prov;
        }
      }
    }
    return null;
  }

  /// Busca un departamento por su nombre
  static DepartmentInfo? findDepartment(String departmentName) {
    final clean = departmentName.trim().toLowerCase();
    for (final dept in departments) {
      if (dept.name.toLowerCase() == clean) {
        return dept;
      }
    }
    return null;
  }

  /// Obtiene la lista de distritos sugeridos para una provincia específica
  static List<String> getSuggestedDistricts(String departmentName, String provinceName) {
    final cleanProv = provinceName.trim().toLowerCase();
    final prov = findProvince(provinceName);
    if (prov != null && prov.keyDistricts.isNotEmpty) {
      return prov.keyDistricts;
    }
    final dept = findDepartment(departmentName);
    if (dept != null) {
      for (final p in dept.provinces) {
        if (p.name.toLowerCase() == cleanProv) {
          return p.keyDistricts;
        }
      }
    }
    return const [];
  }
}

/// Modelo de Ubicación Estructurada para el Radar Comercial IA
class RadarLocation {
  final String department;
  final String province;
  final String? district;
  final String corridor;

  const RadarLocation({
    required this.department,
    required this.province,
    this.district,
    this.corridor = 'Red Vial Nacional',
  });

  /// Ubicación por defecto de Perú (Trujillo, La Libertad)
  static const RadarLocation defaultLocation = RadarLocation(
    department: 'La Libertad',
    province: 'Trujillo',
    district: null,
    corridor: 'Panamericana Norte / Carretera de Penetración a la Sierra',
  );

  /// Ubicación Nacional
  static const RadarLocation nationalLocation = RadarLocation(
    department: 'Perú',
    province: 'Todo el Perú',
    district: null,
    corridor: 'Red Vial Nacional',
  );

  /// Indica si la ubicación corresponde al ámbito nacional
  bool get isNational =>
      province == 'Todo el Perú' ||
      province == 'Nacional' ||
      department == 'Perú' ||
      department == 'Todo el Perú';

  /// Etiqueta para chips y encabezados (ej. "Moche, Trujillo" o "Trujillo")
  String get shortLabel {
    if (isNational) return 'Todo el Perú';
    if (district != null && district!.trim().isNotEmpty) {
      return '$district, $province';
    }
    return province;
  }

  /// Nombre completo de la ubicación (ej. "San Juan de Lurigancho, Lima (Lima)" o "Trujillo, La Libertad")
  String get displayName {
    if (isNational) return 'Todo el Perú';
    if (district != null && district!.trim().isNotEmpty) {
      return '$district, $province ($department)';
    }
    if (department == province) {
      return province;
    }
    return '$province, $department';
  }

  Map<String, dynamic> toJson() => {
    'department': department,
    'province': province,
    'district': district,
    'corridor': corridor,
  };

  factory RadarLocation.fromJson(Map<String, dynamic> json) {
    final rawDist = json['district'] as String?;
    return RadarLocation(
      department: json['department'] ?? 'La Libertad',
      province: json['province'] ?? 'Trujillo',
      district: (rawDist != null && rawDist.trim().isNotEmpty) ? rawDist.trim() : null,
      corridor: json['corridor'] ?? 'Panamericana Norte',
    );
  }

  /// Migración segura desde strings de versiones anteriores ('Trujillo', 'Talara / Piura', etc.)
  factory RadarLocation.fromLegacyString(String legacy) {
    final clean = legacy.trim();
    if (clean.isEmpty || clean == 'Todo el Perú') {
      return nationalLocation;
    }

    // Formato enriquecido Nivel 3: "Distrito, Provincia (Departamento)"
    final n3Regex = RegExp(r'^([^,]+),\s*([^(]+)\s*\(([^)]+)\)$');
    final matchN3 = n3Regex.firstMatch(clean);
    if (matchN3 != null) {
      final distPart = matchN3.group(1)!.trim();
      final provPart = matchN3.group(2)!.trim();
      final deptPart = matchN3.group(3)!.trim();
      final dept = PeruUbigeoCatalog.findDepartment(deptPart) ??
          PeruUbigeoCatalog.findDepartmentByProvince(provPart);
      return RadarLocation(
        department: dept?.name ?? deptPart,
        province: provPart,
        district: distPart,
        corridor: dept?.mainCorridor ?? 'Red Vial Nacional',
      );
    }

    if (clean.contains('/')) {
      final parts = clean.split('/').map((s) => s.trim()).toList();
      final provCandidate = parts[0];
      final deptCandidate = parts.length > 1 ? parts[1] : '';

      final dept = PeruUbigeoCatalog.findDepartmentByProvince(provCandidate) ??
          PeruUbigeoCatalog.findDepartment(deptCandidate);

      if (dept != null) {
        return RadarLocation(
          department: dept.name,
          province: provCandidate,
          district: null,
          corridor: dept.mainCorridor,
        );
      }
    }

    // Búsqueda directa por provincia
    final provDept = PeruUbigeoCatalog.findDepartmentByProvince(clean);
    if (provDept != null) {
      return RadarLocation(
        department: provDept.name,
        province: clean,
        district: null,
        corridor: provDept.mainCorridor,
      );
    }

    // Búsqueda por departamento (asigna su provincia capital)
    final dept = PeruUbigeoCatalog.findDepartment(clean);
    if (dept != null) {
      return RadarLocation(
        department: dept.name,
        province: dept.provinces.first.name,
        district: null,
        corridor: dept.mainCorridor,
      );
    }

    return defaultLocation;
  }

  RadarLocation copyWith({
    String? department,
    String? province,
    String? district,
    String? corridor,
    bool clearDistrict = false,
  }) {
    return RadarLocation(
      department: department ?? this.department,
      province: province ?? this.province,
      district: clearDistrict ? null : (district ?? this.district),
      corridor: corridor ?? this.corridor,
    );
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadarLocation &&
          runtimeType == other.runtimeType &&
          department == other.department &&
          province == other.province &&
          district == other.district;

  @override
  int get hashCode => department.hashCode ^ province.hashCode ^ (district?.hashCode ?? 0);
}
