# Web Anomaly Detector

> Detect code anomalies quantitatively — **Ghost** (broken), **Fragile** (breakable), **Blind Spot** (invisible risks) across 9 layers with 17 measurable parameters.

コードの「違和感」を定量的に検出する Claude Code スキル。
修正提案ではなく **発見・計測・分類** に特化。主観的な「何かおかしい」を数値で立証する。

## Why

静的解析ツールは構文エラーやリンターの違反を見つける。しかし「動くけど壊れやすい」「コード上は正しいが本番で障害を起こす」「開発者の暗黙の仮定に依存している」といった**違和感**は、既存ツールでは検出できない。

Web Anomaly Detector は、この「違和感」を体系的に分類し、grep/glob ベースの計測で数値化する。

### 検出できるもの

- API の型定義と実際のレスポンスが一致しない (Ghost)
- `catch(() => {})` でエラーが握り潰されている (Ghost)
- WebSocket イベントが定義されているが購読されていない (Ghost)
- 外部 API 呼び出しにタイムアウトが設定されていない (Fragile)
- ハードコードされた秘密鍵がソースに埋まっている (Fragile)
- `addEventListener` と `removeEventListener` の数が非対称 (Fragile)
- `0.1 + 0.2` で金額計算している (Blind Spot)
- `new Date()` のタイムゾーンを仮定している (Blind Spot)

### 検出しないもの

- コードスタイルの好み (ESLint の領域)
- テストカバレッジの不足
- ドキュメントの不備

## Installation

```bash
# Clone to your Claude Code skills directory
git clone https://github.com/ohyesiamy/web-anomaly-detector.git ~/.claude/skills/web-anomaly-detector
```

Or manually copy the files into `~/.claude/skills/web-anomaly-detector/`.

> **Note**: `claude install github:...` は将来のマーケットプレイス対応を想定した記述です。現時点では上記の手動インストールを使用してください。

## Quick Start

Claude Code で以下のように話しかける:

```
「このプロジェクトの違和感を探して」
「システム監査して」
「何かおかしいところはないか確認して」
```

スキルが自動ロードされ、3カテゴリ × 9レイヤーのスキャンが実行される。

## Architecture

### 3 Categories × 9 Layers

違和感を3つのカテゴリに分類する。各カテゴリは複数のレイヤーを持つ。

```
Ghost (動かないもの)
├── L1: Contract Mismatch    — 型定義と API の不一致
├── L2: Silent Failure       — エラーが飲み込まれる
├── L3: State Sync Bug       — リアルタイム更新の欠落
└── L4: Dead Feature         — UI に存在するが動かない

Fragile (壊れやすいもの)
├── L5: Structural Contradiction — 命名・設定の矛盾
├── L6: Resource Waste           — N+1, メモリリーク
├── L7: Security Vulnerability   — OWASP Top 10 2025
└── L8: Reliability Risk         — タイムアウト, Circuit Breaker

Blind Spot (見えないリスク)
└── L9: Implicit Knowledge Trap  — 開発者の暗黙の仮定
```

### QAP (Quantitative Anomaly Parameters)

「何かおかしい」を数値化する 17 個のパラメーター。全て grep/glob で計測可能。

| # | Parameter | Type | What it Measures |
|---|-----------|------|------------------|
| G1 | **CFR** (Contract Fulfillment Rate) | Ratio | 型定義と API 実装の一致率 |
| G2 | **EHD** (Error Handling Density) | Ratio | catch 内の適切なエラー処理率 |
| G3 | **ESR** (Event Subscription Ratio) | Ratio | 定義されたイベントの購読率 |
| G4 | **HLR** (Handler Liveness Rate) | Ratio | UI ハンドラの実装率 |
| G5 | **RRR** (Route Reachability Rate) | Ratio | ルートへのリンク存在率 |
| F1 | **NCI** (Naming Consistency Index) | Ratio | 命名規則の一貫性 |
| F2 | **CSS** (Configuration Scatter Score) | Scatter | 設定値の散在度 |
| F3 | **TCR** (Timeout Coverage Rate) | Ratio | 外部呼び出しのタイムアウト設定率 |
| F4 | **AGC** (Auth Guard Coverage) | Ratio | API の認証保護率 |
| F5 | **SEC** (Secret Exposure Count) | Presence | ハードコードされた秘密鍵の数 |
| F6 | **RPC** (Resilience Pair Coverage) | Ratio | リトライ/CB の実装率 |
| F7 | **MLS** (Memory Leak Symmetry) | Symmetry | リソース確保/解放の対称性 |
| F8 | **GSS** (Graceful Shutdown Score) | Presence | シグナルハンドリングの実装 |
| B1 | **TSI** (TODO Staleness Index) | Ratio | 放置された TODO の古さ |
| B2 | **ITCR** (Implicit Type Coercion Risk) | Presence | 暗黙的型変換のリスク数 |
| B3 | **BVG** (Boundary Validation Gap) | Ratio | 入力バリデーションの欠落率 |
| B4 | **DFS** (Dependency Freshness Score) | Ratio | 依存パッケージの管理品質 |

4つの計測タイプ:

| Type | Healthy | Anomalous | Example |
|------|---------|-----------|---------|
| **Ratio** | → 1.0 | → 0.0 | catch の処理率、認証保護率 |
| **Presence** | 0 | > 0 | ハードコードされた秘密鍵の数 |
| **Symmetry** | 0.0 | → 1.0 | addEventListener vs removeEventListener |
| **Scatter** | 1.0 | > 1.5 | 同一設定値の散在箇所数 |

### Composite Scoring

個別パラメーターを重み付けして各カテゴリのスコアを算出し、Overall に統合する。

```
Ghost    = 0.30×CFR + 0.30×EHD + 0.15×ESR + 0.15×HLR + 0.10×RRR
Fragile  = 0.15×NCI + 0.10×CSS' + 0.20×TCR + 0.20×AGC + 0.10×SEC' + 0.10×RPC + 0.10×MLS' + 0.05×GSS
BlindSpot = 0.25×TSI' + 0.20×ITCR' + 0.30×BVG + 0.25×DFS
Overall  = 0.40×Ghost + 0.35×Fragile + 0.25×BlindSpot
```

判定基準:

| Score | Status | Action |
|-------|--------|--------|
| >= 0.80 | Healthy | 軽微な改善のみ |
| 0.50 - 0.80 | Warning | 計画的に対処 |
| < 0.50 | Critical | 即座に対処 |

### Adaptive Thresholds

プロジェクトの文脈に応じて閾値を自動調整する。
CK Metrics の研究知見: 普遍的閾値は存在しない。

| Context | Adjustment |
|---------|-----------|
| Prototype / MVP | WARNING 閾値を 20% 緩和 |
| Production | 標準閾値を使用 |
| Financial / Medical | WARNING 閾値を 15% 厳格化 |
| Monolith | CSS 閾値を緩和 |
| Microservices | TCR/RPC/GSS 閾値を厳格化 |
| Static site / SSG | L3/L8 をスキップ |

## Commands

### `/web-anomaly-detector:scan`

プロジェクト全体を 3カテゴリ × 9レイヤーでスキャンし、QAP スコア付きレポートを出力する。

```bash
/web-anomaly-detector:scan           # 全体スキャン
/web-anomaly-detector:scan diff      # git diff のみ
/web-anomaly-detector:scan path:src/ # 特定ディレクトリ
```

3つの Explore エージェントを並列起動して検出を高速化する。

**出力例:**

```
## 違和感レポート: my-project

### Scores
| Category   | Score | Status  |
|------------|-------|---------|
| Ghost      | 0.72  | WARNING |
| Fragile    | 0.85  | Healthy |
| Blind Spot | 0.45  | CRITICAL|
| **Overall**| **0.68** | **WARNING** |

### CRITICAL (2件)
| # | Cat | Layer | QAP     | Location           | Symptom              | Root Cause            |
|---|-----|-------|---------|--------------------|----------------------|-----------------------|
| 1 | BS  | L9    | BVG=0.4 | server/api/user.ts:17 | 入力バリデーションなし | zod スキーマ未適用     |
| 2 | G   | L2    | EHD=0.3 | lib/api-client.ts:42 | 空 catch ブロック     | エラーがログされない   |

### WARNING (5件) ...
### INFO (3件) ...
```

### `/web-anomaly-detector:score`

QAP 17パラメーターの数値計算のみを実行する軽量版。パターン検出は行わない。

```bash
/web-anomaly-detector:score           # 全体
/web-anomaly-detector:score path:api/ # 特定ディレクトリ
```

**出力例:**

```
## QAP Score: my-project

| Category   | Score | Status  | Key Factors          |
|------------|-------|---------|----------------------|
| Ghost      | 0.82  | Healthy | CFR=0.95, EHD=0.71   |
| Fragile    | 0.65  | WARNING | AGC=0.60, TCR=0.40   |
| Blind Spot | 0.71  | WARNING | BVG=0.55, TSI=0.30   |
| **Overall**| **0.73** | **WARNING** |                 |
```

## Passive Detection Hook

ファイル編集のたびに軽量チェックが自動実行される (`PostToolUse:Edit`)。

検出対象:
- **L2**: 空 catch ブロック、silent `.catch()`、Python の `except: pass`
- **L7**: ハードコード秘密鍵、`eval()` 使用、`innerHTML` 代入、SQL 文字列結合

非ブロッキング — 編集を止めることはない。違和感がある場合のみ警告を表示する。

## Aufheben Agent

検出→分類→**並列修正**→検証を一気通貫で実行するエージェント。

```
「違和感を見つけて修正して」
「アウフヘーベンして」
```

Phase:

```
0. RECON   — プロジェクトスタックを自動検出
1. DETECT  — Explore エージェント×3 で並列検出
2. TRIAGE  — AUTO-FIX / MANUAL-REVIEW / SKIP に分類
3. FIX     — general-purpose エージェント×N で並列修正
4. VERIFY  — ビルド + テスト + 型チェック
5. REPORT  — 統合レポート出力
```

安全装置:
- 修正前に `git stash` でスナップショット保存
- `fix/aufheben-{timestamp}` ブランチで作業
- ビルド失敗 → 即 revert
- 1回の実行で最大20件まで

## Detection Pattern Coverage

### L1-L6: General Detection (references/detection-patterns.md)

| Layer | Patterns | Scope |
|-------|----------|-------|
| L1 Contract Mismatch | 5 patterns | ID suffix, type drift, hardcoded constants, HTTP status, API endpoint |
| L2 Silent Failure | 4 patterns | Empty catch, fire-and-forget, no-log catch, fallback hiding |
| L3 State Sync Bug | 4 patterns | Event subscribe gap, SSE/WS mismatch, dedup weakness, poll vs push |
| L4 Dead Feature | 5 patterns | Empty handler, always-hidden UI, orphan route, unused hook, unused export |
| L5 Structural Contradiction | 5 patterns | Stale comment, config scatter, naming clash, circular import, dead code ref |
| L6 Resource Waste | 5 patterns | N+1 fetch, huge payload, unnecessary recompute, unnecessary re-render, bundle bloat |

### L7: Security (references/security-patterns.md)

OWASP Top 10 2025 + API Security Top 10 2023 から 42 パターン。

| OWASP Category | Patterns |
|----------------|----------|
| A01 Broken Access Control | Auth check missing, IDOR, CORS, SSRF |
| A02 Cryptographic Failures | Hardcoded secrets, weak hash, missing HTTPS |
| A03 Injection | SQL injection, XSS, command injection, path traversal |
| A04 Insecure Design | Mass assignment, rate limit missing |
| A05 Security Misconfiguration | Debug mode, default credentials, verbose errors |
| A06 Vulnerable Components | Known CVE, outdated dependencies |
| A07 Auth Failures | Weak password policy, session fixation, JWT misconfiguration |
| A08 Data Integrity Failures | Unsigned updates, deserialization, CI/CD poisoning |
| A09 Logging Failures | Missing audit log, PII in logs |
| A10 SSRF | URL validation, DNS rebinding |

### L8: Reliability (references/reliability-patterns.md)

SRE / Chaos Engineering から 28 パターン。

| Category | Patterns |
|----------|----------|
| Timeout | HTTP, DB, WebSocket, DNS |
| Retry | Retry storm, backoff, idempotency |
| Circuit Breaker | Missing CB, cascading failure |
| Bulkhead | Thread pool isolation, queue limits |
| Health Check | Liveness, readiness, dependency check |
| Graceful Shutdown | Signal handling, drain logic |
| Observability | Structured logging, metrics, tracing |
| Data Integrity | Transaction boundary, idempotent writes |

### L9: Implicit Knowledge (references/implicit-knowledge.md)

開発者の暗黙の仮定に潜む 32 パターン、12 ドメイン。

| Domain | Patterns | Examples |
|--------|----------|---------|
| T1 Time/Date | 4 | Timezone, DST, timestamp uniqueness, date format |
| T2 String/Unicode | 3 | `.length` != chars, case conversion locale, `\w` is ASCII |
| T3 Names | 2 | Name validation assumptions, email regex |
| T4 Numbers/Currency | 3 | Float money (`0.1+0.2`), currency decimals, MAX_SAFE_INTEGER |
| T5 Network | 3 | Idempotency, DNS assumptions, Content-Type trust |
| T6 Filesystem | 2 | Path separators, filename safety |
| T7 Database | 3 | AUTO_INCREMENT gaps, transaction isolation, NULL logic |
| T8 Auth | 3 | Client-only auth, JWT assumptions, session fixation |
| T9 Pagination | 2 | OFFSET scaling, search injection |
| T10 Cache | 2 | Cache consistency, Cache-Control |
| T11 Concurrency | 2 | Node.js race conditions, Promise.all partial failure |
| T12 Environment | 3 | Env var existence, read-only FS, env parity |

### Case Archive (references/case-archive.md)

実際のバグと本番障害から 12 事例を収録。

| Category | Cases | Source |
|----------|-------|--------|
| Ghost | 3 | Ollama ID mismatch, WebSocket dedup, fire-and-forget |
| Fragile | 5 | CrowdStrike (8.5M BSOD), Cloudflare DNS, GitHub Actions secrets, OpenAI API, Zoom |
| Blind Spot | 4 | AWS S3 region, JS Date month, UTF-8 BOM, floating point money |

**Observation**: L8 (Reliability) and L9 (Implicit Knowledge) account for 8 of 12 production incidents. Ghost failures surface during development; Fragile and Blind Spot issues hide until production.

## Framework Support

Stack-agnostic. Detects project type automatically and adapts queries.

| Category | Supported |
|----------|-----------|
| **Frontend** | Vue/Nuxt, React/Next.js, Svelte/SvelteKit, Angular |
| **Backend** | Node.js/Express/Nitro, Python/Django/FastAPI, Go, Rust |
| **Build** | pnpm, npm, yarn, bun, cargo, go build, pip |

## Research Backing

| Source | Contribution |
|--------|-------------|
| CK Metrics (Chidamber & Kemerer 1994) | CBO/WMC/RFC threshold baselines |
| Shannon Entropy (2025 Springer) | Information-theoretic anomaly detection, 60%+ precision |
| JIT Defect Prediction (2024-2025) | Process metrics outperform code complexity metrics |
| OWASP Top 10 2025 | Security threshold evidence |
| Google SRE (2024) | Reliability pattern severity evidence |

## File Structure

```
web-anomaly-detector/
├── SKILL.md                        # Core skill definition (~110 lines)
├── README.md                       # This file
├── marketplace.json                # Marketplace distribution metadata
├── .claude-plugin/
│   └── plugin.json                 # Plugin manifest (skills, agents, hooks, commands)
├── commands/
│   ├── scan.md                     # /web-anomaly-detector:scan command
│   └── score.md                    # /web-anomaly-detector:score command
├── hooks/
│   └── passive-detect.sh           # PostToolUse:Edit passive detection hook
└── references/
    ├── quantitative-parameters.md  # 17 QAP definitions, formulas, thresholds (396 lines)
    ├── detection-patterns.md       # L1-L6 grep/glob queries, multi-framework (322 lines)
    ├── security-patterns.md        # L7: OWASP 2025 + API Security 2023 — 42 patterns (445 lines)
    ├── reliability-patterns.md     # L8: SRE/Chaos Engineering — 28 patterns (341 lines)
    ├── implicit-knowledge.md       # L9: 12 domains, 32 patterns (416 lines)
    └── case-archive.md             # 12 real-world incidents (125 lines)
```

## License

MIT
