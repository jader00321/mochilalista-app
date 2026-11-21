import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  group('Fase 5: Certificación de Redacción Comercial y Precedencia Gramatical', () {
    test(
      '1. OwnerLegalIdentity.formatPlanArticleName respeta precedencia estricta de los 7 productos',
      () {
        // Ajuste Preventivo #3: 'update' / 'pase' se evalúa ANTES de 'anual'
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Pase Anual de Updates"),
          equals("el Pase Anual de Actualizaciones"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName(
            "Pase Anual de Actualizaciones",
          ),
          equals("el Pase Anual de Actualizaciones"),
        );

        // 'ia' / 'bolsa' / 'extra' se evalúa ANTES de 'anual'
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Bolsa Extra IA"),
          equals("una Bolsa Extra de IA (150 escaneos)"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName(
            "Bolsa Extra de IA (150 escaneos)",
          ),
          equals("una Bolsa Extra de IA (150 escaneos)"),
        );

        // Licencia Perpetua ('la')
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Licencia Perpetua"),
          equals("la Licencia Perpetua"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Perpetua"),
          equals("la Licencia Perpetua"),
        );

        // Planes por período ('el Plan ...')
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Mensual"),
          equals("el Plan Mensual"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Plan Mensual"),
          equals("el Plan Mensual"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Trimestral"),
          equals("el Plan Trimestral"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Plan Trimestral"),
          equals("el Plan Trimestral"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Semestral"),
          equals("el Plan Semestral"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Plan Semestral"),
          equals("el Plan Semestral"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Anual"),
          equals("el Plan Anual"),
        );
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Plan Anual"),
          equals("el Plan Anual"),
        );

        // Fallback
        expect(
          OwnerLegalIdentity.formatPlanArticleName("Especial"),
          equals("el Especial"),
        );
      },
    );

    test(
      '2. OwnerLegalIdentity.buildPlanOrderMessage genera redacción profesional sin duplicar artículos',
      () {
        const hardwareId = "ML-379E";

        // Pase Anual
        final msgPase = OwnerLegalIdentity.buildPlanOrderMessage(
          planName: "Pase Anual de Updates",
          price: "S/ 45.00",
          hardwareId: hardwareId,
        );
        expect(
          msgPase,
          equals(
            "Hola Julio Angello, deseo solicitar el Pase Anual de Actualizaciones (S/ 45.00) para MochilaLista.\n"
            "Mi código de dispositivo (Hardware ID) es: ML-379E\n"
            "Adjunto mi comprobante de pago por Yape / Transferencia bancaria.",
          ),
        );

        // Licencia Perpetua
        final msgPerpetua = OwnerLegalIdentity.buildPlanOrderMessage(
          planName: "Perpetua",
          price: "S/ 280.00",
          hardwareId: hardwareId,
        );
        expect(
          msgPerpetua,
          equals(
            "Hola Julio Angello, deseo solicitar la Licencia Perpetua (S/ 280.00) para MochilaLista.\n"
            "Mi código de dispositivo (Hardware ID) es: ML-379E\n"
            "Adjunto mi comprobante de pago por Yape / Transferencia bancaria.",
          ),
        );

        // Bolsa Extra IA
        final msgIa = OwnerLegalIdentity.buildPlanOrderMessage(
          planName: "Bolsa Extra IA",
          price: "S/ 15.00",
          hardwareId: hardwareId,
        );
        expect(
          msgIa,
          equals(
            "Hola Julio Angello, deseo solicitar una Bolsa Extra de IA (150 escaneos) (S/ 15.00) para MochilaLista.\n"
            "Mi código de dispositivo (Hardware ID) es: ML-379E\n"
            "Adjunto mi comprobante de pago por Yape / Transferencia bancaria.",
          ),
        );

        // Plan Mensual
        final msgMensual = OwnerLegalIdentity.buildPlanOrderMessage(
          planName: "Mensual",
          price: "S/ 35.00",
          hardwareId: hardwareId,
        );
        expect(
          msgMensual,
          equals(
            "Hola Julio Angello, deseo solicitar el Plan Mensual (S/ 35.00) para MochilaLista.\n"
            "Mi código de dispositivo (Hardware ID) es: ML-379E\n"
            "Adjunto mi comprobante de pago por Yape / Transferencia bancaria.",
          ),
        );
      },
    );
  });

  group(
    'Fase 5: Certificación de Gestión de Foco, Chips Compactos y 0px Overflow en OrderPlanBottomSheet',
    () {
      testWidgets(
        '3. Desenfoque defensivo: tocar fuera, chips, copiar o restablecer libera el foco del TextField',
        (tester) async {
          String? sentMessage;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: OrderPlanBottomSheet(
                  planName: "Mensual",
                  price: "S/ 35.00",
                  desc: "Ideal para probar el sistema mes a mes",
                  aiScansBadge: "+50 IA",
                  hardwareId: "ML-379E",
                  defaultMessage: OwnerLegalIdentity.buildPlanOrderMessage(
                    planName: "Mensual",
                    price: "S/ 35.00",
                    hardwareId: "ML-379E",
                  ),
                  isDark: false,
                  onSendWhatsApp: (msg) => sentMessage = msg,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final textFieldFinder = find.byType(TextField);
          expect(textFieldFinder, findsOneWidget);
          final editableFinder = find.byType(EditableText);
          expect(editableFinder, findsOneWidget);
          final FocusNode textFieldFocus = tester
              .widget<EditableText>(editableFinder)
              .focusNode;

          // 1. Enfocar el TextField directamente
          textFieldFocus.requestFocus();
          await tester.pump();
          expect(textFieldFocus.hasFocus, isTrue);

          // 2. Tocar fuera del TextField (sobre la cabecera fija)
          await tester.tap(find.text("Solicitar Mensual"));
          await tester.pump();
          expect(textFieldFocus.hasFocus, isFalse);

          // 3. Volver a enfocar y pulsar un chip rápido ("Ya hice Yape/Plin")
          textFieldFocus.requestFocus();
          await tester.pump();
          expect(textFieldFocus.hasFocus, isTrue);

          await tester.ensureVisible(find.text("Ya hice Yape/Plin"));
          await tester.tap(find.text("Ya hice Yape/Plin"));
          await tester.pump();
          expect(textFieldFocus.hasFocus, isFalse);

          // 4. Volver a enfocar y pulsar un segundo chip ("Pedir BCP/BBVA")
          textFieldFocus.requestFocus();
          await tester.pump();
          expect(textFieldFocus.hasFocus, isTrue);

          await tester.ensureVisible(find.text("Pedir BCP/BBVA"));
          await tester.tap(find.text("Pedir BCP/BBVA"));
          await tester.pump();
          expect(textFieldFocus.hasFocus, isFalse);

          // 5. Volver a enfocar y pulsar "Enviar por WhatsApp"
          textFieldFocus.requestFocus();
          await tester.pump();
          expect(textFieldFocus.hasFocus, isTrue);

          await tester.ensureVisible(find.text("Enviar por WhatsApp"));
          await tester.tap(find.text("Enviar por WhatsApp"));
          await tester.pump();
          expect(textFieldFocus.hasFocus, isFalse);
          expect(sentMessage, isNotNull);
        },
      );

      testWidgets(
        '4. Chips concisos, etiqueta Mensaje (Editable) sin truncar y 0px Overflow en 320x568dp y 360x640dp con barra Android',
        (tester) async {
          final testSizes = [
            const Size(320 * 3, 568 * 3),
            const Size(360 * 3, 640 * 3),
          ];

          for (final size in testSizes) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              MediaQuery(
                data: const MediaQueryData(
                  padding: EdgeInsets.only(bottom: 48),
                  viewPadding: EdgeInsets.only(bottom: 48),
                ),
                child: MaterialApp(
                  home: Scaffold(
                    body: OrderPlanBottomSheet(
                      planName: "Pase Anual de Updates",
                      price: "S/ 45.00",
                      desc: "Actualizaciones garantizadas por 1 año",
                      aiScansBadge: "+100 IA",
                      hardwareId: "ML-379E-LONG-ID",
                      defaultMessage: OwnerLegalIdentity.buildPlanOrderMessage(
                        planName: "Pase Anual de Updates",
                        price: "S/ 45.00",
                        hardwareId: "ML-379E-LONG-ID",
                      ),
                      isDark: false,
                      onSendWhatsApp: (_) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Verificar los 3 chips con texto conciso
            expect(find.text("Ya hice Yape/Plin"), findsOneWidget);
            expect(find.text("Pedir BCP/BBVA"), findsOneWidget);
            expect(find.text("Necesito Factura"), findsOneWidget);

            // Verificar que la etiqueta es concisa "Mensaje (Editable)"
            expect(find.text("Mensaje (Editable)"), findsOneWidget);
            expect(
              find.text("Mensaje para Soporte Oficial (Editable):"),
              findsNothing,
            );

            // Botón Enviar por WhatsApp debe estar presente y visible
            expect(find.text("Enviar por WhatsApp"), findsOneWidget);

            // Cero desbordamientos de RenderFlex
            expect(
              tester.takeException(),
              isNull,
              reason:
                  "No debe haber ningún overflow en pantalla de ${size.width / 3}x${size.height / 3}dp",
            );
          }
        },
      );
    },
  );
}
