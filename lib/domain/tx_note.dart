/// 거래 메모·태그(S9). 쓰는 필드는 `note`·`userTags`·`noteBy`(+`noteAt`, 서버 시각은 data 가 붙인다)뿐이다.
/// 원본 `src`·`cls` 는 절대 건드리지 않는다. Flutter·Firebase 를 모른다.
library;

const kNoteMaxLen = 200;
const kTagMaxLen = 20;
const kTagMaxCount = 8;

/// 태그 정리: 앞뒤 공백·`#` 제거, 빈 것·중복 제거, 길이·개수 제한. 입력 순서 유지.
List<String> normalizeTags(Iterable<String> raw) {
  final out = <String>[];
  for (var t in raw) {
    t = t.trim().replaceFirst(RegExp(r'^#+'), '').trim();
    if (t.isEmpty) continue;
    if (t.length > kTagMaxLen) t = t.substring(0, kTagMaxLen);
    if (!out.contains(t)) out.add(t);
    if (out.length >= kTagMaxCount) break;
  }
  return out;
}

/// 쉼표·공백으로 나눈 입력 문자열 → 태그.
List<String> parseTagInput(String input) => normalizeTags(input.split(RegExp(r'[,\s]+')));

/// 거래 문서에 `update()` 로 쓸 필드. `noteAt` 은 data 계층이 서버 시각으로 더한다.
Map<String, Object?> notePayload({required String note, required Iterable<String> tags, required String? by}) => {
      'note': note.trim().length > kNoteMaxLen ? note.trim().substring(0, kNoteMaxLen) : note.trim(),
      'userTags': normalizeTags(tags),
      'noteBy': ?by,
    };
