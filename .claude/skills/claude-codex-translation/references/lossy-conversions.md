# Lossy Conversions

변환 시 **기능 손실이 발생하는 항목** 카탈로그. README와 사용자 안내문에 반영.

## 1. 동기적 메시지 전달

- **Claude:** `SendMessage`는 메시지 큐 내 도착 즉시 수신자가 알 수 있음 (런타임 스케줄링).
- **Codex:** 외부 MCP 서버를 거치므로 수신자는 폴링하거나 명시적 wait가 필요.
- **사용자 영향:** 응답 지연 가능. 짧은 ping-pong 패턴은 Claude가 더 매끄러움.
- **완화:** 팀 prompt 안에 "주기적으로 `recv_messages` 호출" 지시 명시.

## 2. 빌트인 subagent_type 분류

- **Claude:** `Explore`(읽기 전용), `Plan`(설계 전용), `general-purpose` 카테고리가 1차 primitive로 존재.
- **Codex:** 카테고리 없음. 사용자가 prompt에 행동 지침으로 풀어 써야 함.
- **완화:** `--sandbox readonly` 플래그(존재 시)로 읽기 전용 강제, 또는 안내문으로.

## 3. 자동 컨텍스트 압축

- **Claude:** 대화 길이가 한도에 다가가면 자동 요약 압축.
- **Codex:** (분석 필요) — 수동 세션 분할 또는 `codex resume`/`fork`로 우회.
- **완화:** 오케스트레이터가 phase 사이에 명시적 산출물을 파일로 떨어뜨려 컨텍스트 의존을 최소화.

## 4. WebFetch / WebSearch 빌트인

- **Claude:** 빌트인 도구.
- **Codex:** 별도 MCP 서버 등록 필요.
- **완화:** README 설치 단계에서 권장 MCP 서버(예: `web-search` MCP) 안내.

## 5. ScheduleWakeup / Cron

- **Claude:** 셀프 페이싱 가능.
- **Codex:** OS cron 또는 외부 스케줄러로 우회.
- **완화:** "주기 실행이 필요하면 OS cron으로 `codex exec` 호출" 안내.

## 6. Skill 자동 트리거 description 매칭

- **Claude:** description 텍스트와 사용자 발화가 매칭되면 자동 호출.
- **Codex:** (분석 필요) — 슬래시 트리거 외 자동 매칭이 약할 수 있음.
- **완화:** AGENTS.md에 "어떤 요청이면 어떤 prompt를 호출하라" 명시적 라우팅 표 작성.

## 7. settings.json 권한/허용 룰

- **Claude:** 도구별 미세 권한.
- **Codex:** sandbox 모드 + config.toml 정책으로 표현. 입자도 차이.
- **완화:** Codex sandbox 정책으로 매핑 가능한 항목만 옮기고, 나머지는 안내문.

각 손실은 README의 "Known limitations" 섹션에 1:1로 반영.
