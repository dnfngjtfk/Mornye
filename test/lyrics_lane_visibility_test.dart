import 'dart:convert';

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
  bool showPronunciation = true,
  bool showTranslation = true,
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
              showPronunciation: showPronunciation,
              showTranslation: showTranslation,
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
    // The remaining lane reads at the primary size instead of shrinking into a
    // subtitle, and the hidden lane no longer reserves its height.
    final latin = tester.widget<Text>(find.text('Original'));
    final primarySize = tester.widget<Text>(find.text('Второй')).style?.fontSize;
    expect(latin.style?.fontSize, primarySize);
  });

  testWidgets('a single remaining lane renders as ordinary synced lyrics', (
    tester,
  ) async {
    await _pump(
      tester,
      lyrics: _lyrics(lanes: true),
      showOriginal: false,
      showTranslation: false,
    );
    expect(find.text('Original text'), findsNothing);
    final latin = tester.widget<Text>(find.text('Original'));
    final plain = tester.widget<Text>(find.text('Второй'));
    expect(latin.style, plain.style);
    expect(latin.textAlign, plain.textAlign);
  });

  testWidgets('a stored lane order decides which lane leads', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app_settings': jsonEncode({
        'playerLaneOrder': ['translation', 'pronunciation', 'original'],
      }),
    });
    await _pump(tester, lyrics: _lyrics(lanes: true), showOriginal: true);
    final translated = tester.widget<Text>(find.text('Original text'));
    final original = tester.widget<Text>(find.text('Оригинал'));
    expect(find.text('Original'), findsOneWidget);
    expect(
      translated.style!.fontSize!,
      greaterThan(original.style!.fontSize!),
    );
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
