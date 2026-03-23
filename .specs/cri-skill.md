# 開発指示書: Continuous Rule Improvement (CRI) スキル

## 1. 概要

CRI (Continuous Rule Improvement) は、Claude Codeを利用中の「ユーザーからのコード修正指示」をバックグラウンドで継続的に分析し、頻出するコーディング規約や好みを自動抽出して `.claude/rules` に賢く統合するカスタムスキル群です。最新のAgent Skills仕様を活用し、自律的な競合チェックと柔軟なマージを実現します。

## 2. ディレクトリ・ファイル構成

実装対象となるプロジェクトルート配下のディレクトリ構成は以下の通りです。

```plaintext
.claude/
 ├─ settings.json                 # [更新] Hookの定義
 ├─ rules/                        # 確定したルールが保存されるディレクトリ（既存）
 ├─ tmp/
 │   └─ cri-candidates.json       # [新規] 抽出されたルール候補の一時保存（ステート管理）
 ├─ prompts/
 │   └─ cri-extract-prompt.md     # [新規] 抽出・クラスタリング用プロンプト
 ├─ scripts/
 │   └─ cri-extract.sh            # [新規] 非同期抽出スクリプト（LLMを呼び出してJSONを更新）
 └─ skills/
     └─ cri-review/               
         └─ SKILL.md              # [新規] 対話・マージ用エージェントスキル定義

```

*※注: .claude/tmp/ はリポジトリを汚さないよう .gitignore に追加されるべきパスとして扱います。*

## 3. Hooks 定義 (hooks/hooks.json)

プラグインの `hooks/hooks.json` により、インストール時に自動的にフックが登録されます。手動での settings.json 編集は不要です。

- **PreCompact / SessionEnd**: `cri-extract.sh` をバックグラウンドで非同期実行
- **Stop**: `cri-candidates.json` に `occurrences >= 3` の候補があればターミナルに通知

スクリプト内では `${CLAUDE_PLUGIN_ROOT}` でプラグインのリソース、`$CLAUDE_PROJECT_DIR` でプロジェクトルートを参照します。

## 4. データスキーマ (.claude/tmp/cri-candidates.json)

ルール候補を管理するJSONファイルの初期構造（空の状態）は以下に従ってください。

```json
{
  "candidates": [
    {
      "id": "rule_1a2b3c",
      "category": "style/syntax",
      "proposed_rule": "抽出された汎用的なルール文",
      "target_scope": "適用対象のファイルパスや拡張子（例: src/**/*.tsx）",
      "occurrences": 3,
      "trigger_logs": [
        "ユーザーの実際の修正指示ログ1",
        "ユーザーの実際の修正指示ログ2"
      ],
      "last_updated": "2026-03-05T00:00:00Z"
    }
  ]
}

```

## 5. 各コンポーネントの実装要件

## A. バックグラウンド抽出 (cri-extract.sh & cri-extract-prompt.md)

- **処理:** Claude Codeの直近の会話ログ（transcript）を取得し、Claude CLIツールをバッチモード（非対話）で呼び出して分析させます。
- **LLMタスク (cri-extract-prompt.md):** 「入力ログが特定のロジック修正（ノイズ）か、汎用的な規約か」を判定。規約であれば `cri-candidates.json` の内容と照合し、新規追加または既存の `occurrences` をインクリメントした**更新後のJSONのみ**を出力させるプロンプトを作成してください。
- **スクリプト実装:** 現在のメインセッションのコンテキストを汚染しないよう、`claude -p "$(cat .claude/prompts/cri-extract-prompt.md)" --tools ""` のようにツール利用を無効化したバッチモードで呼び出し、標準出力で `cri-candidates.json` を上書き保存する構成にしてください。

## B. 対話型レビュー＆マージスキル (.claude/skills/cri-review/SKILL.md)

Claude CodeのAgent Skillsとして、対話とマージのワークフローを定義します。以下の内容でファイルを作成してください。

```markdown
---
name: cri-review
description: CRI (Continuous Rule Improvement) - 蓄積されたコーディングルール候補（cri-candidates.json）をレビューし、プロジェクトの規約（.claude/rules/）にマージします。ユーザーからルールのレビューや追加を求められた際に実行してください。
---

# Continuous Rule Improvement (CRI) レビュー実行手順

あなたは有能なリードエンジニアとして、コーディングルールのレビューと統合を対話的に行ってください。以下の手順に厳密に従い、ファイル操作ツール（`read_file`, `edit_file`等）を駆使して自律的に作業を進めてください。

1. **候補の読み込み:** `.claude/tmp/cri-candidates.json` を読み込み、`occurrences >= 3` のルール候補をリストアップしてください。該当がない場合は「✨ 現在レビュー待ちのルールはありません」と伝えて処理を終了してください。
2. **対話型レビュー（ループ処理）:** 候補がある場合、1つずつ以下の処理を行ってください。
   - **ステップA（競合チェック）:** 既存の `.claude/rules/` 配下のファイルと照らし合わせ、新ルールと矛盾や競合がないか自律的に分析してください。
   - **ステップB（ユーザーへの提示）:** 私（ユーザー）に以下のフォーマットで提示し、**必ず私の返答を待ってください。**
     🎯 **新しいルール候補** (対象: [対象スコープ])
     > [ルールの内容]
     
     🔍 **分析結果:** [競合がない旨、または既存ルールとの矛盾点とあなたの提案]
     
     このルールを追加しますか？ `(Y: 追加 / N: スキップ / その他: 修正内容を指示)`
   - **ステップC（マージ実行）:** 私が「Y」または肯定した場合は、`.claude/rules/` 内の適切なMarkdownファイルと見出しを特定し、自然な箇条書きとして追記（`edit_file`）してください。私が文面の修正を指示した場合は、その通りに直して追記してください。
3. **クリーンアップ:** 処理した候補（スキップしたものも含む）を `.claude/tmp/cri-candidates.json` から削除し、完了を報告してください。

```
