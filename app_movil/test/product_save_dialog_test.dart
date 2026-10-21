import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/widgets/product_save_success_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auditoría Fase 1: ProductSaveSuccessDialog (Modo Crear vs Modo Editar)', () {
    testWidgets('Modo Crear muestra título ¡Producto Creado!, contador y Abriendo Inventario...', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductSaveSuccessDialog(
              productName: "Cuaderno Standford A4",
              presentationCount: 1,
              mode: ProductSaveDialogMode.create,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("¡Producto Creado!"), findsOneWidget);
      expect(find.text("Cuaderno Standford A4"), findsOneWidget);
      expect(find.text("1 presentación guardada en catálogo"), findsOneWidget);
      expect(find.text("Abriendo Inventario..."), findsOneWidget);

      expect(find.text("¡Cambios Guardados!"), findsNothing);
      expect(find.text("Actualizando datos del producto..."), findsNothing);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Modo Crear con múltiples variantes muestra plural', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductSaveSuccessDialog(
              productName: "Lapicero Faber Castell",
              presentationCount: 3,
              mode: ProductSaveDialogMode.create,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("¡Producto Creado!"), findsOneWidget);
      expect(find.text("3 presentaciones listas para vender"), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Modo Editar muestra título ¡Cambios Guardados!, sincronizado y Actualizando datos del producto...', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductSaveSuccessDialog(
              productName: "Plumones Sharpie 24u",
              presentationCount: 1,
              mode: ProductSaveDialogMode.edit,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("¡Cambios Guardados!"), findsOneWidget);
      expect(find.text("Plumones Sharpie 24u"), findsOneWidget);
      expect(find.text("1 presentación sincronizada"), findsOneWidget);
      expect(find.text("Actualizando datos del producto..."), findsOneWidget);

      expect(find.text("¡Producto Creado!"), findsNothing);
      expect(find.text("Abriendo Inventario..."), findsNothing);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Modo Editar con múltiples variantes muestra plural sincronizado', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductSaveSuccessDialog(
              productName: "Resma Papel Navigator A4",
              presentationCount: 4,
              mode: ProductSaveDialogMode.edit,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("¡Cambios Guardados!"), findsOneWidget);
      expect(find.text("4 presentaciones sincronizadas"), findsOneWidget);
      expect(find.text("Actualizando datos del producto..."), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
