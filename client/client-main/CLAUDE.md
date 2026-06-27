# CLAUDE.md

이 파일은 Claude Code(claude.ai/code)가 이 저장소에서 작업할 때 참고하는 가이드입니다.

## 프로젝트 개요

Flutter 기반 모바일 앱 (Walk Master). PocketBase 백엔드(`http://4.190.160.14:8090`)와 REST API로 통신하며, Google/Kakao 소셜 로그인과 이메일 인증을 지원한다.

## 주요 명령어

```bash
# 의존성 설치
flutter pub get

# 앱 실행
flutter run

# 코드 분석 및 린트
flutter analyze

# 테스트 실행
flutter test

# 빌드
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web

# 스플래시 화면 재생성 (splash 이미지/색상 변경 후)
dart run flutter_native_splash:create
```

## 아키텍처

```
lib/
├── main.dart            # 진입점 - MaterialApp, SplashPage로 시작
├── pages/               # UI 화면 (페이지 단위)
│   ├── splash_page.dart # 토큰 체크 후 home/intro로 분기
│   ├── intro_page.dart  # 온보딩
│   ├── login_page.dart
│   ├── signup_page.dart
│   └── home_page.dart
└── services/            # 비즈니스 로직
    └── auth_service.dart
```

**인증 흐름:** `SplashPage`가 시작 시 저장된 토큰(`SharedPreferences`)을 확인하여 `HomePage` 또는 `IntroPage`로 라우팅.

**`AuthService`:** 정적 메서드 기반. `SharedPreferences`에 `auth_token`, `auth_email`, `auth_name` 저장. PocketBase REST API(`/api/collections/users/...`)와 직접 통신.

**백엔드:** PocketBase (`http://4.190.160.14:8090`). `AuthService._baseUrl`에 하드코딩됨.

## 스타일 및 테마

- 기본 색상: `#71C6E4` (cyan blue)
- `flutter_lints` 적용 (`analysis_options.yaml` 참조)
- 이미지 에셋: `assets/images/`
