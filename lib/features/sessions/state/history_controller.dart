import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../data/session_repository.dart';
import '../data/session_summary.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this._repository);
  final SessionRepository _repository;
  List<SavedSession> sessions = const [];
  bool loading = false;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    sessions = const [];
    error = null;
    notifyListeners();
    try {
      sessions = await _repository.history();
    } catch (failure) {
      error = errorMessage(failure);
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
