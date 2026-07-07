# 📱 Wamagotchi — Phase 1 + Phase 2(비주얼)

글쓰기로 정령을 키우는 생산성 다마고치. 이 폴더는 Flutter 앱 프로젝트입니다.

- 기획 문서: [`../docs/Wamagotchi_기획서.md`](../docs/Wamagotchi_기획서.md) · [`../docs/Wamagotchi_게임시스템_기획서.md`](../docs/Wamagotchi_게임시스템_기획서.md)
- 이 README는 "AI 협업 워크플로 6단계(문서화)" 원칙에 따라, 새 대화에서 AI에게 보여주면
  프로젝트 상태를 바로 이해할 수 있도록 유지합니다. **기능이 추가될 때마다 갱신하세요.**

---

## ✅ 현재 구현 상태 (Phase 1 MVP + Phase 2 비주얼)

| 기능 | 상태 |
|---|---|
| 메모 작성/수정/목록/삭제 + 로컬 영속화 | ✔ |
| 저장 시 "새로 늘어난 글자 수(공백 제외)" → 마나·경험치 (+1/자) | ✔ |
| 레벨 곡선 `50 + 12×(Lv−1)`, 연속 레벨업, 최대 Lv.100 | ✔ |
| 포만감: 100자당 +8%p (오늘 첫 저장 2배), 시간당 −3%p 자연 감소 | ✔ |
| 알(Lv.1~4) → Lv.5 부화 → **유저가 이름 직접 입력** (검증·이름 뽑기 🎲) | ✔ |
| 기분 3종 (평온/시무룩/기절) + 텍스트 얼굴 | ✔ |
| 상태창 로그 (성장·부화·첫 끼니 메시지) | ✔ |
| 레트로 LCD 색상 팔레트 (#8BAC0F / #0F380F) | ✔ |
| 게임 로직 단위 테스트 (`test/game_engine_test.dart`) | ✔ 작성됨 |
| **— Phase 2 (비주얼) —** | |
| 레벨별 스프라이트 교체 매핑 (알→유년기→성장→진화, `sprites.dart`) | ✔ |
| 스프라이트 위젯 + 에셋 미탑재 시 텍스트 얼굴 폴백 (`pet_sprite.dart`) | ✔ |
| 상태창을 스프라이트 무대 중심으로 재구성 | ✔ |
| 갈무리 폰트 배선 (`fontFamily: 'Galmuri'` + 시스템 폴백) | ✔ (폰트 파일은 사용자 투입) |
| **Higgsfield PNG · Galmuri .ttf 실제 파일 투입** | ⬜ 사용자 작업 → `assets/README.md` 참조 |

> ⚠️ **검증 상태**: 이 코드는 클라우드 세션에서 작성되었고, 해당 환경의 네트워크 정책이
> Flutter SDK 다운로드(storage.googleapis.com)를 차단해 **빌드/테스트 실행은 아직 못 했습니다.**
> 아래 "실행 방법"의 3~4단계(`flutter pub get` → `flutter test`)가 최초 검증 절차입니다.
> 에러가 나오면 에러 메시지를 그대로 AI에게 붙여넣어 진단을 요청하세요.

## 📁 프로젝트 구조 (MVVM — 관심사 분리)

```
wamagotchi/
├── pubspec.yaml            # 의존성: provider(상태 관리), shared_preferences(로컬 저장)
├── lib/
│   ├── main.dart           # 앱 진입점 + 레트로 LCD 테마
│   ├── data/
│   │   ├── balance.dart    # ★ 모든 밸런스 수치 (여기만 고치면 수치 튜닝 끝)
│   │   ├── palette.dart    # LCD 색상 팔레트
│   │   └── sprites.dart    # 레벨→스프라이트 매핑 (Phase 2)
│   ├── logic/
│   │   └── game_engine.dart # ★ 순수 게임 규칙 (Flutter 무관 → 테스트 쉬움)
│   ├── models/
│   │   ├── pet_state.dart  # 정령 상태 (이름/레벨/경험치/마나/포만감/기분)
│   │   ├── memo.dart       # 메모 (제목/본문/글자수)
│   │   └── feed_result.dart # 저장 1회의 정산 결과
│   ├── services/
│   │   └── storage_service.dart # 로컬 저장소 입출력 (여기만 바꾸면 DB 교체 가능)
│   ├── viewmodels/
│   │   ├── game_viewmodel.dart  # 정산·포만감 타이머·부화·이름 짓기
│   │   └── memo_viewmodel.dart  # 메모 CRUD, "늘어난 글자 수" 계산
│   └── views/
│       ├── main_screen.dart     # 상태창+에디터 스플릿 뷰, 저장 버튼, 이름 다이얼로그
│       ├── memo_list_screen.dart
│       └── widgets/
│           ├── pet_status_panel.dart # 상단 상태창 (스프라이트 무대)
│           └── pet_sprite.dart       # 레벨별 스프라이트(+폴백) (Phase 2)
├── assets/
│   ├── README.md           # 스프라이트·폰트 넣는 법 (Phase 2)
│   └── sprites/            # egg/hatchling/grown/evolved.png (사용자 투입)
└── test/
    └── game_engine_test.dart    # 게임 규칙 단위 테스트
```

**핵심 데이터 흐름**: 저장 버튼 → `MemoViewModel.saveMemo()`가 늘어난 글자 수 반환
→ `GameViewModel.feed(글자수)`가 마나/경험치/포만감 정산 → 상태창 자동 갱신.

## 🚀 실행 방법 (처음이라면 순서대로)

1. **Flutter SDK 설치**: https://docs.flutter.dev/get-started/install 에서 OS에 맞게 설치
   (설치 후 터미널에서 `flutter doctor` 실행해 확인)
2. **플랫폼 폴더 생성** (최초 1회 — android/ios 폴더는 자동 생성되는 파일이라 저장소에 없음):
   ```bash
   cd wamagotchi
   flutter create --org com.oldtower --platforms android,ios .
   ```
3. **의존성 설치**: `flutter pub get`
4. **테스트 실행** (게임 규칙 검증): `flutter test`
5. **앱 실행**: 에뮬레이터나 휴대폰(USB 연결) 준비 후 `flutter run`
   - 크롬으로 빠르게 보려면: `flutter run -d chrome`

## 🎮 플레이 확인 시나리오

1. 앱 실행 → 상태창에 `( ● ) 이름 없는 알 Lv.1`
2. 에디터에 아무 글이나 300자쯤 쓰고 [저장] → 마나/경험치 상승, 연속 레벨업
3. Lv.5 도달 → "정령이 깨어났어요!" **이름 입력 다이얼로그** (🎲로 랜덤 추천)
4. 앱 완전 종료 후 재실행 → 메모·정령 상태 유지 확인
5. 같은 메모에서 글자를 지우고 저장 → 마나 +0 (벌점 없음) 확인

## 🗺️ 다음 단계

- **Phase 2 (비주얼)** — 코드·배선 완료. 남은 일: `assets/README.md`대로 **스프라이트 PNG + 갈무리 .ttf 투입**(사용자 작업)
- **Phase 3 (방치 모험)**: 탐험 틱·던전 로그 — `게임시스템_기획서.md` 5장 참조
- 백로그: 붙여넣기 감액 등 어뷰징 방어(시스템 기획서 4.4), 개명 아이템, 기분 '신남', Flutter 스프라이트 idle 애니메이션
