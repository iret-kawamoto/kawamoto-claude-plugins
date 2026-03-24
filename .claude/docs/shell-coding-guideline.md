# シェルスクリプト コーディングガイドライン

> Google Shell Style Guide に基づく。本ドキュメントはプロジェクト内のすべての `*.sh` ファイルに適用される。

---

## 1. 適用範囲

### 背景

シェルスクリプトは小規模なユーティリティやラッパースクリプトに適している。
汎用的なプログラミング言語としては不向きであり、複雑なロジックやデータ操作には Python 等を使用すべきである。

### ルール

- シェルスクリプトは **100行以下** の小規模ツールに限定する
- 主に他のコマンドを呼び出し、データ操作が最小限の場合に使用する
- 100行を超える場合、または複雑な制御フローが必要な場合は即座に別言語へ移行する
- パフォーマンスが重要な処理にはシェルスクリプトを使用しない

---

## 2. ファイルヘッダ・インタープリタ

### 背景

一貫したシバン行と安全なシェルオプションにより、スクリプトの移植性と堅牢性が向上する。

### ルール

- シバンは `#!/usr/bin/env bash` を使用する
- ファイル先頭で `set -euo pipefail` を設定する
- 実行可能スクリプトの拡張子は `.sh`
- ライブラリファイルも `.sh` 拡張子とし、実行権限は付与しない
- SUID/SGID は禁止（`sudo` を使用する）

### 良い例

```bash
#!/usr/bin/env bash
set -euo pipefail

# バックアップを実行するスクリプト
```

### 悪い例

```bash
#!/bin/sh
# POSIX sh では bash 固有機能が使えずエラーになる

#!/usr/bin/env bash
# set -euo pipefail が未設定 — エラーが無視される
```

---

## 3. 出力

### 背景

正常出力とエラー出力を分離することで、パイプライン処理やログ管理が容易になる。

### ルール

- 正常な出力は STDOUT に送る
- エラーメッセージ・診断情報はすべて STDERR に送る
- エラー出力用の共通関数を定義することを推奨する

### 良い例

```bash
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

if ! do_something; then
  err "do_something に失敗しました"
  exit 1
fi
```

### 悪い例

```bash
# エラーも STDOUT に出力 — パイプで正常出力と混在する
if ! do_something; then
  echo "エラーが発生しました"
  exit 1
fi
```

---

## 4. コメント

### 背景

適切なコメントにより、スクリプトの保守性と可読性が大幅に向上する。

### 4.1 ファイルヘッダコメント

各ファイルの先頭に、そのスクリプトの目的を記述する。

```bash
#!/usr/bin/env bash
set -euo pipefail
#
# データベースのホットバックアップを実行する。
# 使用法: backup.sh [--full|--incremental]
```

### 4.2 関数コメント

自明でない関数、およびすべてのライブラリ関数にはヘッダコメントを付ける。

必須項目:
- 関数の説明
- `Globals:` 使用・変更するグローバル変数
- `Arguments:` 引数の説明
- `Outputs:` STDOUT/STDERR への出力
- `Returns:` デフォルト以外の終了ステータス

```bash
#######################################
# バックアップディレクトリをクリーンアップする。
# Globals:
#   BACKUP_DIR
#   ORACLE_SID
# Arguments:
#   None
#######################################
cleanup() {
  …
}

#######################################
# 設定ディレクトリのパスを取得する。
# Globals:
#   SOMEDIR
# Arguments:
#   None
# Outputs:
#   パスを STDOUT に出力
#######################################
get_dir() {
  echo "${SOMEDIR}"
}

#######################################
# ファイルを削除する。
# Arguments:
#   $1 - 削除対象のファイルパス
# Returns:
#   0: 成功、非0: エラー
#######################################
del_thing() {
  rm "$1"
}
```

### 4.3 実装コメント

トリッキーな処理、非自明なロジック、重要なコード部分にコメントを付ける。
すべての行にコメントする必要はない。

### 4.4 TODO コメント

未解決の課題には TODO コメントを使用する。
`TODO` は大文字で記述し、担当者の名前またはIDを括弧内に記載する。

```bash
# TODO(kawamoto): エッジケースの処理を追加する (bug #1234)
```

---

## 5. フォーマット

### 5.1 インデント

- **スペース2つ** でインデントする
- **タブは禁止**（`<<-` ヒアドキュメント内のみ例外）
- コードブロック間に空行を入れて可読性を高める

### 5.2 行長

- 最大 **80文字**
- 長い文字列にはヒアドキュメントまたは埋め込み改行を使用する
- ファイルパスや URL など分割不可能な文字列は例外

```bash
# ヒアドキュメント
cat <<END
非常に長い
文字列をここに記述する。
END

# 埋め込み改行
long_string="これは非常に長い
文字列です。"
```

### 5.3 パイプライン

1行に収まらない場合、1コマンドずつ改行する。パイプ `|` は行頭に置き、2スペースインデントする。

```bash
# 1行に収まる場合
command1 | command2

# 複数行の場合
command1 \
  | command2 \
  | command3 \
  | command4
```

### 5.4 制御構文

`; then` と `; do` は `if`/`for`/`while` と同じ行に記述する。
閉じ文（`fi`, `done`）は開始文と同じインデントで独立した行に記述する。

```bash
# 良い例
for dir in "${dirs_to_cleanup[@]}"; do
  if [[ -d "${dir}/${SESSION_ID}" ]]; then
    log_date "Cleaning up old files in ${dir}/${SESSION_ID}"
    rm "${dir}/${SESSION_ID}/"* || error_message
  else
    mkdir -p "${dir}/${SESSION_ID}" || error_message
  fi
done
```

`for` ループでは明示的に `in "$@"` を記述する:

```bash
for arg in "$@"; do
  echo "argument: ${arg}"
done
```

### 5.5 case 文

- パターンは2スペースインデント
- 1行の場合: 閉じ括弧の後にスペース、`;;` の前にもスペース
- 複数行の場合: パターン、アクション、`;;` をそれぞれ別行に記述
- `;&` と `;;&` は使用禁止

```bash
# 複数行
case "${expression}" in
  a)
    variable="…"
    some_command "${variable}" "${other_expr}"
    ;;
  absolute)
    actions="relative"
    another_command "${actions}" "${other_expr}"
    ;;
  *)
    error "Unexpected expression '${expression}'"
    ;;
esac

# 1行
while getopts 'abf:v' flag; do
  case "${flag}" in
    a) aflag='true' ;;
    b) bflag='true' ;;
    f) files="${OPTARG}" ;;
    v) verbose='true' ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done
```

---

## 6. 変数・クォート

### 背景

クォートなしの変数展開はワード分割とグロブ展開の対象となり、
予期しない動作やセキュリティ上のリスクを引き起こす。

### 6.1 変数展開

- 変数は常に `"${var}"` 形式でクォートする
- 単一文字のシェル特殊変数（`$?`, `$#`, `$$`, `$!`）はブレース不要
- 位置パラメータは `$1` ～ `$9` はブレース不要、`${10}` 以上はブレース必須

```bash
# 良い例
echo "PATH=${PATH}, PWD=${PWD}, mine=${some_var}"
echo "Positional: $1 $5 $3"
echo "Many: ${10}"

# 悪い例
echo a=$avar "b=$bvar"   # ブレースなし — 意図しない展開の可能性
echo "$10$20$30"          # ${1}0${2}0${3}0 と解釈される
```

### 6.2 クォートルール

- 変数、コマンド置換、スペース、メタ文字を含む文字列は常にダブルクォートする
- リスト要素には配列を使用し、安全にクォートする
- `"$@"` を使用する（`$*` は原則使用しない）
- リテラル文字列にはシングルクォートを使用する（展開不要時）
- リテラル整数はクォート不要: `value=32`

```bash
# 良い例
flag="$(some_command and its args "$@" 'quoted separately')"
echo "${flag}"

declare -a FLAGS
FLAGS=(--foo --bar='baz')
readonly FLAGS
mybinary "${FLAGS[@]}"

echo 'Hello stranger, and well met. Earn lots of $$$'
echo "Process $$: Done making \$\$\$."

# 悪い例
flag=$(some_command)        # クォートなし
mybinary ${FLAGS}           # 配列の誤った展開
```

### 例外

- `(( ))` 内の算術式ではクォート不要: `(( i = count + 1 ))`
- `[[ ]]` 内の右辺パターン/正規表現はクォートの有無で動作が変わる:
  - `[[ "${val}" == "literal" ]]` — リテラル比較（クォートあり）
  - `[[ "${val}" =~ ^[0-9]+$ ]]` — 正規表現（クォートなし）

### 関連 ShellCheck ルール

- SC2086: Double quote to prevent globbing and word splitting
- SC2248: Prefer double-quoting even when variables won't word-split

---

## 7. 機能・構文

### 7.1 ShellCheck

- すべてのスクリプトに対して **ShellCheck による静的解析を必須** とする
- ShellCheck の警告は原則としてすべて解消する

### 7.2 コマンド置換

`$(command)` を使用する。バッククォート `` ` `` は禁止。

```bash
# 良い例
var="$(command "$(command1)")"

# 悪い例
var="`command \`command1\``"
```

### 7.3 テスト構文

`[[ … ]]` を使用する。`[ … ]`、`test`、`/usr/bin/[` は禁止。

`[[ ]]` はパス名展開やワード分割を防ぎ、パターンマッチングと正規表現を使用できる。

```bash
# 良い例
if [[ "filename" =~ ^[[:alnum:]]+name ]]; then
  echo "Match"
fi

if [[ "filename" == "f*" ]]; then
  echo "Match"
fi

# 悪い例 — f* がディレクトリ内容に展開される
if [ "filename" == f* ]; then
  echo "Match"
fi
```

### 7.4 文字列テスト

空文字列チェックには `-z` と `-n` を明示的に使用する。

```bash
# 良い例
if [[ -z "${my_var}" ]]; then
  do_something
fi

if [[ -n "${my_var}" ]]; then
  do_something
fi

# 悪い例 — フィラー文字を使用
if [[ "${my_var}X" == "some_stringX" ]]; then
  do_something
fi

# 悪い例 — 暗黙の真偽判定
if [[ "${my_var}" ]]; then
  do_something
fi
```

### 7.5 数値比較

数値比較には `(( ))` を使用する。`[[ ]]` 内での `>` / `<` は辞書順比較になるため禁止。

```bash
# 良い例
if (( my_var > 3 )); then
  do_something
fi

# 許容（明示的なオプション使用時）
if [[ "${my_var}" -gt 3 ]]; then
  do_something
fi

# 悪い例 — 辞書順比較（22 < 3 と評価される）
if [[ "${my_var}" > 3 ]]; then
  do_something
fi
```

### 7.6 ワイルドカード展開

ワイルドカード展開時は明示的にパスを指定する。`-` で始まるファイル名がオプションとして解釈されるのを防ぐ。

```bash
# 良い例
rm -v ./*

# 悪い例 — -f や -r というファイルがオプションとして解釈される
rm -v *
```

### 7.7 eval

**`eval` は使用禁止。** 入力を改変し、設定された変数の検証が不可能になる。

### 7.8 配列

リスト要素には配列を使用する。文字列でリストを管理しない。

```bash
# 良い例
declare -a flags
flags=(--foo --bar='baz')
flags+=(--greeting="Hello ${name}")
mybinary "${flags[@]}"

# 悪い例 — スペースを含む値が壊れる
flags='--foo --bar=baz'
flags+=' --greeting="Hello world"'
mybinary ${flags}
```

### 7.9 パイプと while

パイプから `while` への接続ではサブシェルが生成され、変数変更が親シェルに反映されない。
プロセス置換または `readarray` を使用する。

```bash
# 悪い例 — last_line は常に 'NULL' のまま
last_line='NULL'
your_command | while read -r line; do
  if [[ -n "${line}" ]]; then
    last_line="${line}"
  fi
done
echo "${last_line}"  # 'NULL' が出力される

# 良い例 — プロセス置換
last_line='NULL'
while read -r line; do
  if [[ -n "${line}" ]]; then
    last_line="${line}"
  fi
done < <(your_command)
echo "${last_line}"  # 最後の非空行が出力される

# 良い例 — readarray (bash 4+)
readarray -t lines < <(your_command)
for line in "${lines[@]}"; do
  if [[ -n "${line}" ]]; then
    last_line="${line}"
  fi
done
```

### 7.10 算術演算

`$(( ))` または `(( ))` を使用する。`let`、`$[ ]`、`expr` は禁止。

```bash
# 良い例
echo "$(( 2 + 2 )) is 4"
(( i += 3 ))
local -i hundred="$(( 10 * 10 ))"

# 悪い例
i=$[2 * 10]              # 非推奨構文
let i="2 + 2"            # 非移植的
i=$(expr 4 + 4)          # 外部コマンド — 非効率
```

**注意:** `set -e` 有効時、`(( ))` の結果が0になるとシェルが終了する。
`i=0; (( i++ ))` は `i++` の戻り値が0（インクリメント前の値）のため終了する。

### 7.11 エイリアス

スクリプト内での `alias` は禁止。関数を使用する。

```bash
# 悪い例 — $RANDOM は定義時に1回だけ評価される
alias random_name="echo some_prefix_${RANDOM}"

# 良い例
random_name() {
  echo "some_prefix_${RANDOM}"
}
```

---

## 8. 命名規則

### 8.1 関数名

- `lower_snake_case` を使用する
- パッケージ区切りには `::` を使用可能
- 括弧 `()` は必須、`function` キーワードは省略可能（プロジェクト内で統一する）
- 開きブレースは関数名と同じ行に記述する

```bash
my_func() {
  …
}

mypackage::my_func() {
  …
}
```

### 8.2 変数名

- `lower_snake_case` を使用する
- ループ変数はコレクション名と関連付ける

```bash
for zone in "${zones[@]}"; do
  something_with "${zone}"
done
```

### 8.3 定数・環境変数

- `UPPER_SNAKE_CASE` を使用する
- `readonly` または `declare -r` で宣言する
- ファイル先頭で定義する

```bash
readonly PATH_TO_FILES='/some/path'
declare -xr ORACLE_SID='PROD'
```

実行時に決定される定数は、値の確定後に即座に `readonly` にする:

```bash
ZIP_VERSION="$(dpkg --status zip | sed -n 's/^Version: //p')"
if [[ -z "${ZIP_VERSION}" ]]; then
  handle_error_and_quit
fi
readonly ZIP_VERSION
```

### 8.4 ソースファイル名

- `lowercase` または `lower_snake_case` を使用する
- ハイフンは使用しない: `make_template`（○）、`make-template`（×）

### 8.5 ローカル変数

- 関数内の変数は必ず `local` で宣言する
- **宣言と代入を分離する**（コマンド置換を使用する場合）

```bash
# 良い例 — 宣言と代入を分離
my_func() {
  local name="$1"

  local my_var
  my_var="$(other_func)"
  (( $? == 0 )) || return
}

# 悪い例 — local が終了コードを上書きする
my_func() {
  local my_var="$(other_func)"
  (( $? == 0 )) || return  # $? は local の終了コード
}
```

### 関連 ShellCheck ルール

- SC2155: Declare and assign separately to avoid masking return values

---

## 9. 構造

### 9.1 関数の配置

- すべての関数は定数宣言の直後にまとめて配置する
- 関数の間に実行可能コードを挟まない

### 9.2 main 関数

- 他の関数を含むスクリプトには `main` 関数を必須とする
- `main` はファイル末尾の関数として定義する
- ファイルの最終行で `main "$@"` を呼び出す
- 短い線形スクリプト（関数定義なし）では `main` は不要

```bash
#!/usr/bin/env bash
set -euo pipefail

# 定数
readonly CONFIG_DIR="/etc/myapp"

# 関数定義
setup() {
  …
}

cleanup() {
  …
}

main() {
  setup
  # メイン処理
  cleanup
}

main "$@"
```

---

## 10. コマンド実行

### 10.1 戻り値のチェック

- すべてのコマンドの戻り値を確認する
- パイプラインでは `if` 文で全体の成否を判定するか、`PIPESTATUS` 配列で個別にチェックする
- `set -euo pipefail` 環境下ではパイプライン失敗時に即終了するため、`PIPESTATUS` を使う場合は一時的に `set +e` する必要がある

```bash
# if 文でチェック
if ! mv "${file_list[@]}" "${dest_dir}/"; then
  err "ファイルの移動に失敗: ${file_list[*]} → ${dest_dir}"
  exit 1
fi

# パイプライン全体を if 文でチェック（シンプルな方法）
if ! tar -cf - ./* | ( cd "${dir}" && tar -xf - ); then
  err "tar の作成または展開に失敗"
  exit 1
fi

# パイプラインの各コマンドを個別にチェック（PIPESTATUS 使用時）
# set -euo pipefail 下では失敗時に即終了するため、一時的に無効化する
set +e
tar -cf - ./* | ( cd "${dir}" && tar -xf - )
return_codes=("${PIPESTATUS[@]}")
set -e
if (( return_codes[0] != 0 )); then
  err "tar の作成に失敗"
fi
if (( return_codes[1] != 0 )); then
  err "tar の展開に失敗"
fi
```

### 10.2 ビルトインの優先

シェルビルトインを外部コマンドより優先して使用する。

```bash
# 良い例 — ビルトイン
addition="$(( X + Y ))"
substitution="${string/#foo/bar}"
if [[ "${string}" =~ foo:([0-9]+) ]]; then
  extraction="${BASH_REMATCH[1]}"
fi

# 悪い例 — 外部コマンド
addition="$(expr "${X}" + "${Y}")"
substitution="$(echo "${string}" | sed -e 's/^foo/bar/')"
extraction="$(echo "${string}" | sed -e 's/foo:\([0-9]\)/\1/')"
```

---

## 付録: 一貫性について

判断に迷った場合は、既存コードとの **一貫性** を最優先する。
ただし、一貫性は古い慣習を正当化する根拠にはならない。
新しいスタイルに明確な利点がある場合は、段階的に移行する。
