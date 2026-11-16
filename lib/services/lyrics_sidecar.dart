import 'dart:io';

import 'package:mornye/utils/lyrics_parser.dart';

typedef SidecarLyrics = ({ParsedLyrics lyrics, String raw});

const SidecarLyrics _noSidecar = (lyrics: ParsedLyrics.empty, raw: '');

/// Lyrics that live next to an audio file, as written by the local lyrics
/// pipeline:
///
///   `<stem>.subs.lrc`       original, Latin and translated lanes in one file
///   `<stem>.lrc`            plain or word-timed original
///   `<stem>.syllables.lrc`  finer onsets than the word timings of `.lrc`
///
/// Only files on disk are read; streams and SAF documents have no sidecars.
class LyricsSidecar {
  LyricsSidecar._();

  static const _syllableTolerance = Duration(milliseconds: 50);

  /// The lyrics for [audioPath], or an empty result when it has none.
  static Future<SidecarLyrics> read(String? audioPath) async {
    final base = _stem(audioPath);
    if (base == null) return _noSidecar;

    var found = await _read(base, '.subs.lrc');
    if (!_usable(found.lyrics)) {
      final plain = await _read(base, '.lrc');
      if (_usable(plain.lyrics)) found = plain;
    }
    if (!_usable(found.lyrics)) return _noSidecar;
    return (
      lyrics: await _withSyllableTimings(base, found.lyrics),
      raw: found.raw,
    );
  }

  static bool _usable(ParsedLyrics lyrics) =>
      lyrics.synced && lyrics.lines.length >= 2;

  /// A `.syllables.lrc` belongs to the same song only when every line matches
  /// the original in count, text and timing; otherwise its offsets would sweep
  /// the wrong characters.
  static Future<ParsedLyrics> _withSyllableTimings(
    String base,
    ParsedLyrics lyrics,
  ) async {
    final syllables = (await _read(base, '.syllables.lrc')).lyrics;
    if (!syllables.synced || syllables.lines.length != lyrics.lines.length) {
      return lyrics;
    }
    for (var i = 0; i < lyrics.lines.length; i++) {
      final line = lyrics.lines[i];
      final timed = syllables.lines[i];
      if (line.text != timed.text) return lyrics;
      final delta = line.time - timed.time;
      if (delta.abs() > _syllableTolerance) return lyrics;
    }
    return ParsedLyrics(
      synced: lyrics.synced,
      wordSynced: lyrics.lines.any((line) => line.words.isNotEmpty),
      lines: [
        for (var i = 0; i < lyrics.lines.length; i++)
          _replaceWords(
            lyrics.lines[i],
            syllables.lines[i].words.isEmpty
                ? lyrics.lines[i].words
                : syllables.lines[i].words,
          ),
      ],
      plainText: lyrics.plainText,
      writers: lyrics.writers,
      provider: lyrics.provider,
    );
  }

  static LyricLine _replaceWords(LyricLine line, List<LyricWord> words) =>
      LyricLine(
        time: line.time,
        end: line.end,
        text: line.text,
        words: words,
        romanization: line.romanization,
        romanizationWords: line.romanizationWords,
        translation: line.translation,
        translationWords: line.translationWords,
        voice: line.voice,
        isBackground: line.isBackground,
        vocalGroup: line.vocalGroup,
      );

  static Future<SidecarLyrics> _read(String base, String suffix) async {
    try {
      final file = File('$base$suffix');
      if (!await file.exists()) return _noSidecar;
      final raw = await file.readAsString();
      return (lyrics: LyricsParser.parse(raw), raw: raw);
    } catch (_) {
      // An unreadable sidecar must not hide the lyrics the file does have.
      return _noSidecar;
    }
  }

  /// The path without its audio extension, or null for a source that has no
  /// file next to it.
  static String? _stem(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('content://') || path.startsWith('network://')) {
      return null;
    }
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.scheme != 'file') return null;
    final slash = path.lastIndexOf('/');
    final dot = path.lastIndexOf('.');
    if (dot <= slash || dot == path.length - 1) return null;
    return path.substring(0, dot);
  }
}
