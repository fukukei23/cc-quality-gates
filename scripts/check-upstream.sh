#!/bin/bash
# check-upstream.sh — 本家（private）の更新を確認する手動ツール（自動同期ではない）
# 実行トリガー: 本家の更新を確認したい時（README記載・月1目安）
UPSTREAM="https://github.com/fukukei23/claude-config"
echo "本家の hooks ディレクトリ一覧（参照のみ・cloneせずAPIで確認）:"
gh api "repos/$UPSTREAM/contents/.githooks" -q '.[].name' 2>/dev/null \
    || echo "（要認証・privateリポのため gh auth login 済みの環境で実行）"
echo ""
echo "自リポとの差分は手動で:"
echo "  diff <(curl -sH \"Authorization: token \$(gh auth token)\" $UPSTREAM/raw/main/.githooks/pre-push) hooks/pre-push.template"
