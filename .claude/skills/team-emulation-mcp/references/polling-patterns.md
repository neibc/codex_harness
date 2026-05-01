# Polling Patterns for Codex Prompts

Codex prompt에서 MCP 팀 서버를 안전하게 폴링하는 패턴.

## 1. 단순 폴링 (송신자가 응답을 기다림)

```markdown
다음 절차를 반복한다:

1. `send_message({to: "primitive-translator", content: "테이블 검토"})` 호출
2. 최대 30회 반복:
   a. `recv_messages({as: "me", since: <보낸 메시지 ts>})` 호출
   b. 응답이 있으면 처리 후 루프 탈출
   c. 없으면 1~3초 대기 후 재시도
3. 30회 이내 응답이 없으면 `task_create({subject: "translator unresponsive", ...})`로 에스컬레이션
```

## 2. 종료 조건 폴링 (팀 작업 완료 대기)

```markdown
오케스트레이터는 다음을 반복:

1. `task_list({team_id: <id>, status: "in_progress|pending"})` 호출
2. 비어 있으면 팀 작업 완료. 결과 수집 단계로.
3. 비어 있지 않으면 5~10초 대기 후 재시도
4. 최대 N분 초과 시 timeout 처리: 미완 task의 owner에게 `send_message`로 상태 보고 요청
```

## 3. 브로드캐스트 신호

```markdown
팀 종료 시 leader가:
1. `send_message({to: "*", content: "<TEAM_DONE>"})` 호출
2. `team_destroy({team_id: <id>})` 호출 (영속 저장소는 archive로)
```

## 4. 에러 / 데드락 회피

- 폴링 루프 마다 `task_list` 결과의 oldest task ts를 체크 — 너무 오래된 task는 강제 timeout
- `recv_messages` 호출이 빈 결과를 N회 연속 반환하면 wait 간격 지수 증가 (1s → 2s → 4s, max 30s)
- Codex 자체가 멈춰버린 경우(모델이 더 이상 도구를 호출하지 않음) — 외부 watchdog (cron) 으로 `task_list`를 보고 강제 종료

## 5. Anti-pattern

- ❌ 무한 루프 — Codex 컨텍스트가 토큰 한도로 잘림
- ❌ 1초 미만 인터벌 폴링 — MCP 서버 부하 + 의미 없음
- ❌ 폴링 없이 `send_message`만 보내고 끝 — 수신자가 보지 못함
- ❌ 전역 sleep 없이 도구만 연속 호출 — 응답 도착 전에 모든 호출이 끝남
