/// 스크래핑된 원문(HTML 엔티티·과도한 공백)을 읽기 좋게 정리한다.
///
/// 대외활동 설명은 외부 사이트에서 긁어와 `&nbsp;` 같은 HTML 엔티티와
/// 불규칙한 줄바꿈이 섞여 있어 그대로 보여주면 코드처럼 지저분해 보인다.
String cleanText(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  var s = raw;

  // 줄바꿈성 태그는 개행으로 먼저 변환(원문 줄 구조 보존)한 뒤 나머지 태그 제거
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(
      RegExp(r'</(p|div|li|ul|ol|h[1-6]|tr|blockquote)\s*>',
          caseSensitive: false),
      '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');

  // 자주 나오는 HTML 엔티티 복원
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&middot;': '·',
    '&hellip;': '…',
    '&ndash;': '–',
    '&mdash;': '—',
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));

  // 숫자/16진수 엔티티 (&#123; &#x1F600;)
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1)!);
    return code == null ? m.group(0)! : String.fromCharCode(code);
  });
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1)!, radix: 16);
    return code == null ? m.group(0)! : String.fromCharCode(code);
  });

  s = s.replaceAll(' ', ' '); // non-breaking space

  // 줄 단위로 정리: 원문 줄바꿈은 그대로 두고, 줄 내부 공백만 축소.
  //  - 불릿(•, -, · 등)만 있는 줄은 제거
  //  - 빈 줄이 연속되면 하나로 축소
  final lines = <String>[];
  for (final raw in s.split('\n')) {
    final line = raw.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (line == '•' || line == '-' || line == '·' || line == '*') continue;
    if (line.isEmpty && (lines.isEmpty || lines.last.isEmpty)) continue;
    lines.add(line);
  }
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

/// 목록/미리보기용 한 줄 요약. 줄바꿈을 공백으로 합치고 [max]자로 자른다.
String summarize(String? raw, {int max = 90}) {
  final s = cleanText(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= max) return s;
  return '${s.substring(0, max).trimRight()}…';
}
