# Firebase 설정

family_finance는 **Ninedogs와 같은 Firebase 프로젝트 `ninedogs-b2628`** 을 쓴다(ARCHITECTURE 15장).
새 프로젝트를 만들지 않는다. 이 프로젝트에 **안드로이드 앱을 하나 더 등록**하고, 구글 로그인을 켜고, 규칙을 family_finance 저장소에서 배포한다.

⚠️ 규칙 파일은 프로젝트에 하나뿐이다. 배포하면 Ninedogs 규칙까지 통째로 바뀐다.
**배포 원본은 `family_finance/firestore.rules` 하나**이고, 배포 전에 `test_rules`(Ninedogs 시나리오 포함)가 통과해야 한다.

사용자가 직접 해야 하는 일은 ☑ 표시. 나머지는 Claude가 저장소에서 준비한다.

---

## 0. 프로젝트 상태 확인 ☑
1. https://console.firebase.google.com → `ninedogs-b2628` 선택.
2. 왼쪽 아래 **요금제가 Spark(무료)** 인지 확인. Blaze면 그대로 써도 되지만, 이 앱은 Spark 한도 안에서 설계했다(Functions·Storage 안 씀).
3. **Firestore Database**가 이미 있는지, 위치(region)가 어디인지 적어 둔다(바꿀 수 없음, 확인만).
4. **Authentication → 로그인 방법**에 익명이 켜져 있는지 확인(Ninedogs가 씀 — 끄지 말 것).

## 1. 통합 전: Ninedogs 기기 동기화 확인 ☑
family_finance는 Firestore에 있는 구독만 본다. Ninedogs는 **로컬 우선·옵트인 동기화**라, 연결하지 않은 폰의 구독은 서버에 없다.

1. **각 폰의 Ninedogs** → 설정 → 동기화(연결) 화면:
   - "연결됨"과 **초대 코드**가 보이는지. 두 폰의 코드가 **같은지**.
   - 연결 안 됨 → [연결] → 상대 폰의 코드 입력(로컬 구독이 서버와 합쳐진다).
   - 두 폰 코드가 **다름**(각자 가구를 만듦) → 하나를 고른다. 다른 폰에서 [연결 끊기](서버 내용이 그 폰에 내려온다) → 고른 코드로 [연결](합쳐 올라간다).
2. **콘솔 → Firestore → 데이터**에서 확인:
   - `households` 아래 해당 가구 문서 하나. `memberUids` 개수 == Ninedogs 기기 수.
   - 그 가구의 `subscriptions` 문서 수 == 각 폰 Ninedogs 구독 목록 수(두 폰이 같은 수를 보여야 함).
   - 금고를 쓰면 `meta/vault`가 있고, `credentials` 수 == 계정 정보를 저장한 구독 수.
   - 쓰지 않는 옛 가구 문서가 남아 있으면 지우지 말고 적어 두기만 한다(나중에 정리).
3. 안전망: 한 폰에서 Ninedogs **백업 내보내기** → 파일을 저장소 밖(예: OneDrive 개인 폴더)에 보관.
4. **Ninedogs N3 버전**(문서 단위 저장 + 계약 가드, ROADMAP N2·N3)을 **두 폰 모두** 설치하기 전에는 family_finance에서 구독을 편집하지 않는다.
   family_finance는 `meta/clients`로 이를 확인하고, 옛 Ninedogs가 있으면 구독 편집을 막고 알려 준다.

## 2. 안드로이드 앱 등록 ☑
1. 콘솔 → 프로젝트 설정(톱니) → **앱 추가 → Android**.
2. 패키지 이름: **`com.family.finance`** (`android/app/build.gradle.kts`의 applicationId와 같아야 함. 나중에 못 바꿈).
3. 앱 닉네임: family_finance.
4. SHA-1은 3단계에서 넣어도 된다(여기서 비워 두고 진행 가능).
5. `google-services.json` 다운로드 → **`C:\dev\family_finance\android\app\google-services.json`**.
   이 파일에는 Ninedogs 앱 정보도 함께 들어 있다(같은 프로젝트). 비밀은 아니라 공개 저장소에 커밋한다(4단계에서 키 제한).

## 3. 서명 키와 SHA 등록 ☑ (구글 로그인에 필수)
구글 로그인은 **앱 서명 인증서의 SHA-1**이 Firebase에 등록돼 있어야 동작한다. 처음부터 정식 키로 시작한다.

1. 릴리스 keystore 만들기(한 번만, 남편 노트북에서). Claude가 명령을 준비하고, **비밀번호는 직접 입력**:
   ```powershell
   & "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v -keystore "$env:USERPROFILE\keys\family_finance-release.jks" `
     -alias family_finance -keyalg RSA -keysize 2048 -validity 10000
   ```
   - keystore는 **저장소 밖**(`%USERPROFILE%\keys\`)에 두고, 별도 백업(USB 등) 한 벌.
   - `android/key.properties`(저장소에 안 올라감, `.gitignore`)에 경로·별칭을 적는다. 비밀번호도 이 파일에만.
2. SHA 확인:
   ```powershell
   & "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\keys\family_finance-release.jks" -alias family_finance
   & "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android
   ```
   (프로젝트가 생긴 뒤에는 `cd android; .\gradlew signingReport`로 둘 다 한 번에 볼 수 있다.)
3. 콘솔 → 프로젝트 설정 → `com.family.finance` 앱 → **디지털 지문 추가**: 릴리스 SHA-1, 릴리스 SHA-256, 디버그 SHA-1(개발용). 다른 PC에서 디버그 빌드를 하면 그 PC의 디버그 SHA-1도 추가.
4. 지문을 추가한 뒤 **`google-services.json`을 다시 내려받아** 덮어쓴다(OAuth 클라이언트 정보가 갱신됨).

## 4. 구글 로그인 켜기 ☑
1. 콘솔 → **Authentication → 로그인 방법 → 새 제공업체 추가 → Google** → 사용 설정.
2. 프로젝트 공개용 이름(동의 화면에 보임)과 **지원 이메일** 선택 → 저장. 익명 로그인은 그대로 둔다.
3. 같은 화면의 **웹 SDK 구성 → 웹 클라이언트 ID**를 복사해 Claude에게 알려 준다(비밀 아님).
   `google_sign_in` 7의 `serverClientId`로 쓴다. `google-services.json` 안 `oauth_client` 중 `client_type: 3` 값과 같다.
4. (권장) Google Cloud 콘솔 → API 및 서비스 → 사용자 인증 정보 → 이 프로젝트의 **Android API 키**:
   애플리케이션 제한 = Android 앱, 패키지 `com.jong0227.ninedogs`와 `com.family.finance` + 각 SHA-1 추가.
   ⚠️ Ninedogs 패키지·SHA를 빠뜨리면 **Ninedogs가 멈춘다.** Ninedogs의 SHA-1은 Ninedogs 프로젝트 설정 화면에 등록된 값을 그대로 쓴다.

## 5. 보안 규칙·인덱스 배포 (Claude가 준비, 실행은 승인 후)
1. Firebase CLI 설치·로그인(한 번만) ☑ — 브라우저에서 계정 로그인은 직접:
   ```powershell
   npm install -g firebase-tools
   firebase login
   ```
   PowerShell에서 npm 스크립트 실행이 막히면 `firebase.cmd`로 실행.
2. 저장소 연결: `C:\dev\family_finance`에서 `firebase use --add` → `ninedogs-b2628` 선택(별칭 `default`). `.firebaserc`가 생긴다(커밋해도 됨).
3. **배포 전 테스트**: `cd test_rules; npm test` (Firestore 에뮬레이터 — JDK 필요).
   가계 시나리오와 **Ninedogs 시나리오**(익명 로그인 → 가구 만들기 → 코드 생성 → 다른 익명이 코드로 참여 → 구독·계정·금고 쓰기/지우기 → 나가기)가 모두 통과해야 한다.
4. 배포 직전에 **지금 콘솔에 있는 규칙을 복사해** `private/rules-backup-<날짜>.rules`(저장소 밖이거나 `.gitignore` 대상)로 보관 — 되돌릴 때 쓴다.
5. 배포:
   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes --project ninedogs-b2628
   ```
6. 배포 후 **Ninedogs 실기기 점검** ☑: 두 폰에서 Ninedogs를 열어 구독 목록이 보이는지, 구독 하나를 고쳐 상대 폰에 반영되는지, 금고가 열리는지.
   하나라도 안 되면 4단계 백업 규칙을 콘솔 → Firestore → 규칙에 붙여 넣고 게시해 즉시 되돌린 뒤 Claude에게 알린다.
- Ninedogs 저장소의 `firestore.rules`는 더 이상 배포하지 않는다(ROADMAP N4에서 안내 문구로 교체).

## 6. 확인
1. 폰 A(family_finance): 구글 로그인 → **Ninedogs 초대 코드** 입력 → 구독 목록이 Ninedogs와 같게 보이면 성공 → [가계 시작].
2. 폰 A: 더보기 → 가계 초대 코드 만들기(8자리, 48시간).
3. 폰 B(family_finance): 구글 로그인 → **가계 초대 코드** 입력 → 가구와 가계에 함께 들어감.
4. 폰 A에서 계획 항목을 추가하면 폰 B에 바로 보이는지.
5. 콘솔에서 확인: `households/{가구}` 문서에 **새 필드가 생기지 않았는지**(가계 설정은 `financeMeta/root`에), `memberUids`에 구글 계정 uid 2개가 늘었는지.
6. (N3 설치 후) Ninedogs에서 구독 가격을 바꾸면 family_finance에, family_finance에서 바꾸면 Ninedogs에 반영되는지.

## 7. 평소 운영
- 콘솔 → Firestore → **사용량**을 월 1회 확인(읽기 50,000·쓰기 20,000/일 한도를 Ninedogs와 같이 씀).
- 규칙을 바꿀 땐 항상 `family_finance/firestore.rules` → `test_rules` → 백업 → 배포 → Ninedogs 실기기 점검 순서.
- 구성원 정리: Ninedogs를 지웠다 다시 깔면 익명 uid가 새로 생겨 `memberUids`에 옛 uid가 남는다. 쓰지 않는 uid는 family_finance 가구 설정 화면(owner)에서 확인 후 제거.
- 서비스 계정 키(관리자 업로드, M6 선택)는 필요할 때만 만들고 저장소 밖에 둔다.
