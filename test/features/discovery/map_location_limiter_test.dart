import 'package:carcare_customer_mobile/features/discovery/presentation/map_location_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps only visible locations and respects the marker limit', () {
    final candidates = List.generate(
      200,
      (index) => MapLocationCandidate(
        value: index,
        latitude: 47.9,
        longitude: 106.8 + index / 10000,
        selected: index == 175,
      ),
    );

    final visible = limitMapLocations(
      candidates,
      south: 47,
      north: 48,
      west: 106,
      east: 108,
      limit: 150,
    );

    expect(visible, hasLength(150));
    expect(visible.first, 175);
  });

  test('supports viewports crossing the antimeridian', () {
    const candidates = [
      MapLocationCandidate(value: 'east', latitude: 0, longitude: 179),
      MapLocationCandidate(value: 'west', latitude: 0, longitude: -179),
      MapLocationCandidate(value: 'outside', latitude: 0, longitude: 0),
    ];

    final visible = limitMapLocations(
      candidates,
      south: -10,
      north: 10,
      west: 170,
      east: -170,
    );

    expect(visible, containsAll(['east', 'west']));
    expect(visible, isNot(contains('outside')));
  });

  test('keeps the selected marker when reported bounds exclude it', () {
    const candidates = [
      MapLocationCandidate(
        value: 'selected',
        latitude: 47.9,
        longitude: 106.9,
        selected: true,
      ),
      MapLocationCandidate(value: 'outside', latitude: 48.5, longitude: 107),
    ];

    final visible = limitMapLocations(
      candidates,
      south: 46,
      north: 47,
      west: 105,
      east: 106,
    );

    expect(visible, ['selected']);
  });
}
