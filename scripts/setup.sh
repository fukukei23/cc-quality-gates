#!/bin/bash
# setup.sh — 読者の環境でゲートを有効化する
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 非対話モード: GATE_NONINTERACTIVE=1 で環境変数値を使用（CI・自動テスト向け）
#   GATE_GITLEAKS / GATE_BLOCK_LOG / GATE_WARN_LOG / GATE_WARN_PATTERNS
if [ -n "${GATE_NONINTERACTIVE:-}" ]; then
    GL=${GATE_GITLEAKS:-$HOME/bin/gitleaks}
    LOG=${GATE_BLOCK_LOG:-$HOME/.claude/state/cc-gate-block.log}
    WLOG=${GATE_WARN_LOG:-$HOME/.claude/state/cc-gate-warn.log}
    WPF=${GATE_WARN_PATTERNS:-$HOME/.claude/state/cc-gate-warn-patterns}
else
    read -rp "gitleaks のパス [$HOME/bin/gitleaks]: " GL; GL=${GL:-$HOME/bin/gitleaks}
if [ ! -x "$GL" ]; then
    echo "警告: $GL が実行可能ではありません。gitleaks を導入してください（https://github.com/gitleaks/gitleaks）"
    echo "  例: curl -sSL https://github.com/gitleaks/gitleaks/releases/download/v8.24.3/gitleaks_8.24.3_linux_x64.tar.gz | tar xz -C ~/bin gitleaks"
fi
read -rp "blockログの保存先 [$HOME/.claude/state/cc-gate-block.log]: " LOG
LOG=${LOG:-$HOME/.claude/state/cc-gate-block.log}
read -rp "warnログの保存先 [$HOME/.claude/state/cc-gate-warn.log]: " WLOG
WLOG=${WLOG:-$HOME/.claude/state/cc-gate-warn.log}
read -rp "warnパターン設定ファイル [$HOME/.claude/state/cc-gate-warn-patterns]: " WPF
WPF=${WPF:-$HOME/.claude/state/cc-gate-warn-patterns}
fi

if [ ! -f "$WPF" ]; then
    mkdir -p "$(dirname "$WPF")"
    cat > "$WPF" <<'COMMENT'
# warn層パターン（1行1パターン・完全一致の部分文字列として検査・#始まりはコメント）
# push差分に含まれていたら困る自分固有の語を列挙する（例: 自分のユーザー名・プライベートリポ名）
# 該当しても block はせず warn ログに件数だけ記録する
COMMENT
    echo "warnパターン設定ファイルを作成しました: $WPF（自分固有の語を追記してください）"
fi

REPO=$(git rev-parse --show-toplevel)
mkdir -p "$REPO/.githooks"
sed -e "s|__GITLEAKS_PATH__|$GL|" \
    -e "s|__BLOCK_LOG__|$LOG|" \
    -e "s|__WARN_LOG__|$WLOG|" \
    -e "s|__WARN_PATTERNS_FILE__|$WPF|" \
    "$KIT_ROOT/hooks/pre-push.template" > "$REPO/.githooks/pre-push"
chmod +x "$REPO/.githooks/pre-push"
git -C "$REPO" config core.hooksPath .githooks
echo "setup完了: pre-pushゲートを有効化しました（無効化: git config --unset core.hooksPath）"
echo "次に bash scripts/selftest.sh で導入を確認してください"
