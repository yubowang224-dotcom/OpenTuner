import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentune_tuner/app.dart';
import 'package:opentune_tuner/audio/audio_capture.dart';
import 'package:opentune_tuner/model/app_state.dart';
import 'package:opentune_tuner/widgets/page_entrance.dart';

import 'audio_test.dart' show packet;

class Probe extends StatefulWidget {
  const Probe({super.key, required this.id, required this.events});
  final int id;
  final List<String> events;
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  @override
  void initState() {
    super.initState();
    widget.events.add('init${widget.id}');
  }

  @override
  void dispose() {
    widget.events.add('dispose${widget.id}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('page${widget.id}');
}

void main() {
  testWidgets(
    'entrance removes outgoing page immediately and retains the current subtree on same-page changes',
    (tester) async {
      final events = <String>[];
      Future<void> show(int id, {bool reduce = false}) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: PageEntrance(
              page: id,
              child: Probe(key: ValueKey(id), id: id, events: events),
            ),
          ),
        ),
      );
      await show(0);
      expect(events, ['init0']);
      await show(1);
      expect(find.text('page0'), findsNothing);
      // Flutter initializes the replacement before finalizeTree disposes the
      // outgoing State. Both must complete in this same pump, before fade time.
      expect(events, unorderedEquals(['init0', 'dispose0', 'init1']));
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('page-pointer-gate')),
            )
            .ignoring,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('page-opacity')))
            .opacity,
        inExclusiveRange(0, 1),
      );
      await show(1);
      expect(events.where((e) => e == 'init1').length, 1);
      await show(2);
      await show(3);
      expect(find.text('page1'), findsNothing);
      expect(find.text('page2'), findsNothing);
      await tester.pump(const Duration(milliseconds: 121));
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('page-pointer-gate')),
            )
            .ignoring,
        isFalse,
      );
      await show(4, reduce: true);
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('page-opacity')))
            .opacity,
        1,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('page-pointer-gate')),
            )
            .ignoring,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      expect(
        events.where((e) => e.startsWith('init')).length,
        events.where((e) => e.startsWith('dispose')).length,
      );
    },
  );
  testWidgets(
    'rapid navigation stops live capture on removal and never auto-starts on return',
    (tester) async {
      final calls = <String>[];
      var sequence = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        (MethodCall call) async {
          calls.add(call.method);
          return switch (call.method) {
            'start' => {'status': 'running', 'session': 7},
            'snapshot' => {
              'status': 'running',
              'data': packet(sequence: ++sequence),
            },
            _ => null,
          };
        },
      );
      final state = AppState()..selectPage(2);
      await tester.pumpWidget(OpenTuneApp(state: state));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('capture-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('capture-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 33));
      expect(calls.where((e) => e == 'start').length, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('reference-lock')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reference-lock')));
      await tester.pump();
      expect(find.text('Locked reference'), findsOneWidget);
      state.setMinimal(true);
      await tester.pump();
      expect(calls.contains('stop'), isFalse);
      state.selectPage(0);
      await tester.pump();
      expect(calls.contains('stop'), isTrue);
      state.selectPage(1);
      await tester.pump(const Duration(milliseconds: 20));
      state.selectPage(2);
      await tester.pump();
      expect(calls.where((e) => e == 'start').length, 1);
      expect(find.text('Locked reference'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Automatic reference'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.where((e) => e == 'start').length, 1);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidAudioBridge.channel,
        null,
      );
    },
  );
}
