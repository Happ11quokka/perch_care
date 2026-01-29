---
name: codex
description: |
  사용자가 다음을 요청할 때 사용:
  - "코덱스로 분석", "codex 실행"
  - "코드 리뷰", "버그 찾기"
  주요 명령어: codex exec, codex apply, codex resume
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Codex CLI Integration

OpenAI Codex CLI(`codex-cli`)를 활용한 코드 분석, 리뷰, 버그 수정 스킬.

## Overview

Codex CLI를 실행하여 코드 분석 결과를 받고, 생성된 diff를 프로젝트에 적용하는 워크플로우를 제공합니다.

## When to Use

- 코드 리뷰 요청 시
- 버그 탐색 및 수정 요청 시
- 리팩토링 제안 요청 시
- "코덱스로 분석해줘", "codex 실행" 등의 요청 시

## 모델 선택 가이드

| 작업 유형 | 추천 모델 | Effort |
|-----------|----------|--------|
| 코드 리뷰 | codex-mini-latest (기본) | high |
| 버그 수정 | codex-mini-latest | high |
| 리팩토링 | codex-mini-latest | medium |
| 간단한 질문 | codex-mini-latest | low |

> **참고**: ChatGPT 계정 로그인 시 `codex-mini-latest`가 기본 모델입니다.
> API 키(`OPENAI_API_KEY`) 사용 시 `o4-mini`, `gpt-4.1` 등도 사용 가능합니다.

## Instructions

### 1단계: 사전 확인

Codex CLI 설치 및 버전을 확인합니다.

```bash
which codex && codex --version || echo "codex not found"
```

설치되어 있지 않다면:

```bash
npm install -g @openai/codex
```

### 2단계: 분석 요청 (codex exec)

**핵심 플래그:**
- `--full-auto` : 비대화형 자동 실행 (필수)
- `--output-last-message <path>` : 마지막 응답을 파일로 저장
- `-c 'model_reasoning_effort="high"'` : reasoning effort 설정 (config override)
- `--model <model>` : 모델 지정 (생략 시 config 기본값)

```bash
# 프로젝트 전체 코드 리뷰 (기본 모델, high effort)
codex exec \
  -c 'model_reasoning_effort="high"' \
  --full-auto \
  --output-last-message /tmp/codex_output.md \
  "이 프로젝트의 lib/ 디렉토리 코드를 리뷰해줘. 코드 품질, 버그, 보안, 성능을 한국어 마크다운으로 정리해줘."

# 특정 파일 분석
codex exec \
  -c 'model_reasoning_effort="medium"' \
  --full-auto \
  --output-last-message /tmp/codex_output.md \
  "lib/src/screens/home/home_screen.dart 파일을 분석해줘"

# API 키 사용 시 모델 지정
codex exec \
  --model o4-mini \
  --full-auto \
  --output-last-message /tmp/codex_output.md \
  "이 코드에서 버그를 찾아줘"
```

### 3단계: 결과 확인

`--output-last-message`로 저장한 파일을 읽습니다.

```bash
cat /tmp/codex_output.md
```

결과 파일이 비어 있으면 전체 실행 로그를 확인합니다 (background task output).

### 4단계: 변경사항 적용 (codex apply)

사용자가 "적용해줘" 또는 "수정해줘"라고 요청하면 diff를 적용합니다.

```bash
# 최근 세션의 변경사항 적용
codex apply

# 특정 세션의 변경사항 적용
codex apply <session-id>

# dry-run으로 미리 확인
codex apply --dry-run <session-id>
```

적용 후 반드시 결과를 확인합니다:

```bash
git diff
flutter analyze
```

### 5단계: 세션 이어하기 (codex resume)

이전 분석을 이어서 진행할 때 사용합니다.

```bash
codex resume              # 가장 최근 세션
codex resume <session-id> # 특정 세션
```

## 워크플로우 다이어그램

```
사용자: "코덱스로 분석해줘"
  ↓
[1] which codex && codex --version
  ↓
[2] codex exec -c 'model_reasoning_effort="high"' --full-auto --output-last-message <path> "프롬프트"
  ↓
[3] cat <path> → 결과 파싱 및 리포트
  ↓
사용자: "적용해줘"
  ↓
[4] codex apply → git diff → flutter analyze
  ↓
[5] 결과 리포트 (변경 파일, 분석 결과)
```

## 실행 전 체크리스트

1. `codex` CLI가 설치되어 있는지 확인
2. 인증 확인: `OPENAI_API_KEY` 환경변수 또는 ChatGPT 로그인(`codex login`)
3. 프로젝트 루트 디렉토리에서 실행
4. 적용 전 `git status`로 uncommitted changes 확인

## 에러 핸들링

| 에러 | 원인 | 해결 |
|------|------|------|
| `codex: command not found` | CLI 미설치 | `npm install -g @openai/codex` |
| `Invalid value "xhigh" for model_reasoning_effort` | config에 잘못된 effort 값 | `-c 'model_reasoning_effort="high"'`로 override |
| `Model ... is not available` | ChatGPT 계정에서 미지원 모델 | `--model` 생략 (기본 `codex-mini-latest` 사용) |
| `API key not found` | 환경변수 미설정 | `export OPENAI_API_KEY=<key>` 또는 `codex login` |
| `apply failed` | conflict 발생 | `git stash` 후 재시도 |
| `session not found` | 세션 만료/삭제 | `codex sessions list`로 확인 |

## 인증 방식

| 방식 | 설정 | 사용 가능 모델 |
|------|------|---------------|
| ChatGPT 로그인 | `codex login` | `codex-mini-latest` |
| API 키 | `export OPENAI_API_KEY=...` | `o4-mini`, `gpt-4.1`, `codex-mini-latest` 등 |

## Best Practices

### DO
- `--full-auto` + `--output-last-message`로 결과를 파일에 저장
- `-c 'model_reasoning_effort="high"'`로 effort 명시 (config 오류 방지)
- 적용 후 `flutter analyze`로 정적 분석 실행
- 변경사항을 커밋 전에 리뷰
- 긴 분석은 timeout을 600000ms로 설정

### DON'T
- `--effort` 플래그 직접 사용하지 않기 (v0.42 미지원, config override 사용)
- 분석 결과를 검토 없이 바로 적용하지 않기
- 프로덕션 브랜치에서 직접 `codex apply` 하지 않기
- API 키를 코드에 하드코딩하지 않기
