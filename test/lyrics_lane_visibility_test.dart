import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/utils/lyrics_parser.dart';
import 'package:mornye/widgets/player_lyrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

ParsedLyrics _lyrics({required bool lanes}) => ParsedLyrics(
  synced: true,
  wordSynced: false,
  plainText: '',
  lines: [
    LyricLine(
      time: const Duration(seconds: 10),
      end: const Duration(seconds: 20),
      text: 'Оригинал',
      romanization: lanes ? 'Original' : null,
      translation: lanes ? 'Original text' : null,
    ),
    const LyricLine(time: Duration(seconds: 20), text: 'Второй'),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required ParsedLyrics lyrics,
  required bool showOriginal,
}) async {
  final theme = MornyeTheme.build(Brightness.dark);
  final preview = ValueNotifier<Duration?>(
    const Duration(seconds: 11),
  );
  addTearDown(preview.dispose);
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackStateProvider.overrideWith((ref) => Stream.value(PlaybackState())),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 620,
            height: 900,
            child: SyncedLyricsView(
              lyrics: lyrics,
              seekPreview: preview,
              colorScheme: theme.colorScheme,
              isActive: true,
              showOriginal: showOriginal,
              showPronunciation: true,
              showTranslation: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hiding the original leaves the Latin and translated lanes', (
    tester,
  ) async {
    await _pump(tester, lyrics: _lyrics(lanes: true), showOriginal: false);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Original text'), findsOneWidget);
    expect(find.text('Оригинал'), findsNothing);
  });

  testWidgets('a line without lanes keeps its original text', (tester) async {
    await _pump(tester, lyrics: _lyrics(lanes: false), showOriginal: false);
    expect(find.text('Оригинал'), findsOneWidget);
  });

  testWidgets('the original lane stays when it is shown', (tester) async {
    await _pump(tester, lyrics: _lyrics(lanes: true), showOriginal: true);
    expect(find.text('Оригинал'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
  });
}
