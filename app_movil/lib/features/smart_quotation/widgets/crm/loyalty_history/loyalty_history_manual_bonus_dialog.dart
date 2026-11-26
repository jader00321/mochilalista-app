part of '../client_loyalty_history_modal.dart';

mixin _LoyaltyHistoryManualBonusDialogMixin on _ClientLoyaltyHistoryModalStateBase {
  @override
  void _showAddManualBonusModal() {
    final pointsCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    int deltaScore = 5;
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF282836) : Colors.white;
          final textC = isDark ? Colors.white : Colors.black87;

          final currentPts = _currentClient.puntosActuales;
          final enteredPts = int.tryParse(pointsCtrl.text.trim()) ?? 0;
          final bool exceedsCurrent = !isAdding && enteredPts > currentPts;
          final newBalance = isAdding
              ? currentPts + enteredPts
              : math.max(0, currentPts - enteredPts);

          // Verificar si este bono alcanzará alguna meta activa
          RewardGoalModel? willUnlockGoal;
          if (isAdding && enteredPts > 0) {
            for (var g in _goals) {
              if (newBalance >= g.puntosRequeridos && currentPts < g.puntosRequeridos) {
                willUnlockGoal = g;
                break;
              }
            }
          }

          final quickMotives = isAdding
              ? [
                  "Bono de cortesía",
                  "Pago puntual",
                  "Compra previa",
                  "Promoción especial",
                ]
              : [
                  "Corrección de saldo",
                  "Devolución de mercadería",
                  "Ajuste administrativo",
                ];

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.amber[700], size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Ajuste / Bono Manual",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textC),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila de Chips con Expanded y FittedBox (0 Overflow garantizado en 320/360dp)
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("+ Sumar Puntos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                            selected: isAdding,
                            selectedColor: Colors.green.withValues(alpha: 0.25),
                            onSelected: (val) {
                              setDialogState(() {
                                isAdding = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("- Restar Puntos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                            selected: !isAdding,
                            selectedColor: Colors.red.withValues(alpha: 0.25),
                            onSelected: (val) {
                              setDialogState(() {
                                isAdding = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chips Rápidos de Cantidad de Puntos en 1 Toque (+10, +25, +50, +100)
                    Text(
                      "Puntos Rápidos:",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [10, 25, 50, 100].map((pts) {
                        return ActionChip(
                          avatar: Icon(
                            isAdding ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                            size: 13,
                            color: isAdding ? Colors.green[700] : Colors.red[700],
                          ),
                          label: Text(
                            "$pts pts",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isAdding ? (isDark ? Colors.green[300] : Colors.green[800]) : (isDark ? Colors.red[300] : Colors.red[800]),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: (isAdding ? Colors.green : Colors.red).withValues(alpha: 0.12),
                          side: BorderSide(
                            color: (isAdding ? Colors.green : Colors.red).withValues(alpha: 0.35),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              pointsCtrl.text = "$pts";
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: pointsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: "Cantidad de Puntos",
                        suffixText: "pts",
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Indicador Dinámico de Impacto en Vivo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: exceedsCurrent
                              ? Colors.red.withValues(alpha: 0.6)
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "Saldo actual: $currentPts pts",
                                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_forward_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Nuevo: $newBalance pts",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: exceedsCurrent
                                          ? Colors.red
                                          : (isAdding ? Colors.green[600] : Colors.orange[800]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (exceedsCurrent) ...[
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "El saldo no puede ser negativo (Excede el saldo)",
                                    style: TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (willUnlockGoal != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.amber[800]),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "Desbloqueará '${willUnlockGoal.nombre}' (${willUnlockGoal.puntosRequeridos} pts) para revisión",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.amber[300] : Colors.amber[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: reasonCtrl,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: "Motivo / Justificación",
                        hintText: "Ej. Bono por recomendación",
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Chips Rápidos de Motivo en 1 Toque con Wrap (Cero Cortes visuales tipo '[ Co')
                    Text(
                      "Motivos Frecuentes:",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickMotives.map((m) {
                        return ActionChip(
                          label: Text(m, style: const TextStyle(fontSize: 10.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                          onPressed: () {
                            setDialogState(() {
                              reasonCtrl.text = m;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: (enteredPts <= 0 || exceedsCurrent)
                    ? null
                    : () async {
                        final rawPoints = enteredPts;
                        final deltaPts = isAdding ? rawPoints : -rawPoints;
                        final reason = reasonCtrl.text.trim().isNotEmpty
                            ? reasonCtrl.text.trim()
                            : (isAdding ? "Bono de fidelización otorgado" : "Ajuste manual de puntos");

                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final userId = auth.activeUserId;
                        Navigator.pop(ctx);

                        final unlocked = await _clientService.addManualLoyaltyMovement(
                          _currentClient.id,
                          _currentClient.negocioId,
                          pointsDelta: deltaPts,
                          motivo: reason,
                          scoreDelta: isAdding ? deltaScore : -deltaScore,
                          usuarioId: userId,
                        );

                        widget.onPointsChanged?.call();
                        await _loadHistory();

                        if (context.mounted) {
                          if (unlocked.isNotEmpty) {
                            LoyaltyToastFeedback.showSuccess(
                              context,
                              "Meta '${unlocked.first.tituloRecompensa}' desbloqueada para revisión",
                            );
                          } else {
                            LoyaltyToastFeedback.showSuccess(
                              context,
                              isAdding
                                  ? "Se otorgaron +$rawPoints pts a ${_currentClient.fullName}"
                                  : "Se descontaron -$rawPoints pts a ${_currentClient.fullName}",
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Aplicar", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ),
  );
}
}
