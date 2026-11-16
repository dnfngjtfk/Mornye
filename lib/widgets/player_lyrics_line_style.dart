part of 'player_lyrics.dart';

/// Space a supplement lane adds above its own text. Row measurement uses the
/// same value, so a lane never renders taller than the height reserved for it.
const double _lyricSupplementGap = 4;

const List<String> _defaultLyricLaneOrder = lyricLaneIds;

/// A lane that can be drawn for [line]: its identifier, text, word timing,
/// style and whether it is the translated one.
typedef _LyricLaneData = (
  String id,
  String text,
  List<LyricWord> words,
  TextStyle style,
  bool translation,
);

/// The lanes [line] can show that are switched on, in the listener's order.
/// The first entry is drawn as the line itself, the rest under it.
List<_LyricLaneData> _lyricLanes(
  BuildContext context,
  LyricLine line, {
  required List<String> order,
  required bool showOriginal,
  required bool showPronunciation,
  required bool showTranslation,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  TextStyle supplementStyle({required bool translation}) => base.copyWith(
    fontSize:
        (context.isMornye
            ? (translation ? 18.0 : 22.0)
            : isDesktopPlatform
            ? (translation ? 18.0 : 20.0)
            : (translation ? 14.0 : 16.0)) *
        (line.isBackground ? 0.8 : 1),
    height: 1.35,
    fontWeight: context.isMornye
        ? (translation ? FontWeight.w600 : FontWeight.bold)
        : FontWeight.w500,
  );

  final lanes = <_LyricLaneData>[];
  for (final id in normalizedLyricLaneOrder(order)) {
    switch (id) {
      case 'original':
        if (!showOriginal || line.text.trim().isEmpty) continue;
        // The renderer draws the first lane at the primary style; this one is
        // only used when the listener moves the original under another lane.
        lanes.add((
          'original',
          line.text,
          line.words,
          supplementStyle(translation: false),
          false,
        ));
      case 'pronunciation':
        final text = line.romanization;
        if (!showPronunciation || text == null || text.trim().isEmpty) {
          continue;
        }
        lanes.add((
          'pronunciation',
          text,
          line.romanizationWords,
          supplementStyle(translation: false),
          false,
        ));
      case 'translation':
        final text = line.translation;
        if (!showTranslation || text == null || text.trim().isEmpty) continue;
        lanes.add((
          'translation',
          text,
          line.translationWords,
          supplementStyle(translation: true),
          true,
        ));
    }
  }
  return lanes;
}

TextStyle _primaryLyricStyle(BuildContext context, {bool background = false}) =>
    DefaultTextStyle.of(context).style.merge(
      (Theme.of(context).textTheme.headlineSmall ?? const TextStyle()).copyWith(
        fontSize: context.isMornye
            ? _mornyeLyricFontSize * (background ? 0.68 : 1)
            : background
            ? _materialBackgroundLyricFontSize
            : _materialLyricFontSize,
        height: context.tokens.lyricsLineHeight,
        fontWeight: FontWeight.bold,
      ),
    );

TextAlign _lyricTextAlign(BuildContext context, LyricLine line) {
  final voice = line.voice;
  if (voice == null) return TextAlign.start;
  // The lead voice keeps the reading start, so duets mirror in right-to-left
  // layouts.
  if (voice.isGroup) return TextAlign.start;
  // Provider declarations can be missing or ordered by first appearance.
  // The standard V labels retain their meaning regardless of that order.
  switch (voice.id.toLowerCase()) {
    case 'v1':
    case 'v3':
      return TextAlign.start;
    case 'v2':
      return TextAlign.end;
  }
  return voice.index.isEven ? TextAlign.start : TextAlign.end;
}

Widget _withLyricSupplements(
  BuildContext context,
  LyricLine line,
  Widget primary,
  Color color, {
  required Offset visibility,
  required List<String> laneOrder,

  /// False hides the original lane. The first lane that stays on takes over
  /// the primary slot, so a translated line keeps the normal lyric size and a
  /// hidden lane never reserves space.
  required bool showOriginal,
  required bool showPronunciation,
  required bool showTranslation,
  required LyricPronunciationLayout? pronunciationLayout,
  required TextAlign textAlign,
  Widget Function(String, List<LyricWord>, TextStyle)? timedText,
  Widget Function(String, List<LyricWord>, TextStyle)? timedSupplementText,
}) {
  double laneVisibility(String id) => switch (id) {
    'pronunciation' => visibility.dx,
    'translation' => visibility.dy,
    _ => 1,
  };
  final lanes = _lyricLanes(
    context,
    line,
    order: laneOrder,
    showOriginal: showOriginal,
    showPronunciation: showPronunciation && visibility.dx > 0,
    showTranslation: showTranslation && visibility.dy > 0,
  );
  if (lanes.isEmpty) return primary;
  final AlignmentGeometry alignment = switch (textAlign) {
    TextAlign.end => AlignmentDirectional.topEnd,
    TextAlign.center => Alignment.topCenter,
    _ => AlignmentDirectional.topStart,
  };
  final primaryStyle = _primaryLyricStyle(
    context,
    background: line.isBackground,
  );

  // A promoted lane is drawn with the same builder as the original lyric text,
  // so a single remaining lane is indistinguishable from ordinary sync.
  Widget text(
    String value,
    List<LyricWord> words,
    TextStyle style, {
    bool primary = false,
  }) {
    if (primary && timedText != null) return timedText(value, words, style);
    if (words.isNotEmpty && timedSupplementText != null) {
      return timedSupplementText(value, words, style);
    }
    return Text(value, textAlign: textAlign, style: style);
  }

  Widget head(_LyricLaneData lane) =>
      lane.$1 == 'original'
      ? primary
      : text(lane.$2, lane.$3, primaryStyle.copyWith(color: color), primary: true);

  Widget supplement(_LyricLaneData lane) => LyricSupplementTransition(
    alignment: alignment,
    visibility: laneVisibility(lane.$1),
    child: Padding(
      padding: const EdgeInsets.only(top: _lyricSupplementGap),
      child: text(
        lane.$2,
        lane.$3,
        lane.$4.copyWith(color: color.withValues(alpha: color.a * 0.8)),
      ),
    ),
  );

  final aligned =
      lanes.first.$1 == 'original' &&
      lanes.length > 1 &&
      lanes[1].$1 == 'pronunciation' &&
      context.isMornye &&
      pronunciationLayout != null &&
      line.romanizationWords.isNotEmpty;
  if (!aligned) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head(lanes.first),
        for (final lane in lanes.skip(1)) supplement(lane),
      ],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AlignedLyricPronunciation(
        layout: pronunciationLayout,
        visibility: visibility.dx,
        primaryStyle: primaryStyle,
        pronunciationStyle: lanes[1].$4,
        textAlign: textAlign,
        pronunciationBuilder: timedSupplementText,
        textBuilder:
            timedText ??
            (value, words, style) => Text(
              value,
              textAlign: textAlign,
              style: style.copyWith(color: color),
            ),
      ),
      for (final lane in lanes.skip(2)) supplement(lane),
    ],
  );
}
