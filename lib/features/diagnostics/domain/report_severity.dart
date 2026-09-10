/// Тайлан доторх check хариултуудаас хамгийн муу түвшин — backend
/// `DiagnosticReport.maxSeverity`-тай ижил утгууд (харах: web
/// `lib/diagnostics.ts`-ийн `ReportSeverity`). Web дээрх яг ижил Монгол
/// нэршил ("Хэвийн"/"Анхаарах"/"Солих") ашиглана.
enum ReportSeverity { good, warn, bad }

ReportSeverity? reportSeverityFromApi(Object? value) => switch (value) {
  'GOOD' => ReportSeverity.good,
  'WARN' => ReportSeverity.warn,
  'BAD' => ReportSeverity.bad,
  _ => null,
};

extension ReportSeverityUi on ReportSeverity {
  String get localizedLabel => switch (this) {
    ReportSeverity.good => 'Хэвийн',
    ReportSeverity.warn => 'Анхаарах',
    ReportSeverity.bad => 'Солих шаардлагатай',
  };
}

/// Нэг check хариултын өнгө (worker web-ийн `lib/diagnostics.ts`-ийн
/// `checkOptionTone`-той ижил дүрэм) — үг таарсан эсэхээр тодорхойлно,
/// зөвхөн `DEFAULT_CHECK_OPTIONS`-д биш дур зоргоороо бичсэн check
/// сонголтод ч ажиллана.
enum CheckTone { good, warn, bad }

final RegExp _warnPattern = RegExp(
  r'анхаар|дунд|элэгд|сэжиг|шалгуулах|бага',
);
final RegExp _badPattern = RegExp(
  r'зас|соли|муу|гэмт|яаралт|аюул|болохгүй|доголд|дутуу',
);

CheckTone checkOptionTone(String option) {
  final v = option.toLowerCase();
  if (_warnPattern.hasMatch(v)) return CheckTone.warn;
  if (_badPattern.hasMatch(v)) return CheckTone.bad;
  return CheckTone.good;
}
