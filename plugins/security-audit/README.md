# security-audit

リポジトリのセキュリティ監査を自動実行するプラグイン。言語/フレームワークを自動検出し、OWASP Top 10 コード分析・CVE 調査・外部セキュリティツール実行を並列で行い、統一フォーマットのレポートを出力する。

## インストール

```shell
/plugin install security-audit@kawamoto-claude-plugins
```

## スキル

### security-audit

以下のいずれかで起動:

- `/security-audit` を実行
- 「セキュリティ監査して」「セキュリティチェックして」と依頼
- 「脆弱性がないか確認して」「CVEチェックして」「OWASPチェックして」と依頼
- 「シークレットが漏れていないか確認して」「checkov を実行して」と依頼

#### スコープ指定

- 引数なし: リポジトリ全体
- ディレクトリパス指定: 指定ディレクトリ
- `--changed`: `git diff` の変更ファイルのみ

#### 実行フロー

1. 対象スコープの確認
2. 無視リスト（`.claude/memory/security-audit-ignore.md`）の読み込み
3. 3つのエージェントを **並列実行**:
   - **security-audit-scanner** — 言語検出 + 外部ツール実行
   - **security-audit-owasp-analyzer** — OWASP Top 10 コード分析
   - **security-audit-cve-checker** — 依存関係 CVE チェック
4. **security-audit-reporter** でレポート統合
5. レポート表示 + 無視リスト更新の確認

#### レポート形式

- 深刻度別サマリー（CRITICAL / HIGH / MEDIUM / LOW / INFO）
- 指摘一覧（Finding ID 付き）
- 無視された指摘の一覧
- 各指摘に推奨対応と参考 URL を付記

## エージェント構成

| エージェント | モデル | 役割 |
|---|---|---|
| security-audit-scanner | sonnet | 言語/フレームワーク検出、checkov/trivy/gitleaks 実行 |
| security-audit-owasp-analyzer | sonnet | OWASP Top 10 (2025) コード分析 |
| security-audit-cve-checker | sonnet | 依存関係の CVE 検索（NVD, GitHub Advisory） |
| security-audit-reporter | sonnet | 3エージェントの結果統合、深刻度分類、レポート生成 |

## 対応言語/フレームワーク

Python, Go, TypeScript, JavaScript, Java, Ruby, Rust, Terraform, Docker, Kubernetes (YAML)

## 外部ツール連携

以下のツールがインストール済みであれば自動実行（未インストール時はスキップ）:

- [checkov](https://www.checkov.io/) — IaC セキュリティスキャン
- [trivy](https://trivy.dev/) — 脆弱性・設定ミス・シークレット検出
- [gitleaks](https://gitleaks.io/) — シークレット漏洩検出

## 制約事項

- コードの自動修正は行わない（レポートのみ）
- CVE の WebSearch は上限 20 パッケージ
- 無視リストはプロジェクトスコープ（`.claude/memory/`）に保存

## バージョン

1.0.0
