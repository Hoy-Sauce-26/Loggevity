import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database.dart';
import 'metrics_repository.dart';
import 'portability.dart';

enum BackupFormat {
  json('JSON', 'json', 'application/json'),
  csv('CSV', 'csv', 'text/csv');

  const BackupFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}

/// Outcome of an import, for reporting back to the user.
class ImportOutcome {
  const ImportOutcome({
    required this.added,
    required this.skipped,
    required this.errors,
  });

  /// The user cancelled the file picker.
  const ImportOutcome.cancelled()
      : added = 0,
        skipped = 0,
        errors = const [];

  final int added;

  /// Entries already present, so not added again.
  final int skipped;

  final List<String> errors;

  bool get changedAnything => added > 0;
}

/// Reads and writes portable copies of the user's data.
///
/// Export goes through the platform share sheet rather than writing to a fixed
/// location: with no account and no cloud, the user's choice of destination is
/// the only backup story there is.
class BackupService {
  const BackupService(this.db, this.repo);

  final AppDatabase db;
  final MetricsRepository repo;

  String fileName(BackupFormat format, DateTime now) =>
      'loggevity-${now.year.toString().padLeft(4, '0')}'
      '-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}.${format.extension}';

  /// Serialises everything to [format]. Pure enough to test on its own.
  Future<String> render(BackupFormat format) async {
    final rows = await repo.allEntries();
    if (format == BackupFormat.csv) return exportCsv(rows);
    final settings = await db.loadSettings();
    return exportJson(rows, weekStartDay: settings.weekStartDay);
  }

  /// Writes an export to a temporary file and hands it to the share sheet.
  Future<void> export(BackupFormat format, {DateTime? now}) async {
    final contents = await render(format);
    final dir = await getTemporaryDirectory();
    final file =
        File(p.join(dir.path, fileName(format, now ?? DateTime.now())));
    await file.writeAsString(contents);

    // share_plus is held at 10.x deliberately: 13.x requires win32 ^6, which
    // conflicts with the flutter_secure_storage version holding the database
    // encryption key. Encryption wins that tie.
    await Share.shareXFiles(
      [XFile(file.path, mimeType: format.mimeType)],
      subject: 'Loggevity export',
    );
  }

  /// Prompts for a file and merges whatever it contains.
  Future<ImportOutcome> import() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Loggevity export',
          extensions: ['json', 'csv'],
          uniformTypeIdentifiers: [
            'public.json',
            'public.comma-separated-values-text'
          ],
        ),
      ],
    );
    if (file == null) return const ImportOutcome.cancelled();

    final contents = await file.readAsString();
    // Trust the content over the extension: files arrive renamed often enough,
    // and a JSON export is unmistakable from its first character.
    final looksJson = contents.trimLeft().startsWith('{');
    final parsed = looksJson ? parseJson(contents) : parseCsv(contents);

    final added = await repo.importEntries(parsed.entries);
    return ImportOutcome(
      added: added,
      skipped: parsed.entries.length - added,
      errors: parsed.errors,
    );
  }
}
