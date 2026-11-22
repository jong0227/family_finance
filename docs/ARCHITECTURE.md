# 아키텍처

> 이 문서는 "어디에 무엇을 두는가"와 "왜 그렇게 했는가"를 정한다.
> 새 기능을 붙이기 전에 읽고, 규칙을 바꿔야 하면 코드보다 이 문서를 먼저 고친다.
>
> 이 앱은 자매 앱 두 개 위에 선다.
> - `family_timetable`(가족 시간표): 계층·의존 방향, "화면은 data 직접 import 금지", 권한 한 곳, 스키마 버전 절차, GitHub 릴리스 + 앱 안 업데이트.
> - `Ninedogs`(구독 관리, 공개 저장소): **기술 스택의 기준**(Riverpod 3, 코드 생성 없음, 돈은 int, 파일은 Android 인텐트)이고,
>   **Firebase 프로젝트·가구(household)·초대 코드·구독/계정/금고 문서를 같이 쓰는 이웃 앱**이다.
>   Ninedogs 앱은 계속 살아 있고, 구독은 **양쪽 어디서 고쳐도 서로 반영**된다(15장).

**공개 저장소다.** 이 문서와 코드, 테스트 어디에도 실명·계좌번호·카드번호·실제 금액·우리 집 가맹점 규칙·알림 원문을 쓰지 않는다.
예시는 전부 지어낸 값이다("OO마트", "가나다카드", 12,340원). 개인 데이터는 Firebase와 폰 안에만 있다. → 20장 체크리스트.

---

## 1. 제품 원칙 (모든 결정의 기준)

1. **총액은 절대 안 바뀐다.** 재분류·쿠팡 쪼개기·할부 나누기·환불 상계는 "어디에 썼나"만 바꾼다.
   한 달 결제 합계는 원본(뱅크샐러드)과 항상 1원까지 같아야 한다(테스트로 강제).
2. **원본은 고치지 않는다.** 뱅크샐러드에서 온 값(날짜·금액·가맹점·결제수단)은 읽기 전용이다.
   우리 판단(kind·분류·항목·일회성·할부·구독 연결)은 원본 옆 별도 필드에 쌓는다.
3. **남의 문서에 내 필드를 넣지 않는다.** 구독·계정·금고·가구 문서는 Ninedogs 계약(5.4)이 정한 모양 그대로만 쓴다.
   가계 쪽 확장 정보는 옆 문서(`subscriptionLinks` 등)에 둔다.
4. **확정 원본은 뱅크샐러드, 속보는 알림.** 카드·은행 알림으로 만든 거래는 "임시"다. 뱅크샐러드 내보내기가 오면 대조해 확정하거나 버린다(12장).
5. **한 번 답한 건 다시 묻지 않는다.** 확인 질문의 답은 규칙으로 저장된다. 질문은 한 번에 하나, 금액이 큰 것부터.
6. **"무엇에 썼나"가 "어느 카드로 냈나"보다 중요하다.** 첫 화면은 항목별 계획 대비 실제. 카드·통장은 결제일 현금 점검에서.
7. **부부가 같은 화면을 본다.** 한쪽이 고치면 다른 폰에 바로 보인다. 누가 바꿨는지 남긴다.
8. **되돌릴 수 있다.** 가져오기는 통째로 되돌릴 수 있고, 지우기는 표시(soft delete)가 기본이다.
9. **돈은 정수다.** 금액은 통화 최소 단위 `int`. double 금지. 통화가 다르면 합치지 않는다(Ninedogs `Money`).
10. **무료로 돈다.** Firebase Spark(무료) 요금제 안에서. Cloud Functions·Storage를 쓰지 않는다(14장).
11. **개인 정보는 최소한만, 원문은 안 남긴다.** 알림 원문·캡처 이미지는 폰에서 읽고 버린다. 전체 계좌번호는 입력 칸조차 없다.

---

## 2. 기술 스택 결정 — Ninedogs 기준으로 맞춘다

| 항목 | family_timetable | Ninedogs | **family_finance** | 이유 |
|---|---|---|---|---|
| Firebase 프로젝트 | kids-allowance-48c8e | ninedogs-b2628 | **ninedogs-b2628 (같이 씀)** | 가구·초대 코드·구독/금고 데이터를 제자리에서 공유(사용자 결정, 15장). 안드로이드 앱만 추가 등록 |
| 상태 관리 | Riverpod 2.6.1 | Riverpod 3 | **Riverpod 3 (^3.5.0), 코드 생성 없음** | 공유·이식할 코드가 많은 쪽(Ninedogs: 구독·금고·알림·백업, 테스트 97개)이 3이다. 3의 "안 보이는 화면 구독 일시정지"는 Firestore 읽기 비용에도 유리 |
| 코드 생성 | 없음 | 없음(`custom_lint`·`riverpod_lint` 충돌로 뺌) | **없음** | 손으로 쓴 모델·`fromJson`. 빌드 단계가 없어 PC 두 대에서 같은 결과 |
| 공유 코드 | — | 앱 안 | **`ninedogs_core` 패키지(git 의존성)** | 같은 문서를 두 앱이 쓰므로 모델·직렬화·암호화가 한 벌이어야 한다(5.5) |
| 돈 | int(원) | `Money(minor, currency)` | **`Money` (ninedogs_core)** | 통화가 섞이면 던진다(릴리스에서 assert가 사라져 13,500원 + $1.00 = 13,501원이 된 Ninedogs 버그 교훈) |
| 파일 받기 | — | **Android 인텐트**(`file_picker`는 `share_plus`·`package_info_plus`와 win32 충돌) | **Android 인텐트** | xlsx·JSON·캡처를 ① 다른 앱에서 "공유"로 ② 앱 안 시스템 문서 선택기(`ACTION_OPEN_DOCUMENT`)로. 뱅크샐러드·카톡에서 바로 보낼 수 있어 오히려 편하다 |
| 로그인 | 익명 | 익명 | **구글 로그인** | 돈 데이터. 재설치해도 uid 유지. 가계 데이터 규칙이 "구글 로그인한 가계 구성원"을 요구한다(6.3). Ninedogs는 익명 그대로 |
| 내비게이션 | 기본 Navigator | 기본 Navigator | 기본 Navigator | |
| 로컬 저장 | 파일 JSON | SharedPreferences(로컬 우선, 동기화 옵트인) | **Firestore 오프라인 캐시 + SharedPreferences(이 폰 설정만)** | 가계 데이터는 처음부터 공유 전제. 로컬 전용 모드는 테스트·웹 미리보기용 메모리 저장소만 |
| 배포 | GitHub 릴리스, split arm64 | GitHub 릴리스 + Play flavor, split 안 함 | **GitHub 릴리스, arm64 APK 1개만** | 용량 + "자산이 여럿이면 업데이터가 엉뚱한 걸 받는다" 문제 둘 다 피함. Play 배포 안 함(알림 접근·자체 업데이트 정책) |

Riverpod 3에서 지킬 것(Ninedogs에서 배운 것 포함):
- `AsyncNotifier`의 변경 메서드는 **`await future`로 시작**(build가 늦게 끝나 변경을 덮어쓴 Ninedogs 온보딩 버그).
- `await` 뒤 `if (!ref.mounted) return;`.
- 기본 자동 재시도가 `permission-denied`를 반복 호출하지 않게 `ProviderScope(retry: …)`로 권한·형식 오류는 재시도 안 함.
- provider 본문은 결정적(rebuild마다 UUID를 새로 만들던 Ninedogs 버그).

---

## 3. 계층

```
lib/
├─ main.dart             시작점: Bootstrap → ProviderScope → App
├─ app/                  앱 조립(틀, 세션, Provider). 기능 간 연결은 여기서만.
│  ├─ app.dart           MaterialApp, 탭 틀(탭 구성은 DESIGN_SYSTEM에서 정함 — 이 문서는 탭 수와 무관)
│  ├─ bootstrap.dart     prefs, Firebase, 오프라인 캐시, 알림 채널, 인텐트로 들어온 파일
│  ├─ session.dart       uid, householdId, 가계 구성원 여부
│  └─ providers/         화면이 읽는 모든 상태(기능별 파일)
├─ core/
│  ├─ design/            디자인 토큰·테마·공용 컴포넌트(ServiceIcon은 ninedogs_core/ui에서)
│  └─ format/            원화·날짜 표시
├─ domain/               순수 Dart. Flutter·Firebase를 모른다. PC CLI(tool/)도 그대로 쓴다.
│  ├─ models/            Transaction, LiveTx, PlanVersion, Card, Account, Balance, Rule, Question, ImportRun,
│  │                     NotificationTemplate, SubscriptionLink
│  ├─ subscriptions/     구독 ↔ 거래 매칭·감시(10장). 구독 모델 자체는 ninedogs_core
│  ├─ tx_key.dart        거래 키(7장)
│  ├─ classify/          분류 엔진(9장)
│  ├─ live/              알림 템플릿 적용(Dart판), 임시 거래 ↔ 뱅크샐러드 대조(12장)
│  ├─ coupang/           OCR 줄 → 주문, 여러 캡처 합치기, 결제 맞춰 쪼개기(11장)
│  ├─ summary/           월 집계·할부·일회성·진단(13장)
│  ├─ billing.dart       카드 결제일·영업일·결제일 현금 점검
│  ├─ diff.dart          가져오기 비교·수정 추정 짝짓기(8장)
│  └─ permissions.dart   권한 정책
├─ ingest/               순수 Dart 파서(Flutter 금지, CLI도 씀)
│  ├─ xlsx_reader.dart   최소 xlsx 읽기(archive + xml)
│  ├─ banksalad.dart     "가계부 내역" 시트 → RawRow
│  └─ import_bundle.dart 가져오기 묶음 JSON(PC ↔ 앱 공통)
├─ data/                 저장·플랫폼. domain·ingest·ninedogs_core만 안다.
│  ├─ firestore_paths.dart     컬렉션 경로 상수(한 곳)
│  ├─ household_store.dart     Firestore + 메모리 구현
│  ├─ finance_repository.dart  거래·분류·질문·계획을 바꾸는 유일한 입구
│  ├─ shared/            **Ninedogs 공유 문서 쓰기 전용 입구**: SharedSubscriptionStore, SharedVaultStore, SharedHouseholdStore,
│  │                     ContractGuard(5.6). 여기 말고 어디서도 subscriptions·credentials·meta·households 문서를 쓰지 않는다
│  ├─ import_service.dart      가져오기 파이프라인(8장)
│  ├─ summary_service.dart     월 집계 재계산 + 낙관적 잠금(13장)
│  ├─ live/              알림 리스너 채널(권한 상태·템플릿 전달·학습 모드), 잔액 입력
│  ├─ ocr_service.dart   빈 줄 기준 자르기 + ML Kit 한국어
│  ├─ intents/           파일 받기 채널(xlsx·json·image)
│  ├─ notifications/     로컬 알림(카드 결제일·D-3 잔액 입력·(선택) 구독 결제 예정)
│  ├─ vault/             생체인증 게이트(키 보관은 이 앱 전용), 금고 잠금 상태
│  ├─ catalog_aliases.dart  카탈로그 서비스 → 카드 명세서 가맹점 별칭(가계 전용, 공개 정보만)
│  ├─ backup/            가계 데이터 내보내기/복원
│  ├─ auth_service.dart  구글 로그인
│  └─ update_service.dart  GitHub 릴리스 확인
└─ features/<기능>/      화면. 기능 하나 = 폴더 하나.
   home/ transactions/ trends/ plan/ cards/ cash_check/ subscriptions/ vault/ import/ coupang/
   questions/ live_setup/ household/ onboarding/ settings/ update/
android/app/src/main/kotlin/…/
├─ MainActivity.kt       인텐트 수신(VIEW/SEND/SEND_MULTIPLE)
└─ live/                 FinanceNotificationListener, TemplateMatcher, LiveWriter(Firestore 쓰기)
tool/
├─ import_cli.dart       PC: xlsx → 가져오기 묶음 JSON
├─ fake_data.dart        가짜 xlsx·OCR 텍스트·알림 문구 생성기
├─ holidays/             공휴일 표 → assets/holidays_kr.json
└─ hooks/pre-commit      개인정보 검사(20장)
firestore.rules          **프로젝트 ninedogs-b2628 규칙의 단일 원본**(6.4)
test_rules/              규칙 테스트(가계 + Ninedogs 동작 시나리오)
```

외부 의존: `ninedogs_core`(Ninedogs 저장소 `packages/ninedogs_core`, git 의존성, 태그 고정) — 5.5.

### 의존 방향 (한 방향만)
```
features ──▶ app/providers ──▶ data ──▶ ingest ──▶ domain ──▶ ninedogs_core(model)
    │                                                ▲
    └──────────▶ core/design ──▶ ninedogs_core(ui) ──┘
tool/ (CLI) ─────────────────────────▶ ingest ──▶ domain
android/live (Kotlin) ── 템플릿 규격·liveTx 스키마를 Dart와 적합성 테스트로 묶음(12.4)
```
- `domain/`: `collection`, `crypto`, `meta`, `package:ninedogs_core/model.dart`만. Flutter·Firebase 금지.
- `ingest/`: `domain` + `archive`, `xml`만.
- `features/`는 `data/`·`ingest/`를 **직접 import 하지 않는다.** 읽기는 Provider, 쓰기는 리포지토리 Provider.
- 공유 문서(구독·계정·금고·가구)는 `data/shared/`만 쓴다.
- `test/architecture_test.dart`가 import 줄을 읽어 위 규칙과 "`data/shared/` 밖에서 공유 경로 상수 사용 금지"를 검사한다.

---

## 4. 상태 관리 (Riverpod 3, 손으로 쓴 provider)

- 세션: `sessionProvider`(Notifier) — uid, householdId, `isFinanceMember`, 계약 상태(읽기 전용 여부).
- 읽기(스트림): `householdProvider`, `financeMetaProvider`, `planProvider(month)`, `cardsProvider`, `accountsProvider`,
  `monthSummaryProvider(month)`, `monthTransactionsProvider(month)`, `liveTxProvider`,
  `subscriptionsProvider`(공유 문서), `subscriptionLinksProvider`, `openQuestionsProvider`, `importRunsProvider`, `vaultProvider`.
  **화면에서 스트림을 직접 만들지 않는다.**
- 파생 계산: `planVsActualProvider(month)`, `trendProvider(itemId)`, `diagnosisProvider`, `cashCheckProvider(payDate)`,
  `subscriptionSpendProvider(subId)`(계산값 + 실제 결제).
- 쓰기: `ref.read(financeRepositoryProvider)`, 구독은 `ref.read(sharedSubscriptionStoreProvider)`. "누가"는 리포지토리가 채운다.
- 오래 걸리는 작업(가져오기·OCR): `AsyncNotifier` 컨트롤러.

---

## 5. Firestore 데이터 설계

### 5.1 비용 기준 (Spark 무료 한도)
하루 읽기 50,000 / 쓰기 20,000 / 삭제 20,000, 저장 1 GiB, 문서 1 MiB, 배치 500건. **Ninedogs와 한도를 나눠 쓴다**(Ninedogs 사용량은 작다).
가정: 한 달 거래 300~600건, 1년 약 6,000건, 알림 거래 하루 수십 건, 사용자 2명.

| 화면/작업 | 원본을 읽으면 | 이 설계 |
|---|---|---|
| 홈(이번 달 계획 대비 실제) | 월 500 | **월 집계 1문서** + 계획 1문서 |
| 12개월 추이 | 6,000 | **월 집계 12문서** |
| 1년치 재가져오기 비교 | 6,000 | **월 색인 12문서** |
| 거래 목록(한 달) | 월 500 | 그대로(오프라인 캐시로 재방문은 변경분만) |
| 구독 목록 | 수십 | 그대로(Ninedogs와 같은 컬렉션) |
원칙: **목록은 원본, 숫자는 집계.** 집계는 캐시라 언제든 다시 만든다.

### 5.2 컬렉션 구조와 소유권
```
households/{hid}                        [N] 가구 (Ninedogs 모양 그대로: inviteCode, memberUids, createdAt)
  subscriptions/{subId}                 [N] 구독
  credentials/{subId}                   [N] 금고 암호문
  meta/vault                            [N] 금고 salt·검증값
  meta/contract                         [C] 공유 계약 버전(5.6)
  meta/clients                          [C] 이 가구에 붙은 앱·버전(5.6)
  financeMeta/root                      [F] 가계 루트: 가계 구성원·설정·스키마 버전
  financeMembers/{uid}                  [F] 가계 구성원 프로필
  subscriptionLinks/{subId}             [F] 구독의 가계 확장(카드·계획 항목·매칭)
  planVersions/{YYYY-MM}                [F] 계획 한 벌(구분→분류→항목)
  accounts/{accountId}                  [F] 통장(별칭) + 최근 잔액
    balanceLog/{autoId}                 [F] 잔액 기록
  cards/{cardId}                        [F] 카드
  transactions/{txKey}                  [F] 뱅크샐러드 거래 + 우리 판단
  liveTx/{liveId}                       [F] 알림 임시 거래
  notificationTemplates/{id}            [F] 알림 파서 템플릿
  txIndex/{YYYY-MM}                     [F] 월 색인
  months/{YYYY-MM}                      [F] 월 집계
  financeMeta/rules                     [F] 분류 규칙 한 벌(순서 있는 목록, 9.2)
  questions/{qid}                       [F] 확인 질문 큐
  imports/{importId}                    [F] 가져오기 기록
    changes/{chunkNo}                   [F] 되돌리기용 변경 전 상태
  coupangDays/{YYYY-MM-DD}              [F] 쿠팡 쪼개기
  ocrCaptures/{captureId}               [F] 쿠팡 OCR 레코드
  installments/{txKey}                  [F] 할부 계획
inviteCodes/{code}                      [N] Ninedogs 초대 코드 {householdId}
financeInvites/{code}                   [F] 가계 초대 코드(만료·한 번만)
```
- **[N] Ninedogs 계약 문서**: 모양은 `ninedogs_core`가 정한다. family_finance는 같은 모델로 읽고, 쓸 때는 **`SetOptions(merge: true)` + 계약 필드만**. 자기 필드 금지.
- **[C] 공동 메타**: `ninedogs_core`가 모양을 정하고 두 앱이 다 쓴다. 필드 단위 `update`만.
- **[F] 가계 전용**: family_finance만 쓴다. Ninedogs는 읽지도 않는다. 규칙상 **가계 구성원만** 접근(6.3).

### 5.3 가계 문서 스키마
표기: `string`, `int`(최소 단위 정수), `ts`(Timestamp), `?`는 없을 수 있음.

**`financeMeta/root`** — 가구 문서 대신 가계 설정을 여기 둔다(가구 문서는 Ninedogs 계약이라 필드를 안 늘린다).
| 필드 | 타입 | 설명 |
|---|---|---|
| `memberUids` | list<string> | **가계 구성원**(구글 로그인 uid). 가계 데이터 규칙의 기준(최대 4) |
| `ownerUid` | string | 가계를 켠 사람 |
| `schemaVersion` | int | 가계 데이터 모양 버전(17장) |
| `txKeyVersion` | int | 거래 키 규칙 버전(7장) |
| `settings` | map | `oneOffThreshold:int`(기본 1,000,000), `liveWindowDays:int`(기본 3), `diagnosis:{overPct, overMin, underPct}`, `subscriptionRemindersBy:'ninedogs'|'finance'` |
| `banksaladCoveredUntil` | string? | 최근 가져오기가 덮은 마지막 날짜. 이 날 **이후**만 임시 거래를 집계에 넣는다(12.5) |
| `importLock` | map? | `{importId, uid, at}` |
| `createdAt` | ts | |

**`financeMembers/{uid}`** — `displayName`(앱에서 정한 호칭), `role`('owner'|'member'), `joinedAt`, `inviteCode?`(참여 검증용), `liveDevice?:{enabled, lastEventAt}`. 구글 이메일·사진 저장 안 함.

**구독 주인(owner) — Ninedogs v1.6.0에서 공유 계약에 들어감 (2026-11-22)**
- 구독 문서의 `owner: 'a'|'b'|null`(null = 공동). 사람 이름은 `households/{id}/meta/people` `{ names: { a, b } }`.
- 색은 칸에 고정(a=파랑, b=빨강 계열). family_finance도 같은 필드·문서를 읽고, 사람별 합계에 쓴다.
- v1.5.0 이하 Ninedogs는 저장 때 owner를 지우므로, 두 기기 모두 v1.6.0 이상이어야 한다(N3의 `meta/clients`로 확인).

**`subscriptionLinks/{subId}`** — 구독 문서와 같은 id. 구독이 지워지면 고아가 된다 → 화면에서 숨기고 30일 뒤 정리(거래의 `cls.subscriptionId`는 남겨 "삭제된 구독"으로 표시).
```
{ v:1, cardId?, planItemId?,
  matcher:{ merchantContains:[string], amountTolerancePct:int, dayTolerance:int },
  lastCharge?:{ ref:'tx'|'live', id, date, amount:int },
  watch:{ enabled:bool, lastCheckedMonth?, mutedUntil? },
  updatedAt: ts, updatedBy }
```

**`planVersions/{YYYY-MM}`** — 그 달부터 적용되는 계획 트리(≈30KB). 어떤 달 m의 계획 = id ≤ m 중 최대(`effectivePlan()` 한 곳).
```
{ effectiveFrom:'2026-12', updatedAt, updatedBy,
  groups:[{ id, name, order,                       // 구분
    categories:[{ id, name, order,                 // 지출 분류
      items:[{ id, name, order, monthlyAmount:int, // 항목, 월 계획 금액
               cardId?, accountId?, payDay?:int,   // 결제 카드 / 출금 통장 / 결제일
               recurring:bool, deleted:bool }]}]}]}
```
항목 id는 버전이 바뀌어도 유지. 구독 ↔ 항목 연결은 `subscriptionLinks.planItemId` 쪽에만 둔다(한 방향).

**`accounts/{accountId}`** — `nickname`, `bank?`, `last4?`(끝 4자리만, 선택), `kind`('checking'|'savings'|'loan'|'investment'), `ownerUid?`,
`bsAliases:[string]`, `liveAliases:[string]`, `minBuffer:int?`, `balance?:{amount:int, at:ts, source:'notification'|'manual'|'derived', by}`, `deleted`.
**전체 계좌번호는 저장하지 않는다.** `balanceLog/{id}` — `{amount, at, source, templateId?, by}`, 계좌당 최근 200개.

**`cards/{cardId}`** — `nickname`, `issuer`, `last4?`, `payDay:int`, `usage:{fromDay, fromPrevMonth:bool, toDay}`, `withdrawalAccountId`, `bsAliases`, `liveAliases`, `deleted`.

**`transactions/{txKey}`**
| 필드 | 타입 | 설명 |
|---|---|---|
| `src` | map | **원본(읽기 전용)**: `date`, `time:'HH:mm'`, `type:'income'|'expense'|'transfer'`, `major`, `minor`, `merchant`, `amount:int`(부호 원본대로), `currency`, `payment`, `memo` |
| `month` | string | 'YYYY-MM' |
| `at` | ts | 날짜+시간(KST) |
| `fp` | string | 원본 지문(가변 필드 포함 해시) |
| `status` | string | 'active' / 'missing' / 'superseded' / 'deleted' |
| `supersededBy` | string? | 수정본 키 |
| `cls` | map | `kind`, `categoryId?`, `living?`, `itemId?`, `subscriptionId?`, `by:'rule'|'manual'|'default'|'live'`, `ruleId?`, `oneOff`, `oneOffBy`, `linkTo?` |
| `liveId` | string? | 대조된 임시 거래 |
| `coupangDay` | string? | 쪼개기 대상 날짜 |
| `tags` | string[]? | 규칙 조건 `tag`가 보는 꼬리표(예: `coupangFresh`) |
| `import` | map | `first`, `last` importId |
| `updatedAt`, `updatedBy` | | |
문서당 약 0.6KB, 1년 ≈ 4MB.

**`liveTx/{liveId}`** — Kotlin과 Dart가 같이 쓴다. 필드를 늘릴 땐 양쪽 + 적합성 테스트.
```
{ v:1, templateId, deviceUid, at: ts,
  kind:'approval'|'cancel'|'withdrawal'|'deposit'|'balanceOnly',
  amount:int, currency:'KRW', merchant?:string, cardId?, accountId?, balanceAfter?:int,
  status:'provisional'|'matched'|'orphan'|'dismissed', matchedTxKey?,
  cls?: {transactions.cls와 같은 모양}, month:'YYYY-MM', createdAt: ts }
```
liveId = `lv_` + sha1(templateId | at(분) | amount | merchant | kind) 앞 20자 → 같은 알림이 두 번 와도 같은 문서. **알림 원문 필드는 없다.**

**`notificationTemplates`** 12.3, **`txIndex/{m}`** `{keys:{<txKey>:<fp>}, count}`, **`months/{m}`** 13장, **`financeMeta/rules`** 9.2, **`questions`** 9.4,
**`imports`·`changes`** 8장, **`coupangDays`·`ocrCaptures`** 11장, **`installments`** 13.3.

**`financeInvites/{code}`** — `{householdId, createdBy, createdAt, expiresAt, usedBy?, usedAt?}`. 8자리, 48시간, 한 번만.

### 5.4 Ninedogs 계약 문서 (모양은 ninedogs_core가 정함 — 여기는 요약)
| 문서 | 모양(Ninedogs v1.5 기준) | Ninedogs가 쓰는 방식 | family_finance가 쓰는 방식 |
|---|---|---|---|
| `households/{hid}` | `{inviteCode, memberUids, createdAt(iso)}` | 만들 때 `set`, 참여 `arrayUnion`, 나가기 `arrayRemove` | 만들 때(가구가 없을 때만) core의 `Household` 모양으로 `set` + `inviteCodes` 생성. 이후 `memberUids` `arrayUnion/arrayRemove`만 |
| `subscriptions/{id}` | `Subscription.toJson()`: iso 날짜, `priceHistory:[{effectiveFrom, amount:{minor,currency}, cycle?}]`, `pastPeriods`, `cycle`, `startedAt`, `billingAnchor?`, `canceledAt?`, `accessEndsAt?`, `trialEndsAt?`, `paymentMethod?`, `credentialId?`, `memo?`, `reminderDaysBefore?`, `serviceId?`, `iconUrl?`, `brandColorValue?` (+ 계약 필드 `cv`) | 현재: 목록 전체 맞추기(목록에 없으면 삭제, 전부 `batch.set`) → **N2에서 문서 단위로 바꿈**(15.3) | 문서 하나씩 `set(merge:true)`, 계약 필드만. 삭제는 명시적 `delete` |
| `credentials/{subId}` | `{id, subscriptionId, payload:{v, nonce, data, mac}, updatedAt}` | 위와 같음 | 같은 방식. 암호문은 core의 `VaultCrypto`로만 만든다 |
| `meta/vault` | `{salt, verifier, createdAt}` | `set` | **새 금고 만들기는 금고가 없을 때만**(트랜잭션으로 없음을 확인). 있으면 절대 덮지 않음 |
| `inviteCodes/{code}` | `{householdId}` | 가구 만들 때 `set` | 가구를 새로 만들 때만 |

### 5.5 공유 코드 — `ninedogs_core` 패키지 (추천) vs 복사 + 계약 테스트
대상: 모델(Money·BillingCycle·Subscription·PricePoint·SubscriptionPeriod·Credential·Household), 직렬화, 카탈로그(서비스·요금제·billing_lookup), 아이콘 조회·가장자리 색, VaultCrypto, 가격 이력 계산(누적 지출·결제 예정일·`addMonths`), 계약 버전.

| | A. `packages/ninedogs_core` + git 의존성 (**추천**) | B. 복사 + 계약 테스트(JSON 픽스처) |
|---|---|---|
| 원본 | Ninedogs 저장소 한 곳 | 두 벌(코드가 갈라질 수 있음) |
| 직렬화 일치 | 같은 코드라 구조적으로 보장 | 픽스처가 덮는 만큼만 보장 |
| 금고 호환 | 같은 `VaultCrypto` — 파라미터·검증 문자열이 갈라질 수 없음 | 상수 하나만 틀려도 상대 암호문을 못 엶(픽스처로 잡아야 함) |
| 변경 비용 | 모델을 바꾸면 Ninedogs 태그 → family_finance `ref` 올림(두 단계) | 두 저장소를 손으로 같이 고침 |
| 빌드 | `flutter pub get`이 GitHub에서 받아 옴(공개 저장소라 인증 불필요), `pubspec.lock`에 커밋 고정 | 의존성 없음 |
| 위험 | 패키지 의존성이 두 앱의 버전 범위를 묶음 → **core는 Firebase·Riverpod에 의존하지 않는다** | 조용한 불일치(가장 나쁜 실패 — 돈과 암호문) |

**결정: A.** 같은 Firestore 문서를 두 앱이 쓰는 이상 "직렬화 코드가 하나"인 게 가장 강한 보장이다. 단 A에도 **계약 픽스처 테스트는 같이 둔다**(core 안 `test/contract/`, 그리고 family_finance가 core가 내보내는 픽스처로 자기 쓰기 경로를 검사).

패키지 구성(ROADMAP N1):
```
Ninedogs/packages/ninedogs_core/
  lib/model.dart     순수 Dart: Money, BillingCycle, Subscription…, Household, codec(toFirestore/fromFirestore Map),
                     가격 이력 계산, 카탈로그 데이터, VaultCrypto(cryptography), kContractVersion, ContractStatus
  lib/ui.dart        Flutter: IconResolver, IconPalette(가장자리 색), ServiceIcon 위젯
  lib/fixtures.dart  계약 픽스처(가짜 데이터): 문서 JSON 예시·암호문 예시(테스트용 암호)
  test/
  pubspec.yaml       의존: cryptography, intl(넓은 범위 >=0.19 <0.21), collection, http, shared_preferences, flutter_cache_manager, flutter
```
- family_finance `pubspec.yaml`:
  ```yaml
  ninedogs_core:
    git: { url: https://github.com/jong0227/Ninedogs.git, path: packages/ninedogs_core, ref: ninedogs_core-v1.0.0 }
  ```
  Ninedogs 앱은 `path: packages/ninedogs_core`.
- `domain/`은 `model.dart`만 import(architecture_test가 검사). `ui.dart`는 `core/design`에서만.
- 태그 규칙: `ninedogs_core-vX.Y.Z`. 문서 모양이 바뀌면 X(계약 버전과 같이), 계산·카탈로그 변경은 Y/Z.
- 카탈로그에 가계용 가맹점 별칭을 넣지 않는다(Ninedogs에 쓸모없는 필드) → family_finance `catalog_aliases.dart`(serviceId → 별칭, 공개 정보만).

### 5.6 계약 버전과 "모르는 버전이면 쓰기 금지"
- `kContractVersion`(core) = 공유 문서 모양의 버전. 지금 모양 = **1**.
- 문서 단위: core 코덱이 쓰는 모든 구독·계정 문서에 `cv:<버전>`. `cv`가 없으면 1(옛 Ninedogs가 쓴 문서).
- 가구 단위: `meta/contract` `{version:int, minReaderVersion:int, updatedAt, by}` — 지금까지 이 가구에 쓰인 가장 높은 계약 버전.
- **규칙(두 앱 공통, core의 `ContractGuard`)**
  1. 읽기: 아는 버전보다 높은 `cv` 문서도 아는 필드만으로 보여 준다(모르는 필드는 무시).
  2. 쓰기: `meta/contract.version > kContractVersion`이거나 그 문서의 `cv > kContractVersion`이면 **그 앱은 공유 문서를 쓰지 않는다**(읽기 전용 + "앱을 업데이트해 주세요" 띠). 가계 데이터([F])는 영향 없음.
  3. 모양을 바꾸는 쪽(core X 버전 올림)은 처음 쓸 때 `meta/contract.version`을 올린다.
- `meta/clients` — `{<uid>: {app:'ninedogs'|'finance', appVersion, cv, seenAt}}`. 앱 실행 때 자기 칸만 `update`.
  family_finance는 가구의 `memberUids` 중 `meta/clients`에 없거나 `cv`가 낮은 Ninedogs 기기가 있으면 **공유 문서 쓰기 전에 경고**한다
  (옛 Ninedogs는 목록 전체 덮어쓰기를 하므로 — 15.3).

---

## 6. 인증과 보안 규칙

### 6.1 로그인
- family_finance: **구글 로그인**(`google_sign_in` 7, Credential Manager → `GoogleAuthProvider.credential` → Firebase Auth). 같은 프로젝트에 Google 제공업체를 켠다.
- Ninedogs: 익명 로그인 그대로(바꾸지 않음). 같은 사람이라도 두 앱의 uid는 다르다 → 가구 `memberUids`에 둘 다 들어간다.

### 6.2 가구·가계 참여
1. **가구가 이미 있음(Ninedogs 동기화 연결됨)**: family_finance에서 **Ninedogs 초대 코드** 입력 → `inviteCodes/{code}` get → 가구 `memberUids`에 `arrayUnion`(Ninedogs 규칙 그대로) → 구독이 보인다.
2. **가계 켜기(처음 한 번)**: 가구 구성원이 구글 로그인 상태에서 `financeMeta/root` 생성(없을 때만) → 그 사람이 가계 owner.
3. **배우자 가계 참여**: owner가 **가계 초대 코드**(`financeInvites/{code}`, 8자리·48시간·한 번만) 생성 → 배우자는 코드 하나만 입력하면 앱이
   ① `financeInvites`에서 householdId를 얻고 ② 가구 구성원이 아니면 가구 `memberUids`에 `arrayUnion` ③ 한 배치로 `financeMembers/{uid}` 생성 + `financeMeta.memberUids`에 자기 추가 + 초대 `usedBy`.
4. **가구가 없음(Ninedogs 동기화를 안 씀)**: family_finance가 core `Household` 모양으로 가구 + `inviteCodes`를 만든다 → 나중에 Ninedogs에서 그 코드로 연결하면 Ninedogs가 로컬 구독을 합쳐 올린다(Ninedogs 기존 동작).
Ninedogs 초대 코드(6자리, 만료 없음)는 구독만 열고, 가계 데이터는 가계 초대(만료·1회·구글 로그인)를 따로 거쳐야 연다 — 아래 규칙이 그 경계다.

### 6.3 규칙 (`firestore.rules` 초안 — Ninedogs 동작은 그대로, 가계 데이터만 강화)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn() { return request.auth != null; }
    function isGoogle() { return signedIn() && request.auth.token.firebase.sign_in_provider == 'google.com'; }
    function isMemberOf(hid) {
      return signedIn() && request.auth.uid in get(/databases/$(db)/documents/households/$(hid)).data.memberUids;
    }
    function fin(hid) { return get(/databases/$(db)/documents/households/$(hid)/financeMeta/root).data; }
    function isFinanceMember(hid) { return isGoogle() && request.auth.uid in fin(hid).memberUids; }
    function isFinanceOwner(hid) { return isGoogle() && fin(hid).ownerUid == request.auth.uid; }

    // ── Ninedogs 계약 (동작 변경 없음. 바꾸면 test_rules의 Ninedogs 시나리오가 깨진다) ──
    match /inviteCodes/{code} {
      allow get: if signedIn();
      allow list: if false;
      allow create: if signedIn() && isMemberOf(request.resource.data.householdId);  // 강화 ①: 남의 가구 코드 만들기 금지
      allow update, delete: if false;
    }

    match /households/{hid} {
      allow get: if isMemberOf(hid);
      allow list: if false;
      allow create: if signedIn() && request.auth.uid in request.resource.data.memberUids;
      allow update: if isMemberOf(hid)
        || (signedIn()
            && request.resource.data.memberUids == resource.data.memberUids.concat([request.auth.uid])
            && request.resource.data.inviteCode == resource.data.inviteCode);
      allow delete: if false;

      // 강화 ②: 예전의 {document=**} 전체 허용을 Ninedogs가 실제로 쓰는 경로로 좁힌다.
      // 규칙은 "허용의 합집합"이라 와일드카드가 있으면 아래 가계 규칙을 아무리 좁혀도 소용없다.
      match /subscriptions/{id} { allow read, write: if isMemberOf(hid); }
      match /credentials/{id}   { allow read, write: if isMemberOf(hid); }
      match /meta/{id}          { allow read, write: if isMemberOf(hid); }   // vault, contract, clients

      // ── 가계 전용: 구글 로그인 + 가계 구성원만 ──
      match /financeMeta/{id} {
        allow read: if isFinanceMember(hid);
        allow create: if id == 'root' && isGoogle() && isMemberOf(hid)
          && request.resource.data.ownerUid == request.auth.uid
          && request.resource.data.memberUids == [request.auth.uid];
        allow update: if (isFinanceMember(hid)
            && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['memberUids','ownerUid']))
          || isFinanceOwner(hid)
          || joiningFinance(hid);
        allow delete: if isFinanceOwner(hid);
      }
      function joiningFinance(hid) {
        let code = getAfter(/databases/$(db)/documents/households/$(hid)/financeMembers/$(request.auth.uid)).data.inviteCode;
        let inv = get(/databases/$(db)/documents/financeInvites/$(code)).data;
        return isGoogle() && isMemberOf(hid)
          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['memberUids'])
          && request.resource.data.memberUids == resource.data.memberUids.concat([request.auth.uid])
          && resource.data.memberUids.size() < 4
          && inv.householdId == hid && inv.get('usedBy', null) == null && inv.expiresAt > request.time;
      }
      match /financeMembers/{uid} {
        allow read: if isFinanceMember(hid);
        allow create: if isGoogle() && uid == request.auth.uid;   // financeMeta update 규칙이 초대를 검증
        allow update: if uid == request.auth.uid && isFinanceMember(hid);
        allow delete: if uid == request.auth.uid || isFinanceOwner(hid);
      }
      match /{col}/{docId} {
        allow read, write: if isFinanceMember(hid) && col in ['subscriptionLinks','planVersions','accounts','cards',
          'transactions','liveTx','notificationTemplates','txIndex','months','rules','questions','imports',
          'coupangDays','ocrCaptures','installments'];
      }
      match /accounts/{a}/balanceLog/{id} { allow read, write: if isFinanceMember(hid); }
      match /imports/{i}/changes/{n}      { allow read, write: if isFinanceMember(hid); }
    }

    match /financeInvites/{code} {
      allow get: if isGoogle();
      allow list: if false;
      allow create: if isFinanceMember(request.resource.data.householdId)
        && request.resource.data.createdBy == request.auth.uid && request.resource.data.expiresAt is timestamp;
      allow update: if isGoogle()
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['usedBy','usedAt'])
        && request.resource.data.usedBy == request.auth.uid && resource.data.get('usedBy', null) == null;
      allow delete: if isFinanceMember(resource.data.householdId);
    }
  }
}
```
- 주의: `match /{col}/{docId}` 와일드카드가 `subscriptions`도 잡지만, 거기선 `col in [...]` 목록에 없어 거부 → 위의 구성원 규칙만 적용된다(합집합). 테스트로 확인.
- **Ninedogs를 깨지 않는지**: 강화 ①은 Ninedogs `createHousehold`가 가구를 먼저 `set`한 뒤 코드를 만들어서 통과한다. 강화 ②는 Ninedogs가 `subscriptions`·`credentials`·`meta`만 쓰므로 통과한다. 둘 다 `test_rules/ninedogs_*.test.ts`로 고정(6.5).
- 남는 위험(Ninedogs 쪽, 이 앱이 바꾸지 않음): 익명 로그인 + 만료 없는 6자리 코드라 코드를 맞힌 사람은 가구에 들어와 **구독·암호문**을 볼 수 있다. 계정 정보는 마스터 암호로 암호화돼 있고, **가계 데이터는 구글 로그인 + 가계 초대가 따로 필요해 안 보인다.** Ninedogs도 구글 로그인으로 옮기면 규칙을 더 좁힐 수 있다(ROADMAP N 선택 항목).
- `google-services.json`은 공개 저장소에 커밋(비밀 아님). API 키는 Android 앱 + SHA로 제한(두 앱 모두 등록).

### 6.4 규칙의 단일 원본
- **원본: `family_finance/firestore.rules`.** 프로젝트에 규칙 파일은 하나뿐이라(배포하면 통째로 바뀜) 원본도 하나여야 한다.
  family_finance를 고른 이유: 더 엄격한 쪽(가계)이 자주 바뀌고, Ninedogs 동작까지 포함한 에뮬레이터 규칙 테스트를 이 저장소에 둔다.
  (시간표 앱이 Moneycraft 블록을 품고 배포하던 방식과 같다.)
- Ninedogs 저장소의 `firestore.rules`는 N4에서 "배포 원본은 family_finance — 여기서 배포하지 말 것" 안내와 그 시점 사본으로 바꾼다.
- 배포: `firebase deploy --only firestore:rules,firestore:indexes --project ninedogs-b2628`는 **family_finance 저장소에서만**, `test_rules` 통과 후.
- Ninedogs 계약 블록을 바꾸는 변경은 커밋 메시지에 "Ninedogs 규칙 변경"을 적고 Ninedogs 실기기로 연결·편집을 확인한다.

### 6.5 앱 안 권한 (`domain/permissions.dart`)
가계 구성원은 동등한 편집자. 가계 owner만: 구성원 내보내기, 가계 데이터 삭제, 가져오기 되돌리기.
구독은 가구 구성원이면 누구나(Ninedogs와 같음). 금고는 권한이 아니라 마스터 암호로 연다.

---

## 7. 거래 키와 중복 제거 (뱅크샐러드)

뱅크샐러드 행에는 고유 id가 없다 → **바뀌지 않는 원본 필드로 키를 만든다.**
```
naturalKey = norm(date) | norm(time) | type | amount | norm(merchant) | norm(payment)
txKey      = 'bs_' + base32(sha1(naturalKey)).substring(0, 20) + '_' + n      // n = 1, 2, 3 …
```
- `norm`: 유니코드 NFC, 앞뒤 공백 제거, 연속 공백 하나로, 전각→반각.
- **같은 시각·금액·가맹점 다건**: 한 내보내기 안에서 naturalKey가 같은 행에 n=1,2,…. 둘은 구별할 수 없으므로 "몇 번째"만 맞으면 된다. 하나가 지워지면 `_2`가 사라진 행이 된다.
- **키에 넣지 않는 것**: 대분류·소분류·메모·화폐(사용자가 자주 고침) → `fp`로 "바뀐 행" 처리.
- 결제수단은 키에 넣는다(같은 시각·금액이 다른 카드로 찍히는 경우). 이름이 바뀌면 8.4 짝짓기가 처리.
- `domain/tx_key.dart` 한 곳. 바꾸면 `txKeyVersion`을 올리고 마이그레이션으로 재계산·판단 이전.
- 테스트: 두 번 넣으면 쓰기 0건, 순서를 섞어도 키 집합 같음, 다건 n, 공백·NFC 무시.

---

## 8. 가져오기 파이프라인 (뱅크샐러드)

### 8.1 파일 받기
- 뱅크샐러드 → 내보내기 → xlsx를 **공유 → family_finance**, 또는 앱의 [파일 열기](시스템 문서 선택기). 둘 다 `data/intents` 채널.
- intent-filter: `VIEW`·`SEND`(xlsx `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `application/json`), `SEND_MULTIPLE`(`image/*`). Ninedogs `takePending()` 방식(한 번 넘기면 비움).
- 시트 **"가계부 내역"**, 머리글 `날짜, 시간, 타입, 대분류, 소분류, 내용, 금액, 화폐, 결제수단, 메모`를 **이름으로** 찾는다. 날짜·시간은 엑셀 일련번호/문자열 둘 다, 금액 int, 화폐가 KRW가 아니면 `Money(currency)`로 보관하고 원화 합계에서 따로 표시.
- **파서는 직접**(`archive`+`xml`). `excel` 4.0.6은 2024-08 이후 갱신이 없고 `archive ^3`에 묶여 `image`(archive ^4)와 못 쓴다.
- 파싱은 isolate.

### 8.2 단계
```
① 읽기      xlsx 또는 묶음 JSON → RawRow[] + 덮는 기간                         (isolate, 오프라인 가능)
② 키 붙이기  txKey, fp
③ 비교      덮는 기간의 txIndex → 새로 생김 / 지문 바뀜 / 그대로 / 사라짐
④ 짝짓기    사라짐 × 새로 생김 → 수정 추정(8.4)
⑤ 대조      임시 거래(provisional) × 새 거래 → 확정/고아(12.5)
⑥ 분류      분류 엔진, 수동 판단·임시 판단 이어받기, 구독 매칭(10.3), 질문 후보
⑦ 미리보기  "새 132건, 바뀐 4건, 사라진 1건, 알림 거래 확정 27건, 질문 7개" → [반영]
⑧ 커밋      400건씩 청크 배치: 거래 + txIndex + liveTx 상태 + months.version 증가 + changes   (온라인 필수)
⑨ 마무리    질문 생성, banksaladCoveredUntil 갱신, 집계 재계산, status = committed
```
- ①~⑦은 아무것도 안 쓴다. ⑧ 전 온라인 확인(`Source.server` get).
- 구독 쪽 변화(가격 변동 등)는 가져오기가 **공유 문서를 직접 고치지 않는다** — 질문으로 만들고, 사람이 답할 때 `data/shared/`가 쓴다.

### 8.3 실패 복구
- `imports/{id}`: `status`('staged'|'committing'|'committed'|'failed'|'reverted'), `plan:{added,updated,missing,superseded,liveMatched,liveOrphaned}`, `chunksTotal`, `chunksDone`, `source`, `fileHash`(파일 이름 저장 안 함), `period`, `createdBy`, `createdAt`, `errors`(≤50줄).
- 청크 = 배치 = 원자적, `chunksDone`도 같은 배치. 중단되면 같은 파일로 남은 청크부터. **쓰기가 결정적이라 두 번 써도 같다.**
- 동시 가져오기 금지: `financeMeta.importLock`(트랜잭션, 10분 만료).

### 8.4 뱅크샐러드가 과거 거래를 고친 경우
| 경우 | 감지 | 처리 |
|---|---|---|
| 분류·메모만 바뀜 | 키 같음, fp 다름 | `src` 갱신, `cls` 유지(`by=='default'`면 재분류) |
| 금액·가맹점·결제수단·시각이 바뀜 | 옛 키 사라짐 + 새 키 생김 | 짝짓기: 같은 날짜(±1일)·같은 타입이고 (금액 같음 & 가맹점 비슷) 또는 (가맹점 같음 & 결제수단 같음). 짝이 하나일 때만 자동 — 옛 문서 `superseded`, 새 문서가 판단 이어받음 |
| 지워짐 | 덮는 기간 안인데 없음 | `missing`(집계 제외, 안 지움) + 질문 |
| 덮는 기간 밖 | — | 안 건드림 |
| 다시 나타남 | 같은 키 | `active` 복귀 |

### 8.5 되돌리기
- 커밋 때 바뀌는 문서마다 바꾸기 전 상태(새로 생긴 건 null)를 `changes/{n}`(청크당 ≤300건).
- 되돌리기 = 거꾸로 적용 + txIndex·months·liveTx·`banksaladCoveredUntil` 복원 + 그 가져오기의 질문 닫기. **가장 최근 것부터만.** 그 뒤 직접 고친 거래 수를 먼저 보여 준다. changes는 90일 뒤 정리.

### 8.6 PC 경로 (Claude가 PC에서 처리)
1. **기본: 묶음 JSON.** `dart run tool/import_cli.dart <xlsx> -o x.bundle.json` — 같은 `ingest`·`domain`으로 키·fp까지. 폰으로 보내(공유 → 앱) ③부터 같은 파이프라인. PC Windows OCR 쿠팡 레코드도 `coupangRecords`로.
   ```json
   { "format": "family_finance.import", "version": 1, "txKeyVersion": 1, "source": "banksalad-xlsx",
     "period": {"from": "2025-12-01", "to": "2026-11-21"},
     "rows": [ {"key": "bs_…_1", "fp": "…", "src": { } } ],
     "coupangRecords": [ {"date": "2026-11-03", "name": "…", "price": 12340, "status": "normal", "captureId": "…"} ] }
   ```
2. **선택: 관리자 직접 업로드**(M6). 서비스 계정 키는 저장소 밖, 가계 컬렉션만, 되돌리기 기록 필수. 공유 문서([N])는 관리자 경로로 쓰지 않는다.
- 묶음 JSON은 개인 데이터 → `.gitignore`.

---

## 9. 분류 엔진

### 9.1 두 단계
```
거래(뱅크샐러드 또는 임시) ──▶ ① kind ──▶ ② (소비) 분류·항목 ──▶ ③ 플래그(일회성·할부) ──▶ ④ 구독 연결(10.3)
```
| kind | 집계에서 | 예 |
|---|---|---|
| `spend` 소비 | 지출 | 마트, 외식, 구독 |
| `cardPayment` 카드대금 | 제외(이중 계산 방지) | 통장 → 카드사 |
| `ownTransfer` 내계좌이체 | 제외 | 통장 ↔ 통장 |
| `loanRepayment` 대출상환 | 별도 줄 | |
| `saving` 저축·투자 | 별도 줄 | |
| `proxyPurchase` 대리구매(정산) | 정산 입금과 상계 후 차액만 소비 | |
| `refund` 환불 | 원거래 항목에서 차감 | |
| `tax` 세금 | 지출(별도 구분 가능) | |
| `income` / `familyTransfer` / `cash` / `other` | 각자 줄 | |

### 9.2 규칙 (`financeMeta/rules` 문서 하나 — 순서 있는 목록, 사용자 데이터)
규칙 한 벌은 문서 하나다(`{ v:1, consumptionKind, rules:[...] }`, 수백 개여도 1MB 미만). 질문에서 생기는 규칙·직접 만든 규칙은 같은 목록의 `override` 규칙으로 앞쪽에 쌓인다. 코드: `lib/domain/classify/`(`rule.dart` 모델, `rule_codec.dart` JSON, `classify_engine.dart` 엔진, `month_totals.dart` 월 집계).
```
{ id, note?, enabled?:true, priority?:0, override?:false,
  when: { type, major, minor, merchantEquals, merchantContains, merchantStartsWith, merchantRegex,
          paymentIn, paymentStartsWith, paymentContains, accountId, cardId, tag, memoContains,   // 문자열 또는 목록 = 하나라도 맞으면 참
          amountEq|Min|Max, amountAbsEq|Min|Max,           // 원, 부호 포함 / 절댓값, 경계 포함
          dateFrom, dateTo, dayOfMonth:{from,to},          // 'YYYY-MM-DD' 경계 포함
          kind, categoryId, oneOff,                        // 앞선 규칙이 이미 정한 값을 보는 조건
          anyOf:[when], not:when },                        // 위 조건은 모두 AND, anyOf = OR, not = 부정
  then: { kind?, categoryId?, living?, oneOff? } }         // 키가 있으면 채움(null 도 "없음으로 확정")
```
- `classify(tx, ruleSet)` 순수 함수. **순서가 우선순위**다(`priority`가 있으면 큰 것 먼저, 같으면 목록 순서). 일반 규칙은 비어 있는 필드만 채우고(먼저 채운 규칙이 이긴다), `override` 규칙은 일반 규칙이 채운 값도 덮는다(덮어쓰기끼리는 먼저 쓴 쪽이 이김). `then`에 `kind`가 있으면 "판정 묶음" — kind를 못 채우면 그 규칙은 통째로 건너뛴다.
- 읽는 순서: kind 규칙 -> 분류(`kind` 조건) -> 덮어쓰기 -> 일회성(`oneOff`) -> 생활비 묶음(`living`, `oneOff:false` 조건). 조건 `kind`·`categoryId`·`oneOff`는 앞선 규칙의 결과를 보므로 그 값을 정하는 규칙 뒤에 둔다.
- `kind`·`categoryId`·`living`은 **사용자 분류 체계의 이름 그대로**(문자열)다. 엔진은 이름을 모른다. 집계에서 "소비"로 치는 kind만 `consumptionKind`로 알려 준다. 위 9.1 표의 영문 id는 개념 설명이다.
- `tag`: 거래 문서의 `tags`(예: 쿠팡 로켓프레시 상품 `coupangFresh`)를 본다. 쪼갠 쿠팡 상품은 가맹점 접두어 + 키워드 규칙으로 분류한다.
- JSON 읽기는 모르는 키·타입 오류를 거부한다(오타가 조건을 조용히 빼는 것 방지).
- **기본 규칙**(코드): 뱅크샐러드 대분류 "카드대금"·"내계좌이체"·"저축"·"투자"·"대출상환" -> 해당 kind, 수입 "환불" -> 환불, 나머지 지출 -> 소비 + 대분류를 임시 분류로. **가맹점·사람 이름은 기본 규칙에 넣지 않는다**(예외: 구독 카탈로그 별칭 — 공개 정보). 개인 규칙 전체는 Firebase에만 있고 이 저장소에는 가짜 규칙 테스트만 있다.
- 수동 판단 > 사용자 규칙 > 기본 규칙. 규칙을 고치면 걸리는 기존 거래 일괄 적용(미리보기, 수동 판단 제외). `hits`는 커밋 때 모아서.
- **동일성 검사**: `dart run tool/classify_check.dart <rules.json> <tx_dump.json>` — 저장소 밖 규칙·거래 덤프를 읽어 기존 분류와 거래별·월별로 비교하고 건수만 출력한다.

### 9.3 플래그
- **일회성**: spend & |금액| ≥ `oneOffThreshold`(기본 100만 원) → 자동, 사용자가 바꾸면 `manual`. 집계는 "경상"과 "전체" 둘 다.
- **할부**: 13.3. **대리구매·환불 짝**: `cls.linkTo`(후보는 엔진, 확정은 질문).

### 9.4 확인 질문 큐 (`questions/{qid}`)
```
{ type: 'classify'|'kind'|'proxySettlement'|'refundLink'|'missingFromSource'|'supersedePair'|'oneOff'|'installment'
        |'recurringCandidate'|'coupangUnmatched'|'liveOrphan'
        |'subPriceChanged'|'subResubscribed'|'subNew'|'subMissingCharge',
  txKeys:[string], liveIds:[string], subscriptionId?, priority:int, prompt: map,
  status:'open'|'answered'|'skipped'|'obsolete', answer?, makeRule:bool, ruleDraft?,
  answeredBy?, answeredAt?, importId? }
```
- 화면은 **한 번에 하나**(가장 높은 priority). 답 → 반영 → (선택) 규칙 저장 → 같은 규칙에 걸리는 질문 `obsolete` → 다음.
- qid는 결정적(`type + 대상 해시`). 동시 답은 트랜잭션(`open`일 때만). 건너뛰기 = 7일 뒤 다시.
- 구독 질문(`sub*`)의 답은 공유 문서를 고친다 → `data/shared/` 경유, `ContractGuard`가 읽기 전용이면 "Ninedogs/앱 업데이트 후 답할 수 있어요"로 보류.

---

## 10. 구독 모듈 (Ninedogs와 공유)

### 10.1 무엇을 어떻게 쓰나
| 기능 | 출처 | family_finance에서 |
|---|---|---|
| 모델·가격 이력·누적 지출·말일 처리·인상/정정 구분·재구독(pastPeriods) | `ninedogs_core/model` | 그대로 사용. 편집 화면 동작(인상 vs 오타 질문)도 같은 함수 |
| 카탈로그 59종·요금제·billing_lookup | core | 그대로(새 서비스·가입일 찾기 안내는 **추가하지 않는다** — 사용자 결정) |
| 아이콘(App Store 512px → 파비콘 → 첫 글자, 가장자리 평균색) | `ninedogs_core/ui` | 그대로. `iconUrl`은 공유 문서에 있으니 한쪽에서 찾은 아이콘이 양쪽에 보인다 |
| 금고(VaultCrypto: PBKDF2-HMAC-SHA256 12만 회 → AES-GCM 256, 검증 문자열) | core | 같은 `meta/vault`·`credentials`. 같은 마스터 암호로 두 앱 모두 연다. 자동 잠금·클립보드 1분 삭제는 앱마다 구현 |
| 생체인증 | 각 앱 | 파생 키를 **각 앱의** 보안 저장소에(앱끼리 공유 안 됨, 서버에 안 올라감) |
| 결제 예정 알림(7/3/1일 전) | Ninedogs 앱 | 같은 폰에 두 앱이 있으면 알림이 두 번 온다 → `settings.subscriptionRemindersBy` 기본 'ninedogs'(Ninedogs가 설치돼 있으면). family_finance는 카드 결제일·D-3 잔액 알림만. Ninedogs가 없는 폰이면 'finance'로 바꿀 수 있다 |
| 분야 통계·결제 캘린더 | Ninedogs 앱 | family_finance 구독 화면은 **가계 관점**(카드·계획 항목·실제 결제·감시)에 집중하고 캘린더는 카드 결제일과 겹쳐 보기만. 둘 다 같은 데이터라 어느 앱에서 봐도 같다 |
| 환율(open.er-api.com, USD 구독) | core 또는 Ninedogs | 원화 환산 표시에만. 실제 결제는 카드 거래 원화 금액 우선 |

### 10.2 구독 ↔ 계획 ↔ 카드
- 연결 정보는 전부 `subscriptionLinks/{subId}`: `cardId`, `planItemId`, `matcher`. 구독 문서의 `paymentMethod`(자유 문구)는 Ninedogs 것이라 건드리지 않고 표시만.
- 계획 항목(예: "구독")의 월 계획 금액 vs 연결된 구독들의 월 환산(`monthlyEquivalent`) 합.
- 카드 화면의 "정기결제·고정지출" = 연결된 구독 + `recurring` 계획 항목.

### 10.3 정기결제 감시 (카드 거래 ↔ 구독 매칭) — `domain/subscriptions/watch.dart`
가져오기 ⑥단계와 임시 거래가 들어올 때. 순수 함수 `watch(subscriptions, links, txs, aliases, asOf) → [Finding]`.
1. **예상 결제**: core의 결제 예정일 계산(가격 이력·주기·`billingAnchor`·`trialEndsAt`)과 그 시점 가격.
2. **매칭**: 예정일 ±`dayTolerance`(기본 3일), 가맹점이 `matcher.merchantContains` 또는 `catalog_aliases`에 맞음, 링크에 카드가 있으면 그 카드, 금액이 가까움.
   맞으면 거래 `cls.subscriptionId` + 분류는 링크의 `planItemId`, `subscriptionLinks.lastCharge` 갱신(가계 문서라 자유롭게 씀).
3. **찾는 것**
   | Finding | 조건 | 질문 → 답하면 |
   |---|---|---|
   | 새 정기결제 | 연결 안 된 거래가 카탈로그 별칭에 맞음, 또는 같은 가맹점 3개월 이상 매달 ±3일·±10% | `subNew` "넷플릭스로 보여요. 구독으로 등록할까요?" → 카탈로그 요금제·첫 결제일을 채운 추가 화면 → 공유 문서 생성(Ninedogs에도 나타남) + 링크 |
   | 금액 변동 | 매칭됐는데 금액 ≠ 예상 | `subPriceChanged` "요금이 올랐나요, 잘못 적었나요?" → core의 인상(이력 추가)/정정(마지막 항목 교체) |
   | 해지 후 재결제 | `canceledAt`·`accessEndsAt`이 지난 구독의 가맹점으로 결제 | `subResubscribed` → core 재구독(`pastPeriods`에 이전 구간 보관) |
   | 결제 없음 | 예정일 + 7일 지남, 매칭 없음(뱅크샐러드가 그 날짜를 덮은 뒤에만) | `subMissingCharge` "해지했나요?" → 해지일 입력 |
   | 체험 종료 임박 | `trialEndsAt` D-3 | 질문 아님(알림은 Ninedogs 또는 설정에 따라) |
4. 조용히 실패: 별칭이 없거나 금액이 안 맞으면 질문 남발 금지. 한 구독에 같은 종류 질문은 한 달 한 번(`watch.mutedUntil`).
5. USD 구독: 카드 원화 금액은 환율로 흔들림 → 허용 오차 넓게(기본 15%), 금액 변동 질문은 USD 가격 변화 근거가 있을 때만.

### 10.4 누적 지출 두 가지
- **계산값**(core): 가격 이력으로 결제일마다 그때 가격을 더함. Ninedogs 화면과 같은 숫자.
- **실제값**: `cls.subscriptionId`로 연결된 거래 합. 구독 상세에 둘 다, 차이 나는 달 표시.

### 10.5 공유 문서 쓰기 절차 (`data/shared/SharedSubscriptionStore`)
1. `ContractGuard.canWrite(doc)` 확인(5.6). 아니면 읽기 전용.
2. 편집은 **트랜잭션**: 최신 문서 읽기 → core 모델로 변환 → 변경 적용(`copyWith`) → core 코덱으로 Map → `set(merge:true)`.
   `priceHistory`처럼 목록 필드는 통째로 바뀌므로, 트랜잭션으로 "읽은 뒤 남이 고쳤으면 다시"를 보장한다.
3. 삭제는 명시적 `delete`(구독 + 같은 id의 credentials). 링크는 남겨 30일 뒤 정리.
4. 쓰기 전, 옛 Ninedogs 기기 경고(5.6 `meta/clients`).

---

## 11. 쿠팡 주문내역 OCR 매칭

뱅크샐러드에는 "쿠팡 38,900원"만 있다. 무엇을 샀는지는 쿠팡 앱 주문내역 캡처로 채운다.
PC에서 Python으로 검증한 알고리즘을 Dart로 옮긴다(`domain/coupang/`). 이미지 → 줄 텍스트만 플랫폼(`data/ocr_service.dart`).

### 11.1 OCR (폰 안에서)
1. 캡처 여러 장을 갤러리에서 **공유 → 앱**(`SEND_MULTIPLE`) 또는 앱 안 선택기.
2. **빈 줄 기준으로 자르기**: isolate에서 `image`로 디코드 → 가로 줄마다 픽셀 분산을 계산해 거의 단색인 띠에서 자른다(조각 ≤ 1,600px). 긴 캡처를 통째로 넣으면 ML Kit이 줄여서 작은 글자를 놓친다.
3. 조각마다 `google_mlkit_text_recognition`(`TextRecognitionScript.korean`) → 줄과 위치 → 오프셋 더해 위→아래 정렬.
4. 줄 목록만 남기고 이미지 사본은 지운다. **이미지는 서버에 올리지 않는다.**

### 11.2 줄 → 주문 레코드 (순수)
- 날짜 헤더(짧은 줄의 `2026. 11. 3`) → 다음 헤더까지 **이어받기**.
- 헤더가 잘림 → `11/4(화) 도착`에서 **주문일 = 배송일 − 1일**(`inferred`). 연도는 캡처 시각 이전 중 **요일이 맞는 해**(Python 판의 "가장 최근 해"를 개선).
- 가격 줄(`12,340원`) → 바로 위 의미 있는 줄 1~2개를 상품명. 버튼·메뉴 문구는 잡음 목록으로.
- `취소완료`·`반품` → 취소. `N개 상품`·`모두 보기` → 묶음 주문 표시. `프레시` → 식료품 힌트.

### 11.3 여러 캡처 합치기
날짜별 **가격 다중집합의 합집합**: 가격 p가 캡처 i에서 c_i번 → max(c_i)번. 상품명은 깨끗한 쪽, `support` = 그 가격을 읽은 캡처 수. `ocrCaptures/{id}`에 레코드로.

### 11.4 결제 금액에 맞춰 쪼개기 (총액 보존)
날짜 d: 결제 T = 그날 spend인 쿠팡 결제 합(쿠팡이츠·멤버십 등 별도 서비스 제외 — 일반 목록이라 코드), 상품 합 S.
- S == T → 완전. S < T → 상품 + **"쿠팡 · 내역 미확인" T−S**(묶음 주문 수 표시).
- S > T → 합이 정확히 S−T인 상품 1~3개를 support 낮은 것부터 뺌. 못 찾으면 안 쪼개고 `coupangUnmatched`.
- `coupangDays/{d}`: `{paymentKeys, paymentTotal, items:[{name, price, support, categoryId?, itemId?}], residual, status, capturesUsed, computedAt}`.
- **원본 결제 거래는 그대로**, 집계가 상품·잔액으로 치환. 결제 키가 바뀌면 그날만 다시.
- 상품 → 항목 키워드는 **사용자 규칙**(`when.coupangItem`). 불변식: `Σitems + residual == paymentTotal`.

---

## 12. 실시간 수집 — 카드·은행 알림 (임시 거래·잔액)

뱅크샐러드 내보내기는 매일 못 한다. 결제일 현금 점검에는 최근 며칠의 결제와 통장 잔액이 필요하다.
Ninedogs는 "카드사마다 형식이 달라 유지보수 부담이 크다"며 알림 파싱을 안 하기로 했다. 여기서 부담을 줄이는 방법: **템플릿을 코드가 아니라 사용자 데이터로**, 안 맞으면 조용히 무시, **확정은 뱅크샐러드가** 한다(알림은 틀려도 결국 바로잡힘).

### 12.1 흐름
```
카드사/은행 앱 알림 ──▶ FinanceNotificationListener (Kotlin, NotificationListenerService)
   ① 패키지가 템플릿 목록에 없으면 즉시 무시(본문을 읽지도 않음)
   ② 템플릿 정규식 → {kind, amount, merchant?, balanceAfter?, cardId/accountId, at}
   ③ 원문 버림. 안 맞으면 패키지별 "맞지 않은 알림" 개수만 +1
   ▼
LiveWriter (Kotlin, Firebase Android SDK — Flutter 엔진 없이도)
   배치: liveTx/{liveId} + months/{m}.version increment + (잔액) accounts/{id}.balance(더 최신일 때만) + balanceLog
   ▼
배우자 폰에 실시간 표시 → 앱을 열면 Dart가 분류·구독 감시(liveTx.cls, 질문)
   ▼
뱅크샐러드 가져오기 ⑤단계에서 대조 → matched / orphan
```
- Kotlin이 바로 쓰는 이유: 알림 받은 사람이 며칠 앱을 안 열어도 배우자의 현금 점검이 최신이어야 한다.
  householdId·uid는 Dart가 로그인 후 MethodChannel로 넘겨 둔다. 가계 구성원이 아니면 아무것도 하지 않는다. `financeMeta.schemaVersion`이 지원 범위 밖이면 쓰기 중지.
- 별도 포그라운드 서비스·배터리 예외 불필요(시스템이 바인딩).

### 12.2 원문을 남기지 않는 원칙
- 원문(제목·본문)은 **디스크·Firestore·로그 어디에도** 쓰지 않는다. 남는 건 템플릿이 뽑은 필드뿐. `merchant` 그룹이 없으면 가맹점도 안 남는다.
- **학습 모드**: 사용자가 특정 앱에 대해 켜면 10분 동안 그 앱의 다음 알림 **하나**를 서비스 메모리에만 들고 있다가 템플릿 편집기에 보여 준다. 숫자는 `#`로 가림, 편집기를 닫거나 10분 지나면 버림.
  알림 문구를 직접 붙여 넣어 만들 수도 있다(정규식만 저장).

### 12.3 템플릿 (`notificationTemplates/{id}`, 사용자 데이터)
```
{ name, packageName,                        // 저장소 예시는 가짜 패키지만
  titleRegex?, bodyRegex,                   // 이름 있는 그룹: amount, merchant, balance, month, day, hour, minute, card, account
  kind:'approval'|'cancel'|'withdrawal'|'deposit'|'balanceOnly',
  target:{ cardId?, accountId?, byGroup?:'card'|'account' },
  amountSign:'negative'|'positive', timeFrom:'post'|'text',
  enabled, version, createdBy, updatedAt, stats:{ matched, lastMatchedAt? } }   // stats는 하루 한 번 묶어서
```
- 문자(SMS/RCS)로 오는 알림: 메시지 앱의 알림을 대상으로, `titleRegex`로 발신자 거름. **SMS 읽기 권한은 요청하지 않는다.**
- 정규식은 Dart `RegExp`와 Java `Pattern`에서 같은 뜻인 부분 집합만(이름 있는 그룹, 문자 클래스, 수량자. lookbehind·유니코드 속성 금지). 편집기가 검사.
- 저장소에는 **가짜 예시 템플릿만**(`assets/live_template_examples.json`).

### 12.4 두 구현의 일치 (Kotlin ↔ Dart)
- 템플릿 적용은 Kotlin(`TemplateMatcher`)과 Dart(`domain/live/template_matcher.dart`, 편집기 미리보기) 두 곳.
- **적합성 픽스처** `test/fixtures/live_conformance_fake.json`(가짜 문구 × 템플릿 → 기대 필드, liveId 포함)를 Dart 테스트와 Kotlin JUnit이 **둘 다** 읽는다.

### 12.5 뱅크샐러드로 확정 (중복 제거)
가져오기 ⑤단계, 덮는 기간 안 `provisional`에 대해:
1. 후보 = 같은 대상(카드 `cardId` ↔ 결제수단 `bsAliases`, 통장 `accountId`) & 같은 부호·금액 & 시각 차 ≤ 10분.
2. 여럿이면 시각 차 → 가맹점 유사도 순 **일대일** 짝.
3. 짝 → `matched` + `matchedTxKey`, 거래가 임시 상태 `cls`를 이어받음(`by:'live'`, 거래 쪽 수동 판단이 우선).
4. 짝 없음 + 기간 끝보다 `liveWindowDays`(3일) 이상 이전 → `orphan` + `liveOrphan` 질문. 끝 근처는 `provisional` 유지.
5. 취소 알림은 같은 금액 승인 알림과 먼저 상쇄(둘 다 `dismissed`).
**집계에서**: `at > banksaladCoveredUntil`인 `provisional`만 센다 → 두 번 세지 않는다. 화면엔 "알림 기준(미확정)".

### 12.6 권한 안내 흐름 (`features/live_setup/`)
1. 소개: 무엇을 읽고 무엇을 안 남기는지(12.2). "켜지 않아도 앱은 동작합니다".
2. **제한된 설정 허용**: 스토어 밖 설치 앱은 Android 13부터 알림 접근을 바로 못 켠다 → [앱 정보 열기](`ACTION_APPLICATION_DETAILS_SETTINGS`) → ⋮ → "제한된 설정 허용" 안내(가짜 화면 그림).
3. **알림 접근 허용**: [설정 열기](`ACTION_NOTIFICATION_LISTENER_SETTINGS`) → family_finance 켜기 → 돌아오면 상태 재확인.
4. 카드사·은행 앱 푸시가 켜져 있는지 확인 안내.
5. 템플릿 만들기: 쓰는 앱 고르기(앱 목록을 서버에 올리지 않음) → 학습 모드/붙여 넣기 → 대상 카드·통장 연결.
6. 상태 카드: "오늘 읽은 알림 3건, 맞지 않은 알림 1건 → 템플릿 고치기".
- 부부 각자 자기 폰에서 켠다. `financeMembers/{uid}.liveDevice`로 누가 켰는지 보인다.

### 12.7 잔액 직접 입력
- 출처 우선순위: 알림 잔액 > 직접 입력 > 추정(마지막 잔액 ± 이후 알림 입출금).
- **결제일 D-3 알림**: 그 결제일에 돈이 빠지는 통장 중 잔액이 24시간보다 오래된 것만 → 알림을 누르면 **잔액 입력 시트**(통장마다 숫자 칸 하나, 지난 값 미리 채움, [저장] 한 번 → 현금 점검 결과). 30초 목표.

---

## 13. 집계 — 클라이언트에서 한다

### 13.1 결정: Cloud Functions 안 씀
| | Cloud Functions | 클라이언트(채택) |
|---|---|---|
| 요금 | **Blaze 필요** | Spark 무료 |
| 일관성 | 서버 트리거 | 낙관적 잠금 |
| 오프라인 | 서버가 돌아야 반영 | 폰에서 바로 |
| 코드 | Node/TS 따로 | 순수 Dart 하나 |
사용자 2명·월 수백 건이면 계산은 밀리초. 집계는 원본에서 다시 만들 수 있는 캐시다.

### 13.2 낙관적 잠금
- 거래(뱅크샐러드·임시)를 바꾸는 모든 배치는 `months/{m}.version`을 `increment(1)`(Dart 리포지토리, Kotlin LiveWriter 둘 다).
- `recompute(m)`: version v 읽기 → 그 달 거래·임시 거래·계획·coupangDays·installments·구독 링크(캐시 우선) → `computeMonthSummary()` → 트랜잭션으로 version이 아직 v면 `summaryOf = v`로 쓰기, 아니면 재시도(최대 3).
- 화면은 `version != summaryOf`면 스스로 다시 계산. 계획을 바꾸면 적용 달들의 version을 올린다.
- `months/{m}`: `{version, summaryOf, computedAt, planVersionId, totals:{spend, spendExOneOff, income, byKind}, byItem:{<itemId>:{amount,count,oneOff}}, byCategory, unassigned, byCard, bySubscription, coupangUnknown, liveIncluded, installmentIn, openQuestions, checksum:{srcSpend}}`.

### 13.3 할부
1. 한 번에 찍힌 큰 결제 → "N개월 할부" 표시 → `installments/{txKey}: {months, startMonth, amount}`. 원래 달에서 빼고 시작 달부터 `amount/N`(나머지 원은 첫 달).
2. 매달 청구되는 할부 → 규칙으로 항목에 붙이고 나누지 않음.

### 13.4 월 집계 순서
```
active 거래 + (banksaladCoveredUntil 이후 provisional 임시 거래) → kind별 → spend 중
  쿠팡 치환 → 환불 상계 → 대리구매 상계 → 할부 배분 → 항목/분류/미분류/구독별 → 일회성 분리 → 카드별
검사: (치환·상계·배분 전) 원본 지출 합 == checksum.srcSpend
```

### 13.5 진단
- 항목마다 최근 3개월(일회성 제외) 평균 vs 계획. **줄일 것**: 평균 ≥ 계획 + `overPct`(10%) & 초과 ≥ `overMin`(3만 원), 상위 가맹점 근거. 구독 항목이면 "최근 결제가 없는데 살아 있는 구독"·"쓰지 않는 구독 후보"도.
- **여유**: 3개월 연속 계획의 `underPct`(80%) 이하 → 계획 낮추기 제안. 근거 기간을 항상 같이 쓴다.

### 13.6 카드 결제일과 현금 점검 (`domain/billing.dart`)
- 결제일이 주말·공휴일이면 다음 영업일. 공휴일 표 `assets/holidays_kr.json`(공공 데이터), `tool/holidays/`로 해마다 갱신. 표에 없는 해는 주말만 + "갱신 필요".
- 카드 청구 예상 = 이용 기간 안의 그 카드 결제(확정 + 미확정 임시 − 취소) 합.
- **결제일 현금 점검**(출금 통장별):
  ```
  필요 = Σ(이 통장에서 빠질 카드 청구 예상) + Σ(결제일까지 이 통장 자동이체 계획 항목)
  가용 = 최근 잔액(출처·시각 표시) − minBuffer
  부족 = max(0, 필요 − 가용)   →  "12/22(월) 생활비 통장 12만 원 부족"
  ```
  구독은 카드로 나가면 카드 청구에 이미 들어 있다(이중 계산 금지 — 계좌 자동이체 구독만 따로 더함).
- 정기결제 찾기: 같은 카드·비슷한 가맹점 3개월 이상 매달 → `recurringCandidate` 또는 `subNew`.

---

## 14. 무료 요금제(Spark) 유지

- **Cloud Functions 안 씀**, **Cloud Storage 안 씀**(2024년 9월 공지 이후 Spark 프로젝트는 Storage 버킷을 쓸 수 없다). 캡처는 폰에만, 아이콘은 각 폰이 조회·캐시.
- `ninedogs-b2628`이 지금 Spark인지 FIREBASE_SETUP 0단계에서 확인한다. 같은 프로젝트라 사용량을 Ninedogs와 나눠 쓴다(Ninedogs는 작다).
- 자동 백업(PITR)도 유료 → 앱 안 "가계 데이터 내보내기"(JSON), 가져오기 전 자동 권장. 구독·금고 백업은 Ninedogs 백업 기능이 그대로 한다.
- 예상: 읽기 하루 수천, 쓰기 하루 수백 → 한도의 10% 미만. 콘솔 사용량 월 1회 확인.

---

## 15. Ninedogs와 공존 (결정: 같은 프로젝트·양방향)

### 15.1 결정
- **같은 Firebase 프로젝트 `ninedogs-b2628`**, family_finance 안드로이드 앱만 추가 등록. 가구·초대 코드 공유.
- Ninedogs 앱과 family_finance **둘 다 유지**. 구독을 어느 쪽에서 고쳐도 다른 쪽에 반영(같은 문서를 두 앱이 실시간 구독).
- 처음 검토한 "새 프로젝트 + 백업 가져오기" 안은 사용자 결정으로 쓰지 않는다(Ninedogs를 은퇴시키는 전제였음).

### 15.2 양방향이 되는 원리
- 두 앱 모두 `households/{hid}/subscriptions`·`credentials`를 `snapshots()`로 본다(Ninedogs `watch()`가 이미 있음) → 한쪽이 쓰면 다른 쪽에 바로 보인다.
- 모양은 `ninedogs_core` 하나 → 직렬화 차이로 깨질 일이 없다.
- family_finance는 자기 필드를 안 넣으므로 Ninedogs가 문서를 통째 `set` 해도 잃을 것이 없다(확장 정보는 `subscriptionLinks`).

### 15.3 지금 Ninedogs 저장 방식의 문제와 최소 변경
Ninedogs `save(list)`는 **목록 전체를 맞춘다**: 서버 목록을 읽어 내 목록에 없는 문서를 지우고, 모든 구독을 `batch.set`으로 덮는다.
혼자 쓰거나 Ninedogs끼리는 실시간 구독 덕에 대체로 맞지만, 두 앱이 동시에 쓰면 이렇게 깨진다:
| 상황 | 결과 |
|---|---|
| family_finance가 구독을 새로 만든 직후, 스냅샷이 도착하기 전에 Ninedogs가 저장 | Ninedogs 목록에 없으니 **방금 만든 구독이 지워진다** |
| Ninedogs가 오프라인에서 편집 후 재연결 | 오프라인 동안 family_finance가 바꾼 다른 구독들이 **옛 값으로 덮인다**(전부 set) |
| 같은 구독을 양쪽이 동시에 편집 | 나중 쓴 쪽이 이김(이건 허용 — 트랜잭션으로 family_finance 쪽은 다시 읽고 적용) |
→ Ninedogs 쪽 **최소 변경(ROADMAP N2)**: 저장을 **문서 단위**로 — 바뀐 구독만 `set`, 지우기는 사용자가 지운 id만 `delete`("내 목록에 없으면 삭제" 제거). credentials도 같게. `meta/vault`는 없을 때만 생성.
이 변경이 들어간 Ninedogs(계약 v1 지원 버전)가 **모든 기기에 설치되기 전에는** family_finance가 공유 문서를 쓰지 않는다(5.6 `meta/clients`로 확인, 읽기는 됨).

### 15.4 로컬 우선·옵트인 동기화의 영향
- 동기화를 연결하지 않은 Ninedogs 기기의 구독은 Firestore에 없다 → family_finance에 안 보인다. **통합 전에 모든 Ninedogs 기기를 같은 가구에 연결**(FIREBASE_SETUP 1단계).
- Ninedogs가 연결할 때 로컬과 서버를 id 기준으로 합친다(UUID라 둘 다 산다) — 이 동작은 그대로 둔다.
- 부부가 각자 다른 가구를 만들어 둔 경우: 하나를 고르고, 다른 쪽은 Ninedogs에서 연결 끊기(서버 내용을 기기에 내려받음) → 고른 가구 코드로 연결(합쳐 올라감).
- Ninedogs에서 "연결 끊기"를 하면 그 기기만 빠진다(`arrayRemove`). family_finance 데이터와 무관.

### 15.5 스키마 영향 요약
| 문서 | 변화 |
|---|---|
| `households/{hid}` | 없음(가계 설정은 `financeMeta/root`) |
| `subscriptions`·`credentials` | 계약 필드 `cv`만 추가(core가 씀, 없으면 1). 그 외 없음 |
| `meta/contract`, `meta/clients` | 새로 생김(core 소유, 두 앱이 씀) |
| `inviteCodes` | 없음. 규칙에서 "가구 구성원만 코드 생성"(강화 ①) |
| 가계 컬렉션 [F] | 새로 생김. 구글 로그인 + 가계 구성원만 |
| 규칙 | 와일드카드 `{document=**}` → 명시 경로(강화 ②). Ninedogs 동작 불변 |

---

## 16. 오프라인

- Firestore 오프라인 캐시 켬, 크기 100MB.
- 되는 것: 보기, 질문 답하기, 분류·계획 고치기, 구독 편집(트랜잭션이라 연결 후 확정 — 오프라인이면 "연결되면 저장" 대기), 잔액 입력, 금고 열기(캐시에 암호문이 있으면), 알림 수집(Kotlin SDK 큐).
- 안 되는 것: 가져오기 커밋, 초대 만들기/쓰기, 되돌리기, 아이콘 새로 조회.
- 같은 거래를 둘이 고치면 나중 도착이 이긴다(필드 단위 `update`).
- 화면 위 "오프라인 — 보낼 변경 N건 대기 중" 띠.

---

## 17. 스키마 버전과 마이그레이션

두 종류의 버전이 있다.
| 버전 | 위치 | 누가 올리나 | 모르는 버전을 보면 |
|---|---|---|---|
| **공유 계약** `kContractVersion` | core, 문서 `cv`, `meta/contract` | Ninedogs 저장소(core X 버전) | 그 앱은 공유 문서 **쓰기 금지**, 읽기만(5.6) |
| **가계 스키마** `kSchemaVersion` | `financeMeta/root.schemaVersion` | family_finance | 가계 데이터 **쓰기 금지** + "업데이트해 주세요"(Kotlin LiveWriter도 멈춤) |

가계 스키마를 바꿀 때(시간표 앱 절차):
1. `kSchemaVersion` +1. 2. `fromJson`은 옛 모양도 읽게 기본값. 3. 새 앱이 처음 열 때 변환(청크·이어하기, `financeMeta.migration:{to, done, at}`) 후 버전 올림. 4. 옛 앱은 쓰기 막고 띠. 5. "옛 JSON 읽기" 테스트.
공유 계약을 바꿀 때: core에서 모양 변경 + `kContractVersion` +1 + 픽스처 추가 → Ninedogs 릴리스 → family_finance가 core 태그 올려 릴리스 → 두 앱이 다 깔린 뒤에 첫 쓰기가 `meta/contract`를 올린다. **필드 추가만** 허용(삭제·의미 변경 금지 — 옛 앱이 읽을 수 있어야 함).
- 그 밖의 버전: `txKeyVersion`, 묶음 JSON `version`, `liveTx.v`, 템플릿 `version`.
- 복구 도구(설정 › 고급): "월 색인 다시 만들기", "집계 전부 다시 계산", "임시 거래 대조 다시 하기", "구독 링크 고아 정리".

---

## 18. 테스트 전략

### 18.1 가짜 데이터 픽스처 (실데이터 절대 금지)
`tool/fake_data.dart`(시드 고정)가 지어낸 가구를 만든다: 가맹점 "OO마트·가나다카페·쿠팡", 카드 "가나다카드", 통장 "생활비 통장", 금액 무작위.
- `test/fixtures/banksalad_fake_*.xlsx`, `coupang_ocr_fake_*.txt`, `live_conformance_fake.json`, 기대 결과 JSON. 공유 문서 픽스처는 `package:ninedogs_core/fixtures.dart`(테스트용 마스터 암호로 만든 암호문 포함).
- 어려운 경우: 같은 시각·금액 다건, 엑셀 일련번호 날짜, 분류 변경, 금액 수정(키 변경), 행 삭제, 부분 기간, 쿠팡 헤더 잘림·연말연초·취소·캡처 겹침·S>T, 100만 원 이상, 할부, 알림 중복·승인 후 취소·알림만 있음, 해외 결제 구독, 해지 후 재결제, **Ninedogs가 쓴 cv 없는 문서**, **cv가 더 높은 문서**.
- 실제 파일 확인은 저장소 밖 폴더에서만, 결과는 숫자 요약만.

### 18.2 테스트 종류
| 대상 | 방식 | 위치 |
|---|---|---|
| 거래 키·diff·짝짓기 | 순수 단위 | `test/domain/` |
| 분류 엔진 | 표 기반 | `test/domain/classify_test.dart` |
| 쿠팡 | 픽스처 + 총액 보존 | `test/domain/coupang_test.dart` |
| 월 집계 | 원본 합 == checksum, 할부 합 == 원금, 임시 거래 이중 계산 없음 | `test/domain/summary_test.dart` |
| 구독 감시 | Finding 표 기반(가짜 구독 × 가짜 거래) | `test/domain/subscriptions/` |
| **공유 계약** | core 픽스처를 core 코덱으로 읽고 쓰면 같은 Map(왕복), `SharedSubscriptionStore`가 쓰는 Map의 키 집합 ⊆ 계약 키(+`cv`) — **자기 필드 금지를 테스트로 강제** | `test/data/shared_contract_test.dart` |
| **ContractGuard** | 높은 cv/`meta/contract`면 쓰기 거부, 옛 Ninedogs 기기 경고 | `test/data/contract_guard_test.dart` |
| **양방향 시뮬레이션** | `fake_cloud_firestore` 하나에 "Ninedogs식 저장(N2 이후)"과 family_finance 저장을 번갈아: 서로의 변경이 보존되는지, 동시 편집 트랜잭션 재시도 | `test/data/coexistence_test.dart` |
| 금고 | core 픽스처 암호문을 테스트 암호로 열기, family_finance가 만든 암호문을 core로 열기 | `test/data/vault_test.dart` |
| 알림 템플릿 | 적합성 픽스처(Dart + Kotlin JUnit) | `test/domain/live/`, `android/app/src/test/` |
| 임시 거래 대조 | 일대일, 취소 상쇄, 고아 기간, 판단 이어받기 | `test/domain/live/reconcile_test.dart` |
| xlsx 파서 | 가짜 픽스처 | `test/ingest/` |
| 가져오기 | 두 번 쓰기 0건, 중단 후 이어하기, 되돌리기 | `test/data/import_service_test.dart` |
| **보안 규칙** | 에뮬레이터: 가계(비구성원·익명·Ninedogs 코드만 가진 사람 거부, 가계 초대 흐름) + **Ninedogs 시나리오**(익명 로그인 → 가구 만들기 → 코드 생성 → 다른 익명이 코드로 참여 → 구독·계정·금고 set/delete → 나가기)가 그대로 통과 | `test_rules/` |
| 계층 규칙 | import 줄 검사 | `test/architecture_test.dart` |
| 화면 | 핵심 흐름 위젯 테스트(질문 큐, 잔액 입력, 읽기 전용 띠). 레이아웃은 실기기(플립·폴드) | `test/features/` |
- 규칙: **버그를 고치면 재현 테스트를 같이.** 커밋 전 `flutter analyze` 0건, `flutter test` 통과, Kotlin을 바꾸면 `./gradlew test`, 규칙을 바꾸면 규칙 테스트. core를 바꾸면 Ninedogs·family_finance 둘 다 테스트.

---

## 19. 릴리스 (GitHub 릴리스 APK + 앱 안 업데이트)

- 공개 저장소라 앱이 로그인 없이 `api.github.com/repos/<owner>/family_finance/releases`를 읽는다. pre-release 포함 가장 높은 태그.
- **태그(vX.Y.Z) == pubspec 버전.** `ota_update`로 덮어 설치(데이터 유지), 설치 권한 안내.
- 빌드: `flutter build apk --release --split-per-abi --target-platform android-arm64` → **arm64 APK 하나만** 자산으로.
- **서명은 처음부터 정식 keystore.** 구글 로그인은 서명 SHA-1이 Firebase에 등록돼야 하고, 키를 바꾸면 SHA 재등록 + 업데이트 불가가 겹친다. keystore·`key.properties`는 저장소 밖 백업.
- GitHub Actions 빌드 안 함. PC에서 빌드 → `gh release create`.
- applicationId `com.family.finance`(Ninedogs `com.jong0227.ninedogs`와 별개 앱).
- **core 태그를 올린 릴리스**는 노트에 "Ninedogs vX 이상과 같이 쓰세요"를 적는다. 계약 버전이 바뀌면 Ninedogs를 먼저 내놓는다.
- 릴리스 노트에 개인 정보 금지.

---

## 20. 개인정보 보호 체크리스트 (공개 저장소 — 두 저장소 모두)

저장소에 **절대 들어가면 안 되는 것**
- [ ] 실명, 가족 이름, 전화번호, 이메일, 주소
- [ ] 계좌번호·카드번호(일부라도), 우리가 쓰는 은행·카드 조합
- [ ] 실제 금액(월급, 대출, 보험료, 계획 금액, 잔액, 실제 구독 가격 목록), 실제 가맹점별 규칙, 쿠팡 상품 키워드
- [ ] 카드사·은행 알림 원문과 그걸로 만든 실제 템플릿 정규식
- [ ] 뱅크샐러드 xlsx, 쿠팡 캡처, OCR 결과, 묶음 JSON, Ninedogs 백업, Firestore 내보내기
- [ ] 마스터 암호, 서비스 계정 키, keystore, `key.properties`, `.env`
- [ ] 개인 데이터가 찍힌 스크린샷
- [ ] `ninedogs_core/fixtures.dart`의 암호문은 **테스트 전용 암호**로 만든 가짜(실제 금고 암호문 복사 금지)

장치
- [ ] `.gitignore`: `*.xlsx`(단 `test/fixtures/*_fake_*.xlsx` 예외), `*.bundle.json`, `*backup*.json`(단 `_fake_` 예외), `/private/`, `*.jks`, `*.keystore`, `key.properties`, `service-account*.json`, `*.png`(단 `assets/`·`docs/img/` 예외)
- [ ] 커밋 전 훅: 계좌번호·카드번호 형태, 픽스처 밖 큰 `원` 금액, 개인 금지어. **금지어 목록은 저장소 밖**(`%APPDATA%\family_finance\denylist.txt`). Ninedogs 저장소에도 같은 훅(core를 거기서 고치므로).
- [ ] 로그에 금액·가맹점·uid·알림 내용 금지. Kotlin 리스너는 예외 메시지에도 본문을 넣지 않는다.
- [ ] Firestore에도 최소한만: 전체 계좌번호·구글 이메일·사진·파일 이름·알림 원문 없음, 금고는 암호문만.
- [ ] 크래시 수집 도구 넣지 않음.
- [ ] 이슈·PR·커밋 메시지·릴리스 노트에 실제 금액·가맹점·카드사 문구 금지.
- [ ] 가계 탈퇴: `financeMembers` 삭제 + `financeMeta.memberUids`에서 제거, 알림 수집 끄고 네이티브의 householdId·템플릿 사본 삭제. 가구(구독)에서 나가기는 별도 버튼(Ninedogs 동작과 같음).

---

## 21. 추천 패키지 (2026-11-22 pub.dev 확인)

| 패키지 | 버전 | 용도 | 고른 이유 |
|---|---|---|---|
| `ninedogs_core` | git 태그 `ninedogs_core-v1.0.0` | 공유 모델·코덱·카탈로그·아이콘·금고 | 5.5 |
| `flutter_riverpod` | ^3.5.0 | 상태 관리 | Ninedogs 기준. 코드 생성 없이 |
| `firebase_core` | ^5.2.0 | Firebase | 최신. Ninedogs는 4.x — core가 Firebase에 의존하지 않아 두 앱 버전이 달라도 된다 |
| `cloud_firestore` | ^7.2.0 | DB, 오프라인 캐시, 트랜잭션 | 〃 |
| `firebase_auth` | ^7.1.0 | 로그인 | 〃 |
| `google_sign_in` | ^7.2.0 | 구글 계정(Credential Manager) | 7.x: `GoogleSignIn.instance.initialize(serverClientId:)` → `authenticate()`. 웹 클라이언트 ID 필요 |
| `cryptography` | ^2.9.0 | (core 경유) 금고 | Ninedogs와 같은 라이브러리 — 암호문 호환 |
| `local_auth` | ^3.0.2 | 생체인증 | Ninedogs와 같음 |
| `flutter_secure_storage` | ^11.2.0 | 생체인증용 키 | 앱별 저장(공유 안 함) |
| `flutter_local_notifications` | ^23.0.3 | 카드 결제일·D-3 잔액·(선택) 구독 알림 | |
| `timezone` / `flutter_timezone` | ^0.11.2 / ^5.1.1 | 알림 예약 시간대 | Ninedogs와 같음 |
| `cached_network_image` | ^4.0.7 | 구독 아이콘 | (core ui가 `flutter_cache_manager` 사용) |
| `url_launcher` | ^6.3.3 | 링크 | |
| `share_plus` | ^13.3.1 | 내보내기(카톡 공유) | |
| `google_mlkit_text_recognition` | ^1.0.3 | 한국어 OCR(기기 안) | 무료·오프라인. 안드로이드에 `com.google.mlkit:text-recognition-korean:16.0.1` |
| `image` | ^4.13.1 | 빈 줄 찾기·자르기 | 순수 Dart, `archive ^4` |
| `archive` | ^4.7.1 | xlsx(zip) | 직접 파서 |
| `xml` | ^7.1.0 | xlsx 시트 XML | |
| `crypto` | ^3.0.8 | 거래 키·liveId | |
| `collection` | ^1.19.1 | 다중집합·그룹 | |
| `intl` | Flutter가 고정하는 버전 | 원화·날짜 | core는 넓은 범위로 선언 |
| `fl_chart` | ^1.3.1 | 월 추이 | |
| `uuid` | ^4.6.0 | id | 세 앱 공통 |
| `shared_preferences` | ^2.5.6 | 이 폰 설정 | |
| `path_provider` | ^2.1.6 | 임시 폴더 | |
| `package_info_plus` | ^10.2.2 | 앱 버전 | |
| `http` | ^1.6.0 | 릴리스·아이콘·환율 | |
| `ota_update` | ^7.1.0 | APK 설치 | 시간표 방식 |
| dev: `flutter_lints` | ^6.0.0 | 린트 | 시간표 `analysis_options.yaml` |
| dev: `fake_cloud_firestore` | ^4.5.0 | 리포지토리·공존 시뮬레이션 | |
| dev: `firebase_auth_mocks` | ^0.16.0 | 세션 | |
| dev: `mocktail` | ^1.0.5 | 채널·서비스 가짜 | |
| 규칙 테스트(Node) | `@firebase/rules-unit-testing`, `firebase-tools` 15.x | 규칙 테스트·배포 | |
| Android(Kotlin) | Firebase BoM(FlutterFire와 같은 버전), JUnit | 알림 리스너·LiveWriter | |

**쓰지 않기로 한 것**
- `file_picker`(Ninedogs에서 win32 충돌), `image_picker`(인텐트로 대신).
- 알림 리스너 플러그인(`notification_listener_service`, `flutter_notification_listener`): Flutter 엔진이 떠 있어야 Dart로 전달하고 원문을 Dart까지 넘긴다. 원문을 네이티브에서 바로 버려야 해서 직접 쓴다.
- `excel`, `spreadsheet_decoder`: `archive ^3` 고정.
- `firebase_storage`(Spark 불가), `cloud_functions`(Blaze), `firebase_crashlytics`, `drift`/`sqflite`, 코드 생성 계열.

---

## 22. 새 기능을 붙이는 순서
1. 모델: 가계면 `domain/models/` + 가계 스키마 절차(17장). **구독·금고 모양이면 Ninedogs 저장소의 core에서**(계약 절차). Kotlin이 쓰는 문서면 Kotlin·적합성 픽스처도.
2. 계산은 `domain/`에 순수 함수 + 테스트(총액 보존 불변식).
3. 저장은 리포지토리 메서드 + `fake_cloud_firestore` 테스트. 공유 문서는 `data/shared/`만.
4. 상태는 `app/providers/`. 5. 화면은 `features/<기능>/`. 6. 권한이면 `Permissions`.
7. 새 하위 컬렉션이면 `firestore.rules`(가계 목록) + 규칙 테스트 + 인덱스 — Ninedogs 시나리오도 다시 통과하는지.
8. `docs/ROADMAP.md` 체크, 필요하면 이 문서 갱신.
