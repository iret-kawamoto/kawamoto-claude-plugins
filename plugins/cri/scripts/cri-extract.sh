#!/usr/bin/env bash
# CRI バックグラウンド抽出スクリプト
# Plugin hooks/hooks.json から呼び出される

set -euo pipefail

# プラグインルート（hooks.json から ${CLAUDE_PLUGIN_ROOT} 経由で設定される）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# プロジェクトルート（Claude Code が設定する環境変数）
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"

PROMPT_FILE="${PLUGIN_ROOT}/prompts/cri-extract-prompt.md"
CANDIDATES_FILE="${PROJECT_ROOT}/.claude/tmp/cri-candidates.json"
TMP_DIR="${PROJECT_ROOT}/.claude/tmp"

# .claude/tmp/ ディレクトリが無ければ作成
mkdir -p "${TMP_DIR}"

# cri-candidates.json が無ければ初期化
if [ ! -f "${CANDIDATES_FILE}" ]; then
  echo '{"candidates":[]}' > "${CANDIDATES_FILE}"
fi

# プロンプトファイルの存在確認
if [ ! -f "${PROMPT_FILE}" ]; then
  exit 0
fi

# トランスクリプトの取得
# 優先順位: $CLAUDE_TRANSCRIPT 環境変数 → stdin → ~/.claude/projects/ 配下の最新 JSONL
TRANSCRIPT=""

if [ -n "${CLAUDE_TRANSCRIPT:-}" ]; then
  TRANSCRIPT="${CLAUDE_TRANSCRIPT}"
elif [ ! -t 0 ]; then
  TRANSCRIPT="$(cat)"
else
  # ~/.claude/projects/ 配下の最新 JSONL をフォールバックで使用
  LATEST_JSONL="$(find ~/.claude/projects/ -name '*.jsonl' -type f 2>/dev/null | sort -t/ -k1 | tail -n1)"
  if [ -n "${LATEST_JSONL}" ] && [ -f "${LATEST_JSONL}" ]; then
    TRANSCRIPT="$(tail -n 100 "${LATEST_JSONL}" 2>/dev/null || true)"
  fi
fi

# トランスクリプトが空の場合はスキップ
if [ -z "${TRANSCRIPT}" ]; then
  exit 0
fi

# 現在の候補JSONを読み込む
CURRENT_CANDIDATES="$(cat "${CANDIDATES_FILE}")"

# プロンプトを構築（プレースホルダーを置換）
PROMPT="$(cat "${PROMPT_FILE}")"
PROMPT="${PROMPT/\{\{CURRENT_CANDIDATES\}\}/${CURRENT_CANDIDATES}}"
PROMPT="${PROMPT/\{\{TRANSCRIPT\}\}/${TRANSCRIPT}}"

# LLM を呼び出して分析（バッチモード・ツールなし）
OUTPUT="$(claude -p "${PROMPT}" --no-tools 2>/dev/null || true)"

# 出力が空の場合はスキップ
if [ -z "${OUTPUT}" ]; then
  exit 0
fi

# 出力が valid JSON かつ .candidates キーを持つ場合のみ上書き
if echo "${OUTPUT}" | jq -e '.candidates' > /dev/null 2>&1; then
  echo "${OUTPUT}" > "${CANDIDATES_FILE}"
fi
