import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'assignment.dart';

class AssignmentRepository {
  AssignmentRepository(this._api);
  final ApiClient _api;

  Future<Assignment> fetch() async {
    final json = await _api.get('/v1/assignment');
    return parseModel(() => Assignment.fromJson(json));
  }
}
