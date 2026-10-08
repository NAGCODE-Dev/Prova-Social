// Browser fallback. The web platform does not expose an application file
// directory, so LocalExamStore keeps its existing preferences representation.
import 'local_exam_payload_store.dart';

class LocalExamPayloadStore implements ExamPayloadStorage {
  @override
  bool get fileBacked => false;

  @override
  Future<String?> read() async => null;
  @override
  Future<String?> readBackup() async => null;
  @override
  Future<bool> write(String payload, {String? backupPayload}) async => false;
  @override
  Future<bool> migrate(String payload) async => false;
}
