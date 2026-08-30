# Perch Care — App Store Screenshots

App Store / Play Store 제출용 스크린샷을 브라우저에서 생성하는 Next.js 도구입니다.
앱 실기기 캡처(`public/screenshots/`)를 목업 프레임 + 브랜드 카피 위에 합성해 스토어 규격 PNG로 내보냅니다.

## 실행

```bash
npm install
npm run dev
```

http://localhost:3000 접속.

## 사용 방법

1. 상단에서 **언어**(`中文` / `한국어` / `English`)와 **기기 사이즈**를 선택
2. 슬라이드 미리보기 확인
3. 개별 슬라이드는 각 카드에서 PNG 다운로드, 전체는 **ZIP 일괄 다운로드**
   - 파일명: `perch-screenshots-{locale}-{6.9in}-{1320x2868}.zip`
   - 압축 해제 폴더(`perch-screenshots-*/`)는 루트 `.gitignore`에서 제외됨

## 지원 규격

| 라벨 | 해상도 | 대상 |
|------|--------|------|
| 6.9" | 1320×2868 | iPhone 16 Pro Max 등 |
| 6.5" | 1284×2778 | iPhone 14 Plus 등 |
| 6.3" | 1206×2622 | iPhone 16 Pro |
| 6.1" | 1125×2436 | iPhone X~11 Pro |

## 구조

```
public/
  mockup.png              # 아이폰 목업 프레임 (1022×2082, 화면 영역 좌표는 page.tsx 상수)
  app-icon.png            # 앱 아이콘
  perch-logo.svg          # 로고
  screenshots/{ko,en,zh}/ # 언어별 앱 캡처 원본 (10장)
src/app/
  page.tsx                # 슬라이드 정의 · 카피 · 렌더 · 내보내기 전부
  layout.tsx  globals.css
```

## 수정 포인트 (`src/app/page.tsx`)

- **카피 변경** — `COPY` 상수 (언어별 `heroHeadline` / `slides[].label` / `headline`). `<gradient>` 태그로 그라데이션 강조, `<br/>`로 줄바꿈
- **브랜드 컬러** — `BRAND` 상수 (accent `#FF9A42`는 앱 `AppColors.brandPrimary`와 동일)
- **캡처 교체** — `public/screenshots/{locale}/`에 같은 파일명으로 덮어쓰기. 파일 목록은 `SCREENSHOT_FILES`
- **슬라이드 레이아웃** — `Slide1`~`Slide10` 컴포넌트. 슬라이드 추가 시 `SCREENSHOT_FILES` · `COPY.*.slides` · 렌더 목록을 함께 수정

렌더링은 `html-to-image`(`toPng`)로 DOM을 그대로 캡처하므로, 폰트·이미지가 모두 로드된 뒤 실행됩니다(`preloadAllImages`, 첫 `toPng` 호출은 워밍업용 버림). ZIP 묶음은 `jszip`.

## 참고

이 디렉토리는 Flutter 앱(`lib/`)이나 백엔드(`backend/`) 빌드와 무관한 독립 도구입니다.
