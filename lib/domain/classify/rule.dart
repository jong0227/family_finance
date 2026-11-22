/// 분류 규칙 모델 (순수 Dart — Flutter·Firebase를 모른다). 형식은 ARCHITECTURE 9.2.
///
/// 규칙 = `when`(조건, 모두 만족해야 함) + `then`(채울 필드). 규칙 목록은 **순서가 곧 우선순위**다.
library;

/// 거래 하나에서 규칙이 읽는 값 (`transactions/{key}.src` 와 같은 이름).
class ClassifyInput {
  const ClassifyInput({
    required this.date,
    required this.type,
    required this.amount,
    this.major,
    this.minor,
    this.merchant,
    this.payment,
    this.memo,
    this.accountId,
    this.cardId,
    this.tags = const [],
  });

  /// 'YYYY-MM-DD'
  final String date;

  /// 'income' | 'expense' | 'transfer' (모르는 값도 그대로 받는다)
  final String type;

  /// 원 단위 정수, 부호는 원본대로(지출 음수).
  final int amount;
  final String? major, minor, merchant, payment, memo, accountId, cardId;

  /// 거래 문서의 꼬리표(예: 쿠팡 로켓프레시 상품). 규칙 조건 `tag` 가 본다.
  final List<String> tags;

  factory ClassifyInput.fromSrc(Map<String, Object?> src, {List<String> tags = const []}) => ClassifyInput(
        date: src['date'] as String,
        type: src['type'] as String,
        amount: (src['amount'] as num).toInt(),
        major: src['major'] as String?,
        minor: src['minor'] as String?,
        merchant: src['merchant'] as String?,
        payment: src['payment'] as String?,
        memo: src['memo'] as String?,
        accountId: src['accountId'] as String?,
        cardId: src['cardId'] as String?,
        tags: tags,
      );
}

/// `when` — 있는 조건은 전부 만족해야 한다(AND). 비어 있으면 모든 거래.
/// 문자열 필드의 null 은 빈 문자열로 본다.
class RuleMatch {
  const RuleMatch({
    this.type,
    this.major,
    this.minor,
    this.merchantEquals,
    this.merchantContains,
    this.merchantStartsWith,
    this.merchantRegex,
    this.merchantRegexSource,
    this.paymentIn,
    this.paymentStartsWith,
    this.paymentContains,
    this.accountId,
    this.cardId,
    this.tag,
    this.memoContains,
    this.amountEq,
    this.amountMin,
    this.amountMax,
    this.amountAbsEq,
    this.amountAbsMin,
    this.amountAbsMax,
    this.dateFrom,
    this.dateTo,
    this.dayFrom,
    this.dayTo,
    this.kind,
    this.categoryId,
    this.oneOff,
    this.anyOf,
    this.not,
  });

  // 원본 필드 — 값 목록 중 하나와 같으면 참
  final List<String>? type, major, minor, merchantEquals, paymentIn, accountId, cardId;
  // 거래 꼬리표 중 하나라도 있으면 참
  final List<String>? tag;
  // 부분 문자열·접두어 — 목록 중 하나라도 맞으면 참 (대소문자 구분)
  final List<String>? merchantContains, merchantStartsWith, paymentStartsWith, paymentContains, memoContains;
  // 정규식 — 가맹점 문자열 어디서든 찾으면 참(앞·뒤 고정은 ^ $ 로)
  final RegExp? merchantRegex;
  final String? merchantRegexSource;
  // 금액(원, 부호 포함) / 절댓값. Min·Max 는 경계 포함.
  final int? amountEq, amountMin, amountMax, amountAbsEq, amountAbsMin, amountAbsMax;
  // 날짜 'YYYY-MM-DD' 경계 포함, 일(1~31) 경계 포함
  final String? dateFrom, dateTo;
  final int? dayFrom, dayTo;
  // 지금까지 정해진 결과를 보는 조건(앞선 규칙이 채운 값). 아직 안 정해졌으면 kind·categoryId 는 거짓, oneOff 는 false 로 본다.
  final List<String>? kind, categoryId;
  final bool? oneOff;
  // 하나라도 맞으면 참 / 맞으면 거짓
  final List<RuleMatch>? anyOf;
  final RuleMatch? not;

  bool get isEmpty =>
      type == null &&
      major == null &&
      minor == null &&
      merchantEquals == null &&
      merchantContains == null &&
      merchantStartsWith == null &&
      merchantRegex == null &&
      paymentIn == null &&
      paymentStartsWith == null &&
      paymentContains == null &&
      accountId == null &&
      cardId == null &&
      tag == null &&
      memoContains == null &&
      amountEq == null &&
      amountMin == null &&
      amountMax == null &&
      amountAbsEq == null &&
      amountAbsMin == null &&
      amountAbsMax == null &&
      dateFrom == null &&
      dateTo == null &&
      dayFrom == null &&
      dayTo == null &&
      kind == null &&
      categoryId == null &&
      oneOff == null &&
      anyOf == null &&
      not == null;
}

/// `then` — 키가 있으면(값이 null 이어도) 그 필드를 채운다. null 로 채우면 "없음으로 확정".
class RuleThen {
  const RuleThen({
    this.setKind = false,
    this.kind,
    this.setCategoryId = false,
    this.categoryId,
    this.setLiving = false,
    this.living,
    this.setOneOff = false,
    this.oneOff,
  });

  final bool setKind, setCategoryId, setLiving, setOneOff;
  final String? kind, categoryId, living;
  final bool? oneOff;
}

class ClassifyRule {
  const ClassifyRule({
    required this.id,
    required this.match,
    required this.then,
    this.override = false,
    this.priority = 0,
    this.enabled = true,
    this.note,
  });

  final String id;
  final RuleMatch match;
  final RuleThen then;

  /// true 면 일반 규칙이 이미 채운 값도 덮어쓴다(다른 덮어쓰기 규칙이 채운 값은 못 덮는다).
  final bool override;

  /// 클수록 먼저. 같으면 목록 순서.
  final int priority;
  final bool enabled;
  final String? note;
}

/// 규칙 한 벌. 순서가 의미를 가진다.
class RuleSet {
  const RuleSet({required this.rules, this.consumptionKind = 'spend', this.version = 1});

  final int version;

  /// 집계에서 "소비"로 치는 kind 값(사용자 분류 체계의 이름 그대로).
  final String consumptionKind;
  final List<ClassifyRule> rules;
}
