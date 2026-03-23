#!/usr/bin/env bash
# CRI バックグラウンド抽出スクリプト
# Plugin hooks/hooks.json から呼び出される
#
# PreCompact と SessionEnd の両方から async で呼ばれるため、
# mkdir ベースのロックで同時実行を排他制御する。

set -euo pipefail

# プラグインルート（hooks.json から ${CLAUDE_PLUGIN_ROOT} 経由で設定される）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# プロジェクトルート（Claude Code が設定する環境変数）
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"

PROMPT_FILE="${PLUGIN_ROOT}/prompts/cri-extract-prompt.md"
CANDIDATES_FILE="${PROJECT_ROOT}/.claude/tmp/cri-candidates.json"
TMP_DIR="${PROJECT_ROOT}/.claude/tmp"

# --- 初期化（ロックより先に TMP_DIR を確保する） ---
mkdir -p "${TMP_DIR}"

# --- 排他制御 ---
# mkdir はアトミックなので、ロックディレクトリの作成を競合検出に使う。
# macOS に flock は無いため、ポータブルな mkdir 方式を採用。
LOCKDIR="${TMP_DIR}/.cri-extract.lock"
STALE_THRESHOLD=300  # 5分（LLM呼び出しのタイムアウト目安）

# ステールロック検出: 時間 AND PID 生存チェックの両方で判定。
# STALE_THRESHOLD 超かつロック保持プロセスが死んでいる場合のみ除去。
if [ -d "${LOCKDIR}" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "${LOCKDIR}" 2>/dev/null || stat -c %Y "${LOCKDIR}" 2>/dev/null || echo 0) ))
  if [ "${lock_age}" -gt "${STALE_THRESHOLD}" ]; then
    lock_pid="$(cat "${LOCKDIR}/pid" 2>/dev/null || echo "")"
    if [ -z "${lock_pid}" ] || ! kill -0 "${lock_pid}" 2>/dev/null; then
      rm -rf "${LOCKDIR}" 2>/dev/null || true
    fi
  fi
fi

# 非ブロッキングでロック取得を試行。失敗時は別インスタンスが実行中なのでスキップ。
if ! mkdir "${LOCKDIR}" 2>/dev/null; then
  exit 0
fi
echo $$ > "${LOCKDIR}/pid"
trap 'rm -rf "${LOCKDIR}" 2>/dev/null' EXIT

if [ ! -f "${CANDIDATES_FILE}" ]; then
  echo '{"candidates":[]}' > "${CANDIDATES_FILE}"
fi

if [ ! -f "${PROMPT_FILE}" ]; then
  exit 0
fi

# --- トランスクリプト取得 ---
# 優先順位: $CLAUDE_TRANSCRIPT 環境変数 → stdin → ~/.claude/projects/ 配下の最新 JSONL
TRANSCRIPT=""

if [ -n "${CLAUDE_TRANSCRIPT:-}" ]; then
  TRANSCRIPT="${CLAUDE_TRANSCRIPT}"
elif [ ! -t 0 ]; then
  TRANSCRIPT="$(cat)"
else
  LATEST_JSONL="$(find ~/.claude/projects/ -name '*.jsonl' -type f -print0 2>/dev/null | xargs -0 ls -1t 2>/dev/null | head -n1)"
  if [ -n "${LATEST_JSONL}" ] && [ -f "${LATEST_JSONL}" ]; then
    TRANSCRIPT="$(tail -n 100 "${LATEST_JSONL}" 2>/dev/null || true)"
  fi
fi

if [ -z "${TRANSCRIPT}" ]; then
  exit 0
fi

# --- LLM 分析 ---
CURRENT_CANDIDATES="$(cat "${CANDIDATES_FILE}")"

PROMPT="$(cat "${PROMPT_FILE}")"
PROMPT="${PROMPT/\{\{CURRENT_CANDIDATES\}\}/${CURRENT_CANDIDATES}}"
PROMPT="${PROMPT/\{\{TRANSCRIPT\}\}/${TRANSCRIPT}}"

OUTPUT="$(claude -p "${PROMPT}" --no-tools 2>/dev/null || true)"

if [ -z "${OUTPUT}" ]; then
  exit 0
fi

# --- 原子的書き込み ---
# tmpファイルに書いてから mv で差し替え。途中クラッシュでの部分書き込みを防止。
if echo "${OUTPUT}" | jq -e '.candidates' > /dev/null 2>&1; then
  echo "${OUTPUT}" > "${CANDIDATES_FILE}.tmp"
  mv "${CANDIDATES_FILE}.tmp" "${CANDIDATES_FILE}"
fi
