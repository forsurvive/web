# 🎨 Wamagotchi 에셋 (Phase 2)

- ✅ **정령 스프라이트 4종: 포함 완료.** 사용자가 만든 원화(`../art_src/`)를
  잉크색(#0F380F) 2톤·투명 배경·256×256으로 보정한 파일이 `sprites/`에 들어 있습니다.
- ⬜ **갈무리 폰트: 아직 사용자 투입 필요** (아래 2번 안내).
- 에셋이 없어도 앱은 정상 실행됩니다 — 스프라이트는 텍스트 얼굴로, 폰트는 시스템 폰트로 자동 대체.

---

## 1. 정령 스프라이트 (`assets/sprites/`) — ✅ 완료

레벨에 따라 자동으로 교체됩니다 (`lib/data/sprites.dart` 매핑).
원화 교체 시: 새 그림을 `art_src/`에 두고 아래 규격으로 보정해 같은 파일명으로 덮어쓰면 됩니다.

| 파일명 | 등장 레벨 | 그림 |
|---|---|---|
| `egg.png` | Lv.1~4 | 금 간 알 |
| `hatchling.png` | Lv.5~14 | 부화한 꼬마 정령(그림자 유령) |
| `grown.png` | Lv.15~29 | 뿔 달린 성장형 정령 |
| `evolved.png` | Lv.30~ | 후드를 쓴 도적 정령 |

**만드는 법 (Higgsfield):** 아래 프롬프트로 생성 → 배경 제거(remove background) → **정사각형 투명 PNG**로 저장 →
위 파일명으로 이 폴더에 저장. (권장 크기 128×128 또는 256×256, 픽셀이 뭉개지지 않게 **선명한 도트** 유지)

```
egg      : 1-bit pixel art sprite, pure black on solid white, retro tamagotchi style,
           a mysterious egg with cracks, chunky pixels, solid white background
hatchling: ...a cute tiny shadow ghost with two round eyes, wavy bottom...
grown    : ...a shadow spirit ghost with two tiny horns and round eyes...
evolved  : ...a shadow rogue spirit wearing a pointed hood and cloak, glowing eyes...
```

> 배경은 반드시 `solid white background`로 뽑아야 배경 제거가 깔끔합니다.
> 흑백(1-bit)으로 뽑으면 LCD 녹색 화면 위에서 고전 게임보이 감성이 제대로 삽니다.

## 2. 갈무리 픽셀 폰트 (`assets/fonts/`)

1. 갈무리 폰트를 내려받습니다: <https://galmuri.quiple.dev> (또는 GitHub `quiple/galmuri`).
   - 권장: **`Galmuri11.ttf`** (본문용). 라이선스: SIL Open Font License (앱 내장 무료).
2. 받은 `Galmuri11.ttf` 파일을 `wamagotchi/assets/fonts/` 폴더를 만들어 그 안에 넣습니다.
3. `wamagotchi/pubspec.yaml` 에서 아래 `fonts:` 블록의 **주석(`#`)을 해제**합니다:
   ```yaml
   fonts:
     - family: Galmuri
       fonts:
         - asset: assets/fonts/Galmuri11.ttf
   ```
4. 터미널에서 `flutter pub get` 실행 → 앱을 다시 실행하면 전체 UI가 갈무리 픽셀 폰트로 바뀝니다.
   (코드의 `fontFamily: 'Galmuri'` 가 이 폰트를 가리키고 있습니다.)

> ⚠️ 폰트 파일을 넣기 **전에** `pubspec.yaml`의 `fonts:` 주석을 풀면, 없는 파일을 가리켜 빌드가 실패합니다.
> 반드시 **파일을 먼저 넣고** 주석을 해제하세요.

---

## 참고: 왜 파일이 저장소에 없나요?

이 앱을 만든 클라우드 세션은 외부 이미지/폰트 CDN 접근이 차단되어 있어,
생성한 PNG나 폰트 바이너리를 저장소에 자동 커밋할 수 없었습니다.
대신 **넣을 자리와 연결 코드를 모두 준비**해 두었으니, 위 두 단계만 따라 하면 됩니다.
