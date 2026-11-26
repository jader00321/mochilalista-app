import 'package:excel/excel.dart';

/// Paleta y estilos corporativos reutilizables para reportes `.xlsx`.
class ExcelCorporateStyles {
  ExcelCorporateStyles._();

  static CellStyle titleStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF1E3A8A'),
      bold: true,
      fontSize: 14,
    );
  }

  static CellStyle metaStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF475569'),
      italic: true,
      fontSize: 10,
    );
  }

  static CellStyle sectionHeaderStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('FF0F766E'),
      bold: true,
      fontSize: 11,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle headerStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('FF1E3A8A'),
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  static CellStyle boldLabelStyle() {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('FF0F172A'),
    );
  }

  static CellStyle statusActiveStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF166534'),
      backgroundColorHex: ExcelColor.fromHexString('FFDCFCE7'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  static CellStyle statusExpiringStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF854D0E'),
      backgroundColorHex: ExcelColor.fromHexString('FFFEF3C7'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  static CellStyle statusExpiredStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF991B1B'),
      backgroundColorHex: ExcelColor.fromHexString('FFFEE2E2'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  static CellStyle statusPerpetualStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF581C87'),
      backgroundColorHex: ExcelColor.fromHexString('FFF3E8FF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  static CellStyle statusProspectStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF1E40AF'),
      backgroundColorHex: ExcelColor.fromHexString('FFDBEAFE'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }
}
