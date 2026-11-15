# ccc

Building a cross-plugin dynamic harness for Claude Code, inspired by Dynamic Workflows.

ccc는 **C**laude **C**ode **C**ustom의 약자입니다.

작업마다 여러 Plugin의 skill·agent·hook·workflow를 골라 Harness를 즉석에서 조립하고,
격리된 worktree의 Worker에게 맡깁니다. 잘 맞은 Harness는 저장해 다음 작업에 다시 씁니다.

## 준비물

- Claude Code
- herdr (`hc` 명령이 동작해야 합니다)
- `git`, `jq`, `node`

## 설치

터미널에서 한 번만 실행합니다.

```bash
claude plugin marketplace add /path/to/ccc-plugin
claude plugin install ccc@ccc
```

새 Claude 세션에서 `/ccc:init`이 보이면 설치된 것입니다.

## 사용법

1. 작업할 프로젝트 폴더에서 herdr로 Claude를 엽니다.
2. 아래 표에서 상황에 맞는 명령어를 입력합니다.

| 이럴 때 | 이렇게 입력 |
|---|---|
| 새 작업을 맡길 때 | `/ccc:init <할 일>` |
| Worker는 작업을 끝냈는데 Claude가 마무리(확인·정리·보고)를 안 하고 멈췄을 때 | `/ccc:promote` |

`/ccc:init` 하나로 준비, 작업, 확인, 정리가 끝까지 진행됩니다. `/ccc:promote`는 마무리가 빠졌을 때만 씁니다.

### 예시

```text
/ccc:init 로그인 실패 시 에러 메시지가 안 뜨는 버그 고쳐줘. 테스트 통과해야 하고, PR이나 push는 하지 마.
```

할 일과 함께 이 두 가지를 적어 주세요.

- **끝났다고 볼 기준**: 예) "테스트 통과", "화면 형식은 그대로"
- **PR·push를 해도 되는지**: 적지 않으면 draft PR까지 올립니다.

## 진행 중에 할 일

Claude가 승인을 물으면 `approve`(승인) 또는 `reject`(거절)로 답합니다. 거절할 때 이유를 적으면 Claude가 고쳐서 다시 묻습니다.

승인을 묻는 경우는 이것뿐입니다.

- 작업 환경을 다음에 다시 쓰도록 저장할 때
- 결과 브랜치를 지울 때
- 허락하지 않은 push나 PR을 해야 할 때

## 결과 확인

작업이 끝나면 Claude가 무엇을 바꿨는지 보고합니다.
결과는 `ccc/<작업명>` 브랜치에 있습니다. 내용을 확인한 뒤 직접 merge하세요.

```bash
git branch --list 'ccc/*'
```

## 문제가 생기면

| 증상 | 해결 |
|---|---|
| Claude가 폴더를 믿을지 묻는다 | 처음 여는 폴더라서 그렇습니다. 승인하세요 |
| 진행이 멈춘 것 같다 | Claude 화면에 질문이 떠 있는지 확인하고 답하세요 |
| 작업 전에 멈추고 커밋 안 된 변경이 있다고 한다 | 지금 작업 중인 변경을 먼저 커밋하거나 정리하세요 |
