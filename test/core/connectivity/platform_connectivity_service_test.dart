import 'dart:async';

import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

const _wifi = [ConnectivityResult.wifi];
const _mobile = [ConnectivityResult.mobile];
const _none = [ConnectivityResult.none];

void main() {
  late StreamController<List<ConnectivityResult>> os;
  late List<bool> probeResults;
  late int probeCalls;
  late List<bool> emitted;
  late StreamSubscription<bool> sub;

  Future<void> start({List<ConnectivityResult> initial = _none}) async {
    final service = PlatformConnectivityService(
      probe: () async {
        probeCalls++;
        return probeResults.isEmpty ? false : probeResults.removeAt(0);
      },
      changes: os.stream,
      checkNow: () async => initial,
      debounce: const Duration(milliseconds: 20),
      retryDelays: const [Duration(milliseconds: 10)],
      recheckInterval: const Duration(milliseconds: 60),
    );
    sub = service.onConnectivityChanged.listen(emitted.add);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() {
    os = StreamController();
    probeResults = [];
    probeCalls = 0;
    emitted = [];
  });

  tearDown(() async {
    await sub.cancel();
    await os.close();
  });

  test('emits true only after the probe confirms reachability', () async {
    probeResults = [true];
    await start();
    expect(emitted, [false]);
    os.add(_wifi);
    await wait(5);
    expect(emitted, [false], reason: 'still debouncing');
    await wait(40);
    expect(emitted, [false, true]);
  });

  test(
    'a handover burst causes one probe and no duplicate emissions',
    () async {
      probeResults = [true, true];
      await start(initial: _wifi);
      await wait(40);
      expect(emitted, [true]);
      os
        ..add(_none)
        ..add(_mobile);
      await wait(40);
      expect(emitted, [true, false, true]);
      expect(probeCalls, 2);
    },
  );

  test('interface up but API unreachable reads offline, then recovers '
      'on a later recheck without any OS event', () async {
    probeResults = [false, false, true];
    await start(initial: _wifi);
    await wait(50);
    expect(emitted, [false]);
    await wait(80);
    expect(emitted, [false, true]);
  });

  test('losing every interface emits false immediately and cancels a '
      'pending probe', () async {
    probeResults = [true];
    await start(initial: _wifi);
    os.add(_none);
    await wait(40);
    expect(emitted, [false]);
    expect(probeCalls, 0);
  });
}
