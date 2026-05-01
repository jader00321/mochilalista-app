import 'package:flutter/material.dart';
import '../database/local_db.dart';

class DbInspectorScreen extends StatefulWidget {
  const DbInspectorScreen({super.key});

  @override
  State<DbInspectorScreen> createState() => _DbInspectorScreenState();
}

class _DbInspectorScreenState extends State<DbInspectorScreen> {
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _data = [];
  List<String> _columns = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final tables = await LocalDatabase.instance.getAllTableNames();
    setState(() => _tables = tables);
  }

  Future<void> _loadTableData(String tableName) async {
    setState(() => _isLoading = true);
    final db = await LocalDatabase.instance.database;
    final data = await db.query(tableName, orderBy: 'id DESC');
    
    setState(() {
      _selectedTable = tableName;
      _data = data;
      _columns = data.isNotEmpty ? data.first.keys.toList() : [];
      _isLoading = false;
    });
  }

  void _editCell(int id, String column, dynamic currentValue) {
    final controller = TextEditingController(text: currentValue?.toString() ?? "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Editar $column", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Fila ID: $id", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                labelText: "Valor actual: $currentValue",
              ),
              keyboardType: (currentValue is num) ? TextInputType.number : TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              dynamic newValue = controller.text;
              if (currentValue is int) newValue = int.tryParse(controller.text) ?? currentValue;
              if (currentValue is double) newValue = double.tryParse(controller.text) ?? currentValue;

              await LocalDatabase.instance.genericUpdate(_selectedTable!, column, newValue, id);
              Navigator.pop(context);
              _loadTableData(_selectedTable!);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dato actualizado exitosamente")));
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SQLite Inspector", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: isDark ? Colors.black : Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadTables),
        ],
      ),
      body: Column(
        children: [
          // Barra de navegación de tablas
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12))
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _tables.length,
              itemBuilder: (context, index) {
                final name = _tables[index];
                final isSelected = _selectedTable == name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(name.toUpperCase(), style: TextStyle(
                      fontSize: 12, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87)
                    )),
                    selected: isSelected,
                    selectedColor: Colors.indigoAccent,
                    onSelected: (_) => _loadTableData(name),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _selectedTable == null
                ? const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storage_rounded, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Selecciona una tabla arriba", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ))
                : _data.isEmpty
                  ? const Center(child: Text("La tabla está vacía"))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 45,
                          dataRowMinHeight: 45,
                          headingRowColor: MaterialStateProperty.all(isDark ? Colors.white10 : Colors.indigo.withOpacity(0.05)),
                          columns: _columns.map((col) => DataColumn(
                            label: Text(col.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.indigoAccent))
                          )).toList(),
                          rows: _data.map((row) {
                            return DataRow(
                              cells: _columns.map((col) {
                                final cellValue = row[col];
                                return DataCell(
                                  Text(cellValue?.toString() ?? "NULL", style: TextStyle(
                                    fontSize: 13, 
                                    color: cellValue == null ? Colors.red.withOpacity(0.5) : (isDark ? Colors.white70 : Colors.black87)
                                  )),
                                  onTap: col == 'id' ? null : () => _editCell(row['id'], col, cellValue),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}