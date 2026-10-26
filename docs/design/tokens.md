# 말또 Flutter Cupertino 디자인 토큰

> Issue #20 산출물. 이 문서는 Flutter 구현에 옮길 최소 디자인 토큰과 검증 기준을 정의한다. 제품 흐름과 동작은 `docs/PRD.md`를 따른다.

## 1. 적용 원칙

- **Cupertino 기본값 우선**: 시스템 글꼴, `CupertinoThemeData`, `CupertinoTextThemeData`, `CupertinoColors`를 먼저 사용한다. 별도 값은 낭독 가독성이나 상태 구분에 필요한 경우만 둔다.
- **의미 기반 참조**: 위젯에서 ARGB 값을 직접 사용하지 않고 아래 의미 토큰을 참조한다. 동적 색상은 `CupertinoDynamicColor`인 채로 전달하고, 직접 그리는 객체에서만 `CupertinoDynamicColor.resolve`로 해석한다.
- **시스템 설정 존중**: 밝기, 대비 증가, 텍스트 크기, 굵은 텍스트, Reduce Motion을 앱에서 덮어쓰지 않는다.
- **색상 외 단서 제공**: 상태와 조작 가능 여부를 색상 하나로만 표현하지 않는다.
- **논리 픽셀 기준**: 이 문서의 `pt`와 `dp`는 Flutter의 logical pixel 값으로 옮긴다. 실제 기기에서 플랫폼별 최소 터치 영역을 확인한다.

## 2. 색상

### 2.1 의미 색상 표

| 토큰 | Flutter 값 | 밝은/어두운 모드 | 용도 |
|---|---|---|---|
| `color.background.primary` | `CupertinoColors.systemBackground` | 자동 | 기본 화면 배경 |
| `color.background.secondary` | `CupertinoColors.secondarySystemBackground` | 자동 | 카드·입력 영역처럼 기본 배경 위에 놓이는 면 |
| `color.background.grouped` | `CupertinoColors.systemGroupedBackground` | 자동 | 그룹 목록 배경 |
| `color.text.primary` | `CupertinoColors.label` | 자동 | 제목, 본문, 핵심 상태 |
| `color.text.secondary` | `CupertinoColors.secondaryLabel` | 자동 | 보조 설명, 대기 어절 |
| `color.text.placeholder` | `CupertinoColors.placeholderText` | 자동 | 입력 placeholder에만 사용 |
| `color.action.primary` | `CupertinoColors.systemBlue` | 밝기·고대비 자동 | 주요 조작, 현재 어절 강조 |
| `color.action.destructive` | `CupertinoColors.systemRed` | 밝기·고대비 자동 | 삭제처럼 파괴적인 조작 |
| `color.separator` | `CupertinoColors.separator` | 자동 | 배경이 비치는 1 logical pixel 구분선 |
| `color.separator.opaque` | `CupertinoColors.opaqueSeparator` | 자동 | 배경을 비치면 안 되는 경계 |
| `color.fill.control` | `CupertinoColors.secondarySystemFill` | 자동 | 보조 컨트롤 배경 |
| `color.word.current.fill` | `CupertinoColors.systemIndigo` | 밝기·고대비 자동 | 현재 어절 캡슐 배경. 흰 글자와 모드별 3:1 이상 대비 확보 |
| `color.word.current.text` | `CupertinoColors.white` | 동일 | 현재 어절 글자. 읽기 본문 크기에서만 사용 |
| `color.word.completed.text` | `CupertinoColors.systemIndigo` | 밝기·고대비 자동 | 완료 어절 글자. 현재 어절과 같은 진행 색상군 |
| `color.word.pending.text` | `CupertinoColors.secondaryLabel` | 자동 | 대기 어절 글자 |

`CupertinoThemeData`에는 값의 복제를 피하기 위해 최소 항목만 지정한다.

| Theme 항목 | 값 |
|---|---|
| `primaryColor` | `CupertinoColors.systemBlue` |
| `scaffoldBackgroundColor` | `CupertinoColors.systemBackground` |
| `textTheme` | `CupertinoTextThemeData(primaryColor: CupertinoColors.systemBlue)`를 기반으로 필요한 스타일만 `copyWith` |
| `brightness`, `barBackgroundColor` | 지정하지 않고 시스템·Cupertino 기본값 사용 |

### 2.2 대비 기준

- 모든 텍스트/배경 조합을 **밝은 모드, 어두운 모드, 대비 증가 모드**에서 각각 확인한다.
- 17pt 이하 일반 텍스트는 최소 `4.5:1`, 18pt 이상 또는 굵은 글자는 최소 `3:1`을 통과해야 한다. 작은 커스텀 텍스트에는 가능하면 `7:1`을 목표로 한다.
- 동적 `systemIndigo` 위 흰색인 현재 어절 조합도 작은 텍스트용으로 재사용하지 않는다. `color.word.current.text`는 아래의 24pt·600 굵기 낭독 본문에 한정한다.
- 의미 색의 투명도를 추가로 낮춰 대비를 훼손하지 않는다. 비활성/대기 상태는 시스템 의미 색과 형태·굵기로 표현한다.
- 상태 확인은 흑백 또는 색상 필터에서도 수행한다. 색을 제거해도 현재 어절의 캡슐·굵기와 완료 어절의 굵기가 남아야 한다.

현재 어절의 `systemIndigo`/흰색 조합은 Flutter가 정의한 네 동적 색상 값으로 WCAG 상대 휘도 공식을 적용했다.

| 모드 | 대비 |
|---|---:|
| 밝은 모드 | `5.65:1` |
| 어두운 모드 | `5.06:1` |
| 밝은 모드 + 대비 증가 | `9.65:1` |
| 어두운 모드 + 대비 증가 | `3.44:1` |

가장 낮은 조합도 24pt·600 굵기인 현재 어절 기준 `3:1`을 넘는다. 나머지 시스템 의미 색 조합은 Flutter 버전과 실제 렌더링 배경에 따라 달라질 수 있으므로 구현 후 Accessibility Inspector로 측정한다.

## 3. 타이포그래피와 Dynamic Type

시스템 글꼴을 사용하고 글자 크기 상한을 두지 않는다. `MediaQuery.textScalerOf(context)`가 제공하는 `TextScaler`를 그대로 사용해 iOS Dynamic Type과 Android 비선형 글꼴 확대를 수용한다. `textScaleFactor`와 `TextScaler.noScaling`은 사용하지 않는다.

| 토큰 | 기준 TextStyle | Flutter 출발점 | 용도 |
|---|---|---|---|
| `type.nav.largeTitle` | Cupertino 기본 large title | `textTheme.navLargeTitleTextStyle` | 큰 내비게이션 제목 |
| `type.nav.title` | Cupertino 기본 navigation title | `textTheme.navTitleTextStyle` | 일반 내비게이션 제목 |
| `type.body` | Cupertino 기본 body, 17pt 기준 | `textTheme.textStyle` | 설명과 일반 본문 |
| `type.action` | Cupertino 기본 action | `textTheme.actionTextStyle` | 텍스트 조작 |
| `type.reading` | 시스템 글꼴, 24pt, `FontWeight.w400`, 높이 `1.45` | `textTheme.textStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w400, height: 1.45)` | 낭독 어절 |
| `type.reading.current` | `type.reading` + `FontWeight.w600` | `type.reading.copyWith(fontWeight: FontWeight.w600)` | 현재 어절 |
| `type.status` | 시스템 글꼴, 17pt, `FontWeight.w600` | `textTheme.textStyle.copyWith(fontWeight: FontWeight.w600)` | 반복 상태와 핵심 안내 |
| `type.caption` | 시스템 글꼴, 13pt, `FontWeight.w400` | 명시적 `TextStyle` | 비핵심 보조 문구에만 사용 |

### 3.1 전 단계 수용 기준

| 범위 | 확인 항목 |
|---|---|
| iOS 전체 Dynamic Type 단계 | 가장 작은 단계부터 가장 큰 접근성 단계까지 텍스트가 확대되며, 고정 높이 때문에 잘리지 않는다. |
| **Accessibility XL** | 필수 기준 화면. 현재 어절, 상태, 뒤로, 나가기 조작이 겹치거나 화면 밖으로 사라지지 않는다. |
| Accessibility XXL·XXXL | 같은 핵심 정보와 조작을 스크롤 또는 세로 재배치로 사용할 수 있다. 가로 스크롤을 요구하지 않는다. |
| Android 기본~최대 글꼴 크기 | `TextScaler`의 비선형 확대를 유지하고 최대 200% 설정에서 잘림·겹침을 확인한다. |

구현 규칙:

- 텍스트를 포함하는 행은 고정 높이를 두지 않고 내용에 따라 커지게 한다.
- 큰 글씨에서 가로 버튼 묶음이 맞지 않으면 세로로 재배치한다. 글자를 축소하거나 말줄임으로 핵심 상태·조작을 숨기지 않는다.
- 낭독 본문은 어절 사이에서 줄바꿈할 수 있어야 하며, 현재 어절 강조가 줄 경계를 넘어 깨지지 않아야 한다.
- 글자 크기 확대와 별개로 터치 영역 최소값은 유지한다.

## 4. 간격·크기·모서리

### 4.1 간격

4 logical pixel 기반의 작은 척도만 사용한다.

| 토큰 | 값 | 용도 |
|---|---:|---|
| `space.1` | 4 | 아이콘과 짧은 라벨 사이 |
| `space.2` | 8 | 밀접한 요소, 어절 강조 내부 세로 여백 |
| `space.3` | 12 | 어절 강조 내부 가로 여백, 컨트롤 내부 |
| `space.4` | 16 | 화면 기본 좌우 여백, 관련 그룹 내부 |
| `space.5` | 24 | 섹션 사이 |
| `space.6` | 32 | 주요 영역 사이 |

시스템 내비게이션 바, safe area, 대화상자와 표준 Cupertino 컨트롤의 내부 여백은 별도 토큰으로 덮어쓰지 않는다.

### 4.2 모서리와 선

| 토큰 | 값 | 용도 |
|---|---:|---|
| `radius.small` | 8 | 작은 상태 배경 |
| `radius.medium` | 12 | 입력·카드·일반 버튼 |
| `radius.pill` | `999` 또는 높이의 절반 | 현재 어절 캡슐 |
| `stroke.hairline` | `1 / devicePixelRatio` | 실제 1 device pixel 구분선이 꼭 필요할 때 |
| `stroke.state` | 2 logical pixels | 상태를 색 외 형태로 강조하는 선 |

표준 Cupertino 컴포넌트의 기본 모서리는 그대로 사용한다. 위 값은 커스텀 면과 어절 강조에만 적용한다.

### 4.3 터치 영역

| 토큰 | iOS | Android | 구현 기준 |
|---|---:|---:|---|
| `target.minimum` | 44 × 44pt | 48 × 48dp | 런타임 플랫폼에 맞는 최소 hit region. 보이는 아이콘이 작아도 `SizedBox`·padding으로 확보 |
| `target.preferred` | 48 × 48pt | 48 × 48dp | 공통 레이아웃의 기본 조작 크기 |
| `target.gap` | 8pt 이상 | 8dp 이상 | 인접한 독립 조작 사이 권장 간격 |

`CupertinoButtonSize.large`의 44pt 최소값을 기준으로 삼되 Android에서는 외곽 제약을 48dp 이상으로 확장한다. 전체 영역이 탭 가능해야 하며 아이콘에만 hit test를 두지 않는다.

## 5. 낭독 어절 상태

예시 문장은 프로젝트에서 직접 작성한 더미 문장인 **“오늘 읽을 문장을 천천히 또박또박 말합니다.”**만 사용한다.

| 상태 | 글자 | 면·선 | 색 외 시각 단서 | Semantics 값 |
|---|---|---|---|---|
| 현재 | `type.reading.current`, `color.word.current.text` | `color.word.current.fill` 캡슐, `space.2`/`space.3` 내부 여백 | 굵기 600 + 캡슐 형태 | `현재 어절, {어절}` |
| 완료 | `type.reading.current`, `color.word.completed.text` | 배경·선 없음 | 굵기 600 | `완료한 어절, {어절}` |
| 대기 | `type.reading`, `color.word.pending.text` | 배경·선 없음 | 현재/완료보다 낮은 강조, 장식 없음 | `대기 중인 어절, {어절}` |

추가 규칙:

- 굵기·글자색·캡슐 표현은 원문의 글자나 어절 사이 공백을 바꾸지 않아야 한다.
- 완료 상태에 취소선이나 낮은 opacity를 쓰지 않는다. `systemIndigo`와 굵기 600으로 왼쪽부터 진행 구간이 채워지는 노래방식 흐름을 만들고, 사용자가 문장을 다시 읽을 수 있도록 글자 형태와 대비를 보존한다.
- `Semantics`는 상태가 바뀐 현재 어절을 알 수 있게 하되, 모든 어절 변화마다 과도한 별도 음성 안내가 반복되지 않도록 실제 기기에서 VoiceOver·TalkBack 흐름을 검증한다.
- 현재 어절 변경은 색 변화뿐 아니라 위 세 속성(굵기, 캡슐, 의미 값)이 같은 프레임에 갱신되어야 한다.

## 6. 모션

| 토큰 | 값 | 곡선 | 용도 |
|---|---:|---|---|
| `motion.none` | 0ms | 없음 | Reduce Motion 시 위치 이동·크기 변화, 초기 상태 적용 |
| `motion.fast` | 120ms | `Curves.easeOut` | 눌림/강조 같은 짧은 피드백 |
| `motion.standard` | 200ms | `Curves.easeInOut` | 현재 어절의 색·선·면 전환 |
| `motion.scroll` | 250ms | `Curves.easeInOut` | 현재 어절을 읽을 수 있는 위치로 옮기는 짧은 자동 스크롤 |

- 시스템 컴포넌트의 기본 전환은 재정의하지 않는다. 위 시간은 커스텀 상태 전환에만 사용한다.
- 애니메이션은 상태를 지연시키거나 입력을 막지 않는다. 상태 자체는 즉시 확정하고 표현만 보간한다.
- 반복, 깜빡임, bounce, zoom, 회전 애니메이션은 사용하지 않는다.
- Reduce Motion이 켜지면 위치·크기 애니메이션은 `motion.none`으로 바꾸고 즉시 최종 위치를 표시한다. 상태 색 전환은 정보 손실이 없을 때 생략하거나 짧은 cross-fade만 허용한다.
- Flutter에서는 `MediaQuery.disableAnimationsOf(context)`와 `WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion`을 함께 확인한다. 후자는 iOS 전용 Reduce Motion 신호다. 설정 변경은 `WidgetsBindingObserver.didChangeAccessibilityFeatures`로 다시 반영한다.

## 7. 구현 매핑

권장 구조명은 예시이며 앱 아키텍처를 결정하지 않는다.

| 문서 토큰군 | Dart 표현 | 비고 |
|---|---|---|
| `color.*` | `abstract final class AppColors`의 `static const Color` | 값은 `CupertinoColors` 참조, ARGB 복제 금지 |
| `type.*` | `CupertinoTextThemeData` + `AppTextStyles` 함수/extension | `BuildContext`의 theme와 `TextScaler` 유지 |
| `space.*` | `abstract final class AppSpacing`의 `double` | 4, 8, 12, 16, 24, 32만 제공 |
| `radius.*` | `abstract final class AppRadii`의 `BorderRadius` | 표준 컨트롤에는 적용하지 않음 |
| `target.*` | 플랫폼별 `BoxConstraints` | iOS 44, Android 48 최소값 |
| `motion.*` | `abstract final class AppMotion`의 `Duration` | Reduce Motion 시 0ms 분기 |

문서의 점 표기 이름은 디자인 명세용이다. Dart 식별자는 프로젝트의 명명 규칙에 맞춰 일관되게 변환한다.

## 8. 검증 체크리스트

- [ ] 밝은/어두운/대비 증가 모드에서 의미 색이 동적으로 바뀐다.
- [ ] 텍스트 대비가 작은 일반 글자 `4.5:1`, 큰 글자 또는 굵은 글자 `3:1` 이상이다.
- [ ] iOS Dynamic Type 전 단계와 특히 Accessibility XL에서 잘림·겹침이 없다.
- [ ] iOS Accessibility XXL·XXXL, Android 최대 200% 글꼴 크기에서도 핵심 정보와 조작을 사용할 수 있다.
- [ ] 모든 조작의 hit region이 iOS 44pt, Android 48dp 이상이다.
- [ ] 흑백 화면에서도 현재·완료·대기 어절을 캡슐·굵기·일반 굵기로 구분한다.
- [ ] VoiceOver·TalkBack이 어절 상태와 조작 이름을 의미 있게 읽는다.
- [ ] Reduce Motion에서 자동 스크롤과 상태 애니메이션이 즉시 전환 또는 짧은 fade로 축소된다.
- [ ] 기본 글씨와 큰 글씨 화면을 양 플랫폼에서 스크린샷으로 비교한다.

## 9. 근거

- Apple HIG [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): Dynamic Type, 최소 대비, 색 외 단서, Reduce Motion 기준.
- Apple HIG [Color](https://developer.apple.com/design/human-interface-guidelines/color): 시스템 의미 색과 밝은/어두운/대비 증가 모드 대응.
- Apple HIG [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode): 동적 배경·레이블 색과 모드별 대비 검증.
- Apple HIG [Layout](https://developer.apple.com/design/human-interface-guidelines/layout): Dynamic Type과 다양한 화면 조건에서 적응형 레이아웃 검증.
- Apple HIG [Motion](https://developer.apple.com/design/human-interface-guidelines/motion): 목적 있는 짧은 모션과 모션 선택권.
- Apple HIG [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons): 44 × 44pt 이상 hit region.
- Flutter [`CupertinoColors`](https://api.flutter.dev/flutter/cupertino/CupertinoColors-class.html): 의미 기반 동적 색상 매핑.
- Flutter [`CupertinoDynamicColor`](https://api.flutter.dev/flutter/cupertino/CupertinoDynamicColor-class.html): 밝기·대비·elevation에 따른 색상 해석.
- Flutter [`CupertinoThemeData`](https://api.flutter.dev/flutter/cupertino/CupertinoThemeData-class.html)와 [`CupertinoTextThemeData`](https://api.flutter.dev/flutter/cupertino/CupertinoTextThemeData-class.html): Cupertino 테마와 기본 iOS 텍스트 스타일.
- Flutter [`TextScaler`](https://api.flutter.dev/flutter/painting/TextScaler-class.html): 플랫폼 선호 글꼴 확대 전략과 비선형 확대 지원.
- Flutter [`MediaQueryData.disableAnimations`](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html): 커스텀 애니메이션 축소 처리와 iOS Reduce Motion 차이.
- Flutter [`AccessibilityFeatures.reduceMotion`](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/reduceMotion.html): iOS 전용 Reduce Motion 신호.
- Flutter [`kCupertinoButtonMinSize`](https://api.flutter.dev/flutter/cupertino/kCupertinoButtonMinSize-constant.html): large Cupertino 버튼의 44pt 최소값.

## 10. Marco 결정 필요 항목

없음. 이 문서는 확정된 접근성 요구와 공식 시스템 기본값을 구현 가능한 최소 토큰으로 옮긴다. 24pt 낭독 본문과 완료 어절의 굵은 `systemIndigo` 표현은 #21 목업의 기본·Accessibility XL 화면에서 시각 검증한다.
