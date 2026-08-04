import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/models/user_model.dart';
import 'package:app_movil/models/product_model.dart';

void main() {
  group('UserModel Tests', () {
    test('fromJson should parse correctly', () {
      final json = {
        'id': 1,
        'nombre_completo': 'Juan Perez',
        'activo': 1,
        'email': 'juan@example.com'
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 1);
      expect(user.fullName, 'Juan Perez');
      expect(user.isActive, true);
      expect(user.email, 'juan@example.com');
    });

    test('toSqlite should convert to valid SQLite map', () {
      final user = UserModel(
        id: 2,
        fullName: 'Maria Gomez',
        isActive: false,
        email: 'maria@example.com',
      );

      final map = user.toSqlite();

      expect(map['id'], 2);
      expect(map['nombre_completo'], 'Maria Gomez');
      expect(map['activo'], 0);
      expect(map['email'], 'maria@example.com');
    });
  });

  group('Product Tests', () {
    test('fromJson should parse correctly', () {
      final json = {
        'id': 100,
        'nombre': 'Laptop Acer',
        'categoria_id': 1,
        'estado': 'activo',
      };

      final product = Product.fromJson(json);

      expect(product.id, 100);
      expect(product.nombre, 'Laptop Acer');
      expect(product.categoriaId, 1);
      expect(product.estado, 'activo');
    });

    test('toSqlite should convert to valid SQLite map', () {
      final product = Product(
        id: 101,
        nombre: 'Monitor Samsung',
        categoriaId: 1,
        estado: 'activo',
        presentaciones: [],
        stockTotalCalculado: 0
      );

      final map = product.toSqlite(1);

      expect(map['id'], 101);
      expect(map['nombre'], 'Monitor Samsung');
      expect(map['categoria_id'], 1);
      expect(map['estado'], 'activo');
    });
  });
}
