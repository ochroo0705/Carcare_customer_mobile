// Тайлангийн загварын бүтэц — web-ийн `lib/diagnostics.ts`-ийн
// `TemplateSchema`/`TemplateItem`-тэй ижил, зөвхөн унших зорилготой Dart
// хувилбар (мобайл дээр тайлан засварлагдахгүй тул validation алгасав).

const Map<String, List<PositionDef>> positionSets = {
  'LR': [PositionDef('L', 'Зүүн'), PositionDef('R', 'Баруун')],
  'FB': [PositionDef('F', 'Урд'), PositionDef('B', 'Хойд')],
  'CORNERS': [
    PositionDef('FL', 'Урд зүүн'),
    PositionDef('FR', 'Урд баруун'),
    PositionDef('RL', 'Хойд зүүн'),
    PositionDef('RR', 'Хойд баруун'),
  ],
};

class PositionDef {
  const PositionDef(this.code, this.label);
  final String code;
  final String label;
}

class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.positionSet,
  });

  final String id;
  final String label;
  final String type; // check | text | number | photo | signature
  final List<String> options;
  final String? positionSet;

  List<PositionDef>? get positions =>
      positionSet == null ? null : positionSets[positionSet];

  factory TemplateItem.fromJson(Map json) => TemplateItem(
    id: json['id'] is String ? json['id'] as String : '',
    label: json['label'] is String ? json['label'] as String : '',
    type: json['type'] is String ? json['type'] as String : 'text',
    options: json['options'] is List
        ? (json['options'] as List).whereType<String>().toList(growable: false)
        : const [],
    positionSet: json['positionSet'] is String
        ? json['positionSet'] as String
        : null,
  );
}

class TemplateSection {
  const TemplateSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<TemplateItem> items;

  factory TemplateSection.fromJson(Map json) => TemplateSection(
    id: json['id'] is String ? json['id'] as String : '',
    title: json['title'] is String ? json['title'] as String : '',
    items: json['items'] is List
        ? (json['items'] as List)
              .whereType<Map>()
              .map(TemplateItem.fromJson)
              .toList(growable: false)
        : const [],
  );
}

class TemplateSchema {
  const TemplateSchema({this.sections = const []});

  final List<TemplateSection> sections;

  factory TemplateSchema.fromJson(Object? json) {
    if (json is! Map || json['sections'] is! List) {
      return const TemplateSchema();
    }
    return TemplateSchema(
      sections: (json['sections'] as List)
          .whereType<Map>()
          .map(TemplateSection.fromJson)
          .toList(growable: false),
    );
  }
}

/// Нэг талбарын (item эсвэл байрлалын) бөглөлт.
class ReportEntry {
  const ReportEntry({this.value, this.note, this.photos = const []});

  final Object? value;
  final String? note;
  final List<String> photos;

  factory ReportEntry.fromJson(Object? json) {
    if (json is! Map) return const ReportEntry();
    return ReportEntry(
      value: json['value'],
      note: json['note'] is String ? json['note'] as String : null,
      photos: json['photos'] is List
          ? (json['photos'] as List).whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

/// Бүх талбарын бөглөлт, түлхүүрээр (item.id эсвэл `<id>@<code>`).
class ReportData {
  const ReportData(this._entries);

  final Map<String, ReportEntry> _entries;

  ReportEntry entryFor(String key) => _entries[key] ?? const ReportEntry();

  Iterable<MapEntry<String, ReportEntry>> get entries => _entries.entries;

  factory ReportData.fromJson(Object? json) {
    if (json is! Map) return const ReportData({});
    final entries = <String, ReportEntry>{};
    for (final entry in json.entries) {
      if (entry.key is String) {
        entries[entry.key as String] = ReportEntry.fromJson(entry.value);
      }
    }
    return ReportData(entries);
  }
}

String positionedKey(String itemId, String code) => '$itemId@$code';
