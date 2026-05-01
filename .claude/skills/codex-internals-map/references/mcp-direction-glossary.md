# MCP Direction Glossary

MCP는 양방향이라 헷갈린다. 이 표로 고정한다.

| 구성 | 누가 클라이언트 | 누가 서버 | 우리가 사용? |
|------|----------------|----------|-------------|
| **Codex가 외부 도구 호출** | Codex | 외부 MCP 서버 | ✅ 우리가 만든 **팀 서버**가 여기에 등록됨 |
| **다른 IDE/에이전트가 Codex 호출** | 외부 에이전트 | Codex (`codex mcp-server`) | ❌ 본 하네스에서는 미사용 |
| **Claude Code가 외부 도구 호출** | Claude Code | 외부 MCP 서버 | ✅ Claude 측에서도 같은 팀 서버 재사용 가능 (양방 호환) |

## 우리가 만들 "팀 서버"의 위치

```
Codex (client)  ←→  Team MCP Server  ←→  공유 파일/DB (메시지 큐)
                          ↑
                          └─── Claude Code (client, 옵션)
```

→ 같은 MCP 서버를 Codex와 Claude Code 양쪽에서 등록하면, 두 클라이언트가 같은 팀 컨텍스트를 공유할 수 있다(미래 확장).

## 자주 하는 실수

- "Codex의 mcp-server를 켜면 팀 통신이 된다"고 착각하기 → 그건 Codex 자신을 MCP 서버로 노출하는 것이지, 팀 통신 primitive가 아님.
- "MCP 도구만 만들면 Codex가 자동으로 호출한다"고 착각하기 → prompt에서 도구 호출을 유도하는 지시가 명시되어야 함.
