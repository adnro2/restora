import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../data/assignment.dart';
import '../data/assignment_repository.dart';

class AssignmentController extends ChangeNotifier {
  AssignmentController(this._repository);
  final AssignmentRepository _repository;
  Assignment? assignment;
  String? error;
  bool loading = false;
  bool _disposed = false;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    assignment = null;
    error = null;
    notifyListeners();
    try {
      assignment = await _repository.fetch();
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
