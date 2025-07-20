# Changelog

## [1.0.1] - 2025-07-20

### Added
- **안정성 개선**
  - 네트워크 요청 재시도 로직 (지수 백오프)
  - Graceful shutdown 구현
  - 상세한 메모리 정보 제공

### Changed
- 허브 등록 시 재시도 로직 강화
- 헬스체크 응답에 메모리 MB 단위 정보 추가
- 종료 프로세스 개선

### Fixed
- AGENT_ID 환경변수 실제 사용
- os 모듈 import 최적화

## [1.0.0] - 2025-07-19

### Initial Release
- 기본 크롤러 에이전트 기능
- Playwright 브라우저 자동화
- 허브 통신 시스템
- 워크플로우 실행
- MCP 통합