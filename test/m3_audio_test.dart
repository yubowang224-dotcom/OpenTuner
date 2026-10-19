import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';

import 'audio_test.dart' show FixtureBridge;
import 'm3_model_test.dart' show partialPacket;

List<double> warming({int sequence = 0, int gaps = 0, double age = 0}) {
  final p = partialPacket().take(64).toList();
  p[2] = sequence.toDouble();
  p[3] = 0;
  p[4] = age;
  p[5] = 1;
  p[6] = 0;
  p[7] = 0;
  p[8] = 0;
  p[9] = 0;
  p[10] = 0;
  p[22] = gaps.toDouble();
  for (var i = 48; i <= 57; i++) {
    p[i] = 0;
  }
  p[48] = 1;
  p[60] = 0;
  return p;
}

void main() {
  testWidgets(
    'partial first 750ms window has bounded grace; a full first frame ends startup',
    (t) async {
      var now = 0;
      final bridge = FixtureBridge()
        ..makePacket = (seq, _) {
          if (now < 780) return warming(age: 1e9);
          return partialPacket()..[2] = seq.toDouble();
        };
      final c = AudioCapture(
        bridge: bridge,
        partialMidi: 69,
        monotonicMs: () => now,
      );
      await c.start();
      for (var i = 0; i < 24; i++) {
        now += 33;
        await t.pump(const Duration(milliseconds: 33));
        if (now < 780) {
          expect(c.active, isTrue);
          expect(c.current, isNull);
        }
      }
      expect(c.current?.partialFrame?.ready, isTrue);
      expect(bridge.stops, 0);
      c.dispose();
      await t.pump();
    },
  );
  testWidgets(
    'repeated sequence0 warming cannot indefinitely keep partial capture alive',
    (t) async {
      var now = 0;
      final bridge = FixtureBridge()..makePacket = (_, _) => warming(age: 1e9);
      final c = AudioCapture(
        bridge: bridge,
        partialMidi: 69,
        monotonicMs: () => now,
      );
      await c.start();
      for (var i = 0; i < 48; i++) {
        now += 33;
        await t.pump(const Duration(milliseconds: 33));
      }
      expect(c.status, CaptureStatus.stalled);
      expect(c.current, isNull);
      expect(bridge.stops, greaterThan(0));
      c.dispose();
      await t.pump();
    },
  );
  for (final repeatedGaps in [false, true]) {
    testWidgets(
      'partial discontinuity ${repeatedGaps ? 'repeated empty frames stop' : 'cached warming ages beyond250 then refills'}',
      (t) async {
        var now = 0, phase = 0, dropAt = 0;
        final bridge = FixtureBridge()
          ..makePacket = (seq, _) {
            if (phase == 1) {
              return warming(
                sequence: repeatedGaps ? seq : 2,
                gaps: repeatedGaps ? seq : 1,
                age: repeatedGaps ? 0 : (now - dropAt).toDouble(),
              );
            }
            return partialPacket()
              ..[2] = seq.toDouble()
              ..[22] = phase == 2 ? 1 : 0;
          };
        final c = AudioCapture(
          bridge: bridge,
          partialMidi: 69,
          monotonicMs: () => now,
        );
        await c.start();
        now = 33;
        await t.pump(const Duration(milliseconds: 33));
        expect(c.current?.valid, isTrue);
        phase = 1;
        dropAt = now;
        for (var i = 0; i < (repeatedGaps ? 40 : 25); i++) {
          now += 33;
          await t.pump(const Duration(milliseconds: 33));
          if (i == 0) {
            expect(c.current?.valid, isFalse);
          }
        }
        if (repeatedGaps) {
          expect(c.status, CaptureStatus.stalled);
        } else {
          expect(now - dropAt, greaterThan(750));
          expect(c.active, isTrue);
          expect(c.current?.valid, isNot(true));
          phase = 2;
          now += 33;
          await t.pump(const Duration(milliseconds: 33));
          expect(c.current?.valid, isTrue);
        }
        c.dispose();
        await t.pump();
      },
    );
  }
  testWidgets('cached discontinuity that never refills reaches one deadline', (
    t,
  ) async {
    var now = 0;
    final bridge = FixtureBridge()
      ..makePacket = (_, _) =>
          warming(sequence: 1, gaps: 1, age: now.toDouble());
    final c = AudioCapture(
      bridge: bridge,
      partialMidi: 69,
      monotonicMs: () => now,
    );
    await c.start();
    for (var i = 0; i < 40; i++) {
      now += 33;
      await t.pump(const Duration(milliseconds: 33));
    }
    expect(c.status, CaptureStatus.stalled);
    c.dispose();
    await t.pump();
  });
  testWidgets(
    'wrong partial target is rejected; late sessions cannot attach to another key',
    (t) async {
      final bridge = FixtureBridge()
        ..makePacket = (seq, _) => partialPacket()
          ..[2] = seq.toDouble()
          ..[59] = 81;
      final c = AudioCapture(bridge: bridge, partialMidi: 69);
      await c.start();
      await t.pump(const Duration(milliseconds: 33));
      expect(c.status, CaptureStatus.error);
      expect(c.current, isNull);
      c.dispose();
      await t.pump();
    },
  );
}
