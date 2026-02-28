# Web Anomaly Detector

**コードの「違和感」を数値で暴く** Claude Code スキル。

```
 あなたのコード                          レポート
 ┌──────────┐    ┌─────────────────┐    ┌──────────────────────┐
 │ catch(){} │───▶│  9 Layers Scan  │───▶│ Ghost:    0.72  ⚠   │
 │ eval()    │    │  17 Parameters  │    │ Fragile:  0.85  ✓   │
 │ no timeout│    │  130+ Patterns  │    │ BlindSpot:0.45  ✗   │
 │ sk-key... │    │  LLM Verify     │    │ Overall:  0.68  ⚠   │
 └──────────┘    └─────────────────┘    └──────────────────────┘
```

ESLint が見つけない。テストが通っていても壊れる。本番で初めて発覚する。
そういう **違和感** を体系的に検出し、数値で立証する。

---

## 30秒で理解する

```
  「何かおかしい」を数値化する

  ┌─────────────────────────────────────────────────┐
  │                                                 │
  │    catch(() => {})  ──────▶  EHD = 0.3  ✗       │
  │    エラー握り潰し            エラー処理率30%     │
  │                                                 │
  │    fetch() no timeout ────▶  TCR = 0.4  ⚠       │
  │    タイムアウト未設定        タイムアウト率40%   │
  │                                                 │
  │    api_key = "sk-..."  ───▶  SEC = 3    ✗       │
  │    秘密鍵ハードコード        3件露出             │
  │                                                 │
  │    0.1 + 0.2 で金額計算 ──▶  L9 BlindSpot ⚠     │
  │    浮動小数点の罠            暗黙の仮定          │
  │                                                 │
  └─────────────────────────────────────────────────┘
```

---

## インストール

```bash
git clone https://github.com/ohyesiamy/web-anomaly-detector.git \
  ~/.claude/skills/web-anomaly-detector
```

## 使い方

Claude Code に話しかけるだけ:

```
「このプロジェクトの違和感を探して」
「システム監査して」
「何かおかしいところはないか確認して」
```

---

## 3カテゴリ × 9レイヤー

違和感を **3つの問い** で分類する。

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                                                                 │
  │  Ghost 👻                Fragile 🔨              Blind Spot 🕳  │
  │  "動くの？"              "壊れない？"             "見えてる？"    │
  │                                                                 │
  │  ┌─────────────────┐   ┌─────────────────┐   ┌──────────────┐  │
  │  │ L1 契約不一致    │   │ L5 構造矛盾     │   │ L9 暗黙知    │  │
  │  │ L2 サイレント失敗│   │ L6 リソース浪費 │   │    の罠      │  │
  │  │ L3 状態同期バグ  │   │ L7 セキュリティ │   │              │  │
  │  │ L4 死んだ機能    │   │ L8 信頼性リスク │   │  12ドメイン  │  │
  │  └─────────────────┘   └─────────────────┘   │  32パターン  │  │
  │                                               └──────────────┘  │
  │   5 QAP パラメーター     8 QAP パラメーター    4 QAP パラメーター │
  └─────────────────────────────────────────────────────────────────┘
```

### 各レイヤーの具体例

```
  L1 契約不一致        型定義: { name: string }
                       API実態: { name: "太郎", nickname: "タロー" }
                       → nickname が型にない → CFR 低下

  L2 サイレント失敗    try { await api.post() }
                       catch(e) { }          ← 何もしない
                       → エラーが闇に消える → EHD 低下

  L3 状態同期バグ      server: emit("price_update", data)
                       client: // 誰も listen していない
                       → リアルタイム更新が届かない → ESR 低下

  L4 死んだ機能        <button @click="handleSubmit">送信</button>
                       function handleSubmit() { /* TODO */ }
                       → ボタンを押しても何も起きない → HLR 低下

  L5 構造矛盾          .env:    API_URL=https://api.example.com
                       config:  apiUrl: "http://localhost:3000"
                       → どっちが正しいの？ → CSS 上昇

  L6 リソース浪費      for (const user of users) {
                         await fetch(`/api/profile/${user.id}`)
                       }
                       → N+1 問題。100人 = 100リクエスト

  L7 セキュリティ      const API_KEY = "sk-proj-abc123..."
                       → ソースに秘密鍵が埋まっている → SEC 検出

  L8 信頼性リスク      await fetch("https://external-api.com/data")
                       → タイムアウト未設定 = 無限待機 → TCR 低下

  L9 暗黙知の罠        const total = price * 1.1  // 消費税
                       → 0.1 + 0.2 !== 0.3 の世界 → 金額計算に浮動小数点
```

---

## パイプライン (v3.2)

```
  ┌─────────┐     ┌──────────┐     ┌───────────┐     ┌─────────┐     ┌────────┐
  │  SCOPE  │────▶│ MEASURE  │────▶│  VERIFY   │────▶│ TRIAGE  │────▶│ REPORT │
  │         │     │          │     │           │     │         │     │        │
  │ 対象特定 │     │ 17 QAP   │     │ LLM 検証  │     │ 重要度   │     │ スコア  │
  │ ・全体   │     │ grep/glob│     │ Qwen3     │     │ 分類     │     │ 表付き  │
  │ ・差分   │     │ 並列計測  │     │ 偽陽性除去│     │ C/W/I   │     │ 出力    │
  │ ・パス   │     │          │     │ confidence│     │         │     │        │
  └─────────┘     └──────────┘     └─────┬─────┘     └─────────┘     └────────┘
                                         │
                                  lm-studio-ensure.sh
                                  ┌──────┴──────┐
                                  │ サーバー起動  │
                                  │ モデルロード  │
                                  │ ヘルスチェック│
                                  └──────┬──────┘
                                         │
                                    未起動/失敗時
                                    → grep-only mode
```

### v3.2: LM Studio 完全自動化

`lm-studio-ensure.sh` がサーバー起動 → モデルロード → ヘルスチェックを全自動で実行。
手動で LM Studio を操作する必要はない。

```
  lm-studio-ensure.sh の処理フロー:

  lms CLI 存在？ ─── No ──▶ UNAVAILABLE (grep-only)
       │ Yes
  サーバー起動？ ─── No ──▶ lms server start + 15s 待機
       │ Yes
  モデルロード？ ─── No ──▶ lms load qwen/qwen3-coder-next --gpu max
       │ Yes
  READY:model_id ──────────▶ LLM 検証モード
```

### バージョン比較

| | v2.0 | v3.2 |
|---|---|---|
| 検出 | grep/glob のみ | grep/glob → **LLM 検証** |
| 偽陽性 | そのまま出力 | confidence score で除去 |
| スコア | raw QAP | **adjusted QAP** |
| LM Studio | — | **自動起動 + 自動ロード** |
| フック | **動作せず** (環境変数前提) | **stdin JSON 対応** (修正済) |
| 後方互換 | — | `--grep-only` で v2.0 同等 |

---

## QAP: 17個の定量パラメーター

「何かおかしい」を **4種類の計測** で数値化する。

```
  ┌──────────────────────────────────────────────────────────────┐
  │                    4つの計測タイプ                            │
  │                                                              │
  │  Ratio     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━▶ 1.0       │
  │  (比率)    matching / total        健全 → 1.0               │
  │                                                              │
  │  Presence  ●                                                 │
  │  (存在)    count of anti-patterns  健全 = 0                  │
  │                                                              │
  │  Symmetry  ◀━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━▶           │
  │  (対称性)  |open - close| / max    健全 → 0.0               │
  │                                                              │
  │  Scatter   ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·  ·              │
  │  (散在度)  定義箇所 / キー数       健全 = 1.0               │
  └──────────────────────────────────────────────────────────────┘
```

### 全パラメーター一覧

| # | QAP | 名前 | タイプ | Cat | 健全値 |
|---|-----|------|--------|-----|--------|
| 1 | **CFR** | 契約一致率 | Ratio | Ghost | → 1.0 |
| 2 | **EHD** | エラー処理率 | Ratio | Ghost | → 1.0 |
| 3 | **ESR** | イベント購読率 | Ratio | Ghost | → 1.0 |
| 4 | **HLR** | ハンドラ実装率 | Ratio | Ghost | → 1.0 |
| 5 | **RRR** | ルート到達率 | Ratio | Ghost | → 1.0 |
| 6 | **NCI** | 命名一貫性 | Ratio | Fragile | → 1.0 |
| 7 | **CSS** | 設定散在度 | Scatter | Fragile | = 1.0 |
| 8 | **TCR** | タイムアウト率 | Ratio | Fragile | → 1.0 |
| 9 | **AGC** | 認証保護率 | Ratio | Fragile | → 1.0 |
| 10 | **SEC** | 秘密鍵露出 | Presence | Fragile | = 0 |
| 11 | **RPC** | 耐障害率 | Ratio | Fragile | → 1.0 |
| 12 | **MLS** | リソース対称性 | Symmetry | Fragile | → 0.0 |
| 13 | **GSS** | シャットダウン | Presence | Fragile | = 1 |
| 14 | **TSI** | TODO放置率 | Ratio | Blind Spot | → 0.0 |
| 15 | **ITCR** | 暗黙型変換 | Presence | Blind Spot | = 0 |
| 16 | **BVG** | バリデーション欠落 | Ratio | Blind Spot | → 1.0 |
| 17 | **DFS** | 依存管理品質 | Ratio | Blind Spot | → 1.0 |

### Composite Scoring

```
  Ghost Score     = 0.30×CFR + 0.30×EHD + 0.15×ESR + 0.15×HLR + 0.10×RRR
  Fragile Score   = 0.15×NCI + 0.10×(1/CSS) + 0.20×TCR + 0.20×AGC + ...
  BlindSpot Score = 0.25×(1-TSI) + 0.20×ITCR_norm + 0.30×BVG + 0.25×DFS

  ┌─────────────────────────────────────────────────────┐
  │                                                     │
  │  Overall = 0.40 × Ghost                             │
  │         + 0.35 × Fragile     ◀── 本番障害の主因     │
  │         + 0.25 × BlindSpot   ◀── 長期的リスク       │
  │                                                     │
  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
  │  0.0          0.50          0.80              1.0   │
  │  ✗ Critical   ⚠ Warning     ✓ Healthy              │
  └─────────────────────────────────────────────────────┘
```

---

## コマンド

### `/web-anomaly-detector:scan`

```bash
/web-anomaly-detector:scan           # 全体スキャン
/web-anomaly-detector:scan diff      # git diff のみ
/web-anomaly-detector:scan path:src/ # 特定ディレクトリ
```

3つの Explore エージェントが並列で 9レイヤーをスキャン:

```
  ┌─────────┐
  │  scan   │
  └────┬────┘
       │
  ┌────┴────┬────────────┬────────────┐
  ▼         ▼            ▼            │
Agent A   Agent B     Agent C         │
Ghost     Fragile    Blind Spot       │
L1-L4     L5-L8       L9             │
  │         │            │            │
  └────┬────┴────────────┘            │
       ▼                              │
  ┌──────────┐                        │
  │  TRIAGE  │  ◀── LLM 検証 (opt)   │
  └────┬─────┘                        │
       ▼                              │
  ┌──────────┐                        │
  │  REPORT  │                        │
  └──────────┘                        │
```

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
| # | Cat | Layer | QAP     | Location              | Symptom            |
|---|-----|-------|---------|-----------------------|--------------------|
| 1 | BS  | L9    | BVG=0.4 | server/api/user.ts:17 | バリデーションなし  |
| 2 | G   | L2    | EHD=0.3 | lib/api-client.ts:42  | 空 catch ブロック   |
```

### `/web-anomaly-detector:score`

QAP 数値計算のみの軽量版。パターン検出は行わない。

```bash
/web-anomaly-detector:score           # 全体
/web-anomaly-detector:score path:api/ # 特定ディレクトリ
```

---

## パッシブ検出フック

ファイル編集のたびに自動実行される軽量チェック。**非ブロッキング** — 編集を止めない。

```
  あなたが Edit する
       │
       ▼
  ┌──────────────────┐     ┌───────────────────────────────────┐
  │ passive-detect.sh│────▶│ ⚠ [L2] Empty catch block detected │
  │ (stdin JSON)     │     │ ⚠ [L7] Possible hardcoded secret  │
  └──────────────────┘     └───────────────────────────────────┘
       │
  検出対象:
  ├── L2: 空 catch, silent .catch(), except: pass
  └── L7: 秘密鍵, eval(), innerHTML, SQL 結合
```

---

## Aufheben Agent

検出 → 分類 → **並列修正** → 検証を一気通貫で実行。

```
「アウフヘーベンして」
「違和感を見つけて修正して」
```

```
  ┌─────────┐   ┌────────┐   ┌────────┐   ┌───────┐   ┌────────┐   ┌────────┐
  │  RECON  │──▶│ DETECT │──▶│ TRIAGE │──▶│  FIX  │──▶│ VERIFY │──▶│ REPORT │
  │ Stack検出│   │ 3並列   │   │ 分類    │   │ N並列  │   │ Build  │   │ 統合   │
  └─────────┘   └────────┘   │AUTO-FIX│   └───────┘   │ Test   │   └────────┘
                              │MANUAL  │               │ Types  │
                              │SKIP    │               └────────┘
                              └────────┘

  安全装置:
  ✓ git stash でスナップショット保存
  ✓ fix/aufheben-{timestamp} ブランチで作業
  ✓ ビルド失敗 → 即 revert
  ✓ 1回の実行で最大20件まで
```

---

## 検出パターン: 130+

```
  ┌──────────────────────────────────────────────────────────────┐
  │                   130+ Detection Patterns                    │
  │                                                              │
  │  L1-L6  General ·········· 28 patterns                      │
  │  ├ L1 契約不一致           5  (ID, 型, 定数, HTTP, API)      │
  │  ├ L2 サイレント失敗       4  (空catch, fire&forget, ...)    │
  │  ├ L3 状態同期バグ         4  (event, SSE/WS, dedup, poll)  │
  │  ├ L4 死んだ機能           5  (空handler, 非表示UI, ...)     │
  │  ├ L5 構造矛盾             5  (命名, 設定散在, 循環import)  │
  │  └ L6 リソース浪費         5  (N+1, 巨大payload, bundle)    │
  │                                                              │
  │  L7  Security ············ 42 patterns (OWASP 2025)         │
  │  ├ A01 アクセス制御        Auth, IDOR, CORS, SSRF           │
  │  ├ A02 暗号失敗            秘密鍵, 弱ハッシュ, HTTP          │
  │  ├ A03 インジェクション    SQL, XSS, コマンド, パス           │
  │  └ A04-A10                 設計, 設定, 脆弱性, 認証...       │
  │                                                              │
  │  L8  Reliability ········· 28 patterns (SRE)                │
  │  ├ Timeout                 HTTP, DB, WS, DNS                 │
  │  ├ Retry                   Storm, backoff, 冪等性            │
  │  └ Circuit Breaker         CB欠如, カスケード障害            │
  │                                                              │
  │  L9  Implicit Knowledge ·· 32 patterns (12 domains)         │
  │  ├ 時間/日付               TZ, DST, timestamp一意性          │
  │  ├ 文字列/Unicode          .length, ロケール, \w             │
  │  ├ 数値/通貨               浮動小数点, 通貨桁, MAX_SAFE_INT  │
  │  └ ネットワーク/DB/認証... 冪等性, NULL, セッション固定      │
  └──────────────────────────────────────────────────────────────┘
```

---

## 対応フレームワーク

スタック非依存。プロジェクトを自動検出してクエリを適応。

```
  Frontend          Backend             Build
  ┌──────────┐     ┌──────────────┐    ┌───────────┐
  │ Vue/Nuxt │     │ Node/Express │    │ pnpm      │
  │ React/   │     │ Nitro/Hono   │    │ npm/yarn  │
  │   Next.js│     │ Fastify/tRPC │    │ bun       │
  │ Svelte/  │     │ Python/      │    │ cargo     │
  │   Kit    │     │   FastAPI    │    │ go build  │
  │ Angular  │     │ Go / Rust    │    │ pip       │
  └──────────┘     └──────────────┘    └───────────┘
```

---

## 実例: 本番障害から学ぶ

```
  ┌──────────────────────────────────────────────────────────────┐
  │  Case Archive: 12 real-world incidents                       │
  │                                                              │
  │  Ghost (3)                                                   │
  │  ├── Ollama ID: "nomic-embed-text" vs ":latest" → L1 不一致 │
  │  ├── WebSocket dedup: タイムスタンプ重複 → L3 同期バグ       │
  │  └── fire-and-forget: await 漏れ → L2 サイレント失敗         │
  │                                                              │
  │  Fragile (5)                                                 │
  │  ├── CrowdStrike: NULL pointer → 8.5M台 BSOD  → L8 信頼性  │
  │  ├── Cloudflare DNS: 設定不一致 → L5 構造矛盾               │
  │  ├── GitHub Actions: secret 漏洩 → L7 セキュリティ          │
  │  ├── OpenAI API: レート制限欠如 → L8 信頼性                  │
  │  └── Zoom: 暗号化誤表示 → L5 構造矛盾                       │
  │                                                              │
  │  Blind Spot (4)                                              │
  │  ├── AWS S3: リージョン仮定 → L9 暗黙知                     │
  │  ├── JS Date: month が 0始まり → L9 暗黙知                  │
  │  ├── UTF-8 BOM: 不可視文字 → L9 暗黙知                      │
  │  └── 浮動小数点: 0.1+0.2 金額計算 → L9 暗黙知               │
  │                                                              │
  │  ⚠ L8+L9 が12件中8件。本番で初めて発覚するタイプ。           │
  └──────────────────────────────────────────────────────────────┘
```

---

## Research Backing

| Source | 貢献 |
|--------|------|
| CK Metrics (1994) | CBO/WMC/RFC 閾値のベースライン |
| Shannon Entropy (2025) | 情報理論ベースの異常検出、60%+ precision |
| JIT Defect Prediction (2024-2025) | プロセスメトリクスの優位性を確認 |
| OWASP Top 10 (2025) | セキュリティ閾値の根拠 |
| Google SRE (2024) | 信頼性パターンの重大度根拠 |

---

## File Structure

```
web-anomaly-detector/
├── SKILL.md                        # スキル定義 (エントリポイント)
├── README.md
├── marketplace.json
├── .claude-plugin/
│   └── plugin.json                 # プラグインマニフェスト
├── commands/
│   ├── scan.md                     # /scan コマンド
│   └── score.md                    # /score コマンド
├── hooks/
│   ├── passive-detect.sh           # パッシブ検出フック
│   └── lm-studio-ensure.sh        # LM Studio 自動起動+モデルロード
└── references/
    ├── quantitative-parameters.md  # 17 QAP 定義・公式・閾値
    ├── detection-patterns.md       # L1-L6 grep/glob クエリ集
    ├── security-patterns.md        # L7: OWASP 2025 — 42 patterns
    ├── reliability-patterns.md     # L8: SRE — 28 patterns
    ├── implicit-knowledge.md       # L9: 12 domains, 32 patterns
    ├── llm-verify.md               # LLM 検証パイプライン仕様
    ├── prompts/                    # カテゴリ別 LLM 検証プロンプト
    └── case-archive.md             # 実例集: 12 本番障害
```

## License

MIT
