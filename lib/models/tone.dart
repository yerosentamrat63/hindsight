/// The three voices the app can speak in.
enum Tone { coach, roast, future }

extension ToneX on Tone {
  String get id => name;

  String get label => switch (this) {
    Tone.coach => 'Gentle coach',
    Tone.roast => 'Brutal roast',
    Tone.future => 'Future you',
  };

  String get blurb => switch (this) {
    Tone.coach =>
      'You have more time than you think. Here is what it could build.',
    Tone.roast =>
      'Three hours of strangers dancing. Your portfolio sends its regards.',
    Tone.future =>
      'I am you in five years. Remember that thing you stopped building?',
  };

  static Tone parse(String? s) {
    switch (s) {
      case 'coach':
        return Tone.coach;
      case 'future':
        return Tone.future;
      default:
        return Tone.roast;
    }
  }
}
