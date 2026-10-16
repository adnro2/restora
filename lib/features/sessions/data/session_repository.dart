import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'session_summary.dart';

abstract interface class SessionRepository {
  Future<SavedSession> save(SessionSummary summary);
  Future<List<SavedSession>> history();
}

class ApiSessionRepository implements SessionRepository {
  ApiSessionRepository(this._api);
  final ApiClient _api;

  @override
  Future<SavedSession> save(SessionSummary summary) async {
    final json = await _api.post('/v1/sessions', summary.toJson());
    return parseModel(() => SavedSession.fromJson(json));
  }

  @override
  Future<List<SavedSession>> history() async {
    final json = await _api.get('/v1/sessions');
    return parseModel(
      () => (json['items'] as List<dynamic>)
          .map((item) => SavedSession.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
