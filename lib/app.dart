import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/explore_page.dart';
import 'audio/guitar_page.dart';
import 'audio/metronome_page.dart';
import 'audio/piano_page.dart';
import 'audio/reference_player.dart';

import 'l10n/generated/app_localizations.dart';
import 'model/app_state.dart';
import 'pages.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/page_entrance.dart';
import 'widgets/mode_scroll.dart';

class OpenTuneApp extends StatefulWidget {
  const OpenTuneApp({super.key, this.state, this.referencePlayer});
  final AppState? state;
  final ReferencePlayer? referencePlayer;
  @override
  State<OpenTuneApp> createState() => _OpenTuneAppState();
}

class _OpenTuneAppState extends State<OpenTuneApp> {
  late final AppState state = widget.state ?? AppState();
  late final ReferencePlayer reference =
      widget.referencePlayer ?? ReferencePlayer();
  int _page = 0;
  int _audioRevision = 0;
  String _pianoConfiguration = '';
  @override
  void initState() {
    super.initState();
    _page = state.page;
    _audioRevision = state.audioRevision;
    _pianoConfiguration = '${state.pianoNote}:${state.pianoKind}';
    state.addListener(_pageChanged);
  }

  void _pageChanged() {
    final piano = '${state.pianoNote}:${state.pianoKind}';
    if (state.page != _page ||
        _audioRevision != state.audioRevision ||
        state.page == 1 && piano != _pianoConfiguration) {
      _page = state.page;
      reference.stop();
    }
    _audioRevision = state.audioRevision;
    _pianoConfiguration = piano;
  }

  @override
  void dispose() {
    state.removeListener(_pageChanged);
    if (widget.referencePlayer == null) reference.dispose();
    if (widget.state == null) state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: state.themeMode,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      locale: state.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: AppShell(state: state, reference: reference),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.state, required this.reference});
  final AppState state;
  final ReferencePlayer reference;
  static const icons = [
    Icons.music_note_outlined,
    Icons.piano_outlined,
    Icons.graphic_eq_rounded,
    Icons.av_timer_rounded,
    Icons.tune_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final labels = [s.guitar, s.piano, s.explore, s.metronome, s.settings];
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 700 && size.height >= 500;
    final focus = state.minimal && state.page < 3;
    final showPreviewBadge =
        size.width >= 360 && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final page = switch (state.page) {
      0 => GuitarPage(
        key: ValueKey('guitar-${state.audioRevision}'),
        state: state,
        reference: reference,
      ),
      1 => PianoPage(
        key: ValueKey(
          'piano-${state.audioRevision}-${state.pianoNote}-${state.pianoKind}',
        ),
        state: state,
        reference: reference,
      ),
      2 => ExplorePage(
        key: ValueKey('explore-${state.audioRevision}'),
        state: state,
      ),
      3 => MetronomePage(state: state),
      _ => SettingsPage(state: state),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Theme.of(context)
                    .scaffoldBackgroundColor,
              ),
      child: Scaffold(
        bottomNavigationBar: wide || focus
            ? null
            : MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: NavigationBar(
                  selectedIndex: state.page,
                  onDestinationSelected: state.selectPage,
                  destinations: List.generate(
                    5,
                    (i) => NavigationDestination(
                      key: ValueKey('nav-$i'),
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                  ),
                ),
              ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                child: Row(
                  children: focus
                      ? [
                          Expanded(
                            child: Text(
                              s.appTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          PopupMenuButton<int>(
                            key: const ValueKey('focus-tools'),
                            tooltip: s.switchTool,
                            onSelected: state.selectPage,
                            itemBuilder: (_) => List.generate(
                              5,
                              (i) => PopupMenuItem<int>(
                                key: ValueKey('nav-$i'),
                                value: i,
                                child: Text(labels[i]),
                              ),
                            ),
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                          if (size.width < 360 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3)
                            IconButton(
                              key: const ValueKey('minimal-toggle'),
                              tooltip: s.exitMinimal,
                              onPressed: () => state.setMinimal(false),
                              icon: const Icon(Icons.fullscreen_exit_rounded),
                            )
                          else
                            TextButton.icon(
                              key: const ValueKey('minimal-toggle'),
                              onPressed: () => state.setMinimal(false),
                              icon: const Icon(Icons.fullscreen_exit_rounded),
                              label: Text(s.exitMinimal),
                            ),
                        ]
                      : [
                          Expanded(
                            child: Text(
                              s.appTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (showPreviewBadge)
                            StatusPill(
                              label: state.page < 3
                                  ? s.localAnalysis
                                  : state.page == 3
                                  ? s.nativeAudio
                                  : s.uiPreview,
                            ),
                          if (state.page < 3)
                            IconButton(
                              key: const ValueKey('minimal-toggle'),
                              tooltip: state.minimal
                                  ? s.normalMode
                                  : s.minimalMode,
                              isSelected: state.minimal,
                              onPressed: () => state.setMinimal(!state.minimal),
                              icon: const Icon(
                                Icons.filter_center_focus_rounded,
                              ),
                              selectedIcon: const Icon(
                                Icons.fullscreen_exit_rounded,
                              ),
                            ),
                        ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (wide)
                      NavigationRail(
                        scrollable: true,
                        selectedIndex: state.page,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: state.selectPage,
                        destinations: List.generate(
                          5,
                          (i) => NavigationRailDestination(
                            icon: Icon(icons[i], key: ValueKey('nav-$i')),
                            label: Text(labels[i]),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: PageEntrance(
                            page: state.page,
                            child: ModeScroll(
                              key: ValueKey('mode-page-${state.page}'),
                              storageId: 'page-${state.page}-live',
                              minimal: state.minimal,
                              padding: EdgeInsets.fromLTRB(
                                wide ? 36 : 20,
                                16,
                                wide ? 36 : 20,
                                28,
                              ),
                              child: page,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
