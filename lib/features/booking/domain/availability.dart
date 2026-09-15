/// Нэг цагийн нүх (slot) — booking v2 availability endpoint-оос.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.hour,
    required this.minute,
    required this.available,
    required this.remaining,
    required this.utc,
  });

  /// Салбарын (Ulaanbaatar) орон нутгийн цаг — зөвхөн харуулахад.
  final int hour;
  final int minute;

  /// Сонгох боломжтой эсэх (ирээдүйд + сул багтаамжтай).
  final bool available;

  /// Тухайн нүхэнд үлдсэн багтаамж.
  final int remaining;

  /// Энэ нүхний бодит UTC мөч — сервер (`iso` талбар) тооцсон, эрхийн
  /// эцсийн эх сурвалж. Захиалга илгээхдээ ЭНЭ утгыг хэрэглэнэ, `hour`/
  /// `minute`-аас device-local цаг барьж дахин тооцохгүй — эс бөгөөс
  /// device-ийн timezone Ulaanbaatar-аас өөр үед буруу мөч илгээгдэнэ.
  final DateTime utc;

  ({int hour, int minute}) get time => (hour: hour, minute: minute);
}

/// Тухайн салбар + өдөр + сонгосон ангилалуудын нийт хугацаанд тохирох
/// боломжит цагуудын багц.
class DayAvailability {
  const DayAvailability({
    required this.open,
    required this.durationMinutes,
    required this.slots,
    this.reason,
  });

  final bool open;
  final int durationMinutes;
  final List<AvailabilitySlot> slots;

  /// Хаалттай/цаг байхгүй үеийн шалтгаан (жишээ: "Энэ өдөр амарна.").
  final String? reason;
}
