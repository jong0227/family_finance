# 로드맵

각 단계는 "부부가 실제로 써 볼 수 있는 상태"로 끝낸다. 단계를 건너뛰어 기능을 붙이지 않는다.
모든 단계의 공통 완료 기준: `flutter analyze` 0건, `flutter test` 전부 통과, 규칙을 바꿨으면 `test_rules` 통과,
개인정보 체크리스트(ARCHITECTURE 20장) 확인, 실기기(플립·폴드) 한 번 이상 확인, 이 문서 체크.

Ninedogs 저장소 쪽 작업은 **N 단계**로 따로 적었다. N 단계는 Ninedogs 앱의 동작을 바꾸지 않는 최소 변경만 한다.

```
N0 ─▶ N1 ─▶ N2 ─▶ N3 ───────────┐
            │                   ▼
M0 ─────────┴──▶ M1 ─▶ M2 ─▶ M3(구독: N3 필요) ─▶ M4 ─▶ M5 ─▶ M6
```

---

## N0 — Ninedogs 동기화 상태 확인 (코드 변경 없음)
- [ ] 모든 Ninedogs 기기가 같은 가구에 연결돼 있는지 확인(FIREBASE_SETUP 1단계)
- [ ] 연결 안 된 기기는 연결(로컬 구독이 합쳐 올라감), 가구가 둘이면 하나로 합침
- [ ] Ninedogs에서 백업 내보내기 한 번(안전망). 파일은 저장소 밖 보관
**완료 기준**: 콘솔에서 가구 1개, `memberUids`에 Ninedogs 기기 수만큼 uid, `subscriptions` 문서 수 == 각 폰 구독 수.

## N1 — `packages/ninedogs_core` 추출 (Ninedogs 저장소)
- [ ] `packages/ninedogs_core/lib/model.dart`: Money, BillingCycle, Subscription·PricePoint·SubscriptionPeriod, Credential·StoredCredential·EncryptedPayload, VaultMetadata, Household, 코덱(Map ↔ 모델), 가격 이력 계산(누적 지출·결제 예정일·`addMonths`), 카탈로그 데이터·billing_lookup(내용 변경 없음), VaultCrypto, `kContractVersion = 1`
- [ ] `lib/ui.dart`: IconResolver, IconPalette, ServiceIcon
- [ ] `lib/fixtures.dart`: 계약 픽스처(가짜 구독 JSON, 테스트 암호로 만든 금고 암호문)
- [ ] core는 Firebase·Riverpod에 의존하지 않는다. `intl`은 넓은 범위
- [ ] Ninedogs 앱은 `path:` 의존으로 바꾸고 기존 테스트 97개를 core로 옮기거나 그대로 통과
- [ ] 태그 `ninedogs_core-v1.0.0`
**완료 기준**: Ninedogs 동작·저장 데이터 바이트 단위로 변화 없음(코덱 왕복 테스트), Ninedogs 테스트 전부 통과.

## N2 — 문서 단위 저장 (Ninedogs 저장소)
- [ ] `FirestoreSubscriptionRepository.save(list)` → 바뀐 구독만 `set`, 사용자가 지운 id만 `delete`("내 목록에 없으면 삭제" 제거)
- [ ] credentials도 같게. `meta/vault`는 없을 때만 생성(트랜잭션)
- [ ] 회귀 테스트: 다른 앱이 만든 구독이 Ninedogs 저장 뒤에도 살아 있음, 오프라인 편집 후 다른 구독을 덮지 않음
**완료 기준**: `fake_cloud_firestore`에서 "외부 작성자" 시뮬레이션 테스트 통과.

## N3 — 계약 버전 가드 + 기기 표시 (Ninedogs 저장소)
- [ ] core 코덱이 `cv` 필드를 쓴다(없으면 1로 읽음)
- [ ] `ContractGuard`: `meta/contract.version` 또는 문서 `cv`가 더 높으면 공유 문서 쓰기 금지 + "업데이트해 주세요" 띠
- [ ] 실행 때 `meta/clients`의 자기 칸 갱신(`app:'ninedogs'`, 앱 버전, cv)
- [ ] Ninedogs 릴리스(예: v1.6.0) → **모든 기기에 설치**
**완료 기준**: 두 폰 모두 새 버전, `meta/clients`에 두 기기 모두 `cv:1`.

## N4 — 규칙 원본 이전 (Ninedogs 저장소, M0와 함께)
- [ ] Ninedogs `firestore.rules`를 "배포 원본은 family_finance/firestore.rules" 안내 + 사본으로 교체
- [ ] Ninedogs `CLAUDE.md`에 공존 규칙 요약(공유 문서는 core 코덱만, 규칙은 family_finance에서 배포)
**완료 기준**: 규칙 배포 경로가 하나.

## N(선택) — 나중에 검토
- [ ] Ninedogs도 구글 로그인으로 옮기면 가구 규칙을 uid·초대 만료 기준으로 더 좁힐 수 있음(사용자 결정 필요)
- (하지 않음) 가입일 찾기 안내 추가 — 사용자 결정으로 제외

---

## M0 — 기반
- [ ] Flutter 프로젝트 `com.family.finance`, 시간표 `analysis_options.yaml`, Riverpod 3, 계층 폴더, `test/architecture_test.dart`
- [ ] `ninedogs_core` git 의존(N1 태그). core 없이 못 가는 화면은 M3까지 비움
- [ ] Firebase: `ninedogs-b2628`에 앱 등록, 구글 로그인, 정식 keystore + SHA 등록(FIREBASE_SETUP)
- [ ] 세션: 구글 로그인 → Ninedogs 초대 코드로 가구 참여 / 가구가 없으면 core 모양으로 만들기 → 가계 켜기(`financeMeta/root`) → 가계 초대 코드로 배우자 참여
- [ ] `firestore.rules` 원본(6.3) + `test_rules`(가계 시나리오 + **Ninedogs 시나리오**) → 배포
- [ ] 메모리 저장소(테스트·웹 미리보기), 오프라인 띠
- [ ] 디자인 시스템 토큰·컴포넌트(DESIGN_SYSTEM.md), 앱 틀(탭 구성은 디자인 결정을 따름)
- [ ] 앱 안 업데이트(GitHub 릴리스), 첫 pre-release
- [ ] 개인정보 장치: `.gitignore`, pre-commit 훅(금지어 목록은 저장소 밖), `tool/fake_data.dart` 골격
**완료 기준**: 두 폰이 구글 로그인 → 같은 가구·같은 가계에 들어감. Ninedogs 앱이 규칙 배포 후에도 연결·편집·금고 정상(실기기). 비구성원·익명 계정으로 가계 컬렉션 접근이 거부됨(규칙 테스트).

## M1 — 뱅크샐러드 가져오기 + 거래 목록
- [ ] 인텐트로 xlsx 받기(공유 + 문서 선택기)
- [ ] 직접 xlsx 파서, "가계부 내역" 머리글 이름 매칭, 날짜 일련번호
- [ ] 거래 키(다건 n), 지문, txIndex
- [ ] 파이프라인 ①~⑨, 미리보기, 청크 커밋, 이어하기, 되돌리기(스택), 동시 가져오기 잠금
- [ ] 수정 추정 짝짓기, 사라진 거래 처리
- [ ] 기본 규칙만으로 kind 분류, 월 집계(낙관적 잠금), 월 거래 목록·상세
- [ ] PC CLI `tool/import_cli.dart` → 묶음 JSON → 앱 가져오기
- [ ] 가짜 xlsx 픽스처 + 속성 기반 재내보내기 테스트
**완료 기준**: 1년치 가짜 파일을 두 번 넣으면 두 번째 쓰기 0건. 일부를 고친 재내보내기 후 DB == 마지막 내보내기. 되돌리기 후 원상태. 실제 파일로 저장소 밖에서 돌려 월 합계가 뱅크샐러드와 1원까지 같음.

## M2 — 계획·분류 엔진·확인 질문·진단
- [ ] 계획 편집(구분 → 지출 분류 → 항목, 월 계획 금액, 카드·통장·결제일), 계획 버전(그 달부터 적용)
- [ ] 분류 규칙 엔진 + 규칙 편집, 규칙 변경 일괄 적용 미리보기
- [ ] 질문 큐(한 번에 하나, 금액순, "다음부터도 이렇게"), 동시 답 처리
- [ ] 일회성(100만 원 이상) 자동·수동, 할부(나눠 보기), 환불·대리구매 짝
- [ ] 홈: 이번 달 항목별 계획 대비 실제, 항목별 월 추이 그래프, 줄일 것/여유 진단(근거 기간 표시)
**완료 기준**: 실제 1년치(저장소 밖)로 질문에 답하고 나면 다음 가져오기에서 새 질문이 새 가맹점 것만 나옴. 총액 보존 불변식 테스트 통과.

## M3 — 카드·통장·결제일 + 구독 (N3 완료 필요)
- [ ] 카드(결제일·이용 기간·출금 통장), 통장(별칭·끝 4자리 선택), 뱅크샐러드 결제수단 별칭 연결
- [ ] 영업일 보정(공휴일 표), 카드별 청구 예상, 결제일 달력
- [ ] 구독 탭: 공유 구독 목록(실시간, Ninedogs와 같은 데이터), 편집(core 모델·트랜잭션·merge), `ContractGuard` 읽기 전용 띠, `meta/clients` 옛 기기 경고
- [ ] `subscriptionLinks`: 카드·계획 항목·matcher, `catalog_aliases`
- [ ] 정기결제 감시: 새 정기결제·금액 변동(인상/정정)·해지 후 재결제·결제 없음 질문
- [ ] 누적 지출 계산값 vs 실제값, 금고 열기(같은 마스터 암호), 생체인증
- [ ] 구독 알림 담당 설정(기본: Ninedogs 설치 폰은 Ninedogs)
- [ ] 공존 시뮬레이션 테스트(ARCHITECTURE 18.2)
**완료 기준**: Ninedogs에서 가격을 바꾸면 family_finance에 1~2초 안에 보이고, 반대도 같음. 한쪽에서 만든 구독이 다른 쪽 저장 뒤에도 남음. family_finance가 쓴 구독 문서에 계약 밖 필드가 없음(테스트 + 콘솔 확인). 같은 마스터 암호로 두 앱 모두 계정 정보가 열림.

## M4 — 실시간 수집 + 결제일 현금 점검
- [ ] Kotlin 알림 리스너(허용 패키지만, 원문 즉시 폐기), TemplateMatcher, LiveWriter(가계 구성원·스키마 확인)
- [ ] 템플릿 편집기(붙여 넣기·학습 모드, 정규식 부분 집합 검사, 미리보기), 가짜 예시 템플릿
- [ ] 권한 안내 흐름(제한된 설정 → 알림 접근 → 상태 카드)
- [ ] 임시 거래 목록·분류, 뱅크샐러드 대조(일대일·취소 상쇄·고아), 집계에 "미확정" 반영
- [ ] 잔액(알림·직접 입력·추정), 결제일 현금 점검 화면, D-3 잔액 입력 알림 → 30초 입력 시트
- [ ] Dart ↔ Kotlin 적합성 픽스처 테스트(JUnit 포함)
**완료 기준**: 실기기에서 가짜가 아닌 실제 알림으로 임시 거래가 배우자 폰에 뜨고(원문은 어디에도 없음 — 콘솔·로그 확인), 다음 뱅크샐러드 가져오기에서 중복 없이 확정됨. 결제일 현금 점검이 잔액 기준 시각과 함께 부족 금액을 보여 줌.

## M5 — 쿠팡 주문내역 OCR
- [ ] 캡처 받기(공유 SEND_MULTIPLE + 선택기), 빈 줄 자르기(isolate), ML Kit 한국어
- [ ] 파서(날짜 이어받기, 배송일−1, 요일로 연도), 캡처 합치기(다중집합 합집합), 결제 맞춰 쪼개기(S>T 조합 제거)
- [ ] 쿠팡 날짜별 결과 화면, 상품 → 항목 규칙(사용자 규칙), 미확인 잔액 표시
- [ ] PC OCR 레코드(묶음 JSON `coupangRecords`) 경로
**완료 기준**: 가짜 OCR 픽스처 전부 총액 보존. 실제 캡처(저장소 밖)로 Python 판과 같은 날짜별 결과(또는 더 나은 연도 추정).

## M6 — 운영·마무리
- [ ] 가계 데이터 내보내기/복원(JSON), 가져오기 전 자동 백업 권장
- [ ] 복구 도구(월 색인 재구축, 집계 재계산, 대조 다시, 고아 링크 정리)
- [ ] (선택) 관리자 직접 업로드 CLI(서비스 계정, 가계 컬렉션만)
- [ ] 사용량 점검(콘솔, 월 1회), 실기기 폴드 펼침 레이아웃 정리
- [ ] 정식 릴리스(main 병합 후 pre-release 해제)
**완료 기준**: 한 달 동안 부부가 매일 쓰면서 Spark 한도 10% 미만, 데이터 문제로 되돌리기가 필요했던 일이 있으면 재현 테스트가 들어가 있음.
