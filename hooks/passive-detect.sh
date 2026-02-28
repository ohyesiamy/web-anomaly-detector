#!/bin/bash
# PostToolUse:Edit — パッシブ違和感検出フック
#
# ファイル編集後に軽量チェックを実行し、明らかな違和感を即時通知する。
# 全レイヤースキャンではなく、高速で検出可能な L2 (サイレント失敗) と
# L7 (セキュリティ) の2レイヤーに限定。
#
# 環境変数:
#   CLAUDE_TOOL_USE_FILE_PATH — 編集されたファイルのパス
#   CLAUDE_TOOL_USE_OLD_STRING — 置換前の文字列
#   CLAUDE_TOOL_USE_NEW_STRING — 置換後の文字列

FILE_PATH="${CLAUDE_TOOL_USE_FILE_PATH:-}"
NEW_STRING="${CLAUDE_TOOL_USE_NEW_STRING:-}"

# ファイルパスが空なら終了
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 対象拡張子のフィルタ (.ts, .js, .vue, .tsx, .jsx, .py, .go, .rs)
EXT="${FILE_PATH##*.}"
case "$EXT" in
  ts|js|vue|tsx|jsx|py|go|rs) ;;
  *) exit 0 ;;
esac

WARNINGS=""

# --- L2: サイレント失敗チェック ---

# 空 catch ブロック検出 (新規追加されたコード内)
if echo "$NEW_STRING" | grep -qE 'catch\s*\(\s*\w*\s*\)\s*\{\s*\}'; then
  WARNINGS="${WARNINGS}[L2] Empty catch block detected — errors will be silently swallowed\n"
fi

if echo "$NEW_STRING" | grep -qE 'catch\s*\(\s*\)\s*\{?\s*\}?'; then
  WARNINGS="${WARNINGS}[L2] Empty catch block detected — errors will be silently swallowed\n"
fi

# .catch(() => {}) パターン
if echo "$NEW_STRING" | grep -qE '\.catch\(\s*\(\s*\)\s*=>\s*\{\s*\}\s*\)'; then
  WARNINGS="${WARNINGS}[L2] Silent .catch() — promise errors will be lost\n"
fi

# except: pass (Python)
if echo "$NEW_STRING" | grep -qE 'except.*:\s*pass\s*$'; then
  WARNINGS="${WARNINGS}[L2] except: pass — Python errors silently ignored\n"
fi

# --- L7: セキュリティチェック ---

# ハードコードされた秘密鍵/トークン
if echo "$NEW_STRING" | grep -qEi '(api[_-]?key|secret|password|token|credential)\s*[:=]\s*["\x27][A-Za-z0-9+/=_-]{8,}'; then
  WARNINGS="${WARNINGS}[L7] Possible hardcoded secret detected — use environment variables\n"
fi

# eval() 使用
if echo "$NEW_STRING" | grep -qE '\beval\s*\('; then
  WARNINGS="${WARNINGS}[L7] eval() usage detected — potential code injection risk\n"
fi

# innerHTML 直接代入
if echo "$NEW_STRING" | grep -qE '\.innerHTML\s*='; then
  WARNINGS="${WARNINGS}[L7] innerHTML assignment — potential XSS vulnerability\n"
fi

# SQL 文字列結合
if echo "$NEW_STRING" | grep -qEi "(SELECT|INSERT|UPDATE|DELETE).*\+.*(\"|'|`)" 2>/dev/null; then
  WARNINGS="${WARNINGS}[L7] SQL string concatenation — use parameterized queries\n"
fi

# --- 結果出力 ---

if [ -n "$WARNINGS" ]; then
  echo "⚠ web-anomaly-detector passive check:"
  echo -e "$WARNINGS"
  # 非ブロッキング — exit 0 で編集を止めない
fi

exit 0
