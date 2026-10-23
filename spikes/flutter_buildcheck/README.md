# Flutter build check

ReciteScripts의 Flutter 3.47 개발 환경을 검증하는 최소 프로젝트다.

- iOS 26+
- Android 13 / API 33+
- Flutter Cupertino UI
- 제품 구조를 결정하기 전의 환경 검증 전용 코드

## 검증

```sh
flutter analyze
flutter test
flutter build ios --simulator --debug
flutter build apk --debug
```
