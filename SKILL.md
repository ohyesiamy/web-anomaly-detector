---
name: web-anomaly-detector
description: コードの「違和感」を定量的に検出 — Ghost(動かない)/Fragile(壊れやすい)/Blind Spot(見えないリスク)を数値で立証する
---
<!-- auto-load: 違和感, anomaly, 矛盾, 不整合, audit, 健全性, ヘルスチェック, system-check, security-audit, セキュリティ監査, reliability -->

# Web Anomaly Detector

コードの「違和感」を **3カテゴリ × 9レイヤー** で検出し、**定量パラメーター (QAP)** で立証する。
修正提案ではなく **発見・計測・分類** に特化。

## 起動条件

「違和感を探して」「矛盾がないか確認」「システム監査」「何かおかしい」等の意図表明時。

## 3カテゴリ × 9レイヤー

| Category | 意味 | Layer | 代表 QAP |
|----------|------|-------|----------|
| **Ghost** | 動かないもの | L1 契約不一致 | CFR (Contract Fulfillment Rate) |
| | | L2 サイレント失敗 | EHD (Error Handling Density) |
| | | L3 状態同期バグ | ESR (Event Subscription Ratio) |
| | | L4 死んだ機能 | HLR, RRR (Handler/Route Liveness) |
| **Fragile** | 壊れやすいもの | L5 構造矛盾 | NCI, CSS (Naming/Config Consistency) |
| | | L6 リソース浪費 | MLS (Memory Leak Symmetry) |
| | | L7 セキュリティ欠陥 | AGC, SEC (Auth Guard/Secret Exposure) |
| | | L8 信頼性リスク | TCR, RPC, GSS (Timeout/Resilience) |
| **Blind Spot** | 見えないリスク | L9 暗黙知の罠 | BVG, TSI, DFS (Validation/Staleness) |

## QAP (定量パラメーター)

4つの計測タイプで「何かおかしい」を数値化:

| Type | Healthy | Anomalous | 例 |
|------|---------|-----------|-----|
| Ratio | -> 1.0 | -> 0.0 | catch 処理率、認証保護率 |
| Presence | 0 | > 0 | ハードコード秘密鍵の数 |
| Symmetry | 0.0 | -> 1.0 | addEventListener vs removeEventListener |
| Scatter | 1.0 | > 1.5 | 同一設定値の散在度 |

**Composite Scores** (各カテゴリのスコア → Overall):
```
Ghost    = 0.3×CFR + 0.3×EHD + 0.15×ESR + 0.15×HLR + 0.1×RRR
Fragile  = 0.15×NCI + 0.1×CSS' + 0.2×TCR + 0.2×AGC + 0.1×SEC' + 0.1×RPC + 0.1×MLS' + 0.05×GSS
BlindSpot = 0.25×TSI' + 0.2×ITCR' + 0.3×BVG + 0.25×DFS
Overall  = 0.40×Ghost + 0.35×Fragile + 0.25×BlindSpot
```
判定: >= 0.80 Healthy / 0.50-0.80 Warning / < 0.50 Critical

## 実行ワークフロー

```
1. SCOPE   — 対象範囲を特定 (全体 / フロー / git diff)
2. MEASURE — QAP パラメーターを計測 (grep/glob 並列)
3. SCAN    — 9レイヤーをパターン検出 (Explore エージェント活用)
4. TRIAGE  — QAP スコア + 重要度で分類
5. REPORT  — スコア付きレポートを出力
```

### Step 1: SCOPE
```
- 全体監査: types/, api/, components/, config を全走査
- フロー監査: 特定ユーザーフローのファイル群
- 差分監査: git diff で変更ファイルのみ
```

### Step 2-3: MEASURE + SCAN (並列実行)
QAP 17パラメーターの計測と、9レイヤー別パターン検出を並列実行。
各レイヤーの grep/glob クエリ詳細は references/ を参照。

### Step 4: TRIAGE
```
CRITICAL: QAP < 0.50 / データ消失・セキュリティ・完全非動作
WARNING:  QAP 0.50-0.80 / 部分的非動作・一貫性欠如
INFO:     QAP >= 0.80 だが改善余地あり
```

### Step 5: REPORT
```markdown
## 違和感レポート: [対象]

### Scores
| Category | Score | Status |
|----------|-------|--------|
| Ghost | 0.72 | WARNING |
| Fragile | 0.85 | Healthy |
| Blind Spot | 0.45 | CRITICAL |
| **Overall** | **0.68** | **WARNING** |

### CRITICAL (N件)
| # | Cat | Layer | QAP | Location | Symptom | Root Cause |
|---|-----|-------|-----|----------|---------|------------|
| 1 | Ghost | L1 | CFR=0.6 | file:line | ... | ... |

### WARNING (N件) ...
### INFO (N件) ...
```

## 判断基準

**検出対象**: 動かない / エラー隠蔽 / データ断絶 / 表示矛盾 / セキュリティ脆弱性 / 耐障害性欠如 / 暗黙知の罠
**除外**: コードスタイル / テストカバレッジ / ドキュメント不備

## 参照

- `references/quantitative-parameters.md` — 17個の QAP 定義・計測方法・閾値・Composite Score
- `references/detection-patterns.md` — L1-L6 スタック非依存 grep/glob クエリ集
- `references/security-patterns.md` — L7: OWASP 2025 + API Security 2023 (42パターン)
- `references/reliability-patterns.md` — L8: SRE/Chaos Engineering (28パターン)
- `references/implicit-knowledge.md` — L9: 暗黙知の罠 12ドメイン32パターン (時間/Unicode/金額/ネットワーク/DB/認証/並行処理等)
- `references/case-archive.md` — 実例集: 本番障害 (CrowdStrike/Cloudflare/OpenAI等) + 開発事例
