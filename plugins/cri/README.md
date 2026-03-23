# cri

Continuous Rule Improvement (CRI) - コーディング規約の自動抽出・統合プラグイン。

## Overview

Claude Code での作業中にユーザーが行ったコード修正指示をバックグラウンドで継続的に分析し、汎用的なコーディング規約を自動抽出して `.claude/rules/` に統合するプラグイン。

- **自動抽出**: セッション終了やコンテキスト圧縮のタイミングで会話ログを分析し、規約候補を `cri-candidates.json` に蓄積
- **対話型レビュー**: `occurrences >= 3` の候補を `/cri-review` スキルで対話的にレビューし、`.claude/rules/` に追記
- **ノイズ除去**: 特定のバグ修正や一時的な変更は自動でフィルタリング

## Installation

```shell
/plugin install cri@kawamoto-claude-plugins
```

マーケットプレイスの追加方法はリポジトリの [README](../../README.md) を参照。

## Setup

プラグインをインストールするだけで完了です。hooks は `hooks/hooks.json` により自動的に登録されます。

`cri-candidates.json` はプロジェクトごとの一時データです。リポジトリに含めない場合は `.gitignore` に追加してください。

```shell
echo '.claude/tmp/' >> .gitignore
```

## Skills

### `/cri-review`

蓄積されたルール候補をレビューして `.claude/rules/` にマージするスキル。

**トリガー条件:**

- `/cri-review` と入力したとき
- 「ルールをレビューして」「ルール候補を確認して」と依頼したとき
- 「蓄積されたルールを追加して」と言ったとき

**動作フロー:**

1. `.claude/tmp/cri-candidates.json` から `occurrences >= 3` の候補を読み込む
2. 各候補について、既存の `.claude/rules/` と競合チェックを実施
3. `AskUserQuestion` の `multiSelect` で全候補を一括提示し、ユーザーが追加するものを選択
4. 選択された候補を `.claude/rules/` の適切なファイルに追記（notes による修正指示にも対応）
5. 処理済み候補を `cri-candidates.json` から削除

## Technical Details

### コンポーネント構成

```
hooks/hooks.json        — フック定義（PreCompact, SessionEnd, Stop）
scripts/cri-extract.sh  — バックグラウンド抽出スクリプト
prompts/cri-extract-prompt.md — LLM 分析プロンプト
agents/cri-extract.md   — オンデマンド抽出エージェント（haiku）
skills/cri-review/      — 対話型レビュースキル
```

### データスキーマ

```json
{
  "candidates": [
    {
      "id": "rule_1a2b3c",
      "category": "style/syntax",
      "proposed_rule": "抽出された汎用的なルール文",
      "target_scope": "src/**/*.ts",
      "occurrences": 3,
      "trigger_logs": ["ユーザーの修正指示ログ"],
      "last_updated": "2026-03-05T00:00:00Z"
    }
  ]
}
```

### category の種別

| 値 | 説明 |
|----|------|
| `style/syntax` | コードスタイル・構文規則 |
| `naming` | 命名規則 |
| `structure` | ファイル・モジュール構造 |
| `pattern` | 設計パターン |
| `test` | テスト規則 |
| `doc` | ドキュメント規則 |

## Version

1.0.0
