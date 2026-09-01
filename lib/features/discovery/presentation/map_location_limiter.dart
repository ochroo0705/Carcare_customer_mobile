class MapLocationCandidate<T> {
  const MapLocationCandidate({
    required this.value,
    required this.latitude,
    required this.longitude,
    this.selected = false,
  });

  final T value;
  final double latitude;
  final double longitude;
  final bool selected;
}

List<T> limitMapLocations<T>(
  Iterable<MapLocationCandidate<T>> candidates, {
  required double south,
  required double north,
  required double west,
  required double east,
  int limit = 150,
}) {
  final visible = candidates.where((candidate) {
    if (candidate.selected) return true;
    final withinLatitude =
        candidate.latitude >= south && candidate.latitude <= north;
    final withinLongitude = west <= east
        ? candidate.longitude >= west && candidate.longitude <= east
        : candidate.longitude >= west || candidate.longitude <= east;
    return withinLatitude && withinLongitude;
  }).toList();
  visible.sort((a, b) {
    if (a.selected == b.selected) return 0;
    return a.selected ? -1 : 1;
  });
  return visible.take(limit).map((candidate) => candidate.value).toList();
}
