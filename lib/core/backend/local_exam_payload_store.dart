export 'local_exam_payload_store_stub.dart'
    if (dart.library.io) 'local_exam_payload_store_io.dart';

abstract interface class ExamPayloadStorage {
  bool get fileBacked;
  Future<String?> read();
  Future<String?> readBackup();
  Future<bool> write(String payload, {String? backupPayload});
  Future<bool> migrate(String payload);
}
