class TypeSettings {
  static const String family = 'Onest';

  static String cased(String text) => text;

  static String caps(String text) => text.toUpperCase();
}

extension CasedText on String {
  String get cased => TypeSettings.cased(this);
}
