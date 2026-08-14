/// 스크래핑된 원문(HTML 엔티티·과도한 공백)을 읽기 좋게 정리한다.
///
/// 대외활동 설명은 외부 사이트에서 긁어와 `&nbsp;` 같은 HTML 엔티티와
/// 불규칙한 줄바꿈이 섞여 있어 그대로 보여주면 코드처럼 지저분해 보인다.
String cleanText(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  var s = raw;

  // 남은 HTML 태그 제거
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');

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

  // 줄바꿈 주변 공백 제거
  s = s.replaceAll(RegExp(r'[ \t]*\n[ \t]*'), '\n');

  // 문단(빈 줄로 구분) 단위로 재구성:
  //  - 문단 내부의 단일 줄바꿈은 문장이 잘린 것이므로 공백으로 합친다
  //  - 불릿(•, -, · 등)만 있고 내용이 다음 줄에 있던 경우 자연히 "• 내용"으로 붙는다
  final paragraphs = s
      .split(RegExp(r'\n{2,}'))
      .map((p) => p.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((p) => p.isNotEmpty && p != '•' && p != '-' && p != '·')
      .toList();

  return paragraphs.join('\n\n');
}

/// 목록/미리보기용 한 줄 요약. 줄바꿈을 공백으로 합치고 [max]자로 자른다.
String summarize(String? raw, {int max = 90}) {
  final s = cleanText(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= max) return s;
  return '${s.substring(0, max).trimRight()}…';
}
