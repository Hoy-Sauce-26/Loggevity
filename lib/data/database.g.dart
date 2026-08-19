// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DailyEntriesTable extends DailyEntries
    with TableInfo<$DailyEntriesTable, DailyEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _localDateMeta =
      const VerificationMeta('localDate');
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
      'local_date', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 10, maxTextLength: 10),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<ActivityCategory, int> category =
      GeneratedColumn<int>('category', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<ActivityCategory>(
              $DailyEntriesTable.$convertercategory);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
      'value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, occurredAt, localDate, category, value, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_entries';
  @override
  VerificationContext validateIntegrity(Insertable<DailyEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(_localDateMeta,
          localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta));
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      localDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_date'])!,
      category: $DailyEntriesTable.$convertercategory.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category'])!),
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $DailyEntriesTable createAlias(String alias) {
    return $DailyEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ActivityCategory, int, int> $convertercategory =
      const EnumIndexConverter<ActivityCategory>(ActivityCategory.values);
}

class DailyEntry extends DataClass implements Insertable<DailyEntry> {
  final int id;
  final DateTime occurredAt;
  final String localDate;

  /// Stored as the enum's ordinal. See `enum_ordinals_test.dart` - reordering
  /// [ActivityCategory] would silently recategorise every existing row.
  final ActivityCategory category;

  /// Minutes for the four activity categories and nature; hours for
  /// socializing and sleep. See [ActivityCategory.unit].
  final double value;
  final String? note;
  const DailyEntry(
      {required this.id,
      required this.occurredAt,
      required this.localDate,
      required this.category,
      required this.value,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['local_date'] = Variable<String>(localDate);
    {
      map['category'] =
          Variable<int>($DailyEntriesTable.$convertercategory.toSql(category));
    }
    map['value'] = Variable<double>(value);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  DailyEntriesCompanion toCompanion(bool nullToAbsent) {
    return DailyEntriesCompanion(
      id: Value(id),
      occurredAt: Value(occurredAt),
      localDate: Value(localDate),
      category: Value(category),
      value: Value(value),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory DailyEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyEntry(
      id: serializer.fromJson<int>(json['id']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      localDate: serializer.fromJson<String>(json['localDate']),
      category: $DailyEntriesTable.$convertercategory
          .fromJson(serializer.fromJson<int>(json['category'])),
      value: serializer.fromJson<double>(json['value']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'localDate': serializer.toJson<String>(localDate),
      'category': serializer
          .toJson<int>($DailyEntriesTable.$convertercategory.toJson(category)),
      'value': serializer.toJson<double>(value),
      'note': serializer.toJson<String?>(note),
    };
  }

  DailyEntry copyWith(
          {int? id,
          DateTime? occurredAt,
          String? localDate,
          ActivityCategory? category,
          double? value,
          Value<String?> note = const Value.absent()}) =>
      DailyEntry(
        id: id ?? this.id,
        occurredAt: occurredAt ?? this.occurredAt,
        localDate: localDate ?? this.localDate,
        category: category ?? this.category,
        value: value ?? this.value,
        note: note.present ? note.value : this.note,
      );
  DailyEntry copyWithCompanion(DailyEntriesCompanion data) {
    return DailyEntry(
      id: data.id.present ? data.id.value : this.id,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      category: data.category.present ? data.category.value : this.category,
      value: data.value.present ? data.value.value : this.value,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyEntry(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('localDate: $localDate, ')
          ..write('category: $category, ')
          ..write('value: $value, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, occurredAt, localDate, category, value, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyEntry &&
          other.id == this.id &&
          other.occurredAt == this.occurredAt &&
          other.localDate == this.localDate &&
          other.category == this.category &&
          other.value == this.value &&
          other.note == this.note);
}

class DailyEntriesCompanion extends UpdateCompanion<DailyEntry> {
  final Value<int> id;
  final Value<DateTime> occurredAt;
  final Value<String> localDate;
  final Value<ActivityCategory> category;
  final Value<double> value;
  final Value<String?> note;
  const DailyEntriesCompanion({
    this.id = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.localDate = const Value.absent(),
    this.category = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
  });
  DailyEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime occurredAt,
    required String localDate,
    required ActivityCategory category,
    required double value,
    this.note = const Value.absent(),
  })  : occurredAt = Value(occurredAt),
        localDate = Value(localDate),
        category = Value(category),
        value = Value(value);
  static Insertable<DailyEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? occurredAt,
    Expression<String>? localDate,
    Expression<int>? category,
    Expression<double>? value,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (localDate != null) 'local_date': localDate,
      if (category != null) 'category': category,
      if (value != null) 'value': value,
      if (note != null) 'note': note,
    });
  }

  DailyEntriesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? occurredAt,
      Value<String>? localDate,
      Value<ActivityCategory>? category,
      Value<double>? value,
      Value<String?>? note}) {
    return DailyEntriesCompanion(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      localDate: localDate ?? this.localDate,
      category: category ?? this.category,
      value: value ?? this.value,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(
          $DailyEntriesTable.$convertercategory.toSql(category.value));
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyEntriesCompanion(')
          ..write('id: $id, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('localDate: $localDate, ')
          ..write('category: $category, ')
          ..write('value: $value, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $WeeklySnapshotsTable extends WeeklySnapshots
    with TableInfo<$WeeklySnapshotsTable, WeeklySnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklySnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _weekStartDateMeta =
      const VerificationMeta('weekStartDate');
  @override
  late final GeneratedColumn<DateTime> weekStartDate =
      GeneratedColumn<DateTime>('week_start_date', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _weekStartDayMeta =
      const VerificationMeta('weekStartDay');
  @override
  late final GeneratedColumn<int> weekStartDay = GeneratedColumn<int>(
      'week_start_day', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(DateTime.monday));
  static const VerificationMeta _compositeScoreMeta =
      const VerificationMeta('compositeScore');
  @override
  late final GeneratedColumn<double> compositeScore = GeneratedColumn<double>(
      'composite_score', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scoreModPAMeta =
      const VerificationMeta('scoreModPA');
  @override
  late final GeneratedColumn<double> scoreModPA = GeneratedColumn<double>(
      'score_mod_p_a', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scoreVigPAMeta =
      const VerificationMeta('scoreVigPA');
  @override
  late final GeneratedColumn<double> scoreVigPA = GeneratedColumn<double>(
      'score_vig_p_a', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scoreResMeta =
      const VerificationMeta('scoreRes');
  @override
  late final GeneratedColumn<double> scoreRes = GeneratedColumn<double>(
      'score_res', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scoreFlexMeta =
      const VerificationMeta('scoreFlex');
  @override
  late final GeneratedColumn<double> scoreFlex = GeneratedColumn<double>(
      'score_flex', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scoreNatMeta =
      const VerificationMeta('scoreNat');
  @override
  late final GeneratedColumn<double> scoreNat = GeneratedColumn<double>(
      'score_nat', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scoreSocMeta =
      const VerificationMeta('scoreSoc');
  @override
  late final GeneratedColumn<double> scoreSoc = GeneratedColumn<double>(
      'score_soc', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _scoreSleepMeta =
      const VerificationMeta('scoreSleep');
  @override
  late final GeneratedColumn<double> scoreSleep = GeneratedColumn<double>(
      'score_sleep', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _isSealedMeta =
      const VerificationMeta('isSealed');
  @override
  late final GeneratedColumn<bool> isSealed = GeneratedColumn<bool>(
      'is_sealed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_sealed" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        weekStartDate,
        weekStartDay,
        compositeScore,
        scoreModPA,
        scoreVigPA,
        scoreRes,
        scoreFlex,
        scoreNat,
        scoreSoc,
        scoreSleep,
        isSealed
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<WeeklySnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('week_start_date')) {
      context.handle(
          _weekStartDateMeta,
          weekStartDate.isAcceptableOrUnknown(
              data['week_start_date']!, _weekStartDateMeta));
    } else if (isInserting) {
      context.missing(_weekStartDateMeta);
    }
    if (data.containsKey('week_start_day')) {
      context.handle(
          _weekStartDayMeta,
          weekStartDay.isAcceptableOrUnknown(
              data['week_start_day']!, _weekStartDayMeta));
    }
    if (data.containsKey('composite_score')) {
      context.handle(
          _compositeScoreMeta,
          compositeScore.isAcceptableOrUnknown(
              data['composite_score']!, _compositeScoreMeta));
    } else if (isInserting) {
      context.missing(_compositeScoreMeta);
    }
    if (data.containsKey('score_mod_p_a')) {
      context.handle(
          _scoreModPAMeta,
          scoreModPA.isAcceptableOrUnknown(
              data['score_mod_p_a']!, _scoreModPAMeta));
    } else if (isInserting) {
      context.missing(_scoreModPAMeta);
    }
    if (data.containsKey('score_vig_p_a')) {
      context.handle(
          _scoreVigPAMeta,
          scoreVigPA.isAcceptableOrUnknown(
              data['score_vig_p_a']!, _scoreVigPAMeta));
    } else if (isInserting) {
      context.missing(_scoreVigPAMeta);
    }
    if (data.containsKey('score_res')) {
      context.handle(_scoreResMeta,
          scoreRes.isAcceptableOrUnknown(data['score_res']!, _scoreResMeta));
    } else if (isInserting) {
      context.missing(_scoreResMeta);
    }
    if (data.containsKey('score_flex')) {
      context.handle(_scoreFlexMeta,
          scoreFlex.isAcceptableOrUnknown(data['score_flex']!, _scoreFlexMeta));
    } else if (isInserting) {
      context.missing(_scoreFlexMeta);
    }
    if (data.containsKey('score_nat')) {
      context.handle(_scoreNatMeta,
          scoreNat.isAcceptableOrUnknown(data['score_nat']!, _scoreNatMeta));
    } else if (isInserting) {
      context.missing(_scoreNatMeta);
    }
    if (data.containsKey('score_soc')) {
      context.handle(_scoreSocMeta,
          scoreSoc.isAcceptableOrUnknown(data['score_soc']!, _scoreSocMeta));
    } else if (isInserting) {
      context.missing(_scoreSocMeta);
    }
    if (data.containsKey('score_sleep')) {
      context.handle(
          _scoreSleepMeta,
          scoreSleep.isAcceptableOrUnknown(
              data['score_sleep']!, _scoreSleepMeta));
    } else if (isInserting) {
      context.missing(_scoreSleepMeta);
    }
    if (data.containsKey('is_sealed')) {
      context.handle(_isSealedMeta,
          isSealed.isAcceptableOrUnknown(data['is_sealed']!, _isSealedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeeklySnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklySnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      weekStartDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}week_start_date'])!,
      weekStartDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_start_day'])!,
      compositeScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}composite_score'])!,
      scoreModPA: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score_mod_p_a'])!,
      scoreVigPA: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score_vig_p_a'])!,
      scoreRes: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score_res'])!,
      scoreFlex: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score_flex'])!,
      scoreNat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score_nat'])!,
      scoreSoc: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score_soc'])!,
      scoreSleep: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score_sleep'])!,
      isSealed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_sealed'])!,
    );
  }

  @override
  $WeeklySnapshotsTable createAlias(String alias) {
    return $WeeklySnapshotsTable(attachedDatabase, alias);
  }
}

class WeeklySnapshot extends DataClass implements Insertable<WeeklySnapshot> {
  final int id;

  /// Local midnight on the first day of the week. Unique, and interpreted
  /// against the week-start setting in force when the snapshot was sealed.
  final DateTime weekStartDate;

  /// Which weekday this snapshot's week began on, captured at seal time so a
  /// later change to the setting cannot retroactively reinterpret history.
  final int weekStartDay;
  final double compositeScore;
  final double scoreModPA;
  final double scoreVigPA;
  final double scoreRes;
  final double scoreFlex;
  final double scoreNat;
  final double scoreSoc;
  final double scoreSleep;
  final bool isSealed;
  const WeeklySnapshot(
      {required this.id,
      required this.weekStartDate,
      required this.weekStartDay,
      required this.compositeScore,
      required this.scoreModPA,
      required this.scoreVigPA,
      required this.scoreRes,
      required this.scoreFlex,
      required this.scoreNat,
      required this.scoreSoc,
      required this.scoreSleep,
      required this.isSealed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['week_start_date'] = Variable<DateTime>(weekStartDate);
    map['week_start_day'] = Variable<int>(weekStartDay);
    map['composite_score'] = Variable<double>(compositeScore);
    map['score_mod_p_a'] = Variable<double>(scoreModPA);
    map['score_vig_p_a'] = Variable<double>(scoreVigPA);
    map['score_res'] = Variable<double>(scoreRes);
    map['score_flex'] = Variable<double>(scoreFlex);
    map['score_nat'] = Variable<double>(scoreNat);
    map['score_soc'] = Variable<double>(scoreSoc);
    map['score_sleep'] = Variable<double>(scoreSleep);
    map['is_sealed'] = Variable<bool>(isSealed);
    return map;
  }

  WeeklySnapshotsCompanion toCompanion(bool nullToAbsent) {
    return WeeklySnapshotsCompanion(
      id: Value(id),
      weekStartDate: Value(weekStartDate),
      weekStartDay: Value(weekStartDay),
      compositeScore: Value(compositeScore),
      scoreModPA: Value(scoreModPA),
      scoreVigPA: Value(scoreVigPA),
      scoreRes: Value(scoreRes),
      scoreFlex: Value(scoreFlex),
      scoreNat: Value(scoreNat),
      scoreSoc: Value(scoreSoc),
      scoreSleep: Value(scoreSleep),
      isSealed: Value(isSealed),
    );
  }

  factory WeeklySnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklySnapshot(
      id: serializer.fromJson<int>(json['id']),
      weekStartDate: serializer.fromJson<DateTime>(json['weekStartDate']),
      weekStartDay: serializer.fromJson<int>(json['weekStartDay']),
      compositeScore: serializer.fromJson<double>(json['compositeScore']),
      scoreModPA: serializer.fromJson<double>(json['scoreModPA']),
      scoreVigPA: serializer.fromJson<double>(json['scoreVigPA']),
      scoreRes: serializer.fromJson<double>(json['scoreRes']),
      scoreFlex: serializer.fromJson<double>(json['scoreFlex']),
      scoreNat: serializer.fromJson<double>(json['scoreNat']),
      scoreSoc: serializer.fromJson<double>(json['scoreSoc']),
      scoreSleep: serializer.fromJson<double>(json['scoreSleep']),
      isSealed: serializer.fromJson<bool>(json['isSealed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weekStartDate': serializer.toJson<DateTime>(weekStartDate),
      'weekStartDay': serializer.toJson<int>(weekStartDay),
      'compositeScore': serializer.toJson<double>(compositeScore),
      'scoreModPA': serializer.toJson<double>(scoreModPA),
      'scoreVigPA': serializer.toJson<double>(scoreVigPA),
      'scoreRes': serializer.toJson<double>(scoreRes),
      'scoreFlex': serializer.toJson<double>(scoreFlex),
      'scoreNat': serializer.toJson<double>(scoreNat),
      'scoreSoc': serializer.toJson<double>(scoreSoc),
      'scoreSleep': serializer.toJson<double>(scoreSleep),
      'isSealed': serializer.toJson<bool>(isSealed),
    };
  }

  WeeklySnapshot copyWith(
          {int? id,
          DateTime? weekStartDate,
          int? weekStartDay,
          double? compositeScore,
          double? scoreModPA,
          double? scoreVigPA,
          double? scoreRes,
          double? scoreFlex,
          double? scoreNat,
          double? scoreSoc,
          double? scoreSleep,
          bool? isSealed}) =>
      WeeklySnapshot(
        id: id ?? this.id,
        weekStartDate: weekStartDate ?? this.weekStartDate,
        weekStartDay: weekStartDay ?? this.weekStartDay,
        compositeScore: compositeScore ?? this.compositeScore,
        scoreModPA: scoreModPA ?? this.scoreModPA,
        scoreVigPA: scoreVigPA ?? this.scoreVigPA,
        scoreRes: scoreRes ?? this.scoreRes,
        scoreFlex: scoreFlex ?? this.scoreFlex,
        scoreNat: scoreNat ?? this.scoreNat,
        scoreSoc: scoreSoc ?? this.scoreSoc,
        scoreSleep: scoreSleep ?? this.scoreSleep,
        isSealed: isSealed ?? this.isSealed,
      );
  WeeklySnapshot copyWithCompanion(WeeklySnapshotsCompanion data) {
    return WeeklySnapshot(
      id: data.id.present ? data.id.value : this.id,
      weekStartDate: data.weekStartDate.present
          ? data.weekStartDate.value
          : this.weekStartDate,
      weekStartDay: data.weekStartDay.present
          ? data.weekStartDay.value
          : this.weekStartDay,
      compositeScore: data.compositeScore.present
          ? data.compositeScore.value
          : this.compositeScore,
      scoreModPA:
          data.scoreModPA.present ? data.scoreModPA.value : this.scoreModPA,
      scoreVigPA:
          data.scoreVigPA.present ? data.scoreVigPA.value : this.scoreVigPA,
      scoreRes: data.scoreRes.present ? data.scoreRes.value : this.scoreRes,
      scoreFlex: data.scoreFlex.present ? data.scoreFlex.value : this.scoreFlex,
      scoreNat: data.scoreNat.present ? data.scoreNat.value : this.scoreNat,
      scoreSoc: data.scoreSoc.present ? data.scoreSoc.value : this.scoreSoc,
      scoreSleep:
          data.scoreSleep.present ? data.scoreSleep.value : this.scoreSleep,
      isSealed: data.isSealed.present ? data.isSealed.value : this.isSealed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklySnapshot(')
          ..write('id: $id, ')
          ..write('weekStartDate: $weekStartDate, ')
          ..write('weekStartDay: $weekStartDay, ')
          ..write('compositeScore: $compositeScore, ')
          ..write('scoreModPA: $scoreModPA, ')
          ..write('scoreVigPA: $scoreVigPA, ')
          ..write('scoreRes: $scoreRes, ')
          ..write('scoreFlex: $scoreFlex, ')
          ..write('scoreNat: $scoreNat, ')
          ..write('scoreSoc: $scoreSoc, ')
          ..write('scoreSleep: $scoreSleep, ')
          ..write('isSealed: $isSealed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      weekStartDate,
      weekStartDay,
      compositeScore,
      scoreModPA,
      scoreVigPA,
      scoreRes,
      scoreFlex,
      scoreNat,
      scoreSoc,
      scoreSleep,
      isSealed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklySnapshot &&
          other.id == this.id &&
          other.weekStartDate == this.weekStartDate &&
          other.weekStartDay == this.weekStartDay &&
          other.compositeScore == this.compositeScore &&
          other.scoreModPA == this.scoreModPA &&
          other.scoreVigPA == this.scoreVigPA &&
          other.scoreRes == this.scoreRes &&
          other.scoreFlex == this.scoreFlex &&
          other.scoreNat == this.scoreNat &&
          other.scoreSoc == this.scoreSoc &&
          other.scoreSleep == this.scoreSleep &&
          other.isSealed == this.isSealed);
}

class WeeklySnapshotsCompanion extends UpdateCompanion<WeeklySnapshot> {
  final Value<int> id;
  final Value<DateTime> weekStartDate;
  final Value<int> weekStartDay;
  final Value<double> compositeScore;
  final Value<double> scoreModPA;
  final Value<double> scoreVigPA;
  final Value<double> scoreRes;
  final Value<double> scoreFlex;
  final Value<double> scoreNat;
  final Value<double> scoreSoc;
  final Value<double> scoreSleep;
  final Value<bool> isSealed;
  const WeeklySnapshotsCompanion({
    this.id = const Value.absent(),
    this.weekStartDate = const Value.absent(),
    this.weekStartDay = const Value.absent(),
    this.compositeScore = const Value.absent(),
    this.scoreModPA = const Value.absent(),
    this.scoreVigPA = const Value.absent(),
    this.scoreRes = const Value.absent(),
    this.scoreFlex = const Value.absent(),
    this.scoreNat = const Value.absent(),
    this.scoreSoc = const Value.absent(),
    this.scoreSleep = const Value.absent(),
    this.isSealed = const Value.absent(),
  });
  WeeklySnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime weekStartDate,
    this.weekStartDay = const Value.absent(),
    required double compositeScore,
    required double scoreModPA,
    required double scoreVigPA,
    required double scoreRes,
    required double scoreFlex,
    required double scoreNat,
    required double scoreSoc,
    required double scoreSleep,
    this.isSealed = const Value.absent(),
  })  : weekStartDate = Value(weekStartDate),
        compositeScore = Value(compositeScore),
        scoreModPA = Value(scoreModPA),
        scoreVigPA = Value(scoreVigPA),
        scoreRes = Value(scoreRes),
        scoreFlex = Value(scoreFlex),
        scoreNat = Value(scoreNat),
        scoreSoc = Value(scoreSoc),
        scoreSleep = Value(scoreSleep);
  static Insertable<WeeklySnapshot> custom({
    Expression<int>? id,
    Expression<DateTime>? weekStartDate,
    Expression<int>? weekStartDay,
    Expression<double>? compositeScore,
    Expression<double>? scoreModPA,
    Expression<double>? scoreVigPA,
    Expression<double>? scoreRes,
    Expression<double>? scoreFlex,
    Expression<double>? scoreNat,
    Expression<double>? scoreSoc,
    Expression<double>? scoreSleep,
    Expression<bool>? isSealed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weekStartDate != null) 'week_start_date': weekStartDate,
      if (weekStartDay != null) 'week_start_day': weekStartDay,
      if (compositeScore != null) 'composite_score': compositeScore,
      if (scoreModPA != null) 'score_mod_p_a': scoreModPA,
      if (scoreVigPA != null) 'score_vig_p_a': scoreVigPA,
      if (scoreRes != null) 'score_res': scoreRes,
      if (scoreFlex != null) 'score_flex': scoreFlex,
      if (scoreNat != null) 'score_nat': scoreNat,
      if (scoreSoc != null) 'score_soc': scoreSoc,
      if (scoreSleep != null) 'score_sleep': scoreSleep,
      if (isSealed != null) 'is_sealed': isSealed,
    });
  }

  WeeklySnapshotsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? weekStartDate,
      Value<int>? weekStartDay,
      Value<double>? compositeScore,
      Value<double>? scoreModPA,
      Value<double>? scoreVigPA,
      Value<double>? scoreRes,
      Value<double>? scoreFlex,
      Value<double>? scoreNat,
      Value<double>? scoreSoc,
      Value<double>? scoreSleep,
      Value<bool>? isSealed}) {
    return WeeklySnapshotsCompanion(
      id: id ?? this.id,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      compositeScore: compositeScore ?? this.compositeScore,
      scoreModPA: scoreModPA ?? this.scoreModPA,
      scoreVigPA: scoreVigPA ?? this.scoreVigPA,
      scoreRes: scoreRes ?? this.scoreRes,
      scoreFlex: scoreFlex ?? this.scoreFlex,
      scoreNat: scoreNat ?? this.scoreNat,
      scoreSoc: scoreSoc ?? this.scoreSoc,
      scoreSleep: scoreSleep ?? this.scoreSleep,
      isSealed: isSealed ?? this.isSealed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (weekStartDate.present) {
      map['week_start_date'] = Variable<DateTime>(weekStartDate.value);
    }
    if (weekStartDay.present) {
      map['week_start_day'] = Variable<int>(weekStartDay.value);
    }
    if (compositeScore.present) {
      map['composite_score'] = Variable<double>(compositeScore.value);
    }
    if (scoreModPA.present) {
      map['score_mod_p_a'] = Variable<double>(scoreModPA.value);
    }
    if (scoreVigPA.present) {
      map['score_vig_p_a'] = Variable<double>(scoreVigPA.value);
    }
    if (scoreRes.present) {
      map['score_res'] = Variable<double>(scoreRes.value);
    }
    if (scoreFlex.present) {
      map['score_flex'] = Variable<double>(scoreFlex.value);
    }
    if (scoreNat.present) {
      map['score_nat'] = Variable<double>(scoreNat.value);
    }
    if (scoreSoc.present) {
      map['score_soc'] = Variable<double>(scoreSoc.value);
    }
    if (scoreSleep.present) {
      map['score_sleep'] = Variable<double>(scoreSleep.value);
    }
    if (isSealed.present) {
      map['is_sealed'] = Variable<bool>(isSealed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklySnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('weekStartDate: $weekStartDate, ')
          ..write('weekStartDay: $weekStartDay, ')
          ..write('compositeScore: $compositeScore, ')
          ..write('scoreModPA: $scoreModPA, ')
          ..write('scoreVigPA: $scoreVigPA, ')
          ..write('scoreRes: $scoreRes, ')
          ..write('scoreFlex: $scoreFlex, ')
          ..write('scoreNat: $scoreNat, ')
          ..write('scoreSoc: $scoreSoc, ')
          ..write('scoreSleep: $scoreSleep, ')
          ..write('isSealed: $isSealed')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _weekStartDayMeta =
      const VerificationMeta('weekStartDay');
  @override
  late final GeneratedColumn<int> weekStartDay = GeneratedColumn<int>(
      'week_start_day', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(DateTime.monday));
  @override
  List<GeneratedColumn> get $columns => [id, weekStartDay];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('week_start_day')) {
      context.handle(
          _weekStartDayMeta,
          weekStartDay.isAcceptableOrUnknown(
              data['week_start_day']!, _weekStartDayMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      weekStartDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_start_day'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  /// Always 0 - this table holds exactly one row.
  final int id;

  /// 1 = Monday .. 7 = Sunday. User-configurable.
  final int weekStartDay;
  const AppSetting({required this.id, required this.weekStartDay});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['week_start_day'] = Variable<int>(weekStartDay);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      weekStartDay: Value(weekStartDay),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      weekStartDay: serializer.fromJson<int>(json['weekStartDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weekStartDay': serializer.toJson<int>(weekStartDay),
    };
  }

  AppSetting copyWith({int? id, int? weekStartDay}) => AppSetting(
        id: id ?? this.id,
        weekStartDay: weekStartDay ?? this.weekStartDay,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      weekStartDay: data.weekStartDay.present
          ? data.weekStartDay.value
          : this.weekStartDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('weekStartDay: $weekStartDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, weekStartDay);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.weekStartDay == this.weekStartDay);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<int> weekStartDay;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.weekStartDay = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.weekStartDay = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<int>? weekStartDay,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weekStartDay != null) 'week_start_day': weekStartDay,
    });
  }

  AppSettingsCompanion copyWith({Value<int>? id, Value<int>? weekStartDay}) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      weekStartDay: weekStartDay ?? this.weekStartDay,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (weekStartDay.present) {
      map['week_start_day'] = Variable<int>(weekStartDay.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('weekStartDay: $weekStartDay')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DailyEntriesTable dailyEntries = $DailyEntriesTable(this);
  late final $WeeklySnapshotsTable weeklySnapshots =
      $WeeklySnapshotsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index idxDailyEntriesLocalDate = Index(
      'idx_daily_entries_local_date',
      'CREATE INDEX idx_daily_entries_local_date ON daily_entries (local_date)');
  late final Index idxDailyEntriesCategory = Index('idx_daily_entries_category',
      'CREATE INDEX idx_daily_entries_category ON daily_entries (category)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        dailyEntries,
        weeklySnapshots,
        appSettings,
        idxDailyEntriesLocalDate,
        idxDailyEntriesCategory
      ];
}

typedef $$DailyEntriesTableCreateCompanionBuilder = DailyEntriesCompanion
    Function({
  Value<int> id,
  required DateTime occurredAt,
  required String localDate,
  required ActivityCategory category,
  required double value,
  Value<String?> note,
});
typedef $$DailyEntriesTableUpdateCompanionBuilder = DailyEntriesCompanion
    Function({
  Value<int> id,
  Value<DateTime> occurredAt,
  Value<String> localDate,
  Value<ActivityCategory> category,
  Value<double> value,
  Value<String?> note,
});

class $$DailyEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DailyEntriesTable> {
  $$DailyEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ActivityCategory, ActivityCategory, int>
      get category => $composableBuilder(
          column: $table.category,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$DailyEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyEntriesTable> {
  $$DailyEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$DailyEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyEntriesTable> {
  $$DailyEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ActivityCategory, int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$DailyEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailyEntriesTable,
    DailyEntry,
    $$DailyEntriesTableFilterComposer,
    $$DailyEntriesTableOrderingComposer,
    $$DailyEntriesTableAnnotationComposer,
    $$DailyEntriesTableCreateCompanionBuilder,
    $$DailyEntriesTableUpdateCompanionBuilder,
    (DailyEntry, BaseReferences<_$AppDatabase, $DailyEntriesTable, DailyEntry>),
    DailyEntry,
    PrefetchHooks Function()> {
  $$DailyEntriesTableTableManager(_$AppDatabase db, $DailyEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<String> localDate = const Value.absent(),
            Value<ActivityCategory> category = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String?> note = const Value.absent(),
          }) =>
              DailyEntriesCompanion(
            id: id,
            occurredAt: occurredAt,
            localDate: localDate,
            category: category,
            value: value,
            note: note,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime occurredAt,
            required String localDate,
            required ActivityCategory category,
            required double value,
            Value<String?> note = const Value.absent(),
          }) =>
              DailyEntriesCompanion.insert(
            id: id,
            occurredAt: occurredAt,
            localDate: localDate,
            category: category,
            value: value,
            note: note,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DailyEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DailyEntriesTable,
    DailyEntry,
    $$DailyEntriesTableFilterComposer,
    $$DailyEntriesTableOrderingComposer,
    $$DailyEntriesTableAnnotationComposer,
    $$DailyEntriesTableCreateCompanionBuilder,
    $$DailyEntriesTableUpdateCompanionBuilder,
    (DailyEntry, BaseReferences<_$AppDatabase, $DailyEntriesTable, DailyEntry>),
    DailyEntry,
    PrefetchHooks Function()>;
typedef $$WeeklySnapshotsTableCreateCompanionBuilder = WeeklySnapshotsCompanion
    Function({
  Value<int> id,
  required DateTime weekStartDate,
  Value<int> weekStartDay,
  required double compositeScore,
  required double scoreModPA,
  required double scoreVigPA,
  required double scoreRes,
  required double scoreFlex,
  required double scoreNat,
  required double scoreSoc,
  required double scoreSleep,
  Value<bool> isSealed,
});
typedef $$WeeklySnapshotsTableUpdateCompanionBuilder = WeeklySnapshotsCompanion
    Function({
  Value<int> id,
  Value<DateTime> weekStartDate,
  Value<int> weekStartDay,
  Value<double> compositeScore,
  Value<double> scoreModPA,
  Value<double> scoreVigPA,
  Value<double> scoreRes,
  Value<double> scoreFlex,
  Value<double> scoreNat,
  Value<double> scoreSoc,
  Value<double> scoreSleep,
  Value<bool> isSealed,
});

class $$WeeklySnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklySnapshotsTable> {
  $$WeeklySnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get weekStartDate => $composableBuilder(
      column: $table.weekStartDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekStartDay => $composableBuilder(
      column: $table.weekStartDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get compositeScore => $composableBuilder(
      column: $table.compositeScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scoreModPA => $composableBuilder(
      column: $table.scoreModPA, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scoreVigPA => $composableBuilder(
      column: $table.scoreVigPA, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scoreRes => $composableBuilder(
      column: $table.scoreRes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scoreFlex => $composableBuilder(
      column: $table.scoreFlex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scoreNat => $composableBuilder(
      column: $table.scoreNat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scoreSoc => $composableBuilder(
      column: $table.scoreSoc, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get scoreSleep => $composableBuilder(
      column: $table.scoreSleep, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isSealed => $composableBuilder(
      column: $table.isSealed, builder: (column) => ColumnFilters(column));
}

class $$WeeklySnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklySnapshotsTable> {
  $$WeeklySnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get weekStartDate => $composableBuilder(
      column: $table.weekStartDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekStartDay => $composableBuilder(
      column: $table.weekStartDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get compositeScore => $composableBuilder(
      column: $table.compositeScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scoreModPA => $composableBuilder(
      column: $table.scoreModPA, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scoreVigPA => $composableBuilder(
      column: $table.scoreVigPA, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scoreRes => $composableBuilder(
      column: $table.scoreRes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scoreFlex => $composableBuilder(
      column: $table.scoreFlex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scoreNat => $composableBuilder(
      column: $table.scoreNat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scoreSoc => $composableBuilder(
      column: $table.scoreSoc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get scoreSleep => $composableBuilder(
      column: $table.scoreSleep, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSealed => $composableBuilder(
      column: $table.isSealed, builder: (column) => ColumnOrderings(column));
}

class $$WeeklySnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklySnapshotsTable> {
  $$WeeklySnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get weekStartDate => $composableBuilder(
      column: $table.weekStartDate, builder: (column) => column);

  GeneratedColumn<int> get weekStartDay => $composableBuilder(
      column: $table.weekStartDay, builder: (column) => column);

  GeneratedColumn<double> get compositeScore => $composableBuilder(
      column: $table.compositeScore, builder: (column) => column);

  GeneratedColumn<double> get scoreModPA => $composableBuilder(
      column: $table.scoreModPA, builder: (column) => column);

  GeneratedColumn<double> get scoreVigPA => $composableBuilder(
      column: $table.scoreVigPA, builder: (column) => column);

  GeneratedColumn<double> get scoreRes =>
      $composableBuilder(column: $table.scoreRes, builder: (column) => column);

  GeneratedColumn<double> get scoreFlex =>
      $composableBuilder(column: $table.scoreFlex, builder: (column) => column);

  GeneratedColumn<double> get scoreNat =>
      $composableBuilder(column: $table.scoreNat, builder: (column) => column);

  GeneratedColumn<double> get scoreSoc =>
      $composableBuilder(column: $table.scoreSoc, builder: (column) => column);

  GeneratedColumn<double> get scoreSleep => $composableBuilder(
      column: $table.scoreSleep, builder: (column) => column);

  GeneratedColumn<bool> get isSealed =>
      $composableBuilder(column: $table.isSealed, builder: (column) => column);
}

class $$WeeklySnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WeeklySnapshotsTable,
    WeeklySnapshot,
    $$WeeklySnapshotsTableFilterComposer,
    $$WeeklySnapshotsTableOrderingComposer,
    $$WeeklySnapshotsTableAnnotationComposer,
    $$WeeklySnapshotsTableCreateCompanionBuilder,
    $$WeeklySnapshotsTableUpdateCompanionBuilder,
    (
      WeeklySnapshot,
      BaseReferences<_$AppDatabase, $WeeklySnapshotsTable, WeeklySnapshot>
    ),
    WeeklySnapshot,
    PrefetchHooks Function()> {
  $$WeeklySnapshotsTableTableManager(
      _$AppDatabase db, $WeeklySnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklySnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklySnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklySnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> weekStartDate = const Value.absent(),
            Value<int> weekStartDay = const Value.absent(),
            Value<double> compositeScore = const Value.absent(),
            Value<double> scoreModPA = const Value.absent(),
            Value<double> scoreVigPA = const Value.absent(),
            Value<double> scoreRes = const Value.absent(),
            Value<double> scoreFlex = const Value.absent(),
            Value<double> scoreNat = const Value.absent(),
            Value<double> scoreSoc = const Value.absent(),
            Value<double> scoreSleep = const Value.absent(),
            Value<bool> isSealed = const Value.absent(),
          }) =>
              WeeklySnapshotsCompanion(
            id: id,
            weekStartDate: weekStartDate,
            weekStartDay: weekStartDay,
            compositeScore: compositeScore,
            scoreModPA: scoreModPA,
            scoreVigPA: scoreVigPA,
            scoreRes: scoreRes,
            scoreFlex: scoreFlex,
            scoreNat: scoreNat,
            scoreSoc: scoreSoc,
            scoreSleep: scoreSleep,
            isSealed: isSealed,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime weekStartDate,
            Value<int> weekStartDay = const Value.absent(),
            required double compositeScore,
            required double scoreModPA,
            required double scoreVigPA,
            required double scoreRes,
            required double scoreFlex,
            required double scoreNat,
            required double scoreSoc,
            required double scoreSleep,
            Value<bool> isSealed = const Value.absent(),
          }) =>
              WeeklySnapshotsCompanion.insert(
            id: id,
            weekStartDate: weekStartDate,
            weekStartDay: weekStartDay,
            compositeScore: compositeScore,
            scoreModPA: scoreModPA,
            scoreVigPA: scoreVigPA,
            scoreRes: scoreRes,
            scoreFlex: scoreFlex,
            scoreNat: scoreNat,
            scoreSoc: scoreSoc,
            scoreSleep: scoreSleep,
            isSealed: isSealed,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WeeklySnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WeeklySnapshotsTable,
    WeeklySnapshot,
    $$WeeklySnapshotsTableFilterComposer,
    $$WeeklySnapshotsTableOrderingComposer,
    $$WeeklySnapshotsTableAnnotationComposer,
    $$WeeklySnapshotsTableCreateCompanionBuilder,
    $$WeeklySnapshotsTableUpdateCompanionBuilder,
    (
      WeeklySnapshot,
      BaseReferences<_$AppDatabase, $WeeklySnapshotsTable, WeeklySnapshot>
    ),
    WeeklySnapshot,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<int> id,
  Value<int> weekStartDay,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<int> id,
  Value<int> weekStartDay,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekStartDay => $composableBuilder(
      column: $table.weekStartDay, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekStartDay => $composableBuilder(
      column: $table.weekStartDay,
      builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get weekStartDay => $composableBuilder(
      column: $table.weekStartDay, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> weekStartDay = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            id: id,
            weekStartDay: weekStartDay,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> weekStartDay = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            id: id,
            weekStartDay: weekStartDay,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DailyEntriesTableTableManager get dailyEntries =>
      $$DailyEntriesTableTableManager(_db, _db.dailyEntries);
  $$WeeklySnapshotsTableTableManager get weeklySnapshots =>
      $$WeeklySnapshotsTableTableManager(_db, _db.weeklySnapshots);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
