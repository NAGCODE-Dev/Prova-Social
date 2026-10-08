import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_exam_payload_store.dart';

/// Durable private exam storage. Writes use a flushed temporary file followed
/// by a rename; the previous complete payload is retained as a backup.
class LocalExamPayloadStore implements ExamPayloadStorage {
  static const _fileName = 'private_exams_v1.json';
  static const _backupName = 'private_exams_v1.json.bak';
  static const _temporaryName = 'private_exams_v1.json.tmp';

  @override
  bool get fileBacked => true;

  Future<Directory> _directory() => getApplicationSupportDirectory();

  @override
  Future<String?> read() async {
    final file = File('${(await _directory()).path}/$_fileName');
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<String?> readBackup() async {
    final file = File('${(await _directory()).path}/$_backupName');
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<bool> write(String payload, {String? backupPayload}) async {
    final directory = await _directory();
    final current = File('${directory.path}/$_fileName');
    final backup = File('${directory.path}/$_backupName');
    final temporary = File('${directory.path}/$_temporaryName');
    final backupTemporary = File('${directory.path}/$_backupName.tmp');
    try {
      if (await current.exists()) {
        if (backupPayload == null) {
          await current.copy(backupTemporary.path);
        } else {
          await backupTemporary.writeAsString(backupPayload, flush: true);
        }
        if (await backup.exists()) await backup.delete();
        await backupTemporary.rename(backup.path);
      } else if (backupPayload != null) {
        await backupTemporary.writeAsString(backupPayload, flush: true);
        if (await backup.exists()) await backup.delete();
        await backupTemporary.rename(backup.path);
      }
      await temporary.writeAsString(payload, flush: true);
      await temporary.rename(current.path);
      return true;
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if (await backupTemporary.exists()) await backupTemporary.delete();
    }
  }

  @override
  Future<bool> migrate(String payload) async {
    if (await read() != null) return true;
    return write(payload, backupPayload: '[]');
  }
}
