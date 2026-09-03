// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_database.dart';

// ignore_for_file: type=lint
class $CachedOrganizationsTable extends CachedOrganizations
    with TableInfo<$CachedOrganizationsTable, CachedOrganizationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedOrganizationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchesJsonMeta = const VerificationMeta(
    'branchesJson',
  );
  @override
  late final GeneratedColumn<String> branchesJson = GeneratedColumn<String>(
    'branches_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    position,
    slug,
    name,
    logoUrl,
    branchesJson,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_organizations';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedOrganizationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('branches_json')) {
      context.handle(
        _branchesJsonMeta,
        branchesJson.isAcceptableOrUnknown(
          data['branches_json']!,
          _branchesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_branchesJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slug};
  @override
  CachedOrganizationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedOrganizationRow(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      branchesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branches_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedOrganizationsTable createAlias(String alias) {
    return $CachedOrganizationsTable(attachedDatabase, alias);
  }
}

class CachedOrganizationRow extends DataClass
    implements Insertable<CachedOrganizationRow> {
  final int position;
  final String slug;
  final String name;
  final String? logoUrl;

  /// JSON array of branches: `{id, name, city, district, latitude?, longitude?}`.
  final String branchesJson;
  final DateTime cachedAt;
  const CachedOrganizationRow({
    required this.position,
    required this.slug,
    required this.name,
    this.logoUrl,
    required this.branchesJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['slug'] = Variable<String>(slug);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    map['branches_json'] = Variable<String>(branchesJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedOrganizationsCompanion toCompanion(bool nullToAbsent) {
    return CachedOrganizationsCompanion(
      position: Value(position),
      slug: Value(slug),
      name: Value(name),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      branchesJson: Value(branchesJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedOrganizationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedOrganizationRow(
      position: serializer.fromJson<int>(json['position']),
      slug: serializer.fromJson<String>(json['slug']),
      name: serializer.fromJson<String>(json['name']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      branchesJson: serializer.fromJson<String>(json['branchesJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'slug': serializer.toJson<String>(slug),
      'name': serializer.toJson<String>(name),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'branchesJson': serializer.toJson<String>(branchesJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedOrganizationRow copyWith({
    int? position,
    String? slug,
    String? name,
    Value<String?> logoUrl = const Value.absent(),
    String? branchesJson,
    DateTime? cachedAt,
  }) => CachedOrganizationRow(
    position: position ?? this.position,
    slug: slug ?? this.slug,
    name: name ?? this.name,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    branchesJson: branchesJson ?? this.branchesJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedOrganizationRow copyWithCompanion(CachedOrganizationsCompanion data) {
    return CachedOrganizationRow(
      position: data.position.present ? data.position.value : this.position,
      slug: data.slug.present ? data.slug.value : this.slug,
      name: data.name.present ? data.name.value : this.name,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      branchesJson: data.branchesJson.present
          ? data.branchesJson.value
          : this.branchesJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedOrganizationRow(')
          ..write('position: $position, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('branchesJson: $branchesJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(position, slug, name, logoUrl, branchesJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedOrganizationRow &&
          other.position == this.position &&
          other.slug == this.slug &&
          other.name == this.name &&
          other.logoUrl == this.logoUrl &&
          other.branchesJson == this.branchesJson &&
          other.cachedAt == this.cachedAt);
}

class CachedOrganizationsCompanion
    extends UpdateCompanion<CachedOrganizationRow> {
  final Value<int> position;
  final Value<String> slug;
  final Value<String> name;
  final Value<String?> logoUrl;
  final Value<String> branchesJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedOrganizationsCompanion({
    this.position = const Value.absent(),
    this.slug = const Value.absent(),
    this.name = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.branchesJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedOrganizationsCompanion.insert({
    required int position,
    required String slug,
    required String name,
    this.logoUrl = const Value.absent(),
    required String branchesJson,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : position = Value(position),
       slug = Value(slug),
       name = Value(name),
       branchesJson = Value(branchesJson),
       cachedAt = Value(cachedAt);
  static Insertable<CachedOrganizationRow> custom({
    Expression<int>? position,
    Expression<String>? slug,
    Expression<String>? name,
    Expression<String>? logoUrl,
    Expression<String>? branchesJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (slug != null) 'slug': slug,
      if (name != null) 'name': name,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (branchesJson != null) 'branches_json': branchesJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedOrganizationsCompanion copyWith({
    Value<int>? position,
    Value<String>? slug,
    Value<String>? name,
    Value<String?>? logoUrl,
    Value<String>? branchesJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedOrganizationsCompanion(
      position: position ?? this.position,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      branchesJson: branchesJson ?? this.branchesJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (branchesJson.present) {
      map['branches_json'] = Variable<String>(branchesJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedOrganizationsCompanion(')
          ..write('position: $position, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('branchesJson: $branchesJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedVehiclesTable extends CachedVehicles
    with TableInfo<$CachedVehiclesTable, CachedVehicleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plateMeta = const VerificationMeta('plate');
  @override
  late final GeneratedColumn<String> plate = GeneratedColumn<String>(
    'plate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  @override
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vinMeta = const VerificationMeta('vin');
  @override
  late final GeneratedColumn<String> vin = GeneratedColumn<String>(
    'vin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    position,
    id,
    plate,
    make,
    model,
    year,
    vin,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedVehicleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plate')) {
      context.handle(
        _plateMeta,
        plate.isAcceptableOrUnknown(data['plate']!, _plateMeta),
      );
    } else if (isInserting) {
      context.missing(_plateMeta);
    }
    if (data.containsKey('make')) {
      context.handle(
        _makeMeta,
        make.isAcceptableOrUnknown(data['make']!, _makeMeta),
      );
    } else if (isInserting) {
      context.missing(_makeMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('vin')) {
      context.handle(
        _vinMeta,
        vin.isAcceptableOrUnknown(data['vin']!, _vinMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedVehicleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVehicleRow(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      plate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate'],
      )!,
      make: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}make'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      vin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vin'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedVehiclesTable createAlias(String alias) {
    return $CachedVehiclesTable(attachedDatabase, alias);
  }
}

class CachedVehicleRow extends DataClass
    implements Insertable<CachedVehicleRow> {
  final int position;
  final String id;
  final String plate;
  final String make;
  final String model;
  final int? year;
  final String? vin;
  final DateTime cachedAt;
  const CachedVehicleRow({
    required this.position,
    required this.id,
    required this.plate,
    required this.make,
    required this.model,
    this.year,
    this.vin,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['id'] = Variable<String>(id);
    map['plate'] = Variable<String>(plate);
    map['make'] = Variable<String>(make);
    map['model'] = Variable<String>(model);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || vin != null) {
      map['vin'] = Variable<String>(vin);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedVehiclesCompanion toCompanion(bool nullToAbsent) {
    return CachedVehiclesCompanion(
      position: Value(position),
      id: Value(id),
      plate: Value(plate),
      make: Value(make),
      model: Value(model),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      vin: vin == null && nullToAbsent ? const Value.absent() : Value(vin),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedVehicleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVehicleRow(
      position: serializer.fromJson<int>(json['position']),
      id: serializer.fromJson<String>(json['id']),
      plate: serializer.fromJson<String>(json['plate']),
      make: serializer.fromJson<String>(json['make']),
      model: serializer.fromJson<String>(json['model']),
      year: serializer.fromJson<int?>(json['year']),
      vin: serializer.fromJson<String?>(json['vin']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'id': serializer.toJson<String>(id),
      'plate': serializer.toJson<String>(plate),
      'make': serializer.toJson<String>(make),
      'model': serializer.toJson<String>(model),
      'year': serializer.toJson<int?>(year),
      'vin': serializer.toJson<String?>(vin),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedVehicleRow copyWith({
    int? position,
    String? id,
    String? plate,
    String? make,
    String? model,
    Value<int?> year = const Value.absent(),
    Value<String?> vin = const Value.absent(),
    DateTime? cachedAt,
  }) => CachedVehicleRow(
    position: position ?? this.position,
    id: id ?? this.id,
    plate: plate ?? this.plate,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year.present ? year.value : this.year,
    vin: vin.present ? vin.value : this.vin,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedVehicleRow copyWithCompanion(CachedVehiclesCompanion data) {
    return CachedVehicleRow(
      position: data.position.present ? data.position.value : this.position,
      id: data.id.present ? data.id.value : this.id,
      plate: data.plate.present ? data.plate.value : this.plate,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      year: data.year.present ? data.year.value : this.year,
      vin: data.vin.present ? data.vin.value : this.vin,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVehicleRow(')
          ..write('position: $position, ')
          ..write('id: $id, ')
          ..write('plate: $plate, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('vin: $vin, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(position, id, plate, make, model, year, vin, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVehicleRow &&
          other.position == this.position &&
          other.id == this.id &&
          other.plate == this.plate &&
          other.make == this.make &&
          other.model == this.model &&
          other.year == this.year &&
          other.vin == this.vin &&
          other.cachedAt == this.cachedAt);
}

class CachedVehiclesCompanion extends UpdateCompanion<CachedVehicleRow> {
  final Value<int> position;
  final Value<String> id;
  final Value<String> plate;
  final Value<String> make;
  final Value<String> model;
  final Value<int?> year;
  final Value<String?> vin;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedVehiclesCompanion({
    this.position = const Value.absent(),
    this.id = const Value.absent(),
    this.plate = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.vin = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedVehiclesCompanion.insert({
    required int position,
    required String id,
    required String plate,
    required String make,
    required String model,
    this.year = const Value.absent(),
    this.vin = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : position = Value(position),
       id = Value(id),
       plate = Value(plate),
       make = Value(make),
       model = Value(model),
       cachedAt = Value(cachedAt);
  static Insertable<CachedVehicleRow> custom({
    Expression<int>? position,
    Expression<String>? id,
    Expression<String>? plate,
    Expression<String>? make,
    Expression<String>? model,
    Expression<int>? year,
    Expression<String>? vin,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (id != null) 'id': id,
      if (plate != null) 'plate': plate,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (vin != null) 'vin': vin,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedVehiclesCompanion copyWith({
    Value<int>? position,
    Value<String>? id,
    Value<String>? plate,
    Value<String>? make,
    Value<String>? model,
    Value<int?>? year,
    Value<String?>? vin,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedVehiclesCompanion(
      position: position ?? this.position,
      id: id ?? this.id,
      plate: plate ?? this.plate,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      vin: vin ?? this.vin,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (plate.present) {
      map['plate'] = Variable<String>(plate.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (vin.present) {
      map['vin'] = Variable<String>(vin.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVehiclesCompanion(')
          ..write('position: $position, ')
          ..write('id: $id, ')
          ..write('plate: $plate, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('vin: $vin, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedAppointmentsTable extends CachedAppointments
    with TableInfo<$CachedAppointmentsTable, CachedAppointmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAppointmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestedAtMeta = const VerificationMeta(
    'requestedAt',
  );
  @override
  late final GeneratedColumn<String> requestedAt = GeneratedColumn<String>(
    'requested_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantNameMeta = const VerificationMeta(
    'tenantName',
  );
  @override
  late final GeneratedColumn<String> tenantName = GeneratedColumn<String>(
    'tenant_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantSlugMeta = const VerificationMeta(
    'tenantSlug',
  );
  @override
  late final GeneratedColumn<String> tenantSlug = GeneratedColumn<String>(
    'tenant_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchNameMeta = const VerificationMeta(
    'branchName',
  );
  @override
  late final GeneratedColumn<String> branchName = GeneratedColumn<String>(
    'branch_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehiclePlateMeta = const VerificationMeta(
    'vehiclePlate',
  );
  @override
  late final GeneratedColumn<String> vehiclePlate = GeneratedColumn<String>(
    'vehicle_plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    position,
    id,
    status,
    requestedAt,
    tenantName,
    tenantSlug,
    branchName,
    note,
    categoryName,
    vehiclePlate,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_appointments';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAppointmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('requested_at')) {
      context.handle(
        _requestedAtMeta,
        requestedAt.isAcceptableOrUnknown(
          data['requested_at']!,
          _requestedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedAtMeta);
    }
    if (data.containsKey('tenant_name')) {
      context.handle(
        _tenantNameMeta,
        tenantName.isAcceptableOrUnknown(data['tenant_name']!, _tenantNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantNameMeta);
    }
    if (data.containsKey('tenant_slug')) {
      context.handle(
        _tenantSlugMeta,
        tenantSlug.isAcceptableOrUnknown(data['tenant_slug']!, _tenantSlugMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantSlugMeta);
    }
    if (data.containsKey('branch_name')) {
      context.handle(
        _branchNameMeta,
        branchName.isAcceptableOrUnknown(data['branch_name']!, _branchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_branchNameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
    }
    if (data.containsKey('vehicle_plate')) {
      context.handle(
        _vehiclePlateMeta,
        vehiclePlate.isAcceptableOrUnknown(
          data['vehicle_plate']!,
          _vehiclePlateMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedAppointmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAppointmentRow(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      requestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requested_at'],
      )!,
      tenantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_name'],
      )!,
      tenantSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_slug'],
      )!,
      branchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_name'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      ),
      vehiclePlate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_plate'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedAppointmentsTable createAlias(String alias) {
    return $CachedAppointmentsTable(attachedDatabase, alias);
  }
}

class CachedAppointmentRow extends DataClass
    implements Insertable<CachedAppointmentRow> {
  final int position;
  final String id;
  final String status;

  /// ISO-8601 string, stored verbatim so the DateTime round-trips with its
  /// UTC/local flag intact — the appointments screen formats `requestedAt`'s
  /// raw fields without `toLocal()`, so a UTC-origin value must not silently
  /// become local (which Drift's default int DateTime storage would do).
  final String requestedAt;
  final String tenantName;
  final String tenantSlug;
  final String branchName;
  final String? note;
  final String? categoryName;
  final String? vehiclePlate;
  final DateTime cachedAt;
  const CachedAppointmentRow({
    required this.position,
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    this.note,
    this.categoryName,
    this.vehiclePlate,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['id'] = Variable<String>(id);
    map['status'] = Variable<String>(status);
    map['requested_at'] = Variable<String>(requestedAt);
    map['tenant_name'] = Variable<String>(tenantName);
    map['tenant_slug'] = Variable<String>(tenantSlug);
    map['branch_name'] = Variable<String>(branchName);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || categoryName != null) {
      map['category_name'] = Variable<String>(categoryName);
    }
    if (!nullToAbsent || vehiclePlate != null) {
      map['vehicle_plate'] = Variable<String>(vehiclePlate);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedAppointmentsCompanion toCompanion(bool nullToAbsent) {
    return CachedAppointmentsCompanion(
      position: Value(position),
      id: Value(id),
      status: Value(status),
      requestedAt: Value(requestedAt),
      tenantName: Value(tenantName),
      tenantSlug: Value(tenantSlug),
      branchName: Value(branchName),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      categoryName: categoryName == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryName),
      vehiclePlate: vehiclePlate == null && nullToAbsent
          ? const Value.absent()
          : Value(vehiclePlate),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedAppointmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAppointmentRow(
      position: serializer.fromJson<int>(json['position']),
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      requestedAt: serializer.fromJson<String>(json['requestedAt']),
      tenantName: serializer.fromJson<String>(json['tenantName']),
      tenantSlug: serializer.fromJson<String>(json['tenantSlug']),
      branchName: serializer.fromJson<String>(json['branchName']),
      note: serializer.fromJson<String?>(json['note']),
      categoryName: serializer.fromJson<String?>(json['categoryName']),
      vehiclePlate: serializer.fromJson<String?>(json['vehiclePlate']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<String>(status),
      'requestedAt': serializer.toJson<String>(requestedAt),
      'tenantName': serializer.toJson<String>(tenantName),
      'tenantSlug': serializer.toJson<String>(tenantSlug),
      'branchName': serializer.toJson<String>(branchName),
      'note': serializer.toJson<String?>(note),
      'categoryName': serializer.toJson<String?>(categoryName),
      'vehiclePlate': serializer.toJson<String?>(vehiclePlate),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedAppointmentRow copyWith({
    int? position,
    String? id,
    String? status,
    String? requestedAt,
    String? tenantName,
    String? tenantSlug,
    String? branchName,
    Value<String?> note = const Value.absent(),
    Value<String?> categoryName = const Value.absent(),
    Value<String?> vehiclePlate = const Value.absent(),
    DateTime? cachedAt,
  }) => CachedAppointmentRow(
    position: position ?? this.position,
    id: id ?? this.id,
    status: status ?? this.status,
    requestedAt: requestedAt ?? this.requestedAt,
    tenantName: tenantName ?? this.tenantName,
    tenantSlug: tenantSlug ?? this.tenantSlug,
    branchName: branchName ?? this.branchName,
    note: note.present ? note.value : this.note,
    categoryName: categoryName.present ? categoryName.value : this.categoryName,
    vehiclePlate: vehiclePlate.present ? vehiclePlate.value : this.vehiclePlate,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedAppointmentRow copyWithCompanion(CachedAppointmentsCompanion data) {
    return CachedAppointmentRow(
      position: data.position.present ? data.position.value : this.position,
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      requestedAt: data.requestedAt.present
          ? data.requestedAt.value
          : this.requestedAt,
      tenantName: data.tenantName.present
          ? data.tenantName.value
          : this.tenantName,
      tenantSlug: data.tenantSlug.present
          ? data.tenantSlug.value
          : this.tenantSlug,
      branchName: data.branchName.present
          ? data.branchName.value
          : this.branchName,
      note: data.note.present ? data.note.value : this.note,
      categoryName: data.categoryName.present
          ? data.categoryName.value
          : this.categoryName,
      vehiclePlate: data.vehiclePlate.present
          ? data.vehiclePlate.value
          : this.vehiclePlate,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAppointmentRow(')
          ..write('position: $position, ')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('tenantName: $tenantName, ')
          ..write('tenantSlug: $tenantSlug, ')
          ..write('branchName: $branchName, ')
          ..write('note: $note, ')
          ..write('categoryName: $categoryName, ')
          ..write('vehiclePlate: $vehiclePlate, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    position,
    id,
    status,
    requestedAt,
    tenantName,
    tenantSlug,
    branchName,
    note,
    categoryName,
    vehiclePlate,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAppointmentRow &&
          other.position == this.position &&
          other.id == this.id &&
          other.status == this.status &&
          other.requestedAt == this.requestedAt &&
          other.tenantName == this.tenantName &&
          other.tenantSlug == this.tenantSlug &&
          other.branchName == this.branchName &&
          other.note == this.note &&
          other.categoryName == this.categoryName &&
          other.vehiclePlate == this.vehiclePlate &&
          other.cachedAt == this.cachedAt);
}

class CachedAppointmentsCompanion
    extends UpdateCompanion<CachedAppointmentRow> {
  final Value<int> position;
  final Value<String> id;
  final Value<String> status;
  final Value<String> requestedAt;
  final Value<String> tenantName;
  final Value<String> tenantSlug;
  final Value<String> branchName;
  final Value<String?> note;
  final Value<String?> categoryName;
  final Value<String?> vehiclePlate;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedAppointmentsCompanion({
    this.position = const Value.absent(),
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.tenantName = const Value.absent(),
    this.tenantSlug = const Value.absent(),
    this.branchName = const Value.absent(),
    this.note = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.vehiclePlate = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedAppointmentsCompanion.insert({
    required int position,
    required String id,
    required String status,
    required String requestedAt,
    required String tenantName,
    required String tenantSlug,
    required String branchName,
    this.note = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.vehiclePlate = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : position = Value(position),
       id = Value(id),
       status = Value(status),
       requestedAt = Value(requestedAt),
       tenantName = Value(tenantName),
       tenantSlug = Value(tenantSlug),
       branchName = Value(branchName),
       cachedAt = Value(cachedAt);
  static Insertable<CachedAppointmentRow> custom({
    Expression<int>? position,
    Expression<String>? id,
    Expression<String>? status,
    Expression<String>? requestedAt,
    Expression<String>? tenantName,
    Expression<String>? tenantSlug,
    Expression<String>? branchName,
    Expression<String>? note,
    Expression<String>? categoryName,
    Expression<String>? vehiclePlate,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (tenantName != null) 'tenant_name': tenantName,
      if (tenantSlug != null) 'tenant_slug': tenantSlug,
      if (branchName != null) 'branch_name': branchName,
      if (note != null) 'note': note,
      if (categoryName != null) 'category_name': categoryName,
      if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedAppointmentsCompanion copyWith({
    Value<int>? position,
    Value<String>? id,
    Value<String>? status,
    Value<String>? requestedAt,
    Value<String>? tenantName,
    Value<String>? tenantSlug,
    Value<String>? branchName,
    Value<String?>? note,
    Value<String?>? categoryName,
    Value<String?>? vehiclePlate,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedAppointmentsCompanion(
      position: position ?? this.position,
      id: id ?? this.id,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      tenantName: tenantName ?? this.tenantName,
      tenantSlug: tenantSlug ?? this.tenantSlug,
      branchName: branchName ?? this.branchName,
      note: note ?? this.note,
      categoryName: categoryName ?? this.categoryName,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<String>(requestedAt.value);
    }
    if (tenantName.present) {
      map['tenant_name'] = Variable<String>(tenantName.value);
    }
    if (tenantSlug.present) {
      map['tenant_slug'] = Variable<String>(tenantSlug.value);
    }
    if (branchName.present) {
      map['branch_name'] = Variable<String>(branchName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (vehiclePlate.present) {
      map['vehicle_plate'] = Variable<String>(vehiclePlate.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAppointmentsCompanion(')
          ..write('position: $position, ')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('tenantName: $tenantName, ')
          ..write('tenantSlug: $tenantSlug, ')
          ..write('branchName: $branchName, ')
          ..write('note: $note, ')
          ..write('categoryName: $categoryName, ')
          ..write('vehiclePlate: $vehiclePlate, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedServiceOrdersTable extends CachedServiceOrders
    with TableInfo<$CachedServiceOrdersTable, CachedServiceOrderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedServiceOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantNameMeta = const VerificationMeta(
    'tenantName',
  );
  @override
  late final GeneratedColumn<String> tenantName = GeneratedColumn<String>(
    'tenant_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantSlugMeta = const VerificationMeta(
    'tenantSlug',
  );
  @override
  late final GeneratedColumn<String> tenantSlug = GeneratedColumn<String>(
    'tenant_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchNameMeta = const VerificationMeta(
    'branchName',
  );
  @override
  late final GeneratedColumn<String> branchName = GeneratedColumn<String>(
    'branch_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<int> totalAmount = GeneratedColumn<int>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidAmountMeta = const VerificationMeta(
    'paidAmount',
  );
  @override
  late final GeneratedColumn<int> paidAmount = GeneratedColumn<int>(
    'paid_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehiclePlateMeta = const VerificationMeta(
    'vehiclePlate',
  );
  @override
  late final GeneratedColumn<String> vehiclePlate = GeneratedColumn<String>(
    'vehicle_plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    position,
    id,
    tenantName,
    tenantSlug,
    branchName,
    completedAt,
    status,
    totalAmount,
    paidAmount,
    vehiclePlate,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_service_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedServiceOrderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_name')) {
      context.handle(
        _tenantNameMeta,
        tenantName.isAcceptableOrUnknown(data['tenant_name']!, _tenantNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantNameMeta);
    }
    if (data.containsKey('tenant_slug')) {
      context.handle(
        _tenantSlugMeta,
        tenantSlug.isAcceptableOrUnknown(data['tenant_slug']!, _tenantSlugMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantSlugMeta);
    }
    if (data.containsKey('branch_name')) {
      context.handle(
        _branchNameMeta,
        branchName.isAcceptableOrUnknown(data['branch_name']!, _branchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_branchNameMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('paid_amount')) {
      context.handle(
        _paidAmountMeta,
        paidAmount.isAcceptableOrUnknown(data['paid_amount']!, _paidAmountMeta),
      );
    } else if (isInserting) {
      context.missing(_paidAmountMeta);
    }
    if (data.containsKey('vehicle_plate')) {
      context.handle(
        _vehiclePlateMeta,
        vehiclePlate.isAcceptableOrUnknown(
          data['vehicle_plate']!,
          _vehiclePlateMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedServiceOrderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedServiceOrderRow(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_name'],
      )!,
      tenantSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_slug'],
      )!,
      branchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_name'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_amount'],
      )!,
      paidAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_amount'],
      )!,
      vehiclePlate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_plate'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedServiceOrdersTable createAlias(String alias) {
    return $CachedServiceOrdersTable(attachedDatabase, alias);
  }
}

class CachedServiceOrderRow extends DataClass
    implements Insertable<CachedServiceOrderRow> {
  final int position;
  final String id;
  final String tenantName;
  final String tenantSlug;
  final String branchName;

  /// ISO-8601 string — see the note on [CachedAppointments.requestedAt]. The
  /// history screen formats `completedAt`'s raw fields too.
  final String completedAt;
  final String status;
  final int totalAmount;
  final int paidAmount;
  final String? vehiclePlate;
  final DateTime cachedAt;
  const CachedServiceOrderRow({
    required this.position,
    required this.id,
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    required this.completedAt,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    this.vehiclePlate,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['id'] = Variable<String>(id);
    map['tenant_name'] = Variable<String>(tenantName);
    map['tenant_slug'] = Variable<String>(tenantSlug);
    map['branch_name'] = Variable<String>(branchName);
    map['completed_at'] = Variable<String>(completedAt);
    map['status'] = Variable<String>(status);
    map['total_amount'] = Variable<int>(totalAmount);
    map['paid_amount'] = Variable<int>(paidAmount);
    if (!nullToAbsent || vehiclePlate != null) {
      map['vehicle_plate'] = Variable<String>(vehiclePlate);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedServiceOrdersCompanion toCompanion(bool nullToAbsent) {
    return CachedServiceOrdersCompanion(
      position: Value(position),
      id: Value(id),
      tenantName: Value(tenantName),
      tenantSlug: Value(tenantSlug),
      branchName: Value(branchName),
      completedAt: Value(completedAt),
      status: Value(status),
      totalAmount: Value(totalAmount),
      paidAmount: Value(paidAmount),
      vehiclePlate: vehiclePlate == null && nullToAbsent
          ? const Value.absent()
          : Value(vehiclePlate),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedServiceOrderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedServiceOrderRow(
      position: serializer.fromJson<int>(json['position']),
      id: serializer.fromJson<String>(json['id']),
      tenantName: serializer.fromJson<String>(json['tenantName']),
      tenantSlug: serializer.fromJson<String>(json['tenantSlug']),
      branchName: serializer.fromJson<String>(json['branchName']),
      completedAt: serializer.fromJson<String>(json['completedAt']),
      status: serializer.fromJson<String>(json['status']),
      totalAmount: serializer.fromJson<int>(json['totalAmount']),
      paidAmount: serializer.fromJson<int>(json['paidAmount']),
      vehiclePlate: serializer.fromJson<String?>(json['vehiclePlate']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'id': serializer.toJson<String>(id),
      'tenantName': serializer.toJson<String>(tenantName),
      'tenantSlug': serializer.toJson<String>(tenantSlug),
      'branchName': serializer.toJson<String>(branchName),
      'completedAt': serializer.toJson<String>(completedAt),
      'status': serializer.toJson<String>(status),
      'totalAmount': serializer.toJson<int>(totalAmount),
      'paidAmount': serializer.toJson<int>(paidAmount),
      'vehiclePlate': serializer.toJson<String?>(vehiclePlate),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedServiceOrderRow copyWith({
    int? position,
    String? id,
    String? tenantName,
    String? tenantSlug,
    String? branchName,
    String? completedAt,
    String? status,
    int? totalAmount,
    int? paidAmount,
    Value<String?> vehiclePlate = const Value.absent(),
    DateTime? cachedAt,
  }) => CachedServiceOrderRow(
    position: position ?? this.position,
    id: id ?? this.id,
    tenantName: tenantName ?? this.tenantName,
    tenantSlug: tenantSlug ?? this.tenantSlug,
    branchName: branchName ?? this.branchName,
    completedAt: completedAt ?? this.completedAt,
    status: status ?? this.status,
    totalAmount: totalAmount ?? this.totalAmount,
    paidAmount: paidAmount ?? this.paidAmount,
    vehiclePlate: vehiclePlate.present ? vehiclePlate.value : this.vehiclePlate,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedServiceOrderRow copyWithCompanion(CachedServiceOrdersCompanion data) {
    return CachedServiceOrderRow(
      position: data.position.present ? data.position.value : this.position,
      id: data.id.present ? data.id.value : this.id,
      tenantName: data.tenantName.present
          ? data.tenantName.value
          : this.tenantName,
      tenantSlug: data.tenantSlug.present
          ? data.tenantSlug.value
          : this.tenantSlug,
      branchName: data.branchName.present
          ? data.branchName.value
          : this.branchName,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      status: data.status.present ? data.status.value : this.status,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      paidAmount: data.paidAmount.present
          ? data.paidAmount.value
          : this.paidAmount,
      vehiclePlate: data.vehiclePlate.present
          ? data.vehiclePlate.value
          : this.vehiclePlate,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedServiceOrderRow(')
          ..write('position: $position, ')
          ..write('id: $id, ')
          ..write('tenantName: $tenantName, ')
          ..write('tenantSlug: $tenantSlug, ')
          ..write('branchName: $branchName, ')
          ..write('completedAt: $completedAt, ')
          ..write('status: $status, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('paidAmount: $paidAmount, ')
          ..write('vehiclePlate: $vehiclePlate, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    position,
    id,
    tenantName,
    tenantSlug,
    branchName,
    completedAt,
    status,
    totalAmount,
    paidAmount,
    vehiclePlate,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedServiceOrderRow &&
          other.position == this.position &&
          other.id == this.id &&
          other.tenantName == this.tenantName &&
          other.tenantSlug == this.tenantSlug &&
          other.branchName == this.branchName &&
          other.completedAt == this.completedAt &&
          other.status == this.status &&
          other.totalAmount == this.totalAmount &&
          other.paidAmount == this.paidAmount &&
          other.vehiclePlate == this.vehiclePlate &&
          other.cachedAt == this.cachedAt);
}

class CachedServiceOrdersCompanion
    extends UpdateCompanion<CachedServiceOrderRow> {
  final Value<int> position;
  final Value<String> id;
  final Value<String> tenantName;
  final Value<String> tenantSlug;
  final Value<String> branchName;
  final Value<String> completedAt;
  final Value<String> status;
  final Value<int> totalAmount;
  final Value<int> paidAmount;
  final Value<String?> vehiclePlate;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedServiceOrdersCompanion({
    this.position = const Value.absent(),
    this.id = const Value.absent(),
    this.tenantName = const Value.absent(),
    this.tenantSlug = const Value.absent(),
    this.branchName = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.paidAmount = const Value.absent(),
    this.vehiclePlate = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedServiceOrdersCompanion.insert({
    required int position,
    required String id,
    required String tenantName,
    required String tenantSlug,
    required String branchName,
    required String completedAt,
    required String status,
    required int totalAmount,
    required int paidAmount,
    this.vehiclePlate = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : position = Value(position),
       id = Value(id),
       tenantName = Value(tenantName),
       tenantSlug = Value(tenantSlug),
       branchName = Value(branchName),
       completedAt = Value(completedAt),
       status = Value(status),
       totalAmount = Value(totalAmount),
       paidAmount = Value(paidAmount),
       cachedAt = Value(cachedAt);
  static Insertable<CachedServiceOrderRow> custom({
    Expression<int>? position,
    Expression<String>? id,
    Expression<String>? tenantName,
    Expression<String>? tenantSlug,
    Expression<String>? branchName,
    Expression<String>? completedAt,
    Expression<String>? status,
    Expression<int>? totalAmount,
    Expression<int>? paidAmount,
    Expression<String>? vehiclePlate,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (id != null) 'id': id,
      if (tenantName != null) 'tenant_name': tenantName,
      if (tenantSlug != null) 'tenant_slug': tenantSlug,
      if (branchName != null) 'branch_name': branchName,
      if (completedAt != null) 'completed_at': completedAt,
      if (status != null) 'status': status,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedServiceOrdersCompanion copyWith({
    Value<int>? position,
    Value<String>? id,
    Value<String>? tenantName,
    Value<String>? tenantSlug,
    Value<String>? branchName,
    Value<String>? completedAt,
    Value<String>? status,
    Value<int>? totalAmount,
    Value<int>? paidAmount,
    Value<String?>? vehiclePlate,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedServiceOrdersCompanion(
      position: position ?? this.position,
      id: id ?? this.id,
      tenantName: tenantName ?? this.tenantName,
      tenantSlug: tenantSlug ?? this.tenantSlug,
      branchName: branchName ?? this.branchName,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantName.present) {
      map['tenant_name'] = Variable<String>(tenantName.value);
    }
    if (tenantSlug.present) {
      map['tenant_slug'] = Variable<String>(tenantSlug.value);
    }
    if (branchName.present) {
      map['branch_name'] = Variable<String>(branchName.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<int>(totalAmount.value);
    }
    if (paidAmount.present) {
      map['paid_amount'] = Variable<int>(paidAmount.value);
    }
    if (vehiclePlate.present) {
      map['vehicle_plate'] = Variable<String>(vehiclePlate.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedServiceOrdersCompanion(')
          ..write('position: $position, ')
          ..write('id: $id, ')
          ..write('tenantName: $tenantName, ')
          ..write('tenantSlug: $tenantSlug, ')
          ..write('branchName: $branchName, ')
          ..write('completedAt: $completedAt, ')
          ..write('status: $status, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('paidAmount: $paidAmount, ')
          ..write('vehiclePlate: $vehiclePlate, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedOrganizationDetailsTable extends CachedOrganizationDetails
    with
        TableInfo<
          $CachedOrganizationDetailsTable,
          CachedOrganizationDetailRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedOrganizationDetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slug, payloadJson, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_organization_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedOrganizationDetailRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slug};
  @override
  CachedOrganizationDetailRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedOrganizationDetailRow(
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedOrganizationDetailsTable createAlias(String alias) {
    return $CachedOrganizationDetailsTable(attachedDatabase, alias);
  }
}

class CachedOrganizationDetailRow extends DataClass
    implements Insertable<CachedOrganizationDetailRow> {
  final String slug;
  final String payloadJson;
  final DateTime cachedAt;
  const CachedOrganizationDetailRow({
    required this.slug,
    required this.payloadJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slug'] = Variable<String>(slug);
    map['payload_json'] = Variable<String>(payloadJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedOrganizationDetailsCompanion toCompanion(bool nullToAbsent) {
    return CachedOrganizationDetailsCompanion(
      slug: Value(slug),
      payloadJson: Value(payloadJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedOrganizationDetailRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedOrganizationDetailRow(
      slug: serializer.fromJson<String>(json['slug']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slug': serializer.toJson<String>(slug),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedOrganizationDetailRow copyWith({
    String? slug,
    String? payloadJson,
    DateTime? cachedAt,
  }) => CachedOrganizationDetailRow(
    slug: slug ?? this.slug,
    payloadJson: payloadJson ?? this.payloadJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedOrganizationDetailRow copyWithCompanion(
    CachedOrganizationDetailsCompanion data,
  ) {
    return CachedOrganizationDetailRow(
      slug: data.slug.present ? data.slug.value : this.slug,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedOrganizationDetailRow(')
          ..write('slug: $slug, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slug, payloadJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedOrganizationDetailRow &&
          other.slug == this.slug &&
          other.payloadJson == this.payloadJson &&
          other.cachedAt == this.cachedAt);
}

class CachedOrganizationDetailsCompanion
    extends UpdateCompanion<CachedOrganizationDetailRow> {
  final Value<String> slug;
  final Value<String> payloadJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedOrganizationDetailsCompanion({
    this.slug = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedOrganizationDetailsCompanion.insert({
    required String slug,
    required String payloadJson,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : slug = Value(slug),
       payloadJson = Value(payloadJson),
       cachedAt = Value(cachedAt);
  static Insertable<CachedOrganizationDetailRow> custom({
    Expression<String>? slug,
    Expression<String>? payloadJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slug != null) 'slug': slug,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedOrganizationDetailsCompanion copyWith({
    Value<String>? slug,
    Value<String>? payloadJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedOrganizationDetailsCompanion(
      slug: slug ?? this.slug,
      payloadJson: payloadJson ?? this.payloadJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedOrganizationDetailsCompanion(')
          ..write('slug: $slug, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CacheDatabase extends GeneratedDatabase {
  _$CacheDatabase(QueryExecutor e) : super(e);
  $CacheDatabaseManager get managers => $CacheDatabaseManager(this);
  late final $CachedOrganizationsTable cachedOrganizations =
      $CachedOrganizationsTable(this);
  late final $CachedVehiclesTable cachedVehicles = $CachedVehiclesTable(this);
  late final $CachedAppointmentsTable cachedAppointments =
      $CachedAppointmentsTable(this);
  late final $CachedServiceOrdersTable cachedServiceOrders =
      $CachedServiceOrdersTable(this);
  late final $CachedOrganizationDetailsTable cachedOrganizationDetails =
      $CachedOrganizationDetailsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedOrganizations,
    cachedVehicles,
    cachedAppointments,
    cachedServiceOrders,
    cachedOrganizationDetails,
  ];
}

typedef $$CachedOrganizationsTableCreateCompanionBuilder =
    CachedOrganizationsCompanion Function({
      required int position,
      required String slug,
      required String name,
      Value<String?> logoUrl,
      required String branchesJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedOrganizationsTableUpdateCompanionBuilder =
    CachedOrganizationsCompanion Function({
      Value<int> position,
      Value<String> slug,
      Value<String> name,
      Value<String?> logoUrl,
      Value<String> branchesJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedOrganizationsTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedOrganizationsTable> {
  $$CachedOrganizationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchesJson => $composableBuilder(
    column: $table.branchesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedOrganizationsTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedOrganizationsTable> {
  $$CachedOrganizationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchesJson => $composableBuilder(
    column: $table.branchesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedOrganizationsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedOrganizationsTable> {
  $$CachedOrganizationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get branchesJson => $composableBuilder(
    column: $table.branchesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedOrganizationsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $CachedOrganizationsTable,
          CachedOrganizationRow,
          $$CachedOrganizationsTableFilterComposer,
          $$CachedOrganizationsTableOrderingComposer,
          $$CachedOrganizationsTableAnnotationComposer,
          $$CachedOrganizationsTableCreateCompanionBuilder,
          $$CachedOrganizationsTableUpdateCompanionBuilder,
          (
            CachedOrganizationRow,
            BaseReferences<
              _$CacheDatabase,
              $CachedOrganizationsTable,
              CachedOrganizationRow
            >,
          ),
          CachedOrganizationRow,
          PrefetchHooks Function()
        > {
  $$CachedOrganizationsTableTableManager(
    _$CacheDatabase db,
    $CachedOrganizationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedOrganizationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedOrganizationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedOrganizationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String> branchesJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedOrganizationsCompanion(
                position: position,
                slug: slug,
                name: name,
                logoUrl: logoUrl,
                branchesJson: branchesJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int position,
                required String slug,
                required String name,
                Value<String?> logoUrl = const Value.absent(),
                required String branchesJson,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedOrganizationsCompanion.insert(
                position: position,
                slug: slug,
                name: name,
                logoUrl: logoUrl,
                branchesJson: branchesJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedOrganizationsTable, CachedOrganizationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$CacheDatabase,
                    $CachedOrganizationsTable,
                    CachedOrganizationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedOrganizationsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $CachedOrganizationsTable,
      CachedOrganizationRow,
      $$CachedOrganizationsTableFilterComposer,
      $$CachedOrganizationsTableOrderingComposer,
      $$CachedOrganizationsTableAnnotationComposer,
      $$CachedOrganizationsTableCreateCompanionBuilder,
      $$CachedOrganizationsTableUpdateCompanionBuilder,
      (
        CachedOrganizationRow,
        BaseReferences<
          _$CacheDatabase,
          $CachedOrganizationsTable,
          CachedOrganizationRow
        >,
      ),
      CachedOrganizationRow,
      PrefetchHooks Function()
    >;
typedef $$CachedVehiclesTableCreateCompanionBuilder =
    CachedVehiclesCompanion Function({
      required int position,
      required String id,
      required String plate,
      required String make,
      required String model,
      Value<int?> year,
      Value<String?> vin,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedVehiclesTableUpdateCompanionBuilder =
    CachedVehiclesCompanion Function({
      Value<int> position,
      Value<String> id,
      Value<String> plate,
      Value<String> make,
      Value<String> model,
      Value<int?> year,
      Value<String?> vin,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedVehiclesTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedVehiclesTable> {
  $$CachedVehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedVehiclesTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedVehiclesTable> {
  $$CachedVehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedVehiclesTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedVehiclesTable> {
  $$CachedVehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get plate =>
      $composableBuilder(column: $table.plate, builder: (column) => column);

  GeneratedColumn<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get vin =>
      $composableBuilder(column: $table.vin, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedVehiclesTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $CachedVehiclesTable,
          CachedVehicleRow,
          $$CachedVehiclesTableFilterComposer,
          $$CachedVehiclesTableOrderingComposer,
          $$CachedVehiclesTableAnnotationComposer,
          $$CachedVehiclesTableCreateCompanionBuilder,
          $$CachedVehiclesTableUpdateCompanionBuilder,
          (
            CachedVehicleRow,
            BaseReferences<
              _$CacheDatabase,
              $CachedVehiclesTable,
              CachedVehicleRow
            >,
          ),
          CachedVehicleRow,
          PrefetchHooks Function()
        > {
  $$CachedVehiclesTableTableManager(
    _$CacheDatabase db,
    $CachedVehiclesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedVehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> plate = const Value.absent(),
                Value<String> make = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> vin = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedVehiclesCompanion(
                position: position,
                id: id,
                plate: plate,
                make: make,
                model: model,
                year: year,
                vin: vin,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int position,
                required String id,
                required String plate,
                required String make,
                required String model,
                Value<int?> year = const Value.absent(),
                Value<String?> vin = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedVehiclesCompanion.insert(
                position: position,
                id: id,
                plate: plate,
                make: make,
                model: model,
                year: year,
                vin: vin,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedVehiclesTable, CachedVehicleRow>(table),
                  BaseReferences<
                    _$CacheDatabase,
                    $CachedVehiclesTable,
                    CachedVehicleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedVehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $CachedVehiclesTable,
      CachedVehicleRow,
      $$CachedVehiclesTableFilterComposer,
      $$CachedVehiclesTableOrderingComposer,
      $$CachedVehiclesTableAnnotationComposer,
      $$CachedVehiclesTableCreateCompanionBuilder,
      $$CachedVehiclesTableUpdateCompanionBuilder,
      (
        CachedVehicleRow,
        BaseReferences<_$CacheDatabase, $CachedVehiclesTable, CachedVehicleRow>,
      ),
      CachedVehicleRow,
      PrefetchHooks Function()
    >;
typedef $$CachedAppointmentsTableCreateCompanionBuilder =
    CachedAppointmentsCompanion Function({
      required int position,
      required String id,
      required String status,
      required String requestedAt,
      required String tenantName,
      required String tenantSlug,
      required String branchName,
      Value<String?> note,
      Value<String?> categoryName,
      Value<String?> vehiclePlate,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedAppointmentsTableUpdateCompanionBuilder =
    CachedAppointmentsCompanion Function({
      Value<int> position,
      Value<String> id,
      Value<String> status,
      Value<String> requestedAt,
      Value<String> tenantName,
      Value<String> tenantSlug,
      Value<String> branchName,
      Value<String?> note,
      Value<String?> categoryName,
      Value<String?> vehiclePlate,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedAppointmentsTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedAppointmentsTable> {
  $$CachedAppointmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantName => $composableBuilder(
    column: $table.tenantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantSlug => $composableBuilder(
    column: $table.tenantSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehiclePlate => $composableBuilder(
    column: $table.vehiclePlate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedAppointmentsTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedAppointmentsTable> {
  $$CachedAppointmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantName => $composableBuilder(
    column: $table.tenantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantSlug => $composableBuilder(
    column: $table.tenantSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehiclePlate => $composableBuilder(
    column: $table.vehiclePlate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedAppointmentsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedAppointmentsTable> {
  $$CachedAppointmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantName => $composableBuilder(
    column: $table.tenantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantSlug => $composableBuilder(
    column: $table.tenantSlug,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehiclePlate => $composableBuilder(
    column: $table.vehiclePlate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedAppointmentsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $CachedAppointmentsTable,
          CachedAppointmentRow,
          $$CachedAppointmentsTableFilterComposer,
          $$CachedAppointmentsTableOrderingComposer,
          $$CachedAppointmentsTableAnnotationComposer,
          $$CachedAppointmentsTableCreateCompanionBuilder,
          $$CachedAppointmentsTableUpdateCompanionBuilder,
          (
            CachedAppointmentRow,
            BaseReferences<
              _$CacheDatabase,
              $CachedAppointmentsTable,
              CachedAppointmentRow
            >,
          ),
          CachedAppointmentRow,
          PrefetchHooks Function()
        > {
  $$CachedAppointmentsTableTableManager(
    _$CacheDatabase db,
    $CachedAppointmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAppointmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAppointmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAppointmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> requestedAt = const Value.absent(),
                Value<String> tenantName = const Value.absent(),
                Value<String> tenantSlug = const Value.absent(),
                Value<String> branchName = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                Value<String?> vehiclePlate = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedAppointmentsCompanion(
                position: position,
                id: id,
                status: status,
                requestedAt: requestedAt,
                tenantName: tenantName,
                tenantSlug: tenantSlug,
                branchName: branchName,
                note: note,
                categoryName: categoryName,
                vehiclePlate: vehiclePlate,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int position,
                required String id,
                required String status,
                required String requestedAt,
                required String tenantName,
                required String tenantSlug,
                required String branchName,
                Value<String?> note = const Value.absent(),
                Value<String?> categoryName = const Value.absent(),
                Value<String?> vehiclePlate = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedAppointmentsCompanion.insert(
                position: position,
                id: id,
                status: status,
                requestedAt: requestedAt,
                tenantName: tenantName,
                tenantSlug: tenantSlug,
                branchName: branchName,
                note: note,
                categoryName: categoryName,
                vehiclePlate: vehiclePlate,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedAppointmentsTable, CachedAppointmentRow>(
                    table,
                  ),
                  BaseReferences<
                    _$CacheDatabase,
                    $CachedAppointmentsTable,
                    CachedAppointmentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedAppointmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $CachedAppointmentsTable,
      CachedAppointmentRow,
      $$CachedAppointmentsTableFilterComposer,
      $$CachedAppointmentsTableOrderingComposer,
      $$CachedAppointmentsTableAnnotationComposer,
      $$CachedAppointmentsTableCreateCompanionBuilder,
      $$CachedAppointmentsTableUpdateCompanionBuilder,
      (
        CachedAppointmentRow,
        BaseReferences<
          _$CacheDatabase,
          $CachedAppointmentsTable,
          CachedAppointmentRow
        >,
      ),
      CachedAppointmentRow,
      PrefetchHooks Function()
    >;
typedef $$CachedServiceOrdersTableCreateCompanionBuilder =
    CachedServiceOrdersCompanion Function({
      required int position,
      required String id,
      required String tenantName,
      required String tenantSlug,
      required String branchName,
      required String completedAt,
      required String status,
      required int totalAmount,
      required int paidAmount,
      Value<String?> vehiclePlate,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedServiceOrdersTableUpdateCompanionBuilder =
    CachedServiceOrdersCompanion Function({
      Value<int> position,
      Value<String> id,
      Value<String> tenantName,
      Value<String> tenantSlug,
      Value<String> branchName,
      Value<String> completedAt,
      Value<String> status,
      Value<int> totalAmount,
      Value<int> paidAmount,
      Value<String?> vehiclePlate,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedServiceOrdersTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedServiceOrdersTable> {
  $$CachedServiceOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantName => $composableBuilder(
    column: $table.tenantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantSlug => $composableBuilder(
    column: $table.tenantSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidAmount => $composableBuilder(
    column: $table.paidAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehiclePlate => $composableBuilder(
    column: $table.vehiclePlate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedServiceOrdersTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedServiceOrdersTable> {
  $$CachedServiceOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantName => $composableBuilder(
    column: $table.tenantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantSlug => $composableBuilder(
    column: $table.tenantSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidAmount => $composableBuilder(
    column: $table.paidAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehiclePlate => $composableBuilder(
    column: $table.vehiclePlate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedServiceOrdersTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedServiceOrdersTable> {
  $$CachedServiceOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantName => $composableBuilder(
    column: $table.tenantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tenantSlug => $composableBuilder(
    column: $table.tenantSlug,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidAmount => $composableBuilder(
    column: $table.paidAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehiclePlate => $composableBuilder(
    column: $table.vehiclePlate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedServiceOrdersTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $CachedServiceOrdersTable,
          CachedServiceOrderRow,
          $$CachedServiceOrdersTableFilterComposer,
          $$CachedServiceOrdersTableOrderingComposer,
          $$CachedServiceOrdersTableAnnotationComposer,
          $$CachedServiceOrdersTableCreateCompanionBuilder,
          $$CachedServiceOrdersTableUpdateCompanionBuilder,
          (
            CachedServiceOrderRow,
            BaseReferences<
              _$CacheDatabase,
              $CachedServiceOrdersTable,
              CachedServiceOrderRow
            >,
          ),
          CachedServiceOrderRow,
          PrefetchHooks Function()
        > {
  $$CachedServiceOrdersTableTableManager(
    _$CacheDatabase db,
    $CachedServiceOrdersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedServiceOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedServiceOrdersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedServiceOrdersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> tenantName = const Value.absent(),
                Value<String> tenantSlug = const Value.absent(),
                Value<String> branchName = const Value.absent(),
                Value<String> completedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalAmount = const Value.absent(),
                Value<int> paidAmount = const Value.absent(),
                Value<String?> vehiclePlate = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedServiceOrdersCompanion(
                position: position,
                id: id,
                tenantName: tenantName,
                tenantSlug: tenantSlug,
                branchName: branchName,
                completedAt: completedAt,
                status: status,
                totalAmount: totalAmount,
                paidAmount: paidAmount,
                vehiclePlate: vehiclePlate,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int position,
                required String id,
                required String tenantName,
                required String tenantSlug,
                required String branchName,
                required String completedAt,
                required String status,
                required int totalAmount,
                required int paidAmount,
                Value<String?> vehiclePlate = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedServiceOrdersCompanion.insert(
                position: position,
                id: id,
                tenantName: tenantName,
                tenantSlug: tenantSlug,
                branchName: branchName,
                completedAt: completedAt,
                status: status,
                totalAmount: totalAmount,
                paidAmount: paidAmount,
                vehiclePlate: vehiclePlate,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedServiceOrdersTable, CachedServiceOrderRow>(
                    table,
                  ),
                  BaseReferences<
                    _$CacheDatabase,
                    $CachedServiceOrdersTable,
                    CachedServiceOrderRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedServiceOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $CachedServiceOrdersTable,
      CachedServiceOrderRow,
      $$CachedServiceOrdersTableFilterComposer,
      $$CachedServiceOrdersTableOrderingComposer,
      $$CachedServiceOrdersTableAnnotationComposer,
      $$CachedServiceOrdersTableCreateCompanionBuilder,
      $$CachedServiceOrdersTableUpdateCompanionBuilder,
      (
        CachedServiceOrderRow,
        BaseReferences<
          _$CacheDatabase,
          $CachedServiceOrdersTable,
          CachedServiceOrderRow
        >,
      ),
      CachedServiceOrderRow,
      PrefetchHooks Function()
    >;
typedef $$CachedOrganizationDetailsTableCreateCompanionBuilder =
    CachedOrganizationDetailsCompanion Function({
      required String slug,
      required String payloadJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedOrganizationDetailsTableUpdateCompanionBuilder =
    CachedOrganizationDetailsCompanion Function({
      Value<String> slug,
      Value<String> payloadJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedOrganizationDetailsTableFilterComposer
    extends Composer<_$CacheDatabase, $CachedOrganizationDetailsTable> {
  $$CachedOrganizationDetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedOrganizationDetailsTableOrderingComposer
    extends Composer<_$CacheDatabase, $CachedOrganizationDetailsTable> {
  $$CachedOrganizationDetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedOrganizationDetailsTableAnnotationComposer
    extends Composer<_$CacheDatabase, $CachedOrganizationDetailsTable> {
  $$CachedOrganizationDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedOrganizationDetailsTableTableManager
    extends
        RootTableManager<
          _$CacheDatabase,
          $CachedOrganizationDetailsTable,
          CachedOrganizationDetailRow,
          $$CachedOrganizationDetailsTableFilterComposer,
          $$CachedOrganizationDetailsTableOrderingComposer,
          $$CachedOrganizationDetailsTableAnnotationComposer,
          $$CachedOrganizationDetailsTableCreateCompanionBuilder,
          $$CachedOrganizationDetailsTableUpdateCompanionBuilder,
          (
            CachedOrganizationDetailRow,
            BaseReferences<
              _$CacheDatabase,
              $CachedOrganizationDetailsTable,
              CachedOrganizationDetailRow
            >,
          ),
          CachedOrganizationDetailRow,
          PrefetchHooks Function()
        > {
  $$CachedOrganizationDetailsTableTableManager(
    _$CacheDatabase db,
    $CachedOrganizationDetailsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedOrganizationDetailsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedOrganizationDetailsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedOrganizationDetailsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> slug = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedOrganizationDetailsCompanion(
                slug: slug,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String slug,
                required String payloadJson,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedOrganizationDetailsCompanion.insert(
                slug: slug,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $CachedOrganizationDetailsTable,
                    CachedOrganizationDetailRow
                  >(table),
                  BaseReferences<
                    _$CacheDatabase,
                    $CachedOrganizationDetailsTable,
                    CachedOrganizationDetailRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedOrganizationDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$CacheDatabase,
      $CachedOrganizationDetailsTable,
      CachedOrganizationDetailRow,
      $$CachedOrganizationDetailsTableFilterComposer,
      $$CachedOrganizationDetailsTableOrderingComposer,
      $$CachedOrganizationDetailsTableAnnotationComposer,
      $$CachedOrganizationDetailsTableCreateCompanionBuilder,
      $$CachedOrganizationDetailsTableUpdateCompanionBuilder,
      (
        CachedOrganizationDetailRow,
        BaseReferences<
          _$CacheDatabase,
          $CachedOrganizationDetailsTable,
          CachedOrganizationDetailRow
        >,
      ),
      CachedOrganizationDetailRow,
      PrefetchHooks Function()
    >;

class $CacheDatabaseManager {
  final _$CacheDatabase _db;
  $CacheDatabaseManager(this._db);
  $$CachedOrganizationsTableTableManager get cachedOrganizations =>
      $$CachedOrganizationsTableTableManager(_db, _db.cachedOrganizations);
  $$CachedVehiclesTableTableManager get cachedVehicles =>
      $$CachedVehiclesTableTableManager(_db, _db.cachedVehicles);
  $$CachedAppointmentsTableTableManager get cachedAppointments =>
      $$CachedAppointmentsTableTableManager(_db, _db.cachedAppointments);
  $$CachedServiceOrdersTableTableManager get cachedServiceOrders =>
      $$CachedServiceOrdersTableTableManager(_db, _db.cachedServiceOrders);
  $$CachedOrganizationDetailsTableTableManager get cachedOrganizationDetails =>
      $$CachedOrganizationDetailsTableTableManager(
        _db,
        _db.cachedOrganizationDetails,
      );
}
