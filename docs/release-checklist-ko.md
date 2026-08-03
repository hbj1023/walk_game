# Walk Master Android 배포 전 체크리스트

## 1. 소스와 데이터

- [ ] `git fetch origin` 후 현재 브랜치가 `origin/main`을 포함하는지 확인
- [ ] 작업 파일을 한국어 커밋 메시지로 커밋하고 원격에 푸시
- [ ] `server/server-main/scripts/backup-pocketbase.sh`로 운영 PocketBase 백업 생성
- [ ] 백업 파일의 SHA-256과 복구 위치 확인
- [ ] 새 PocketBase 마이그레이션을 빈 데이터베이스와 운영 복사본에서 각각 검증

## 2. Android 식별과 서명

- [ ] 패키지명 `com.hbj1023.walkmaster` 유지
- [ ] `android/key.properties`와 업로드 키 저장소 존재 확인
- [ ] 업로드 키 파일과 비밀번호를 저장소 외부에 별도 백업
- [ ] `version`의 build number가 이전 출시보다 큰지 확인
- [ ] 서명된 AAB 생성 후 서명 인증서 확인

패키지명이 `com.example.capstone_app`에서 변경됐기 때문에 기존 수동 설치 앱에는 업데이트로 덮어쓸 수 없다. 테스트 기기에서는 기존 앱을 제거하고 새 앱을 설치한다. 서버 계정 데이터는 유지되지만 기기의 로그인 캐시는 초기화된다. Play에 첫 출시한 뒤에는 패키지명을 변경하지 않는다.

## 3. 자동 검증

저장소 루트에서 실행한다.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pre-release-check.ps1
```

- [ ] `flutter analyze`
- [ ] Flutter 전체 테스트
- [ ] Go 전체 테스트
- [ ] Android 릴리스 AAB 빌드
- [ ] AAB SHA-256 생성
- [ ] 개인정보 처리방침과 계정 삭제 페이지 포함 확인
- [ ] 프로덕션 웹 200, 인증 없는 `/main` 401 확인

## 4. 실기기 필수 검증

- [ ] 신규 설치 후 회원가입부터 시작되는지 확인
- [ ] 화면을 끄고 앱을 백그라운드로 보낸 상태에서 걸음 수 수집 확인
- [ ] 백그라운드에서 게임 음악이 정지하는지 확인
- [ ] 오프라인 공격 기회가 가득 차면 알림이 오고, 소비 후 다시 충전되는지 확인
- [ ] 위치·신체 활동·알림 권한 허용과 거부 흐름 확인
- [ ] 고객센터 입력 시 키보드가 올라오고 닫힌 뒤 홈 화면이 정상 복원되는지 확인
- [ ] 앱 내부 계정 삭제와 웹 삭제 요청 모두 확인
- [ ] 저속 네트워크, 네트워크 단절, 앱 강제 종료 후 복구 확인

## 5. Play Console

- [ ] 개인정보 처리방침 URL 공개 접근 확인
- [ ] 외부 계정 삭제 URL 공개 접근 및 실제 접수 확인
- [ ] Data safety와 건강 앱 선언 입력
- [ ] 앱 아이콘, 스크린샷, 설명, 콘텐츠 등급, 대상 연령 입력
- [ ] 내부 테스트 트랙에 먼저 배포
- [ ] 내부 테스트 설치 링크로 새 설치와 업데이트 확인
- [ ] 비정상 종료, ANR, 권한 거부율을 확인한 뒤 단계적 공개

## 6. 출시 후

- [ ] API와 PocketBase 상태 확인
- [ ] 로그인, 전투, 상점, 레이드, 알림 스모크 테스트
- [ ] `account_deletion_requests`와 `support_reports` 처리 담당자 지정
- [ ] 장애 시 사용할 이전 웹 패키지와 PocketBase 백업 위치 기록
