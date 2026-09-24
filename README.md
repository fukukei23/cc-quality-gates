# cc-quality-gates

Claude Code CLI環境で実運用している品質ゲート（gitleaks+pre-push+CI）を
読者向けに書き直したキットです。本家（private）で守っているゲートの
切出し時点スナップショットをコピーし独立管理しています。
動作環境: Linux/macOS（WindowsはWSL/Git Bash）・gitleaks 8.24.3

## 導入

```bash
git clone https://github.com/fukukei23/cc-quality-gates.git
cd cc-quality-gates
bash scripts/setup.sh   # gitleaksパス等を対話的に設定し pre-push を有効化
bash scripts/selftest.sh # 導入成功/失敗を即時確認（PASS=5期待）
```

無効化: `git config --unset core.hooksPath`

## 構成

| パス | 役割 |
|---|---|
| `hooks/pre-push.template` | pre-pushゲートのテンプレート（環境依存値はプレースホルダ） |
| `scripts/setup.sh` | 対話セットアップ（core.hooksPath 有効化込み） |
| `scripts/selftest.sh` | 導入検証（gitleaks実行可/hook設置/実発火/CI存在の4項目） |
| `scripts/check-upstream.sh` | 本家（private）との差分確認の手動ツール |
| `.github/workflows/leaks.yml` | キット自身へ自己適用するCI（hook迂回の最終防衛） |
| `docs/f0-summary.json` | ベースライン確定（F0）の機械可読サマリ |
| `docs/port-diff-pre-push.txt` | 本家→キットの切出しdiff（ロジック無変更の証跡） |
| `evidence/` | F1/F3の検証証跡 |

## 仕組み（3層）

1. **pre-push hook（層1）**: push直前に gitleaks+keyword代入形パターンで差分走査・検知時はblockしてログ記録
2. **CI（層2）**: hook迂回push（`--no-verify`等）でも全push+週次full history走査で検知
3. **selftest（導入検証）**: 導入が正しく効いているかをモック鍵で実発火テスト

## 本家との差分ポリシー

- 本家（private: claude-config）のゲートは運用で進化します。キットはスナップショット独立管理
- `scripts/check-upstream.sh` で本家との差分を手動確認できます（自動同期はしません）
