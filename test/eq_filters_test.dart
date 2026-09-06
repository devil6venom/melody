// The EQ's contract: off means untouched, on means the curve you asked for,
// and never loud enough to clip.
//
// These exist because the bug they cover was inaudible as a bug — it just
// sounded like a bad equaliser. A listener reported "increasing mid and
// diminishing highs"; the numbers below are what that complaint looks like
// written down, and what it looks like fixed.

import 'package:flutter_test/flutter_test.dart';
import 'package:sunoh/audio/eq_filters.dart';

/// Treble Boost — the preset the original report was made against.
const trebleBoost = <double>[0, 0, 0, 0, 2, 4, 6, 8, 9, 7];
const vocalClarity = <double>[-3, -2, 2, 6, 7, 6, 5, 3, 1, -1];
const electronic = <double>[6, 5, 2, 0, 1, 3, 4, 6, 8, 6];

void main() {
  group('bypass', () {
    test('a flat EQ emits no filters at all', () {
      expect(buildEqFilters(List<double>.filled(10, 0)), isEmpty);
    });

    test('a band below the epsilon still counts as flat', () {
      final gains = List<double>.filled(10, 0.0)..[3] = 0.0005;
      expect(buildEqFilters(gains), isEmpty);
    });

    test('one real band is enough to engage the chain', () {
      final gains = List<double>.filled(10, 0.0)..[3] = 3;
      expect(buildEqFilters(gains), isNotEmpty);
    });
  });

  group('accuracy', () {
    // Before the fix these errors were +3.35 dB at 4 kHz and -2.66 dB at
    // 16 kHz. Half a dB is below what anyone can hear on a band.
    for (final (name, preset) in [
      ('treble boost', trebleBoost),
      ('vocal clarity', vocalClarity),
      ('electronic', electronic),
    ]) {
      test('$name lands on its curve within 0.5 dB', () {
        final delivered = deliveredResponseDb(preset);
        // The preamp shifts the whole curve down for headroom, so it is the
        // *shape* that must match — level is the next test's business.
        final offset = delivered[0] - preset[0];
        for (var i = 0; i < preset.length; i++) {
          expect(
            delivered[i] - offset,
            closeTo(preset[i], 0.5),
            reason:
                '${kEqFrequencies[i]} Hz: asked ${preset[i]}, '
                'got ${(delivered[i] - offset).toStringAsFixed(2)}',
          );
        }
      });

      test('$name asks for headroom, but not the worst case', () {
        // Between nothing and the true peak. Nothing was the original bug —
        // ten boosts stacking with no room, clipping loud masters. The peak
        // was yesterday's overcorrection, costing 7-12 dB on every track and
        // reported by a listener as the volume being broken.
        final preamp = eqPreampDb(preset);
        expect(preamp, greaterThan(1.0), reason: 'a boosted curve needs room');
        expect(
          preamp,
          lessThan(6.0),
          reason: 'not the pathological worst case',
        );
      });
    }

    test('highs are no longer swallowed relative to mids', () {
      // The exact complaint: mids up, highs down. Measured against what was
      // asked for, the top band must not come out worse than the mids.
      final d = deliveredResponseDb(trebleBoost);
      final offset = d[0] - trebleBoost[0];
      final midErr = (d[7] - offset) - trebleBoost[7]; // 4 kHz
      final topErr = (d[9] - offset) - trebleBoost[9]; // 16 kHz
      expect(midErr.abs(), lessThan(0.5));
      expect(topErr.abs(), lessThan(0.5));
    });
  });

  group('filter strings', () {
    test('shelves at the ends, peaking in between, and nothing else', () {
      final f = buildEqFilters(trebleBoost);
      // The preamp is not a filter — it goes to mpv's `volume-gain` property,
      // so the chain is exactly ten bands and nothing else. Pinned because a
      // filter mpv rejects takes the whole chain, and playback, with it.
      expect(f, hasLength(10));
      expect(f.first, startsWith('lavfi-bass=f=31:'));
      expect(f.last, startsWith('lavfi-treble=f=16000:'));
      expect(f.where((s) => s.startsWith('lavfi-equalizer=')), hasLength(8));
    });

    test('a cut-only curve needs no preamp', () {
      expect(eqPreampDb(List<double>.filled(10, -3.0)), lessThan(0.01));
    });

    test('a boosted curve reports the headroom it needs', () {
      // Load-bearing: this goes straight to `setVolumeGain`, so understating
      // it clips and overstating it is loudness thrown away for nothing.
      // Pink-weighted, so ~4 dB where the peak of this curve is ~12.
      expect(eqPreampDb(trebleBoost), closeTo(4.2, 0.4));
      expect(eqPreampDb(List<double>.filled(10, 0)), 0);
    });
  });
}
