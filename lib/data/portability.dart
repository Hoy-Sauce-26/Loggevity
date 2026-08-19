import 'dart:convert';

import '../scoring/scoring.dart';
import 'database.dart';
import 'week.dart';

/// Schema version written into exports. Bump when the shape changes so an
/// older file can still be recognised and migrated rather than rejected.
const int kExportSchemaVersion = 1;

const String _appTag = 'loggevity';

/// One entry in a portable file, independent of any database identity.
///
/// Row ids are deliberately not exported: they are local storage detail, and
/// carrying them across devices would invite collisions on import.
class PortableEntry {
  const PortableEntry({
    required this.localDate,
    required this.category,
    required this.value,
    required this.occurredAt,
    this.note,
  });

  final String localDate;
  final ActivityCategory category;
  final double value;
  final DateTime occurredAt;
  final String? note;

  /// Identity for de-duplication on import: the same activity, of the same
  /// size, at the same moment. Re-importing a file is then a no-op rather than
  /// a way to silently double your week.
  String get fingerprint =>
      '$localDate|${category.name}|$value|${occurredAt.toUtc().toIso8601String()}';
}

/// What an import produced, including everything it could not use.
class ImportResult {
  const ImportResult({required this.entries, required this.errors});

  final List<PortableEntry> entries;

  /// Human-readable, one per rejected row, naming the row and the reason.
  final List<String> errors;

  bool get isEmpty => entries.isEmpty;
}

/// Raised when a file is not a Loggevity export at all.
class ImportFormatException implements Exception {
  const ImportFormatException(this.message);

  final String message;

  @override
  String toString() => 'ImportFormatException: $message';
}

PortableEntry _fromRow(DailyEntry row) => PortableEntry(
      localDate: row.localDate,
      category: row.category,
      value: row.value,
      occurredAt: row.occurredAt,
      note: row.note,
    );

// --- Export ---

/// Full-fidelity JSON export. This is the format to prefer for backups.
String exportJson(
  List<DailyEntry> rows, {
  int weekStartDay = DateTime.monday,
  DateTime? exportedAt,
}) {
  final payload = {
    'app': _appTag,
    'schemaVersion': kExportSchemaVersion,
    'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'weekStartDay': weekStartDay,
    'entries': [
      for (final row in rows)
        {
          'localDate': row.localDate,
          // Written by name, never by ordinal: the ordinal is a storage detail
          // that would silently recategorise everything if the enum ever moved.
          'category': row.category.name,
          'value': row.value,
          'unit': row.category.unit.name,
          'occurredAt': row.occurredAt.toUtc().toIso8601String(),
          if (row.note != null) 'note': row.note,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

const List<String> kCsvHeader = [
  'local_date',
  'category',
  'value',
  'unit',
  'occurred_at',
  'note',
];

/// Spreadsheet-friendly export. Carries the same entries as the JSON form.
String exportCsv(List<DailyEntry> rows) {
  final buffer = StringBuffer()..writeln(kCsvHeader.join(','));
  for (final row in rows) {
    buffer.writeln([
      row.localDate,
      row.category.name,
      _number(row.value),
      row.category.unit.name,
      row.occurredAt.toUtc().toIso8601String(),
      _csvField(row.note ?? ''),
    ].join(','));
  }
  return buffer.toString();
}

String _number(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String _csvField(String value) {
  if (!value.contains(RegExp('[",\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

// --- Import ---

/// Parses a JSON export. Rejects files that are not Loggevity exports, but
/// tolerates individual bad entries, reporting them rather than failing whole.
ImportResult parseJson(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    throw ImportFormatException('not valid JSON (${e.message})');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ImportFormatException(
        'expected a JSON object at the top level');
  }
  if (decoded['app'] != _appTag) {
    throw const ImportFormatException('not a Loggevity export');
  }
  final version = decoded['schemaVersion'];
  if (version is! int || version > kExportSchemaVersion) {
    throw ImportFormatException(
        'unsupported export version $version - this app reads up to '
        '$kExportSchemaVersion');
  }
  final raw = decoded['entries'];
  if (raw is! List) {
    throw const ImportFormatException('missing an "entries" list');
  }

  final entries = <PortableEntry>[];
  final errors = <String>[];
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map<String, dynamic>) {
      errors.add('entry ${i + 1}: not an object');
      continue;
    }
    try {
      entries.add(_parseEntry(
        category: item['category'],
        value: item['value'],
        localDate: item['localDate'],
        occurredAt: item['occurredAt'],
        note: item['note'] as String?,
      ));
    } on FormatException catch (e) {
      errors.add('entry ${i + 1}: ${e.message}');
    }
  }
  return ImportResult(entries: entries, errors: errors);
}

/// Parses a CSV export, matching columns by header name so column order and
/// extra columns do not matter.
ImportResult parseCsv(String source) {
  final lines = const LineSplitter().convert(source)
    ..removeWhere((l) => l.trim().isEmpty);
  if (lines.isEmpty) {
    throw const ImportFormatException('the file is empty');
  }
  final header = _splitCsvLine(lines.first).map((h) => h.trim()).toList();
  for (final required in ['local_date', 'category', 'value', 'occurred_at']) {
    if (!header.contains(required)) {
      throw ImportFormatException('missing required column "$required"');
    }
  }

  final entries = <PortableEntry>[];
  final errors = <String>[];
  for (var i = 1; i < lines.length; i++) {
    final cells = _splitCsvLine(lines[i]);
    if (cells.length < header.length) {
      errors.add('row ${i + 1}: expected ${header.length} columns, '
          'found ${cells.length}');
      continue;
    }
    String? cell(String name) {
      final index = header.indexOf(name);
      return index == -1 ? null : cells[index];
    }

    try {
      final note = cell('note');
      entries.add(_parseEntry(
        category: cell('category'),
        value: cell('value'),
        localDate: cell('local_date'),
        occurredAt: cell('occurred_at'),
        note: (note == null || note.isEmpty) ? null : note,
      ));
    } on FormatException catch (e) {
      errors.add('row ${i + 1}: ${e.message}');
    }
  }
  return ImportResult(entries: entries, errors: errors);
}

PortableEntry _parseEntry({
  required Object? category,
  required Object? value,
  required Object? localDate,
  required Object? occurredAt,
  String? note,
}) {
  final matched =
      ActivityCategory.values.where((c) => c.name == category).firstOrNull;
  if (matched == null) {
    throw FormatException('unknown category "$category"');
  }

  final parsedValue =
      value is num ? value.toDouble() : double.tryParse('$value');
  if (parsedValue == null || parsedValue.isNaN || parsedValue.isInfinite) {
    throw FormatException('value "$value" is not a number');
  }

  final parsedAt = DateTime.tryParse('$occurredAt');
  if (parsedAt == null) {
    throw FormatException('occurredAt "$occurredAt" is not a date');
  }

  // A missing or malformed day key is recoverable: derive it from the
  // timestamp rather than discarding an otherwise good entry.
  var day = '$localDate';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
    day = localDateKey(parsedAt.toLocal());
  }

  return PortableEntry(
    localDate: day,
    category: matched,
    value: parsedValue,
    occurredAt: parsedAt.toUtc(),
    note: note,
  );
}

List<String> _splitCsvLine(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      cells.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  cells.add(buffer.toString());
  return cells;
}

/// Convenience for callers holding database rows.
List<PortableEntry> toPortable(List<DailyEntry> rows) =>
    rows.map(_fromRow).toList();
