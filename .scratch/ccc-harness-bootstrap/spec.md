# ccc-plugin bootstrap: 개인 Marketplace + Harness 라이브러리 + Control Plane 스킬

Status: ready-for-agent

용어는 `CONTEXT.md`를 따른다 (Control Plane, Worker, Plugin, Harness, Instant Harness, Component, Smoke Check, Conflict Rules, Promotion).

## Problem Statement

나는 마음에 드는 Claude Code 플러그인이 여럿 있지만, 프로젝트·작업마다 필요한 조합이 다르다. 지금은 전역 `settings.json`에 플러그인을 켜 두거나 매번 손으로 설정을 바꾸고 있어서:

- 모든 세션에 모든 플러그인이 켜져 컨텍스트가 낭비되고, 플러그인끼리 Component(skill, agent, hook, workflow)가 겹쳐 Worker가 헷갈린다.
- 어떤 작업에 어떤 조합이 잘 맞았는지가 기록되지 않아, 잘 동작한 세팅을 다음에 재현할 수 없다.
- herdr에서 여러 Worker를 병렬로 돌릴 때, worktree마다 작업에 맞는 환경을 만드는 과정(설정, hook, AGENTS.md, 추적되지 않는 파일, 의존성)이 매번 즉흥적이다.
- 플러그인을 고치고 싶을 때 업스트림 업데이트를 따라가기 어렵다.

## Solution

`ccc-plugin` 레포를 세 가지 역할을 하는 하나의 저장소로 만든다.

1. **개인 Plugin Marketplace**: 마음에 드는 Plugin을 업스트림 Git 소스로 등록해 두고, 프로젝트·worktree 단위로 골라 켠다. 코드 수정이 불가피하면 개인 Fork로 소스를 바꾼다.
2. **Harness 라이브러리**: 검증된 작업 환경을 폴더 하나로 완결된 Harness(Component + 설정 템플릿 + 지침 + 사용 안내)로 보관한다.
3. **Control Plane 스킬** (`ccc-harness` 플러그인): herdr의 Control Plane이 `/ccc:init`으로 대상 프로젝트를 스캔하고 worktree에 Harness 또는 Instant Harness를 설치한 뒤 실제 Worker로 Smoke Check까지 하고, 작업이 끝나면 `/ccc:promote`로 그 환경이 재사용할 가치가 있는지 평가해 Harness로 승격하거나 project memory에 기록한다.

## User Stories

### Marketplace와 Plugin 관리

1. As a 사용자, I want 마음에 드는 Plugin들을 ccc 마켓플레이스 하나에 등록, so that 내가 쓰는 Plugin 모음을 한곳에서 관리할 수 있다
2. As a 사용자, I want 마켓플레이스 항목이 업스트림 Git 소스를 가리키게, so that 업스트림 업데이트를 손대지 않고 따라갈 수 있다
3. As a 사용자, I want Plugin 코드를 고쳐야 할 때 소스를 내 Fork로 바꾸는 탈출구, so that 수정과 업스트림 추적을 Git으로 함께 할 수 있다
4. As a 사용자, I want 코드 수정 전에 Harness 쪽(지침, hook, 설정)에서 먼저 동작을 보완하는 것을 원칙으로, so that Fork 유지 부담을 최소화할 수 있다
5. As a 사용자, I want 초기 Plugin으로 mattpocock-skills, exa, ponytail, pyright-lsp, superpowers를 등록, so that 지금 쓰는 도구들로 바로 시작할 수 있다
6. As a 사용자, I want 전역으로 켤 Plugin(ccc-harness, exa)과 작업별로 켤 Plugin을 별도 문서 없이 구분, so that Plugin을 추가·제거할 때 문서를 고치지 않아도 된다
7. As a Control Plane, I want 마켓플레이스 목록과 전역 settings를 실행 시점에 비교해 전역 활성 여부를 판별, so that 항상 실제 설정 기준으로 판단할 수 있다
8. As a 사용자, I want 전역 settings.json의 머신 고유 설정(env, herdr hook)을 ccc가 덮어쓰지 않게, so that 내 환경이 망가지지 않는다

### Component 파악

9. As a Control Plane, I want Plugin의 기능을 요약 문서가 아니라 로컬 캐시에서 직접 읽어 파악, so that 항상 최신 상태로 판단할 수 있다
10. As a Control Plane, I want 각 Component의 이름과 description만 가볍게 추출, so that 스킬이 많은 Plugin도 적은 비용으로 훑을 수 있다
11. As a Control Plane, I want 전역, 프로젝트 기존 설정, 활성화할 모든 Plugin, Harness 자체의 Component를 한 번에 펼쳐 놓고 보기, so that 어느 층에서든 생기는 중복과 우선순위 문제를 찾을 수 있다
12. As a Control Plane, I want skill뿐 아니라 agent, hook, workflow까지 같은 기준으로 스캔, so that Component 종류에 상관없이 충돌을 잡을 수 있다
13. As a Control Plane, I want 실제로 겪은 Component 간 충돌과 우선순위를 Conflict Rules에서 읽기, so that 캐시만 봐서는 알 수 없는 조합 노하우를 쓸 수 있다
14. As a 사용자, I want Conflict Rules에는 실제로 부딪힌 경우만 짧게 누적, so that 문서가 낡거나 비대해지지 않는다
15. As a Control Plane, I want 같은 역할의 Component가 둘 이상이면 하나를 골라 Worker 지침에 명시, so that Worker가 어느 것을 쓸지 헷갈리지 않는다

### Harness 형식

16. As a 사용자, I want Harness를 폴더 하나로 완결된 실행 번들로, so that 다른 머신·프로젝트에서도 같은 동작을 재현할 수 있다
17. As a 사용자, I want Harness에 skills, agents, hooks, workflow, 설정 템플릿, 지침 템플릿을 필요한 만큼만 담기, so that 단순한 Harness는 가볍게 유지할 수 있다
18. As a 사용자, I want Harness 밖의 Component가 필요하면 Harness 안으로 복사, so that Harness가 바깥 환경에 기대지 않는다
19. As a 사용자, I want Plugin 전체가 필요하면 Plugin 자체를 Harness 설정에 등록하고, 일부 Component만 필요하면 그 Component만 복사, so that 업스트림 추적과 모듈화를 상황에 맞게 고를 수 있다
20. As a 사용자, I want 복사한 Component를 원본과 동기화하지 않기, so that Harness가 복사 시점 상태로 고정된 모듈로 동작한다
21. As a 사용자, I want HARNESS.md에 이 Harness가 맞는 작업과 맞지 않는 작업을 적기, so that init 때 고르는 기준이 된다
22. As a 사용자, I want HARNESS.md에 상황별 사용법(무엇을 어떤 순서로 쓰고 어떻게 검증하는지)을 적기, so that 같은 Harness라도 상황에 맞게 쓸 수 있다
23. As a 사용자, I want HARNESS.md에 init 때 판단할 점을 적기, so that Control Plane이 프로젝트 스캔 결과에 맞춰 설치를 조정할 수 있다
24. As a 사용자, I want HARNESS.md에 Smoke Check 작업을 적기, so that 설치 후 이 조합이 실제로 동작하는지 확인할 수 있다
25. As a 사용자, I want Harness에 project-specific 내용(특정 라이브러리 버전, 특정 디렉토리 책임 등)이 절대 들어가지 않게, so that Harness가 범용으로 재사용된다
26. As a 사용자, I want HARNESS.md를 200줄 이하로, so that Control Plane과 내가 빠르게 읽을 수 있다
27. As a 사용자, I want 처음에는 Harness 작성 규칙과 빈 템플릿만 두기, so that 검증되지 않은 Harness가 쌓이지 않고 실제 작업에서 승격된 것만 남는다

### `/ccc:init`: 스캔과 선택

28. As a Control Plane, I want 항상 대상 프로젝트 폴더를 먼저 스캔(기술 스택, 테스트 도구, 기존 CLAUDE.md/AGENTS.md), so that 프로젝트에 맞는 환경을 조립할 수 있다
29. As a Control Plane, I want 해당 프로젝트의 Claude project memory에서 추천 Harness를 확인, so that 과거에 잘 맞았던 Harness를 재사용할 수 있다
30. As a Control Plane, I want 맞는 Harness가 있으면 그것을, 없으면 Instant Harness를 조립, so that 어떤 작업이든 시작할 수 있다
31. As a Control Plane, I want 이번 작업이 HARNESS.md의 어느 상황에 해당하는지 판단, so that 그 상황의 사용법만 Worker에게 전달할 수 있다
32. As a Control Plane, I want 특이한 오픈소스 Plugin이 들어와도 고정 스크립트가 아니라 가이드를 읽고 판단해서 조립, so that 형식이 다른 Plugin도 수용할 수 있다

### `/ccc:init`: worktree 준비

33. As a Control Plane, I want 작업마다 git worktree와 전용 브랜치를 만들기, so that 병렬 Worker끼리 작업이 섞이지 않는다
34. As a Control Plane, I want git이 추적하지 않는 필요한 파일(.env 등)을 새 worktree로 복사, so that Worker가 바로 실행 가능한 환경에서 시작한다
35. As a Control Plane, I want worktree에서 의존성을 설치, so that Worker가 설치 문제로 막히지 않는다
36. As a Control Plane, I want 웹 프로젝트일 때만 worktree별 포트를 분리, so that 병렬 dev server끼리 포트가 겹치지 않는다
37. As a 사용자, I want worktrunk 같은 별도 도구 없이 git worktree와 ccc 절차만으로 관리, so that 의존성이 늘지 않는다

### `/ccc:init`: Harness 설치

38. As a Control Plane, I want Harness 파일을 worktree로 심링크가 아니라 전체 복사, so that 병렬 작업에서 서로 꼬이지 않는다
39. As a Control Plane, I want 작업용 Plugin 활성화와 설정을 worktree의 로컬 설정(settings.local.json)에만 쓰기, so that 프로젝트의 추적되는 설정이 오염되지 않는다
40. As a Control Plane, I want 상황에 맞는 지침으로 AGENTS.md를 만들고 CLAUDE.md가 그것을 import하게, so that AGENTS.md와 CLAUDE.md를 함께 둘 수 있다
41. As a Control Plane, I want 주입한 파일을 git 로컬 exclude에 등록, so that 프로젝트의 .gitignore를 건드리지 않고도 git status가 깨끗하다
42. As a Control Plane, I want 어떤 Harness를 썼는지 worktree 안에 기록, so that promote 때 무엇을 평가할지 안다
43. As a Control Plane, I want 복사한 skill은 이름 앞에 Harness 이름을 붙이고 같은 이름의 전역 원본은 로컬 설정으로 끄기, so that 전역이 프로젝트를 이기는 skill 우선순위 때문에 복사본이 가려지지 않는다
44. As a Control Plane, I want 복사한 agent와 workflow는 원래 이름을 유지, so that 프로젝트가 전역을 이기는 우선순위 덕분에 복사본만 보인다
45. As a Control Plane, I want Plugin에서 일부 Component만 복사했다면 worktree에서 그 Plugin을 끄기, so that 같은 일을 하는 Component가 둘 생기지 않는다
46. As a Control Plane, I want Harness의 hook이 이미 다른 층(전역, 프로젝트, 다른 Plugin)에서 실행 중이면 로컬 설정에 등록하지 않기, so that hook이 중복 실행되지 않는다
47. As a Control Plane, I want 모든 hook을 끄는 설정은 쓰지 않기, so that herdr 상태 hook이 꺼지지 않는다
48. As a Control Plane, I want 이런 이름·우선순위·중복 규칙을 전역↔프로젝트뿐 아니라 프로젝트 기존 설정↔Harness, Plugin↔Plugin 사이에도 똑같이 적용, so that 어느 층에서 생긴 충돌이든 같은 방식으로 해결된다

### `/ccc:init`: Smoke Check

49. As a Control Plane, I want 설치 후 herdr로 그 worktree에서 실제 Worker를 띄워 확인, so that `claude -p`와 달리 실제 작업 환경(herdr hook, 대화형 세션)에서 검증할 수 있다
50. As a Control Plane, I want 먼저 공통 점검(기대한 Component와 MCP가 로드됐는지), so that 켰는데 안 뜨는 문제를 바로 잡을 수 있다
51. As a Control Plane, I want 이어서 Harness별 확인 작업을 실행, so that Plugin끼리 실제로 맞물려 동작하는지 볼 수 있다
52. As a Control Plane, I want Instant Harness라면 확인 작업을 init 때 직접 정하기, so that 미리 정의된 Harness가 없어도 검증할 수 있다
53. As a Control Plane, I want 실패하면 원인을 고쳐 최대 2회 재시도, so that 사소한 설정 문제로 사용자를 부르지 않는다
54. As a 사용자, I want 재시도해도 안 되면 보고받기, so that 막힌 상태로 방치되지 않는다
55. As a Control Plane, I want 실패 원인과 수정 내용을 기록, so that promote 판단과 Conflict Rules의 재료가 된다
56. As a 사용자, I want Smoke Check가 PR 같은 외부 공개 작업을 하지 않게, so that 검증 중에 의도치 않게 공개되는 일이 없다

### 작업과 마무리

57. As a Worker, I want 내 상황에 필요한 사용법만 담긴 AGENTS.md를 받기, so that 불필요한 지침에 흔들리지 않는다
58. As a Worker, I want 작업 완료 보고에 Harness 사용감을 1~2줄 남기기, so that Control Plane이 평가 근거를 얻는다
59. As a Worker, I want 작업이 끝나면 draft PR을 올리기, so that 끝까지 막힘 없이 진행할 수 있다
60. As a 사용자, I want draft PR을 내가 확인하고 ready로 바꾸기, so that 정식 공개 시점은 내가 정한다
61. As a 사용자, I want init 때 명시적으로 허락하면 Worker가 바로 정식 PR을 올리게, so that 신뢰하는 작업은 더 빠르게 끝낼 수 있다

### `/ccc:promote`

62. As a Control Plane, I want worktree를 정리하기 직전에 평가, so that Harness 상태가 아직 남아 있을 때 판단하고 추출할 수 있다
63. As a 사용자, I want 언제든 직접 `/ccc:promote`를 호출, so that 자동 제안이 없어도 승격할 수 있다
64. As a Control Plane, I want Worker 보고뿐 아니라 세션 출력과 transcript를 직접 확인, so that Worker의 자기평가에 기대지 않고 공정하게 판단할 수 있다
65. As a Control Plane, I want 세 가지 기준(막힘 없이 완주했는가, Harness 구성이 실제로 기여했는가, 재사용 가치가 있는가)으로 평가, so that 근거 있는 제안만 한다
66. As a 사용자, I want 가치가 있을 때만 승격·기록을 제안받기, so that 매번 묻는 피로가 없다
67. As a Control Plane, I want 범용 Harness로 쓸 만하면 ccc-plugin의 Harness 폴더로 추출해 커밋을 제안, so that 검증된 환경이 라이브러리로 쌓인다
68. As a Control Plane, I want 추출할 때 project-specific 내용을 제거하고 200줄 이하로 다듬기, so that 승격된 Harness가 범용 규칙을 지킨다
69. As a Control Plane, I want 승격할 때 Harness가 쓰는 외부 Component를 Harness 안으로 복사, so that 승격된 Harness가 폴더 하나로 완결된다
70. As a Control Plane, I want "이 프로젝트에는 이 Harness가 맞다"는 사실은 해당 프로젝트의 Claude project memory에 기록, so that 프로젝트 레포를 건드리지 않고도 다음 init에서 재사용된다
71. As a 사용자, I want Harness 승격(ccc-plugin 커밋)과 프로젝트 친화도 기록(project memory)을 분리, so that 범용 레시피와 프로젝트 취향이 섞이지 않는다
72. As a Control Plane, I want 평가 중 발견한 Component 충돌을 Conflict Rules에 추가 제안, so that 다음 init이 같은 문제를 피한다
73. As a Control Plane, I want 평가가 끝난 뒤에만 worktree와 브랜치를 정리, so that 평가 근거가 정리 과정에서 사라지지 않는다

### 설치와 운영

74. As a 사용자, I want ccc 마켓플레이스 등록과 ccc-harness 전역 활성화를 마지막에 확인받고 진행, so that 전역 설정 변경을 내가 통제한다
75. As a 사용자, I want 어떤 프로젝트에서 herdr Control Plane을 열든 `/ccc:init`을 바로 호출, so that 일관된 흐름으로 작업을 시작할 수 있다

## Implementation Decisions

### 모듈

- **Marketplace 매니페스트**: ccc-plugin 루트가 Claude Code 마켓플레이스가 된다. 외부 Plugin은 `github` 또는 `git-subdir` 소스로 업스트림을 가리킨다. 직접 만든 `ccc-harness`만 레포 내부 경로 소스로 둔다. 외부 Plugin 코드를 레포에 복사(벤더링)하지 않는다.
- **`ccc-harness` 플러그인**: Control Plane 전용. `init`과 `promote` 두 skill을 제공한다. 전역으로 켜 둔다.
- **Harness 라이브러리**: Harness 작성 규칙 문서와 빈 템플릿 하나로 시작한다. 실제 Harness는 Promotion으로만 추가된다.
- **Conflict Rules**: 단일 파일. 처음엔 비어 있고, 실제로 겪은 Component 간 충돌과 우선순위만 한두 줄씩 누적한다.
- **ADR**: "Harness는 외부 Component를 복사해 폴더 하나로 완결한다" 결정을 ADR로 남긴다 (되돌리기 어렵고, 처음 보는 사람에게 의외이며, 실제 trade-off의 결과).

### Harness 폴더 계약

- 필수: `HARNESS.md` (맞는/맞지 않는 작업, 구성 Component, 상황별 사용법, init 때 판단할 점, Smoke Check 작업).
- 선택: Worker 지침 템플릿, 로컬 설정 템플릿, skills, agents, hooks, workflow. 필요한 것만 둔다.
- 금지: project-specific 내용. HARNESS.md 200줄 초과.
- Plugin 전체가 필요하면 설정 템플릿의 Plugin 활성화로 등록하고, 일부 Component만 필요하면 그 Component만 복사한다. 복사한 경우 출처를 HARNESS.md에 적는다. 복사본은 원본과 동기화하지 않는다.

### Component 우선순위와 처리 규칙 (Claude Code 공식 문서로 확인)

| Component | 같은 이름일 때 | 복사본 처리 |
|---|---|---|
| skill | 전역(personal)이 프로젝트를 이김. `skillOverrides`는 이름으로만 매칭하며 Plugin skill에는 적용되지 않음 | 이름 앞에 Harness 이름을 붙이고, 같은 이름의 전역 원본을 로컬 설정의 `skillOverrides`로 끔 |
| agent | 프로젝트가 전역을 이기고, Plugin agent가 가장 낮음 | 원래 이름 유지 |
| workflow | 프로젝트가 전역을 이김 | 원래 이름 유지 |
| hook | 모든 층의 hook이 합쳐져 전부 실행됨. 개별 hook만 끌 수 없음 | 다른 층에서 이미 실행 중이면 로컬 설정에 등록하지 않음. 모든 hook을 끄는 설정은 쓰지 않음 |
| Plugin Component | `plugin:name`으로 이름이 분리됨 | 일부만 복사했다면 worktree에서 그 Plugin을 끔 |

이 규칙은 전역↔worktree, 프로젝트 기존 설정↔Harness, Plugin↔Plugin 모든 층 사이에 똑같이 적용된다.

### `/ccc:init` 흐름

1. 대상 프로젝트 스캔: 스택, 테스트 도구, 기존 CLAUDE.md/AGENTS.md, project memory.
2. Component 파악: 마켓플레이스 목록과 전역 settings를 비교해 전역 활성 Plugin을 판별. 전역, 프로젝트, 활성화 후보 Plugin, Harness의 모든 Component를 로컬 캐시에서 이름과 description만 읽어 펼친다. Conflict Rules와 대조한다.
3. Harness 선택 또는 Instant Harness 조립. 작업이 HARNESS.md의 어느 상황인지 판단한다.
4. worktree 준비: `git worktree add`, 전용 브랜치, 추적되지 않는 필요 파일 복사, 의존성 설치, 필요할 때만 포트 분리.
5. Harness 설치: worktree의 `.claude/`로 전체 복사(심링크 금지), 로컬 설정 작성, 해당 상황의 사용법만 담은 AGENTS.md 작성, CLAUDE.md에서 AGENTS.md import, 주입 파일을 git 로컬 exclude에 등록, 사용한 Harness 기록. Component 우선순위 규칙을 적용한다.
6. Smoke Check: herdr(`hc`)로 worktree에서 Worker를 백그라운드로 띄워 공통 점검 후 Harness별 확인 작업. 실패 시 고쳐서 최대 2회 재시도 후 사용자에게 보고. 실패 원인 기록. 외부 공개 작업 금지.

판단이 필요한 부분(Plugin 선택, 상황 판단, 충돌 해결)은 고정 스크립트가 아니라 Control Plane이 가이드를 읽고 수행한다. 특이한 오픈소스 Plugin도 수용하기 위해서다.

### 작업과 `/ccc:promote` 흐름

- Worker는 작업 후 draft PR을 올리고, 완료 보고에 Harness 사용감 1~2줄을 남긴다. 사용자가 init 때 명시적으로 허락한 경우에만 정식 PR.
- Control Plane은 worktree 정리 직전(또는 사용자의 직접 호출 시) Worker 보고 + 세션 출력 + transcript + 목표 달성 여부로 세 기준을 평가하고, 가치가 있을 때만 제안한다.
- 범용 레시피는 Harness 폴더로 추출해 ccc-plugin에 커밋(project-specific 제거, 200줄 이하, 외부 Component 복사). 프로젝트 친화도는 해당 프로젝트의 Claude project memory에 기록. 둘은 분리된 경로다.
- 평가가 끝난 뒤에만 worktree와 브랜치를 정리한다.

### 기본값

- worktree 위치: 대상 프로젝트 옆의 `<프로젝트>.worktrees/<branch>`.
- 브랜치 이름: `ccc/<작업명>`.
- worktrunk는 도입하지 않는다. 반복되는 불편이 생기면 재검토.

### 전역 설정 변경 (사용자 확인 후 마지막에)

- 사용자 전역 settings에 ccc 마켓플레이스를 등록하고 `ccc-harness`를 전역 활성화한다.
- exa를 어느 마켓플레이스 소스로 켤지는 그때 결정한다.
- 기존 env, herdr hook 등 머신 고유 설정은 건드리지 않는다.

## Testing Decisions

- 좋은 테스트는 외부에서 관찰 가능한 결과만 본다: 생성된 worktree의 파일 상태, `git status`의 청결도, Worker가 보고하는 로드된 Component 목록, Smoke Check 결과, 승격된 Harness 폴더의 내용과 규칙 준수 여부. skill 내부 문구나 스캔 순서 같은 구현 세부는 테스트하지 않는다.
- **단일 통합 Seam: init → Smoke Check → promote 생애주기.** 임시 Git 샘플 프로젝트를 대상으로:
  - `/ccc:init` 후: worktree와 브랜치가 생겼는가, 로컬 설정이 유효한 JSON이고 켠 Plugin이 마켓플레이스와 캐시에 실제로 있는가, 복사된 Component가 올바른 위치·이름이고 frontmatter가 유효한가, hook 스크립트에 실행 권한이 있는가, AGENTS.md가 CLAUDE.md에서 import되는가, 주입물이 git status에 나타나지 않는가, herdr Worker의 Smoke Check가 통과하는가.
  - 우선순위 규칙: 전역에 같은 이름의 skill이 있을 때 Worker에게 복사본만 보이는가, 같은 hook이 전역에 있을 때 한 번만 실행되는가, 일부 Component만 복사한 Plugin이 worktree에서 꺼졌는가.
  - `/ccc:promote` 후: 추출된 Harness에 project-specific 내용이 없고 HARNESS.md가 200줄 이하인가, 외부 Component가 Harness 안에 복사됐는가, project memory 기록이 프로젝트 레포가 아닌 memory 디렉토리에 생겼는가, 평가 후에만 worktree가 정리됐는가.
- 보조 검증: 마켓플레이스 매니페스트와 설정 템플릿의 JSON·스키마 유효성.
- Prior art: 레포에 기존 테스트가 없다. 이 프로젝트 자체가 Smoke Check라는 "실제 Worker를 띄워 확인"하는 패턴을 정의하므로, 통합 테스트도 같은 패턴(herdr로 Worker를 띄워 결과를 읽기)을 따른다.

## Out of Scope

- 초기 Harness 콘텐츠: 작성 규칙과 템플릿만 만든다. 실제 Harness는 실제 작업에서 Promotion으로 채운다.
- Plugin별 요약 카탈로그 문서: 캐시 실시간 스캔과 Conflict Rules로 대체한다.
- 외부 Plugin 코드 벤더링.
- worktrunk 도입과 빌드 캐시 공유(ext4라 불가).
- Claude Code 외 에이전트(Codex 등)를 Worker로 쓰는 것.
- 사용자 전역 settings를 ccc가 템플릿으로 동기화·덮어쓰기하는 것.
- tdd-guard, chorus, codex Plugin.
- 복사한 Component와 원본의 자동 동기화.
- 루프 같은 작업 흐름을 고정 메커니즘으로 강제하는 것: HARNESS.md에 안내로 적고, 구체 판단은 init 때 한다.

## Further Notes

- superpowers는 이전에 다른 프로젝트 scope로만 설치된 적이 있어서, 마켓플레이스에 등록할 때 소스를 확인해야 한다.
- pyright-lsp는 시스템에 pyright 바이너리가 있어야 동작한다. Smoke Check의 공통 점검에서 확인한다.
- 문서 확인 결과 Claude Code는 linked worktree에 `.claude/skills`가 없으면 메인 체크아웃의 project skill을 대신 로드한다. Harness를 `.claude/`로 복사하면 이 fallback이 꺼지므로, 프로젝트 원래 skill이 필요하면 함께 복사해야 하는지 구현 때 확인한다.
- ponytail과 superpowers는 자체 hook(SessionStart 등)을 가진다. 둘 다 켤 때 hook 중복·상호작용을 Smoke Check에서 확인하고, 문제가 있으면 첫 Conflict Rules 항목으로 남긴다.
- mattpocock-skills와 superpowers는 역할이 겹치는 skill이 많다(tdd ↔ test-driven-development, code-review ↔ requesting-code-review, diagnosing-bugs ↔ systematic-debugging, grilling ↔ brainstorming). 동시에 켤 때 우선순위를 정해야 한다.
- 이슈 트래커는 로컬 `.scratch/` 규칙을 쓴다.
