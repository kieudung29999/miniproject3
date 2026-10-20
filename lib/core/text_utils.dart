const Map<String, String> _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _lookup = {
  for (final e in _groups.entries)
    for (final r in e.value.runes) String.fromCharCode(r): e.key,
};

/// Lowercase + bỏ dấu tiếng Việt. Độ dài chuỗi giữ nguyên (1 ký tự -> 1 ký tự)
/// nên có thể dùng chỉ số của chuỗi đã chuẩn hóa để cắt chuỗi gốc.
String removeDiacritics(String input) {
  final b = StringBuffer();
  for (final r in input.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_lookup[ch] ?? ch);
  }
  return b.toString();
}
