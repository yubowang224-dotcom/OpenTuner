enum ReadingSource { none, demonstration, microphone }

enum PitchValidity { noSignal, uncertain, valid }

/// The presentation boundary, not an audio estimator or a pitch tracker.
/// Stage 2 adapts accepted DSP results to [GaugeReading.tracked].
/// Raw Hz, tracked Hz, confidence and capture timestamps belong to that adapter.
class GaugeReading {
  const GaugeReading.waiting()
    : source = ReadingSource.none,
      validity = PitchValidity.noSignal,
      note = null,
      cents = null;
  const GaugeReading.uncertain()
    : source = ReadingSource.microphone,
      validity = PitchValidity.uncertain,
      note = null,
      cents = null;
  GaugeReading.demonstration({required String note, required double cents})
    : this._valid(ReadingSource.demonstration, note, cents);

  /// Use cents relative to actual target Hz, including non-ET piano curves.
  GaugeReading.tracked({required String note, required double cents})
    : this._valid(ReadingSource.microphone, note, cents);
  GaugeReading._valid(this.source, this.note, this.cents)
    : validity = PitchValidity.valid {
    if (!cents!.isFinite || note!.isEmpty) {
      throw ArgumentError(
        'A valid presentation needs a note and finite cents.',
      );
    }
  }
  final ReadingSource source;
  final PitchValidity validity;
  final String? note;
  final double? cents;
  bool get isValid => validity == PitchValidity.valid;
}
