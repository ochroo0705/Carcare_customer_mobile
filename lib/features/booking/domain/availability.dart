/// Нэг цагийн нүх (slot) — booking v2 availability endpoint-оос.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.hour,
    required this.minute,
    required this.available,
    required this.remaining,
  });

  final int hour;
  final int minute;

  /// Сонгох боломжтой эсэх (ирээдүйд + сул багтаамжтай).
  final bool available;

  /// Тухайн нүхэнд үлдсэн багтаамж.
  final int remaining;

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
