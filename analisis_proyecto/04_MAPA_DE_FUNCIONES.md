# 📖 Mapa de Funciones - MochilaLista App v2.0
## Referencia Técnica Completa de Funcionalidades

---

## 1. 🔐 Sistema de Autenticación (Offline)

### AuthProvider (`providers/auth_provider.dart` - 290 líneas)
| Función | Descripción | Retorna |
|---------|-------------|---------|
| `checkInitialState()` | Verifica si hay perfiles en SQLite y restaura la última sesión activa | `void` |
| `createProfileAndLogin()` | Crea usuario + negocio en una transacción SQLite, guarda PIN si existe | `bool` |
| `loginWithProfile(userId)` | Activa un perfil, guarda en SharedPreferences, verifica PIN | `void` |
| `profileHasPin(userId)` | Consulta FlutterSecureStorage para verificar si existe PIN | `bool` |
| `verifyPin(userId, pin)` | Compara PIN ingresado con el almacenado en secure storage | `bool` |
| `logout()` | Limpia sesión de SharedPreferences y vuelve a selección de perfil | `void` |
| `deleteProfileAndData(userId, pin)` | Verifica PIN, borra usuario en cascada (negocios, productos, etc.) | `bool` |
| `updateUserProfile(nombre, tel)` | Actualiza datos personales del usuario activo | `bool` |
| `changePassword(currentPin, newPin)` | Verifica PIN actual y reemplaza con nuevo PIN en secure storage | `bool` |
| `createBusinessProfile(...)` | Crea negocio adicional para el usuario activo | `bool` |
| `updateBusinessProfile(...)` | Actualiza datos del negocio (nombre, RUC, dirección, moneda, logo) | `bool` |
| `uploadBusinessLogo(imageFile)` | Procesa imagen, comprime y guarda como logo del negocio | `bool` |
| `refreshActiveUser()` | Recarga datos del usuario activo desde SQLite sin cambiar estado | `void` |

### AuthService (`services/auth_service.dart` - 151 líneas)
| Función | Descripción | Tabla SQLite |
|---------|-------------|-------------|
| `getLocalProfiles()` | Lista todos los usuarios activos con su negocio asociado | `usuarios` + `negocios` |
| `getUserProfile(userId)` | Obtiene perfil completo (usuario + negocio) por ID | `usuarios` + `negocios` |
| `registerLocalProfile(...)` | Crea usuario + negocio en transacción, procesa logo si hay | `usuarios` + `negocios` |
| `updateProfile(userId, ...)` | Actualiza nombre y teléfono del usuario | `usuarios` |
| `createBusiness(userId, ...)` | Inserta nuevo negocio vinculado al usuario | `negocios` |
| `updateBusiness(bizId, ...)` | Actualiza datos del negocio, maneja limpieza de logo | `negocios` |
| `uploadLogo(bizId, imageFile)` | Procesa imagen y actualiza `logo_url` en negocios | `negocios` |
| `deleteLocalProfile(userId)` | Borra usuario con CASCADE (borra todo su negocio y datos) | `usuarios` |

---

## 2. 📦 Sistema de Inventario

### InventoryProvider (`providers/inventory_provider.dart` - 430 líneas)
| Función | Descripción |
|---------|-------------|
| `loadInventory(reset, searchQuery, filters...)` | Carga inventario paginado con filtros (categoría, marca, precio, stock, ofertas) |
| `loadMore()` | Carga siguiente página de inventario |
| `loadMasterData(showAll)` | Carga categorías, marcas y proveedores en paralelo |
| `createCategory/Brand/Provider(...)` | CRUD de datos maestros con recarga automática |
| `updateCategory/Brand/Provider(...)` | Actualiza datos maestros verificando dependencias |
| `deleteCategory/Brand/Provider(id)` | Elimina con validación de productos vinculados |
| `createFullProduct(...)` | Crea producto con N presentaciones en transacción SQLite |
| `editFullProduct(...)` | Edita producto, actualiza/crea/elimina presentaciones |
| `updatePresentation(id, ...)` | Actualización granular de una presentación específica |
| `deleteProduct(id)` | Elimina producto y limpia imágenes asociadas |
| `sortProducts/Categories/Brands/Providers(type)` | Ordenamiento en memoria (alpha/id, asc/desc) |
| `fetchProductById(id)` | Obtiene producto completo con todas sus presentaciones |

### ProductService (`services/product_service.dart` - 209 líneas)
| Función | Descripción | Operación SQL |
|---------|-------------|---------------|
| `fetchInventory(queryParams)` | Query paginada con JOIN de 26 columnas + filtros dinámicos | SELECT + JOIN |
| `fetchProductById(id)` | Producto con todas sus presentaciones activas | SELECT + subquery |
| `deleteProduct(id)` | Borra producto y limpia imágenes de todas sus presentaciones | DELETE + I/O |
| `createFullProduct(...)` | Transacción: INSERT producto + N INSERT presentaciones | Transaction |
| `editFullProduct(...)` | Transacción: UPDATE producto + DELETE/UPDATE/INSERT presentaciones | Transaction |
| `updatePresentation(id, body)` | Actualización parcial de presentación por ID | UPDATE |

---

## 3. 🧠 Motor de IA y Escaneo

### ScannerProvider (`providers/scanner_provider.dart` - 587 líneas)
| Función | Descripción |
|---------|-------------|
| `uploadAndAnalyzeImage(imageFile)` | Envía imagen a Google Gemini, parsea JSON de factura estructurada |
| `runMatchingProcess()` | Compara items de IA contra catálogo local con LIKE queries |
| `scanBarcode(barcode)` | Busca producto/presentación por código de barras |
| `searchProviders(query)` | Busca proveedores por nombre con LIKE |
| `updateRawItems(...)` | Permite editar los datos extraídos por IA antes del matching |
| `manualLinkProductGroup(uuid, product, siblings)` | Vincula manualmente un grupo de staging con producto existente |
| `unlinkProductGroup(uuid)` | Desvincula un grupo, regresa a estado "NUEVO" |
| `switchVariantLink(uuid, presId)` | Cambia vinculación de variante a otra presentación |
| `switchVariantToNew(uuid)` | Marca variante como nueva (crea presentación nueva) |
| `removeVariantByUuid(uuid)` | Elimina variante del staging |
| `toggleVariantUpdate(uuid, field)` | Toggle de qué campos actualizar (costo/precio/nombre) |
| `addNewProductGroup()` | Agrega grupo de producto manualmente al staging |
| `addNewVariantToGroup(uuid)` | Agrega variante a un grupo existente |
| `executeBatchSave()` | Transacción masiva: crea proveedor + factura + productos + presentaciones |
| `updateStagingProvider(...)` | Cambia proveedor en staging (manual o auto) |

### AIExtractionService (`features/smart_quotation/services/ai_extraction_service.dart` - 88 líneas)
| Función | Descripción |
|---------|-------------|
| `analyzeImage(imageFile, _)` | Envía lista escolar a Gemini, retorna metadata + items estructurados |

---

## 4. 📋 Sistema de Cotización Inteligente

### SmartQuotationProvider (7225 bytes)
| Función | Descripción |
|---------|-------------|
| `loadQuotations()` | Carga todas las cotizaciones del negocio con items |
| `createQuotation(...)` | Crea cotización en SQLite con items |
| `updateQuotation(...)` | Actualiza cotización existente |
| `deleteQuotation(id)` | Elimina cotización con sus items |
| `cloneQuotation(id)` | Duplica cotización como plantilla |

### MatchingProvider (`features/smart_quotation/providers/matching_provider.dart` - 13056 bytes)
| Función | Descripción |
|---------|-------------|
| `runMatching(items)` | Ejecuta matching de items de lista escolar contra catálogo local usando `string_similarity` |
| `manualMatch(itemId, productId)` | Vinculación manual de item con producto |
| `confirmMatch(itemId)` | Confirma un match sugerido |
| `rejectMatch(itemId)` | Rechaza match y marca como "sin inventario" |

### WorkbenchProvider (10572 bytes)
| Función | Descripción |
|---------|-------------|
| `loadDashboard()` | Carga resumen de cotizaciones activas para el dashboard |
| `loadWorkbenchItems()` | Carga cotizaciones en cola de trabajo |

### SaleProvider (13688 bytes)
| Función | Descripción |
|---------|-------------|
| `createSale(...)` | Registra venta con items, descuenta stock, actualiza deuda del cliente |
| `loadSalesHistory()` | Historial de ventas con filtros |
| `voidSale(id)` | Anula venta y restaura stock |
| `registerPayment(...)` | Registra pago parcial/total, actualiza deuda |

---

## 5. 👥 CRM de Clientes

### ClientService (`features/smart_quotation/services/client_service.dart` - 15951 bytes)
| Función | Descripción |
|---------|-------------|
| `getClients(negocioId)` | Lista clientes con deudas calculadas |
| `createClient(...)` | Registra nuevo cliente con datos completos |
| `updateClient(id, ...)` | Actualiza información del cliente |
| `deleteClient(id)` | Elimina cliente (solo si no tiene ventas activas) |
| `getClientDebts(clientId)` | Obtiene detalle de deudas del cliente |
| `recalculateDebt(clientId)` | Recalcula `deuda_total` sumando ventas pendientes |

---

## 6. 🖨️ Generación de PDF y WhatsApp

### PDFGenerator (`features/smart_quotation/utils/pdf_generator.dart` - 23184 bytes)
| Función | Descripción |
|---------|-------------|
| `generateQuotationPDF(...)` | Genera PDF profesional de cotización con logo, items, totales |
| `generateSaleReceipt(...)` | Genera recibo/ticket de venta |

### WhatsApp Integration (whatsapp_preview_screen.dart - 32288 bytes)
| Función | Descripción |
|---------|-------------|
| Flujo completo | Previsualiza mensaje → genera PDF → abre WhatsApp con número pre-llenado |

---

## 7. 💾 Backup y Restauración

### BackupManager (`utils/backup_manager.dart` - 144 líneas)
| Función | Descripción |
|---------|-------------|
| `exportToWhatsApp()` | Comparte archivo .db vía Share Sheet |
| `exportToDownloads()` | Copia .db a carpeta de descargas (manejo Android 13+) |
| `exportToGoogleDrive()` | Sube .db a Google Drive vía OAuth2 |
| `restoreBackup()` | Selecciona .db con file picker y sobreescribe base de datos |

### BackupProvider (`providers/backup_provider.dart` - 3760 bytes)
| Función | Descripción |
|---------|-------------|
| `loadSettings()` | Lee configuración de backup automático de SharedPreferences |
| `toggleAutoBackup()` | Activa/desactiva backup automático con WorkManager |
| `setFrequency(days)` | Configura frecuencia (7, 15, 30 días) |
| `setLocation(location)` | Configura destino (Local/Drive) |

---

## 8. 🛠️ Utilidades y Hardware

### HardwareValidator (`utils/hardware_validator.dart` - 223 líneas)
| Función | Descripción |
|---------|-------------|
| `checkInternet(context)` | Valida conectividad + ping real a Google. Muestra modal premium si falla |
| `checkGPS(context)` | Valida servicio de ubicación y permisos. Muestra modal si falta |

### ThemeProvider (`providers/theme_provider.dart`)
| Función | Descripción |
|---------|-------------|
| `toggleThemeMode()` | Alterna entre claro/oscuro |
| `setThemeMode(mode)` | Establece modo específico |
| `appTextTheme` | Tipografía base de la app |

### PrinterProvider (`providers/printer_provider.dart`)
| Función | Descripción |
|---------|-------------|
| `connectPrinter(address)` | Conecta impresora Bluetooth térmica |
| `printReceipt(data)` | Imprime ticket de venta en impresora térmica |
| `disconnectPrinter()` | Desconecta impresora |

---

## 9. 🗄️ Base de Datos Local

### LocalDatabase (`database/local_db.dart` - 235 líneas)
| Función | Descripción |
|---------|-------------|
| `database` (getter) | Singleton de conexión a SQLite |
| `_initDB(filePath)` | Inicializa BD con configuración |
| `_onConfigure(db)` | Habilita PRAGMA foreign_keys |
| `_onUpgrade(db, old, new)` | Ejecuta migraciones v1→v4 |
| `_createDB(db, version)` | Crea las 13+ tablas con constraints |
| `getAllTableNames()` | Debug: lista todas las tablas |
| `genericUpdate(table, col, val, id)` | Actualización genérica (debug) |
| `genericDelete(table, id)` | Borrado genérico (debug) |
| `closeConnection()` | Cierra y nullifica conexión |
| `clearDatabase()` | Borra toda la BD (nuclear) |
