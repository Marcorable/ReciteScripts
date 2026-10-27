# 빌드 검증과 배포 서명

## 시크릿 없는 검증

Pull Request와 `develop` CI는 배포 자격 증명을 사용하지 않는다.

- `flutter analyze`, 순수 Dart 테스트, Flutter 테스트
- Android Debug APK 빌드
- iOS Simulator Debug 앱 빌드(`--no-codesign`)
- 커밋 금지 파일, 대표적인 시크릿 패턴, 제품 경로의 제3자 콘텐츠 표지 검사

이 단계는 같은 커밋이 양 플랫폼에서 컴파일되고 테스트되는지 확인한다. 시뮬레이터 앱은 서명이 필요 없고 실제 기기에 배포하지 않는다.

## 실제 배포

TestFlight와 스토어 배포는 별도의 출시 Issue와 보호된 배포 workflow에서만 수행한다. 저장소에는 인증서, provisioning profile, App Store Connect API 키, Android keystore를 넣지 않는다. 필요한 값은 GitHub Actions Secrets 또는 배포 머신의 레포 밖 keychain/credential store에서 주입하며 로그에 출력하지 않는다.

배포 단계는 다음 조건을 모두 확인한 뒤 추가한다.

1. Marco가 배포 실행과 대상 버전을 승인한다.
2. 보호된 environment와 최소 권한을 설정한다.
3. iOS 배포 서명과 Android release signing을 실행 시점에만 구성한다.
4. 서명 전과 동일한 소스 커밋에서 release artifact를 만든다.
5. 업로드 결과와 artifact 식별자만 기록하고 자격 증명은 즉시 정리한다.

현재 Walking Skeleton에는 실제 배포 workflow를 포함하지 않는다.
