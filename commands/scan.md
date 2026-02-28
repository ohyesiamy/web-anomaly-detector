---
name: scan
description: "プロジェクト全体をスキャンし、3カテゴリ×9レイヤーの違和感レポートを生成する"
---

# /web-anomaly-detector:scan

プロジェクト全体を 3カテゴリ × 9レイヤーでスキャンし、QAP スコア付きレポートを出力する。

## Usage

```bash
/web-anomaly-detector:scan [scope]
```

### Arguments

- `scope` (optional): `full` (default) / `diff` (git diff のみ) / `path:src/api` (特定ディレクトリ)

## Execution Flow

### 1. SCOPE — プロジェクト偵察 (並列)

以下を並列で実行し、プロジェクトのスタックを自動検出:

```
Glob "package.json"       → Node/TS/JS (pnpm/npm/yarn/bun)
Glob "Cargo.toml"         → Rust
Glob "go.mod"             → Go
Glob "requirements.txt"   → Python
Glob "nuxt.config.*"      → Nuxt
Glob "next.config.*"      → Next.js
Glob "tsconfig.json"      → TypeScript
```

スコープに応じた対象ファイルリストを作成:
- `full`: ソースディレクトリ全体
- `diff`: `git diff --name-only HEAD` の出力
- `path:X`: 指定ディレクトリ配下

### 2. MEASURE + SCAN — 3 Explore エージェント並列

Agent ツールで 3つの Explore エージェントを **並列** 起動:

```
Agent A (Ghost — L1-L4):
  - references/detection-patterns.md の L1-L4 パターンで grep/glob
  - CFR, EHD, ESR, HLR, RRR を計測
  - 出力: SEVERITY|LAYER|FILE:LINE|SYMPTOM|ROOT_CAUSE

Agent B (Fragile — L5-L8):
  - references/detection-patterns.md L5-L6 + security-patterns.md L7 + reliability-patterns.md L8
  - NCI, CSS, TCR, AGC, SEC, RPC, MLS, GSS を計測
  - 出力: 同上フォーマット

Agent C (Blind Spot — L9):
  - references/implicit-knowledge.md の 32 パターンで grep
  - TSI, ITCR, BVG, DFS を計測
  - 出力: 同上フォーマット
```

各エージェントのプロンプトに含めるコンテキスト:
- 対象ファイルリスト (Step 1 で取得)
- 該当 references/ ファイルのパス
- QAP 計測方法 (quantitative-parameters.md の該当セクション)

### 3. TRIAGE — 集約・分類

3 エージェントの結果を集約し、以下のルールで分類:

```
CRITICAL: QAP < 0.50 / データ消失・セキュリティ・完全非動作
WARNING:  QAP 0.50-0.80 / 部分的非動作・一貫性欠如
INFO:     QAP >= 0.80 だが改善余地あり
```

### 4. REPORT — レポート出力

以下のフォーマットで直接出力 (ファイル保存はしない):

```markdown
## 違和感レポート: [プロジェクト名]

### Scores
| Category | Score | Status |
|----------|-------|--------|
| Ghost | 0.XX | STATUS |
| Fragile | 0.XX | STATUS |
| Blind Spot | 0.XX | STATUS |
| **Overall** | **0.XX** | **STATUS** |

### CRITICAL (N件)
| # | Cat | Layer | QAP | Location | Symptom | Root Cause |
|---|-----|-------|-----|----------|---------|------------|

### WARNING (N件)
| # | Cat | Layer | QAP | Location | Symptom | Root Cause |
|---|-----|-------|-----|----------|---------|------------|

### INFO (N件)
| # | Cat | Layer | QAP | Location | Symptom | Root Cause |
|---|-----|-------|-----|----------|---------|------------|
```

## Tool Coordination

| Tool | 用途 |
|------|------|
| **Glob** | プロジェクト偵察・ファイル検索 |
| **Grep** | パターン検出・QAP 計測 |
| **Read** | references/ ファイルロード |
| **Agent (Explore)** | 3カテゴリ並列スキャン |
| **Bash** | `git diff` (差分スコープ時) |

## Boundaries

**Will:**
- 3カテゴリ × 9レイヤーの全パターンスキャン
- 17 QAP パラメーターの計測
- Composite Score の算出
- 重要度別レポート出力

**Will Not:**
- コードの修正 (修正は `/web-aufheben` エージェントの責務)
- テスト実行
- ファイル書き出し (レポートは画面出力のみ)
