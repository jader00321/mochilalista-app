import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import '../models/smart_quotation_model.dart';
import '../../../models/user_model.dart';
import '../models/pdf_config_model.dart';
import 'pdf_generator.dart';

class ReceiptManager {
  
  // Genera el archivo configurado para Auditoría Rápida o Compartir con un clic
  static Future<File> _generateFile(SmartQuotationModel quotation, UserModel? user, {Map<String, dynamic>? saleData}) async {
    final bool isSale = saleData != null;

    // CONFIGURACIÓN: "TICKET LIMPIO" PARA DESCARGAS DE 1 CLIC
    final config = PdfConfig(
      theme: PdfTheme.minimal, // Tema más limpio
      showImages: false,
      
      // Solo el nombre del negocio (Ocultamos datos privados)
      showBusinessInfo: true,
      includeLogo: true, 
      includeOwnerPhone: false,
      includeShopAddress: false,
      includeShopRuc: false,

      // Cliente y Título
      showClientName: true,
      showInstitutionInfo: false, // No notas ni colegio en versión rápida
      documentTitle: isSale ? "COMPROBANTE" : "COTIZACIÓN", 
      
      // Ocultamos tabla financiera interna, solo mostramos Total
      showTransactionDetails: isSale,
      showProductUnit: false,          // 🔥 Oculto en ticket rápido
      showProductUnitPrice: false,     // 🔥 Oculto en ticket rápido
      showProductSubtotal: true,       // 🔥 Mostramos el total final del producto
      showProductSavings: false,       // 🔥 Oculto en ticket rápido
      
      showTotalSavings: false, 
      showTotalGlobal: true, 
    );

    final pdfBytes = await PdfGenerator.generatePdf(
      quotation: quotation,
      ownerInfo: user,
      config: config,
      saleData: saleData, 
    );

    final dir = await getTemporaryDirectory();
    final String fileName = isSale 
        ? 'Comprobante_Venta_${saleData['id']}.pdf' 
        : 'Cotizacion_${quotation.id}.pdf';
        
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    
    return file;
  }

  // Descarga y Abre
  static Future<void> openReceipt(SmartQuotationModel quotation, UserModel? user, {Map<String, dynamic>? saleData}) async {
    final file = await _generateFile(quotation, user, saleData: saleData);
    await OpenFilex.open(file.path);
  }

  // Genera y Comparte directamente
  static Future<void> shareReceipt(SmartQuotationModel quotation, UserModel? user, {Map<String, dynamic>? saleData}) async {
    final file = await _generateFile(quotation, user, saleData: saleData);
    
    final String textMsg = saleData != null 
        ? '¡Gracias por su compra! Adjuntamos su comprobante.'
        : 'Adjuntamos la cotización solicitada. Quedamos a su disposición.';
        
    await Share.shareXFiles([XFile(file.path)], text: textMsg);
  }
}