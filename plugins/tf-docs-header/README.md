# tf-docs-header

`environments/<env>/main.tf` および `modules/<module>/main.tf` に [terraform-docs](https://terraform-docs.io/) 用のヘッダコメントを自動付与・更新するプラグイン。

## Overview

Terraform ファイルを編集した後、`main.tf` の先頭にある `/** ... */` ヘッダを自動で生成・最新化する。`variables.tf` や `outputs.tf` の内容を解析して、変数・リソース・モジュール情報をコードと同期する。

変更が不要な場合（ヘッダがすでに最新の場合）は書き込みを行わない。

## Installation

```shell
/plugin install tf-docs-header@kawamoto-claude-plugins
```

マーケットプレイスの追加方法はリポジトリの [README](../../README.md) を参照。

## Skills

### `tf-docs-header`

**トリガー条件:**

- `.tf` ファイルを編集した直後
- 「tf-docs ヘッダを付与して」「ヘッダを更新して」「ドキュメントヘッダを追加して」と依頼されたとき
- 「terraform-docs を実行する前に」と言われたとき

**動作フロー:**

1. `git diff` / `git status` で変更された `.tf` ファイルを特定する
2. `environments/<env>/` または `modules/<module>/` に絞り込む
3. 各ディレクトリの `main.tf` 先頭を確認してモードを決定する

   | 状態 | モード |
   |------|--------|
   | `/**` で始まらない | **add** — ヘッダを新規作成して挿入 |
   | `/**` で始まる | **update** — 差分のみ反映して置換 |

4. `variables.tf`・`outputs.tf`・`main.tf` を読み込んでヘッダを生成する
5. 変更が必要な場合のみファイルを編集する

**生成されるヘッダ（`modules/` の場合）:**

```
/**
 * ## <モジュール名>
 * <モジュールの一文説明>
 *
 * ### Features
 * - <機能>: <説明>
 *
 * ### Usage
 * ```
 * module "<name>" {
 *   source = "../../modules/<name>"
 *
 *   <必須変数> = "<例>"
 * }
 * ```
 */
```

**生成されるヘッダ（`environments/` の場合）:**

```
/**
 * ## <env名> 環境
 * <環境の用途・概要>
 *
 * ### 使用モジュール
 * - <モジュール名>: <用途>
 */
```

**ルール:**

- `### Features` はリソースから判断できる機能のみ列挙（なければセクション省略）
- `### Usage` は `default` なし（必須）の変数のみ記載（なければセクション省略）
- `### 使用モジュール` は `module "..."` ブロックをすべて列挙
- ヘッダ部分のみを編集し、それ以外のコードには触れない
- 推測や将来の機能を書かない（コードに存在するものだけを反映する）

## Technical Details

### エージェント構成

```
tf-docs-orchestrator (haiku)
├── tf-docs-analyze (sonnet)  — 分析・変更要否判断・ヘッダ文字列生成
└── tf-docs-apply   (haiku)   — main.tf へのヘッダ書き込み（変更ありの場合のみ）
```

| Agent | モデル | 役割 |
|-------|--------|------|
| tf-docs-orchestrator | haiku | 対象ディレクトリの特定・エージェント呼び出し・結果集約 |
| tf-docs-analyze | sonnet | ファイル分析・ヘッダ生成・変更要否の判断 |
| tf-docs-apply | haiku | `Edit` ツールによるファイル編集 |

`tf-docs-apply` は `tf-docs-analyze` が `needs_change: true` を返した場合のみ呼び出される。

## Requirements

- Terraform プロジェクトが `environments/<env>/` または `modules/<module>/` 構成を使っていること
- `main.tf` が対象ディレクトリに存在すること

## Version

1.0.0