// What the format line says, asserted rather than squinted at on a phone.
//
// The rules that matter and are easy to get wrong: a lossy stream never claims
// a bit depth, a lossless one never claims a bitrate, and the resample arrow
// appears only when the device is genuinely doing something to the audio.

import 'package:flutter_test/flutter_test.dart';
import 'package:sunoh/audio/stream_format.dart';

void main() {
  group('bit depth', () {
    test('reads mpv sample format names', () {
      expect(bitDepthForFormat('s16'), 16);
      expect(bitDepthForFormat('s16p'), 16);
      expect(bitDepthForFormat('s32'), 32);
      expect(bitDepthForFormat('u8'), 8);
    });

    test('float is not a bit depth', () {
      // ffmpeg hands back float for most lossy decoders. Calling that "32-bit"
      // would flatter an AAC stream into looking like a master.
      expect(bitDepthForFormat('float'), isNull);
      expect(bitDepthForFormat('floatp'), isNull);
      expect(bitDepthForFormat('double'), isNull);
      expect(bitDepthForFormat(null), isNull);
    });
  });

  group('lossless detection', () {
    test('recognises the codecs that carry a bit depth', () {
      expect(isLosslessCodec('flac'), isTrue);
      expect(isLosslessCodec('ALAC (Apple Lossless)'), isTrue);
      expect(isLosslessCodec('pcm_s16le'), isTrue);
    });

    test('and the ones that do not', () {
      expect(isLosslessCodec('aac'), isFalse);
      expect(isLosslessCodec('opus'), isFalse);
      expect(isLosslessCodec('mp3'), isFalse);
      expect(isLosslessCodec(null), isFalse);
    });
  });

  group('full label', () {
    test('lossless gets a bit depth and no bitrate', () {
      expect(
        streamFormatLabel(
          codec: 'flac',
          decodedFormat: 's32',
          sampleRateHz: 96000,
          outputRateHz: 96000,
          // Present, and deliberately ignored: FLAC's bitrate varies by
          // passage and says less than the bit depth does.
          bitrateBps: 2800000,
        ),
        'FLAC · 32-bit / 96 kHz',
      );
    });

    test('lossy gets a bitrate and no bit depth', () {
      expect(
        streamFormatLabel(
          codec: 'aac',
          decodedFormat: 'floatp',
          sampleRateHz: 44100,
          outputRateHz: 44100,
          bitrateBps: 256000,
        ),
        'AAC · 256 kbps / 44.1 kHz',
      );
    });

    test('the arrow appears when the device resamples', () {
      expect(
        streamFormatLabel(
          codec: 'flac',
          decodedFormat: 's32',
          sampleRateHz: 96000,
          outputRateHz: 48000,
        ),
        'FLAC · 32-bit / 96 kHz → 48 kHz',
      );
    });

    test('and not when it does not', () {
      final label = streamFormatLabel(
        codec: 'flac',
        decodedFormat: 's16',
        sampleRateHz: 44100,
        outputRateHz: 44100,
      );
      expect(label, isNot(contains('→')));
      expect(label, 'FLAC · 16-bit / 44.1 kHz');
    });

    test('nothing known yet means no line, not an empty one', () {
      expect(streamFormatLabel(codec: null), isNull);
      expect(streamFormatLabel(codec: '  '), isNull);
    });

    test('a bitrate mpv has not worked out yet is simply left off', () {
      expect(
        streamFormatLabel(
          codec: 'opus',
          decodedFormat: 'float',
          sampleRateHz: 48000,
        ),
        'Opus · 48 kHz',
      );
    });
  });

  group('compact label', () {
    test('drops the unit words', () {
      expect(
        streamFormatLabelCompact(
          codec: 'flac',
          decodedFormat: 's32',
          sampleRateHz: 96000,
          outputRateHz: 96000,
        ),
        '32/96',
      );
      expect(
        streamFormatLabelCompact(
          codec: 'aac',
          decodedFormat: 'floatp',
          sampleRateHz: 44100,
          bitrateBps: 256000,
        ),
        'AAC 256k',
      );
    });

    test('but keeps the arrow', () {
      // The one part of the line about the listener's hardware rather than the
      // file, so it survives the trim even though "kHz" does not.
      expect(
        streamFormatLabelCompact(
          codec: 'flac',
          decodedFormat: 's32',
          sampleRateHz: 96000,
          outputRateHz: 48000,
        ),
        '32/96→48',
      );
    });

    test('44.1 keeps its decimal, 48 does not gain one', () {
      expect(
        streamFormatLabelCompact(
          codec: 'flac',
          decodedFormat: 's16',
          sampleRateHz: 44100,
        ),
        '16/44.1',
      );
      expect(
        streamFormatLabelCompact(
          codec: 'flac',
          decodedFormat: 's16',
          sampleRateHz: 48000,
        ),
        '16/48',
      );
    });
  });
}
