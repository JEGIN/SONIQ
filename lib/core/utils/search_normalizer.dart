/// Search-only Unicode normalization. It lowercases text and decomposes common
/// precomposed Latin accents into base letters plus combining marks. Marks and
/// language-specific letters are preserved, so ñ, ç, Tamil, Arabic, and other
/// scripts do not collapse into unrelated spellings. Stored metadata is never
/// modified.
class SearchNormalizer {
  SearchNormalizer._();

  static const _decomposition = <int, String>{
    0x00E0: 'a\u0300',
    0x00E1: 'a\u0301',
    0x00E2: 'a\u0302',
    0x00E3: 'a\u0303',
    0x00E4: 'a\u0308',
    0x00E5: 'a\u030A',
    0x0101: 'a\u0304',
    0x0103: 'a\u0306',
    0x0105: 'a\u0328',
    0x00E7: 'c\u0327',
    0x0107: 'c\u0301',
    0x0109: 'c\u0302',
    0x010B: 'c\u0307',
    0x010D: 'c\u030C',
    0x010F: 'd\u030C',
    0x0111: 'd\u0335',
    0x00E8: 'e\u0300',
    0x00E9: 'e\u0301',
    0x00EA: 'e\u0302',
    0x00EB: 'e\u0308',
    0x0113: 'e\u0304',
    0x0115: 'e\u0306',
    0x0117: 'e\u0307',
    0x0119: 'e\u0328',
    0x011B: 'e\u030C',
    0x00EC: 'i\u0300',
    0x00ED: 'i\u0301',
    0x00EE: 'i\u0302',
    0x00EF: 'i\u0308',
    0x0129: 'i\u0303',
    0x012B: 'i\u0304',
    0x012D: 'i\u0306',
    0x012F: 'i\u0328',
    0x00F1: 'n\u0303',
    0x0144: 'n\u0301',
    0x0146: 'n\u0327',
    0x0148: 'n\u030C',
    0x00F2: 'o\u0300',
    0x00F3: 'o\u0301',
    0x00F4: 'o\u0302',
    0x00F5: 'o\u0303',
    0x00F6: 'o\u0308',
    0x014D: 'o\u0304',
    0x014F: 'o\u0306',
    0x0151: 'o\u030B',
    0x0155: 'r\u0301',
    0x0157: 'r\u0327',
    0x0159: 'r\u030C',
    0x015B: 's\u0301',
    0x015D: 's\u0302',
    0x015F: 's\u0327',
    0x0161: 's\u030C',
    0x00F9: 'u\u0300',
    0x00FA: 'u\u0301',
    0x00FB: 'u\u0302',
    0x00FC: 'u\u0308',
    0x0169: 'u\u0303',
    0x016B: 'u\u0304',
    0x016D: 'u\u0306',
    0x016F: 'u\u030A',
    0x0171: 'u\u030B',
    0x0173: 'u\u0328',
    0x00FD: 'y\u0301',
    0x00FF: 'y\u0308',
    0x0177: 'y\u0302',
    0x017A: 'z\u0301',
    0x017C: 'z\u0307',
    0x017E: 'z\u030C',
  };

  static String normalize(String value) {
    final lower = value.toLowerCase();
    return String.fromCharCodes(_expand(lower.runes));
  }

  static Iterable<int> _expand(Iterable<int> codePoints) sync* {
    for (final codePoint in codePoints) {
      final decomposed = _decomposition[codePoint];
      if (decomposed == null) {
        yield codePoint;
      } else {
        yield* decomposed.runes;
      }
    }
  }
}
