#!/bin/bash
# selftest.sh — 導入成功/失敗を即時確認
# 検証項目: ①gitleaks実行可 ②hook設置+実行ビット ③モック鍵での実発火 ④CI側ゲート存在
# 注意: ③はテスト用コミットを1件作って戻す（このリポではなく導入先リポで実行すること）
set -uo pipefail
PASS=0; FAIL=0
chk() { if [ $? -eq 0 ]; then echo "PASS: $1"; PASS=$((PASS+1)); else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi; }

HOOK="$(git rev-parse --show-toplevel)/.githooks/pre-push"
# hookからsetup.shが埋め込んだ設定値を抽出（前後の引用符を除去）
strip_q() { sed -e 's/^"//' -e 's/"$//'; }
GL="$(grep -m1 '^GITLEAKS=' "$HOOK" 2>/dev/null | cut -d= -f2- | strip_q || true)"
GL=${GL:-$HOME/bin/gitleaks}
BLOCK_LOG="$(grep -m1 '^BLOCK_LOG=' "$HOOK" 2>/dev/null | cut -d= -f2- | strip_q || true)"
BLOCK_LOG=${BLOCK_LOG:-$HOME/.claude/state/cc-gate-block.log}

# 1) gitleaks実行可能判定
"$GL" version >/dev/null 2>&1; chk "gitleaks実行可能 ($GL)"

# 2) hook設置+実行ビット
[ -x "$HOOK" ]; chk "pre-push設置+実行ビット"

# 3) 実発火テスト（モック鍵を一時commit→hookを直接発火→リセット）
DUMMY="gate-selftest-dummy.txt"
echo "fake_token = \"MOCK-$(openssl rand -hex 12)\"" > "$DUMMY"
git add "$DUMMY" && git commit -qm "selftest: mock" 2>/dev/null
BEFORE=$(wc -l < "$BLOCK_LOG" 2>/dev/null || echo 0)
bash "$HOOK" <<< "refs/heads/selftest $(git rev-parse HEAD) refs/heads/selftest 0000000000000000000000000000000000000000" >/dev/null 2>&1
AFTER=$(wc -l < "$BLOCK_LOG" 2>/dev/null || echo 0)
[ "$AFTER" -gt "$BEFORE" ]; chk "hook実発火（blockログ増加: $BEFORE→$AFTER）"
git reset -q --hard HEAD~1; rm -f "$DUMMY"

# 4) 検出バイパス確認（CI側ゲートの存在=hook迂回pushの最終防衛）
grep -q "gitleaks" "$(git rev-parse --show-toplevel)/.github/workflows/leaks.yml" 2>/dev/null; chk "CI側ゲート存在（hook迂回の最終防衛）"

# 5) 設定ファイルバイパス耐性（.gitleaks.tomlでgitleaks層を全allowlist化しても層2パターンが止める）
# 既知限界: 接尾語付き変数名（token2 等）は層2の正規表現を素通りする（文脈判定は§4.3で意図的にscope外）
DUMMY2="gate-selftest-bypass.txt"
echo "selftest_token = \"MOCK-$(openssl rand -hex 12)\"" > "$DUMMY2"
printf '[extend]\nuseDefault = true\n[allowlist]\npaths = ["(.*)"]\ndescription = "selftest permissive"\n' > .gitleaks.toml
git add "$DUMMY2" .gitleaks.toml && git commit -qm "selftest: bypass" 2>/dev/null
B2=$(wc -l < "$BLOCK_LOG" 2>/dev/null || echo 0)
bash "$HOOK" <<< "refs/heads/selftest-bypass $(git rev-parse HEAD) refs/heads/selftest-bypass 0000000000000000000000000000000000000000" >/dev/null 2>&1
A2=$(wc -l < "$BLOCK_LOG" 2>/dev/null || echo 0)
[ "$A2" -gt "$B2" ]; chk "設定バイパス耐性（gitleaks層無効化でもblock: $B2→$A2）"
git reset -q --hard HEAD~1; rm -f "$DUMMY2" .gitleaks.toml

echo "result: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
