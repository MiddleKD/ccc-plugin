# ccc-plugin

작업마다 맞춤 환경(Harness)을 갖춘 Worker를 띄우고, 잘 동작한 환경은 재사용할 수 있게 쌓아 두는 개인 Claude Code 마켓플레이스입니다.

herdr에서 여는 Claude 세션 하나가 **Control Plane**이 됩니다. 사용자는 Control Plane에게 할 일을 말하기만 하면 됩니다. 그러면 Control Plane이 다음을 처리합니다.

1. 프로젝트 옆에 격리된 git worktree를 만듭니다.
2. 그 작업에 맞는 skill, agent, hook, workflow, 지침(`AGENTS.md`)을 조립합니다.
3. 실제 Worker를 띄워 환경이 제대로 뜨는지 확인합니다(Smoke Check).
4. 작업을 Worker에게 넘기고 끝까지 지켜봅니다.
5. 끝나면 그 환경이 다시 쓸 가치가 있는지 평가해서, 있으면 Harness 라이브러리로 승격합니다.

용어는 [`CONTEXT.md`](CONTEXT.md)를 따릅니다.

## 구성

| 경로 | 내용 |
|---|---|
| `.claude-plugin/marketplace.json` | `ccc` 마켓플레이스. 외부 Plugin은 업스트림 Git 소스를 가리키고, 코드를 이 레포에 복사하지 않습니다 |
| `plugins/ccc/` | Control Plane 플러그인: `init`·`promote` skill, 검사 스크립트, Worker용 hook |
| `harnesses/` | 승격된 Harness 라이브러리와 빈 템플릿(`_template/`) |
| `CONFLICTS.md` | 실제로 부딪힌 Plugin·Component 충돌과 우선순위 기록 |
| `docs/adr/` | 되돌리기 어려운 설계 결정 |

등록된 Plugin: `ccc`, `mattpocock-skills`, `exa`, `ponytail`, `pyright-lsp`, `superpowers`.

## 설치

### 필요한 것

- Claude Code
- herdr와 `hc` (herdr-core): Worker와 Smoke Check를 띄우는 데 씁니다. `claude -p`는 쓰지 않습니다.
- `git`, `jq`, `node`
- LSP Plugin을 쓸 경우 그 바이너리(예: `pyright-langserver`)

### 마켓플레이스 등록과 활성화

```bash
claude plugin marketplace add /path/to/ccc-plugin
claude plugin install ccc@ccc
```

`ccc`는 사용자(user) scope로 전역에 켜 둡니다. 그래야 어느 프로젝트에서 Control Plane을 열든 바로 쓸 수 있습니다.

나머지 Plugin은 전역으로 켤 필요가 없습니다. Control Plane이 작업별로 worktree 안에서만 켭니다(`--scope local`). 늘 쓰는 Plugin(예: `exa`)만 전역으로 켜 두세요.

```bash
claude plugin install exa@ccc   # 선택: 전역으로 늘 쓸 Plugin
```

전역 `~/.claude/settings.json`의 `env`와 herdr hook은 ccc가 건드리지 않습니다.

### 설치 확인

```bash
claude plugin list | grep -A3 'ccc@ccc'      # Status: enabled
```

새 Claude 세션에서 `/ccc:init`과 `/ccc:promote`가 보이면 설치된 것입니다.

## 기본 사용법

### 1. Control Plane 열기

작업할 프로젝트 폴더에서 herdr로 Claude 세션을 엽니다. 이 세션이 Control Plane입니다. 시작하기 전에 메인 체크아웃에 커밋되지 않은 변경이 없게 해 두세요.

### 2. 할 일 말하기

자연어로 말하면 Control Plane이 알아서 `/ccc:init`을 부릅니다. 직접 `/ccc:init <할 일>`로 불러도 됩니다.

```text
돈 계산을 float에서 Decimal로 옮겨줘. 세금은 센트 단위 반올림, 영수증 형식은 그대로.
새 Worker에게 맡기고 끝까지 지켜본 뒤 worktree 정리 전에 할 일도 다 해. PR/push는 하지 마.
```

요청에 넣으면 좋은 것:
- **완료 조건**: 어떤 테스트·타입검사가 통과해야 하는지, 바뀌면 안 되는 것은 무엇인지
- **공개 범위**: PR·push 여부. 기본값은 draft PR이고, "PR/push 금지"라고 하면 커밋에서 멈춥니다
- **검증 성격**: "고친 사람이 스스로 안전하다고 판정하면 안 된다"처럼 말하면 독립 reviewer agent가 붙습니다

### 3. 진행 중에 일어나는 일

Control Plane이 `/ccc:init`을 다음 순서로 진행합니다.

1. **스캔**: 스택, 테스트 도구, 기존 `CLAUDE.md`/`AGENTS.md`/`.claude/`, 그리고 이 프로젝트의 project memory를 확인합니다.
2. **Component 파악**: 전역·프로젝트·Plugin의 모든 Component를 로컬 캐시에서 읽고 `CONFLICTS.md`와 대조합니다.
3. **Harness 선택**: 맞는 승격 Harness가 있으면 그것을, 같은 작업 형태의 저장된 초안이 있으면 그것을 쓰고, 둘 다 없으면 Instant Harness를 새로 만듭니다.
4. **worktree 준비**: `../<프로젝트>.worktrees/<작업명>`에 `ccc/<작업명>` 브랜치로 만들고, `.env` 같은 추적되지 않는 파일 복사와 의존성 설치까지 합니다.
5. **Harness 설치**: Component 복사, `settings.local.json`, `AGENTS.md`, `CLAUDE.md`의 `@AGENTS.md` import까지 설치합니다. 주입한 파일은 git local exclude에 등록돼 `git status`에 나타나지 않습니다.
6. **Smoke Check**: 실제 Worker를 띄워 Component가 로드되고 검증 명령이 도는지 확인합니다. 실패하면 최대 2회 고쳐서 재시도합니다.
7. **Worker에게 넘김**: 게이트를 모두 통과해야만 `ccc-handoff.sh`가 Worker를 띄웁니다. Control Plane은 Worker가 끝날 때까지 기다립니다.

Worker가 끝나면 Control Plane이 `/ccc:promote`를 부릅니다.

1. Worker 보고, transcript, git 상태로 세 기준(막힘 없이 끝냈는가, Harness가 기여했는가, 재사용 가치가 있는가)을 각각 예/아니오로 평가합니다.
2. 판정에 따라 Harness를 승격하거나(사용자 승인 후 이 레포에 커밋), project memory에 기록합니다.
3. worktree를 지우고 **브랜치는 남깁니다**. Worker의 커밋이 결과물입니다.

### 4. 승인 요청에 답하기

Control Plane은 다음 작업 전에 승인을 요청합니다.
- 이 레포(`ccc-plugin`)에 커밋할 때(Harness 승격, `CONFLICTS.md` 추가)
- Worker 브랜치를 지울 때
- `--force`로 worktree를 지울 때
- 허락된 범위를 넘는 push나 PR을 할 때

요청은 대화창에 오고, `approve` 또는 `reject`(이유 포함)로 답하면 됩니다. 반려하면서 고칠 점을 말하면 Control Plane이 반영해서 다시 요청합니다.

다른 에이전트가 hc로 Control Plane에게 일을 시킨 경우에는 승인 요청이 `hc send`로 그 에이전트에게 갑니다.

### 5. 결과 받기

마지막 보고에는 다음이 들어 있습니다.
- 브랜치와 커밋 해시
- 검증 결과(게이트 출력)
- Harness 구성: 어떤 skill·agent·hook·workflow·md를 왜 골랐는지
- 판정과 근거 3줄
- 남은 일

결과물은 `ccc/<작업명>` 브랜치에 있습니다. 확인한 뒤 직접 merge하거나 PR을 여세요.

## 상황별 사용

| 상황 | 하는 일 |
|---|---|
| 처음 해 보는 종류의 작업 | 그냥 요청합니다. Instant Harness가 만들어지고, 쓸 만하면 승격이 제안됩니다 |
| 전에 했던 종류의 작업(다른 프로젝트 포함) | 그냥 요청합니다. 맞는 승격 Harness가 자동으로 선택됩니다 |
| 같은 프로젝트에서 반복되는 작업(릴리스 감사 등) | 그냥 요청합니다. 저장된 초안을 이어서 쓰고 실행 횟수가 쌓이며, 반복이 확인되면 승격됩니다 |
| 여러 작업을 동시에 | Control Plane에 작업을 여러 개 맡깁니다. worktree와 브랜치가 작업마다 분리되고, 웹 프로젝트는 포트도 나뉩니다 |
| 독립 검증이 필요한 작업(보안, 감사) | 요청에 "스스로 판정하면 안 된다"고 적습니다. reviewer agent가 붙습니다 |
| 특정 Harness를 쓰고 싶을 때 | `harnesses/<이름>/HARNESS.md`를 쓰라고 요청에 적습니다 |
| 승격을 직접 판단하고 싶을 때 | 언제든 `/ccc:promote`를 부릅니다. worktree가 남아 있을 때 불러야 합니다 |

## 명령어

### Skill

| 명령 | 언제 |
|---|---|
| `/ccc:init <할 일>` | 새 Worker에게 작업을 맡길 때. 보통은 자연어 요청만으로 Control Plane이 알아서 부릅니다 |
| `/ccc:promote` | Worker가 끝난 뒤 worktree를 지우기 전. 보통은 Control Plane이 알아서 부릅니다 |

### 검사 스크립트

Control Plane이 쓰는 스크립트지만, 사용자가 직접 상태를 확인할 때도 쓸 수 있습니다. 경로는 `plugins/ccc/scripts/`입니다.

```bash
# worktree가 Worker를 받을 준비가 됐는지
ccc-gate.sh init <worktree>

# 작업이 끝난 뒤 정리가 제대로 됐는지 (worktree 제거, 브랜치 보존, 판정 기록, 메인 체크아웃 상태)
ccc-gate.sh cleanup <메인 체크아웃> ccc/<작업명>

# Harness 폴더가 라이브러리 규칙을 지키는지. worktree를 주면 프로젝트 경로가 섞였는지도 봅니다
ccc-gate.sh harness harnesses/<이름> [<원래 worktree>]
```

모든 줄이 `PASS`이고 마지막에 `ALL GATES PASS`가 나오면 통과입니다. `FAIL` 줄 아래에 고칠 내용이 적혀 있습니다.

`ccc-handoff.sh`(Worker 시작)와 `ccc-verdict.sh`(판정 기록과 보고)는 Control Plane 세션 안에서만 의미가 있습니다.

### 상태 확인

```bash
git worktree list                     # 진행 중인 worktree
git branch --list 'ccc/*'             # Worker 결과 브랜치
ls .git/ccc/                          # 작업별 handoff 기록 (Worker, 판정, 게이트 출력)
ls .git/ccc/drafts/                   # 이 프로젝트에 저장된 Instant Harness 초안과 실행 횟수
hc ls                                 # 실행 중인 Control Plane·Worker
```

## Harness 라이브러리

`harnesses/<이름>/`의 폴더 하나가 Harness 하나입니다. 다음 파일로 구성됩니다.
- **필수** `HARNESS.md`(200줄 이하): 맞는 작업과 맞지 않는 작업, Component와 고른 이유, 단계별 게이트, 함정, init 때 판단할 점, Smoke Check
- **선택**: `skills/`, `agents/`, `workflows/`, `hooks/`, `AGENTS.md`, `settings.local.json`

현재 승격된 Harness:

| 이름 | 맞는 작업 |
|---|---|
| `typed-value-migration` | 여러 모듈에 걸친 값 표현 변경(예: float → Decimal, 정수 센트), 엄격한 타입 검사 |
| `root-cause-bugfix` | 스택 트레이스 없는 증상 보고에서 근본 원인을 찾아 테스트 먼저 수정, 같은 원인의 다른 증상까지 차단 |
| `documentation-release-audit` | 릴리스 전 Markdown 문서 전체 감사(깨진 링크, CLI 플래그, TODO/deprecated) |

Harness는 Promotion으로만 추가됩니다. 작성 규칙은 [`harnesses/README.md`](harnesses/README.md)에 있고, 외부 Component를 복사해 폴더 하나로 완결하는 이유는 [ADR 0001](docs/adr/0001-harness-self-contained-copy.md)에 있습니다. Harness에는 프로젝트 고유 정보를 넣지 않습니다. 그런 정보는 init이 worktree의 `AGENTS.md`에 채웁니다.

## Plugin 추가와 수정

- **Plugin 추가**: `.claude-plugin/marketplace.json`에 업스트림 `github` 또는 `git-subdir` 소스로 항목을 추가하고 `claude plugin validate .claude-plugin/marketplace.json`으로 확인합니다.
- **Plugin 동작 보완**: 먼저 Harness 쪽(지침, hook, 설정)에서 보완합니다. 코드를 꼭 고쳐야 할 때만 그 Plugin의 소스를 개인 Fork로 바꿉니다.
- **충돌 기록**: 실제로 부딪힌 충돌만 `CONFLICTS.md`에 한두 줄씩 기록합니다. Control Plane이 promote 때 제안합니다.

## 알아 두면 좋은 동작

- **worktree 안의 subagent는 그 worktree에서 실행됩니다**: ccc hook이 Worker의 Agent 호출에서 `isolation`을 지웁니다. 그래야 reviewer가 아직 커밋하지 않은 변경을 보고, 메인 체크아웃에 worktree가 남지 않습니다. `.claude/.ccc.json`이 없는 일반 세션에서는 아무것도 하지 않습니다.
- **skill은 전역이 프로젝트를 이깁니다**: 그래서 복사한 skill은 이름 앞에 Harness 이름을 붙이고, 같은 이름의 전역 skill은 worktree 설정에서 끕니다. Plugin skill은 `skillOverrides`로 숨길 수 없어서 Plugin 자체를 끕니다.
- **hook은 모든 층이 합쳐져 실행됩니다**: `command` 문자열이 같은 hook은 한 번만 실행됩니다. `disableAllHooks`는 herdr 상태 hook까지 꺼 버리므로 쓰지 않습니다.
- **같은 작업을 반복하면 브랜치 이름에 번호가 붙습니다**(`-2`, `-3`). 이전 브랜치는 건드리지 않습니다.

## 문제 해결

| 증상 | 확인할 것 |
|---|---|
| Control Plane이 Worker를 띄우지 않음 | `ccc-gate.sh init <worktree>`를 실행해 `FAIL` 줄을 확인합니다 |
| LSP Plugin이 동작하지 않음(`Executable not found`) | hc 세션의 PATH에 셸 rc에서 추가한 경로(pnpm, nvm 등)가 없을 수 있습니다. worktree `settings.local.json`의 `env.PATH`로 넣습니다 |
| 메인 체크아웃에 `.claude/worktrees/`가 생김 | subagent worktree가 남은 것입니다. 안을 확인한 뒤 `git worktree remove`로 지웁니다. `ccc-gate.sh cleanup`이 이 경우를 잡습니다 |
| 새 폴더에서 Claude가 trust 확인을 물음 | 처음 여는 프로젝트라 그렇습니다. 직접 승인하세요 |
| 승인 요청이 오지 않고 멈춤 | Control Plane 화면에 대화창 질문이 떠 있는지 확인합니다(`hc read <terminal>`) |

## 현재 한계

- 지금까지 검증은 직접 만든 샘플 프로젝트로만 했습니다. 실제 프로젝트에서는 아직 써 보지 않았습니다.
- Control Plane이 skill을 직접 만드는 경우는 아직 관찰하지 못했습니다. workflow 작성은 고친 뒤 다시 확인하지 않았습니다.
- 승격된 `documentation-release-audit`의 재사용 근거는 한 프로젝트에서 반복 실행한 결과뿐입니다.
- Worker 커밋의 Co-Authored-By 형식은 Control Plane이 정하지 않습니다.
