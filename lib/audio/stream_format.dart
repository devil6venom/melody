// What is actually being decoded, written the way a listener would read it.
//
// Pure Dart on purpose — no Flutter, no player — so the strings can be
// asserted in a unit test instead of squinted at on a phone.
//
// ## Why this shows something for every stream
//
// The quality tag used to render only when the audio was lossless, on the
// argument that "am I getting what I turned on" is answered by silence the
// rest of the time. That reads well until you are the person holding the
// phone: a YouTube track showed nothing at all, which is indistinguishable
// from the tag being broken.
//
// So every stream gets a line, and the line says the true thing about *that*
// stream — a bitrate for a lossy one, a bit depth for a lossless one, and
// never both. AAC has no bit depth worth printing; the decoder's output format
// is an implementation detail of ffmpeg, not a property of the file.
//
// ## The arrow
//
// Android will accept a 96 kHz stream and open its AudioTrack at 48 kHz,
// resampling on the way. Reporting the decoder's rate alone would be the truth
// about the file and a lie about the sound, so when the device does that the
// line says so: `24-bit / 96 kHz -> 48 kHz`. That is the honest version of
// "hi-res needs hardware that can play it" — the phone tells you itself.

/// Bit depth implied by an mpv sample format name (`s16`, `s32p`, `float`…).
///
/// Null for float and for anything unrecognised. Float is what ffmpeg hands
/// back for most lossy decoders and says nothing about the source, so calling
/// it "32-bit" would flatter an AAC stream into looking like a master.
int? bitDepthForFormat(String? mpvFormat) {
  if (mpvFormat == null) return null;
  final name = mpvFormat.toLowerCase();
  if (name.startsWith('float') || name.startsWith('double')) return null;
  if (name.startsWith('u8')) return 8;
  if (name.startsWith('s16')) return 16;
  if (name.startsWith('s24')) return 24;
  if (name.startsWith('s32')) return 32;
  return null;
}

/// Codecs whose output is bit-exact, so a bit depth is a fact about the file.
const Set<String> kLosslessCodecs = {
  'flac',
  'alac',
  'wav',
  'pcm',
  'ape',
  'wavpack',
  'tta',
};

/// True when [codec] names a lossless format.
bool isLosslessCodec(String? codec) {
  if (codec == null) return false;
  final c = codec.toLowerCase();
  return kLosslessCodecs.any(c.contains);
}

/// A display name for a codec: `flac` -> `FLAC`, `aac` -> `AAC`.
String prettyCodec(String raw) {
  final first = raw.trim().split(RegExp(r'[\s(]')).first.toLowerCase();
  return switch (first) {
    'alac' => 'ALAC',
    'aac' || 'aac_latm' => 'AAC',
    'opus' => 'Opus',
    'vorbis' => 'Vorbis',
    'mp3' || 'mp3float' => 'MP3',
    'pcm' => 'PCM',
    _ => first.toUpperCase(),
  };
}

/// Sample rate as kHz, trimmed: 44100 -> `44.1 kHz`, 48000 -> `48 kHz`.
String prettyRate(int hz) {
  final khz = hz / 1000;
  final text = khz == khz.roundToDouble()
      ? khz.toStringAsFixed(0)
      : khz.toStringAsFixed(1);
  return '$text kHz';
}

/// One line describing the stream, or null when nothing is known yet.
///
/// [decodedFormat] and [outputRateHz] describe the decoder and the audio
/// device respectively; when the two rates disagree the device is resampling
/// and the line says so.
String? streamFormatLabel({
  String? codec,
  String? decodedFormat,
  int? sampleRateHz,
  int? outputRateHz,
  double? bitrateBps,
}) {
  final raw = codec?.trim();
  if (raw == null || raw.isEmpty) return null;

  final parts = <String>[prettyCodec(raw)];
  final lossless = isLosslessCodec(raw);

  if (lossless) {
    final depth = bitDepthForFormat(decodedFormat);
    if (depth != null) parts.add('$depth-bit');
  } else {
    // Rounded to the nearest kbps and only when mpv has a figure — an
    // encoder's nominal rate is not something the file carries, so this is
    // measured and appears a second or two into playback.
    final kbps = bitrateBps == null ? null : (bitrateBps / 1000).round();
    if (kbps != null && kbps > 0) parts.add('$kbps kbps');
  }

  if (sampleRateHz != null && sampleRateHz > 0) {
    final rate = prettyRate(sampleRateHz);
    // Only when the device is actually doing something different. Equal rates
    // are the normal case and an arrow pointing at the same number is noise.
    parts.add(
      outputRateHz != null && outputRateHz > 0 && outputRateHz != sampleRateHz
          ? '$rate → ${prettyRate(outputRateHz)}'
          : rate,
    );
  }

  if (parts.length == 1) return parts.first;
  // The codec is separated from the numbers, the numbers from each other, the
  // way a spec sheet reads: `FLAC · 24-bit / 96 kHz`.
  return '${parts.first} · ${parts.skip(1).join(' / ')}';
}

/// The same facts, shortened for the mini player.
///
/// `24/96`, `AAC 256k`, and `24/96→48` when the device resamples. The mini
/// player gives this a share of one line next to the artist's name, so every
/// character costs someone else's — the unit words go, and the bit depth and
/// rate are set against each other the way a spec is spoken aloud.
///
/// The resample arrow survives the trim on purpose. It is the one part of this
/// line that says something about the listener's own hardware rather than the
/// file, and that is worth more than the word "kHz".
String? streamFormatLabelCompact({
  String? codec,
  String? decodedFormat,
  int? sampleRateHz,
  int? outputRateHz,
  double? bitrateBps,
}) {
  final raw = codec?.trim();
  if (raw == null || raw.isEmpty) return null;

  final resampled =
      sampleRateHz != null &&
      outputRateHz != null &&
      outputRateHz > 0 &&
      outputRateHz != sampleRateHz;
  final tail = resampled ? '→${(outputRateHz / 1000).round()}' : '';

  if (isLosslessCodec(raw)) {
    final depth = bitDepthForFormat(decodedFormat);
    final khz = sampleRateHz == null ? null : sampleRateHz / 1000;
    if (depth == null && khz == null) return null;
    final rate = khz == null
        ? ''
        : (khz == khz.roundToDouble()
              ? khz.toStringAsFixed(0)
              : khz.toStringAsFixed(1));
    if (depth == null) return '$rate$tail';
    return rate.isEmpty ? '$depth-bit' : '$depth/$rate$tail';
  }

  final kbps = bitrateBps == null ? null : (bitrateBps / 1000).round();
  final name = prettyCodec(raw);
  if (kbps == null || kbps <= 0) return '$name$tail';
  return '$name ${kbps}k$tail';
}
