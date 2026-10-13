// lib/features/health/controllers/health_reminders_controller.dart
//
// Recordatorios de salud de TODAS las mascotas del usuario
// (GET /health/reminders). Lo usa la tarjeta "Salud" de Home.
// Vencidos primero (el backend ya los ordena).

import 'package:flutter/foundation.dart';

import '../models/health_models.dart';
import '../services/health_service.dart';

class HealthRemindersController extends ChangeNotifier {
  List<HealthReminderModel> _items = [];
  bool _loading = false;

  List<HealthReminderModel> get items => List.unmodifiable(_items);
  bool get hasOverdue => _items.any((r) => r.isOverdue);

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      _items = await HealthService.getReminders(days: 30);
      notifyListeners();
    } catch (_) {
      // Información secundaria en Home: si falla, se conserva lo anterior
      // sin mostrar error (no debe competir con el flujo de emergencia).
    } finally {
      _loading = false;
    }
  }

  void clear() {
    _items = [];
    notifyListeners();
  }
}
