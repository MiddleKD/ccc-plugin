# 0001. Harness는 외부 Component를 복사해 폴더 하나로 완결한다

Date: 2026-11-15
Status: Accepted

## Context

`ccc-plugin`의 Harness는 여러 작업과 프로젝트, 머신에서 동일한 Worker 실행 환경을 재현해야 한다.
Harness가 외부 Plugin의 일부 Component(skill, agent, hook, workflow)를 조합해 쓸 때 두 가지 선택지가 있다:

1. **참조 방식**: Harness가 외부 Plugin 이름·버전·경로만 참조하고, 실행 시점에 외부 캐시나 마켓플레이스에서 동적으로 가져온다.
2. **복사(완결) 방식**: Harness가 일부 Component만 필요할 때는 해당 파일을 Harness 폴더 안으로 복사해 고정하고, Plugin 전체가 필요할 때만 `settings.local.json`에서 Plugin을 활성화한다. 복사한 Component는 원본과 자동 동기화하지 않는다.

## Decision

Harness는 외부 Component를 복사해 폴더 하나로 완결한다.

- Plugin 전체가 필요하면 Harness의 `settings.local.json`에서 그 Plugin을 활성화한다.
- 일부 Component만 필요하면 해당 Component를 Harness 폴더(`skills/`, `agents/`, `hooks/`, `workflows/`)로 복사하고, worktree에서는 원본 Plugin을 비활성화한다.
- 복사한 Component의 출처(원본 Plugin 이름과 버전)는 `HARNESS.md`에 기록하되, 원본과의 자동 동기화는 하지 않는다.
- 작업용 worktree에 Harness를 설치할 때도 심링크가 아니라 전체 복사를 사용한다.

## Consequences

- **재현성과 격리**: 업스트림 Plugin이 업데이트되거나 다른 머신에서 실행해도 검증된 Harness의 동작이 깨지지 않는다. 병렬 worktree 간 간섭도 없다.
- **우선순위 충돌 처리 필요**: 복사된 project-level skill은 global(personal) skill에게 가려지므로, 복사 시 `<harness>-` 접두사를 붙이고 원본을 `skillOverrides`로 끄는 규칙이 필요하다. hook은 모든 층이 합쳐 실행되므로 중복 등록을 피해야 한다.
- **업스트림 수정 반영 비용**: 원본 Plugin에 버그 수정이 들어가도 Harness 복사본에는 자동 반영되지 않는다. 필요 시 사람이 명시적으로 다시 복사하거나 Promotion을 갱신해야 한다.
- **링크드 worktree fallback 주의**: Claude Code는 worktree에 `.claude/skills`가 없을 때만 메인 체크아웃의 project skill을 fallback 로드한다. Harness가 `.claude/skills`를 복사하면 fallback이 꺼지므로, 대상 프로젝트 고유의 skill이 필요하면 `/ccc:init` 시 함께 복사해야 한다.
