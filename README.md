# Web Anomaly Detector

**コードの「違和感」を数値で暴く** Claude Code スキル。

```mermaid
graph LR
    A["あなたのコード<br/>catch(){} / eval()<br/>no timeout / sk-key..."] --> B["9 Layers Scan<br/>17 Parameters<br/>130+ Patterns"]
    B --> C["LLM Verify<br/>Qwen3-Coder-Next<br/>偽陽性除去"]
    C --> D["Scored Report<br/>Ghost: 0.72 ⚠<br/>Fragile: 0.85 ✓<br/>BlindSpot: 0.45 ✗<br/>Overall: 0.68 ⚠"]

    style A fill:#2d1b69,stroke:#8b5cf6,color:#e2e8f0
    style B fill:#1e3a5f,stroke:#3b82f6,color:#e2e8f0
    style C fill:#1a4731,stroke:#22c55e,color:#e2e8f0
    style D fill:#4a1d1d,stroke:#ef4444,color:#e2e8f0
```

---

## 「違和感」とは何か

### ESLint が見つけないもの

コードの品質を守るツールは無数にある。ESLint, Prettier, TypeScript, テストスイート。
しかし **全部パスしても本番で壊れるコード** が存在する。

```typescript
// ESLint: ✓  TypeScript: ✓  テスト: ✓  本番: 💀
try {
  const result = await paymentAPI.charge(amount);
  return result;
} catch (error) {
  // TODO: エラーハンドリング
}
```

このコードは構文的に正しい。型も通る。テストでは `paymentAPI` がモックされているから通る。
しかし本番で決済APIが 500 を返したとき、**エラーは闇に消え、ユーザーには「成功」と表示される。**

これが **違和感** — コードは「動いている」が、何かが根本的におかしい。

### 違和感の3つの本質

```mermaid
graph TB
    subgraph " "
        direction TB
        Q["何かおかしい..."]
        Q --> G["動くの？<br/><b>Ghost</b>"]
        Q --> F["壊れない？<br/><b>Fragile</b>"]
        Q --> B["見えてる？<br/><b>Blind Spot</b>"]

        G --> G1["コードは存在する<br/>でも実際には機能しない"]
        F --> F1["今は動いている<br/>でも条件が変わると壊れる"]
        B --> B1["正しいと思っている<br/>でも前提が間違っている"]
    end

    style Q fill:#374151,stroke:#9ca3af,color:#f9fafb
    style G fill:#581c87,stroke:#a855f7,color:#f3e8ff
    style F fill:#7c2d12,stroke:#f97316,color:#fff7ed
    style B fill:#1e3a5f,stroke:#3b82f6,color:#eff6ff
    style G1 fill:#none,stroke:#a855f7,color:#e2e8f0
    style F1 fill:#none,stroke:#f97316,color:#e2e8f0
    style B1 fill:#none,stroke:#3b82f6,color:#e2e8f0
```

#### Ghost — 幽霊コード

**「存在するが機能しない」コード。** 見た目は正常。テストも通る。でも実際にユーザーが操作すると何も起きない。

| 症状 | 例 | なぜ危険か |
|------|-----|-----------|
| 型とAPIの不一致 | 型は `{ name }` だがAPIは `{ name, nickname }` を返す | `nickname` にアクセスすると `undefined` |
| エラー握り潰し | `catch(e) { }` で何もしない | 障害が起きても誰も気づかない |
| 誰も聴いていないイベント | サーバーが `emit("update")` するがクライアントに `on("update")` がない | リアルタイム更新が永久に届かない |
| 空のハンドラ | ボタンの `onClick` が `// TODO` | UIは反応するが処理が空 |

**なぜ既存ツールで見つからないか:** コードとしては valid。型も合っている (APIレスポンスを `any` や緩い型で受ければ)。テストはモックが正しく返すから通る。**実行時の「接続」が切れている** ことは静的解析で見つけにくい。

#### Fragile — 脆いコード

**「今は動くが、条件が変わると壊れる」コード。** 開発環境では問題なし。しかし本番のトラフィック、ネットワーク遅延、悪意あるリクエストで崩壊する。

| 症状 | 例 | なぜ危険か |
|------|-----|-----------|
| タイムアウト未設定 | `fetch(url)` にタイムアウトなし | 外部APIが遅延 → 全リクエストが詰まる |
| 秘密鍵のハードコード | `const key = "sk-proj-..."` | GitHubに公開 → 数分で不正利用 |
| N+1 クエリ | ループ内で個別 `fetch()` | 100件 = 100リクエスト → DB過負荷 |
| リトライストーム | 失敗時に即座にリトライ | 障害のAPIにさらに負荷 → 雪崩 |

**なぜ既存ツールで見つからないか:** 正常系のテストは通る。負荷テストや異常系テストがないと露呈しない。「たまたまうまくいっている」状態。

#### Blind Spot — 暗黙の前提

**「正しいと信じているが、前提が間違っている」コード。** プログラマーの知識の盲点を突く。

| 症状 | 例 | なぜ危険か |
|------|-----|-----------|
| 浮動小数点で金額計算 | `price * 1.1` (消費税) | `0.1 + 0.2 === 0.30000000000000004` |
| `.length` で文字数取得 | `"👨‍👩‍👧".length` | 答えは `8` (11ではなく) |
| 月が0始まり | `new Date(2024, 1, 1)` | 1月ではなく **2月** 1日 |
| `==` で比較 | `"0" == false` | `true` になる (型強制) |

**なぜ既存ツールで見つからないか:** 言語仕様として「正しい」動作。バグではなく **仕様の理解不足** 。ESLint の一部ルールで `==` は検出できるが、浮動小数点や Unicode の問題は検出できない。

### なぜ数値化するのか

「違和感がある」だけでは、修正の優先度をつけられない。

```mermaid
graph LR
    subgraph 従来
        A1["レビュアーの勘"] --> A2["なんかこの catch 怪しい"]
        A2 --> A3["...でも動いてるし放置"]
    end

    subgraph "Web Anomaly Detector"
        B1["grep/glob 計測"] --> B2["EHD = 0.30<br/>エラー処理率 30%"]
        B2 --> B3["LLM 検証<br/>confidence = 0.92"]
        B3 --> B4["CRITICAL: 即座に修正"]
    end

    style A3 fill:#4a1d1d,stroke:#ef4444,color:#fca5a5
    style B4 fill:#14532d,stroke:#22c55e,color:#bbf7d0
```

**EHD (Error Handling Density) = 0.30** は「try-catch の 70% がエラーを握り潰している」という客観的事実。
感覚ではなく数値なので、チームで共有でき、改善を追跡できる。

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

```mermaid
block-beta
    columns 3

    block:ghost:1
        columns 1
        gh["Ghost 👻<br/>動くの？"]
        L1["L1 契約不一致"]
        L2["L2 サイレント失敗"]
        L3["L3 状態同期バグ"]
        L4["L4 死んだ機能"]
        gq["5 QAP"]
    end

    block:fragile:1
        columns 1
        fr["Fragile 🔨<br/>壊れない？"]
        L5["L5 構造矛盾"]
        L6["L6 リソース浪費"]
        L7["L7 セキュリティ"]
        L8["L8 信頼性リスク"]
        fq["8 QAP"]
    end

    block:blind:1
        columns 1
        bl["Blind Spot 🕳<br/>見えてる？"]
        L9["L9 暗黙知の罠<br/>12ドメイン<br/>32パターン"]
        bq["4 QAP"]
    end

    style gh fill:#581c87,stroke:#a855f7,color:#f3e8ff
    style fr fill:#7c2d12,stroke:#f97316,color:#fff7ed
    style bl fill:#1e3a5f,stroke:#3b82f6,color:#eff6ff
    style gq fill:#581c87,stroke:#a855f7,color:#f3e8ff
    style fq fill:#7c2d12,stroke:#f97316,color:#fff7ed
    style bq fill:#1e3a5f,stroke:#3b82f6,color:#eff6ff
```

### 各レイヤーの具体例

<details>
<summary><b>L1 契約不一致</b> — 型定義と実行時データが食い違う</summary>

```typescript
// 型定義
interface User { name: string; }

// API が実際に返すデータ
{ "name": "太郎", "nickname": "タロー" }

// → nickname が型にない → user.nickname は undefined
// → CFR (Contract Fulfillment Rate) 低下
```
</details>

<details>
<summary><b>L2 サイレント失敗</b> — エラーが闇に消える</summary>

```typescript
try {
  await paymentAPI.charge(amount);
} catch (error) {
  // 何もしない ← 決済失敗がユーザーに伝わらない
}

// → EHD (Error Handling Density) 低下
```
</details>

<details>
<summary><b>L3 状態同期バグ</b> — 送信と受信が噛み合わない</summary>

```typescript
// サーバー
socket.emit("price_update", newPrice);

// クライアント — 誰も listen していない
// socket.on("price_update", ...) が存在しない

// → ESR (Event Subscription Ratio) 低下
```
</details>

<details>
<summary><b>L4 死んだ機能</b> — UIは存在するが中身が空</summary>

```vue
<button @click="handleSubmit">送信</button>

<script>
function handleSubmit() {
  // TODO: 実装する
}
</script>

<!-- ボタンを押しても何も起きない → HLR 低下 -->
```
</details>

<details>
<summary><b>L5 構造矛盾</b> — 設定が複数箇所で食い違う</summary>

```bash
# .env
API_URL=https://api.example.com

# config.ts
apiUrl: "http://localhost:3000"

# どっちが正しいの？ → CSS (Config Scatter Score) 上昇
```
</details>

<details>
<summary><b>L6 リソース浪費</b> — 知らないうちにリソースを食い尽くす</summary>

```typescript
// N+1 問題
for (const user of users) {
  const profile = await fetch(`/api/profile/${user.id}`);
}
// 100人 = 100リクエスト。1リクエストで取れるのに。
```
</details>

<details>
<summary><b>L7 セキュリティ</b> — OWASP Top 10 に該当する脆弱性</summary>

```typescript
const API_KEY = "sk-proj-abc123def456...";
// → ソースコードに秘密鍵 → GitHubに公開 → 数分で悪用
// → SEC (Secret Exposure Count) 検出
```
</details>

<details>
<summary><b>L8 信頼性リスク</b> — 正常時は見えない爆弾</summary>

```typescript
const data = await fetch("https://external-api.com/data");
// タイムアウト未設定 → 外部APIが遅延 → 全リクエスト停止
// → TCR (Timeout Coverage Ratio) 低下
```
</details>

<details>
<summary><b>L9 暗黙知の罠</b> — 正しいと信じている間違い</summary>

```typescript
const total = price * 1.1; // 消費税10%
// 0.1 + 0.2 === 0.30000000000000004
// 金額計算に浮動小数点 → 1円ズレが蓄積 → 会計不一致

"👨‍👩‍👧".length  // → 8 (見た目は1文字なのに)
new Date(2024, 1, 1) // → 2月1日 (1月じゃない)
```
</details>

---

## パイプライン (v3.2)

```mermaid
graph LR
    S["SCOPE<br/>対象特定"] --> M["MEASURE<br/>17 QAP<br/>grep/glob 並列"]
    M --> V["VERIFY<br/>LLM 検証<br/>偽陽性除去"]
    V --> T["TRIAGE<br/>重要度分類<br/>C / W / I"]
    T --> R["REPORT<br/>スコア付き<br/>レポート"]

    V -.-> E["lm-studio-ensure.sh<br/>自動起動+ロード"]
    E -.->|未起動/失敗| FB["grep-only<br/>fallback"]

    style S fill:#1e3a5f,stroke:#3b82f6,color:#e2e8f0
    style M fill:#1a4731,stroke:#22c55e,color:#e2e8f0
    style V fill:#581c87,stroke:#a855f7,color:#e2e8f0
    style T fill:#7c2d12,stroke:#f97316,color:#e2e8f0
    style R fill:#374151,stroke:#9ca3af,color:#f9fafb
    style E fill:#14532d,stroke:#22c55e,color:#bbf7d0
    style FB fill:#374151,stroke:#6b7280,color:#9ca3af
```

### 2-Stage 検証: なぜ LLM が必要か

grep だけでは **偽陽性** が避けられない。

```mermaid
graph TB
    subgraph "Stage 1: grep/glob (高速・広範囲)"
        G1["catch(e) { } を検出"] --> |"500件マッチ"| G2["全部が異常？<br/>No — 多くは正常"]
    end

    subgraph "Stage 2: LLM 検証 (高精度・選択的)"
        L1["catch(e) { logger.error(e); throw e; }"]
        L2["catch(e) { }"]
        L3["catch(e) { return fallback; }"]

        L1 --> |"FALSE_POSITIVE<br/>conf: 0.95"| FP["除外"]
        L2 --> |"TRUE_POSITIVE<br/>conf: 0.92"| TP["残す"]
        L3 --> |"UNCERTAIN<br/>conf: 0.45"| UN["要確認"]
    end

    G2 --> L1
    G2 --> L2
    G2 --> L3

    style FP fill:#14532d,stroke:#22c55e,color:#bbf7d0
    style TP fill:#4a1d1d,stroke:#ef4444,color:#fca5a5
    style UN fill:#78350f,stroke:#f59e0b,color:#fef3c7
```

- `catch(e) { logger.error(e); throw e; }` → **偽陽性。** エラーをログに記録して再スローしている。正常。
- `catch(e) { }` → **真陽性。** 完全な握り潰し。
- `catch(e) { return fallback; }` → **判断保留。** 意図的なフォールバックかもしれない。

grep は上記を区別できないが、LLM (Qwen3-Coder-Next) はコンテキストを理解して判定する。

### LM Studio 完全自動化

```mermaid
flowchart TD
    Start["scan 開始"] --> CLI{"lms CLI<br/>存在？"}
    CLI -->|No| Fallback["grep-only mode"]
    CLI -->|Yes| Server{"サーバー<br/>起動済？"}
    Server -->|No| StartServer["lms server start<br/>15s 待機"]
    Server -->|Yes| Model{"Qwen3-Coder-Next<br/>ロード済？"}
    StartServer --> Model
    Model -->|No| LoadModel["lms load<br/>qwen/qwen3-coder-next<br/>--gpu max"]
    Model -->|Yes| Ready["READY<br/>LLM 検証モード"]
    LoadModel --> Ready

    style Fallback fill:#374151,stroke:#6b7280,color:#9ca3af
    style Ready fill:#14532d,stroke:#22c55e,color:#bbf7d0
    style StartServer fill:#1e3a5f,stroke:#3b82f6,color:#e2e8f0
    style LoadModel fill:#581c87,stroke:#a855f7,color:#f3e8ff
```

`lm-studio-ensure.sh` が全自動で実行。手動操作は一切不要。

### バージョン比較

| | v2.0 | v3.2 |
|---|---|---|
| 検出 | grep/glob のみ | grep/glob → **LLM 検証** |
| 偽陽性 | そのまま出力 | confidence score で除去 |
| スコア | raw QAP | **adjusted QAP** |
| LM Studio | — | **自動起動 + 自動ロード** |
| 後方互換 | — | `--grep-only` で v2.0 同等 |

---

## QAP: 17個の定量パラメーター

「何かおかしい」を 4 種類の計測で数値化する。

```mermaid
graph TB
    subgraph "4つの計測タイプ"
        R["<b>Ratio</b> (比率)<br/>matching / total → 1.0<br/>例: catch処理率, 認証保護率"]
        P["<b>Presence</b> (存在)<br/>count of anti-patterns = 0<br/>例: ハードコード秘密鍵の数"]
        SY["<b>Symmetry</b> (対称性)<br/>|open - close| / max → 0.0<br/>例: addEventListener vs remove"]
        SC["<b>Scatter</b> (散在度)<br/>定義箇所 / キー数 = 1.0<br/>例: 同一設定値の散在"]
    end

    style R fill:#14532d,stroke:#22c55e,color:#bbf7d0
    style P fill:#4a1d1d,stroke:#ef4444,color:#fca5a5
    style SY fill:#1e3a5f,stroke:#3b82f6,color:#eff6ff
    style SC fill:#78350f,stroke:#f59e0b,color:#fef3c7
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

```mermaid
graph LR
    subgraph Ghost["Ghost Score"]
        G["0.30×CFR + 0.30×EHD<br/>+ 0.15×ESR + 0.15×HLR<br/>+ 0.10×RRR"]
    end
    subgraph Fragile["Fragile Score"]
        F["0.15×NCI + 0.10×(1/CSS)<br/>+ 0.20×TCR + 0.20×AGC<br/>+ 0.15×RPC + ..."]
    end
    subgraph BlindSpot["BlindSpot Score"]
        B["0.25×(1-TSI) + 0.20×ITCR<br/>+ 0.30×BVG + 0.25×DFS"]
    end

    G --> O["<b>Overall</b><br/>0.40 × Ghost<br/>+ 0.35 × Fragile<br/>+ 0.25 × BlindSpot"]
    F --> O
    B --> O

    O --> H{"Score"}
    H -->|">= 0.80"| Healthy["✓ Healthy"]
    H -->|"0.50 - 0.80"| Warning["⚠ Warning"]
    H -->|"< 0.50"| Critical["✗ Critical"]

    style Ghost fill:#581c87,stroke:#a855f7,color:#f3e8ff
    style Fragile fill:#7c2d12,stroke:#f97316,color:#fff7ed
    style BlindSpot fill:#1e3a5f,stroke:#3b82f6,color:#eff6ff
    style Healthy fill:#14532d,stroke:#22c55e,color:#bbf7d0
    style Warning fill:#78350f,stroke:#f59e0b,color:#fef3c7
    style Critical fill:#4a1d1d,stroke:#ef4444,color:#fca5a5
```

Ghost の重みが最大 (0.40) — 「動かないコード」が最も致命的だから。
Fragile (0.35) — 本番障害の直接原因。
BlindSpot (0.25) — 長期的リスク。発覚が遅いほど修正コストが膨らむ。

---

## コマンド

### `/web-anomaly-detector:scan`

```bash
/web-anomaly-detector:scan           # 全体スキャン
/web-anomaly-detector:scan diff      # git diff のみ
/web-anomaly-detector:scan path:src/ # 特定ディレクトリ
```

3つの Explore エージェントが並列で 9 レイヤーをスキャン:

```mermaid
graph TB
    Scan["scan 実行"] --> A["Agent A<br/>Ghost<br/>L1-L4"]
    Scan --> B["Agent B<br/>Fragile<br/>L5-L8"]
    Scan --> C["Agent C<br/>Blind Spot<br/>L9"]

    A --> Merge["結果統合"]
    B --> Merge
    C --> Merge

    Merge --> Verify{"LLM<br/>検証？"}
    Verify -->|Yes| LLM["Qwen3-Coder-Next<br/>偽陽性除去"]
    Verify -->|No| Triage["TRIAGE"]
    LLM --> Triage
    Triage --> Report["REPORT"]

    style A fill:#581c87,stroke:#a855f7,color:#f3e8ff
    style B fill:#7c2d12,stroke:#f97316,color:#fff7ed
    style C fill:#1e3a5f,stroke:#3b82f6,color:#eff6ff
    style LLM fill:#14532d,stroke:#22c55e,color:#bbf7d0
```

**出力例:**

```
## 違和感レポート: my-project

### Scores
| Category   | Raw  | Adjusted | Status  |
|------------|------|----------|---------|
| Ghost      | 0.72 | 0.68     | WARNING |
| Fragile    | 0.85 | 0.83     | Healthy |
| Blind Spot | 0.45 | 0.41     | CRITICAL|
| **Overall**| **0.68** | **0.64** | **WARNING** |

### CRITICAL (2件)
| # | Cat | Layer | QAP     | Conf | Location              | Symptom            |
|---|-----|-------|---------|------|-----------------------|--------------------|
| 1 | BS  | L9    | BVG=0.4 | 0.88 | server/api/user.ts:17 | バリデーションなし  |
| 2 | G   | L2    | EHD=0.3 | 0.92 | lib/api-client.ts:42  | 空 catch ブロック   |
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

```mermaid
sequenceDiagram
    participant User as あなた
    participant Edit as Edit ツール
    participant Hook as passive-detect.sh
    participant Output as 警告出力

    User->>Edit: コードを編集
    Edit->>Hook: stdin JSON (file_path, new_string)
    Hook->>Hook: L2 チェック (空catch, silent .catch)
    Hook->>Hook: L7 チェック (秘密鍵, eval, innerHTML)
    Hook-->>Output: ⚠ [L2] Empty catch block detected
    Hook-->>Output: ⚠ [L7] Possible hardcoded secret
    Note over Hook: exit 0 — 編集はブロックしない
```

---

## Aufheben Agent

検出 → 分類 → **並列修正** → 検証を一気通貫で実行するエージェント。

```
「アウフヘーベンして」
「違和感を見つけて修正して」
```

```mermaid
graph LR
    R["RECON<br/>Stack検出"] --> D["DETECT<br/>3並列スキャン"]
    D --> T["TRIAGE<br/>AUTO-FIX<br/>MANUAL<br/>SKIP"]
    T --> F["FIX<br/>N並列修正"]
    F --> V["VERIFY<br/>Build/Test<br/>Types"]
    V --> Rep["REPORT<br/>統合レポート"]

    style R fill:#1e3a5f,stroke:#3b82f6,color:#e2e8f0
    style D fill:#581c87,stroke:#a855f7,color:#f3e8ff
    style T fill:#78350f,stroke:#f59e0b,color:#fef3c7
    style F fill:#14532d,stroke:#22c55e,color:#bbf7d0
    style V fill:#7c2d12,stroke:#f97316,color:#fff7ed
    style Rep fill:#374151,stroke:#9ca3af,color:#f9fafb
```

**安全装置:**
- `git stash` でスナップショット保存
- `fix/aufheben-{timestamp}` ブランチで作業
- ビルド失敗 → 即 revert
- 1回の実行で最大 20 件まで

---

## 検出パターン: 130+

```mermaid
pie title 130+ Detection Patterns
    "L1-L6 General" : 28
    "L7 Security (OWASP)" : 42
    "L8 Reliability (SRE)" : 28
    "L9 Implicit Knowledge" : 32
```

| Layer | 件数 | カバー領域 |
|-------|------|-----------|
| **L1-L6** General | 28 | 契約不一致, サイレント失敗, 状態同期, 死機能, 構造矛盾, リソース浪費 |
| **L7** Security | 42 | OWASP 2025 Top 10: アクセス制御, 暗号失敗, インジェクション, 設計, 設定 |
| **L8** Reliability | 28 | SRE パターン: Timeout, Retry Storm, Circuit Breaker, カスケード障害 |
| **L9** Implicit Knowledge | 32 | 12ドメイン: 時間/Unicode/金額/ネットワーク/DB/認証/並行処理 |

---

## 実例: 本番障害から学ぶ

```mermaid
graph TB
    subgraph Ghost["Ghost (3件)"]
        G1["Ollama ID<br/>'nomic-embed-text' vs ':latest'<br/>→ L1 契約不一致"]
        G2["WebSocket dedup<br/>タイムスタンプ重複<br/>→ L3 同期バグ"]
        G3["fire-and-forget<br/>await 漏れ<br/>→ L2 サイレント失敗"]
    end

    subgraph Fragile["Fragile (5件)"]
        F1["CrowdStrike<br/>NULL pointer → 8.5M台 BSOD<br/>→ L8 信頼性"]
        F2["Cloudflare DNS<br/>設定不一致<br/>→ L5 構造矛盾"]
        F3["GitHub Actions<br/>secret 漏洩<br/>→ L7 セキュリティ"]
        F4["OpenAI API<br/>レート制限欠如<br/>→ L8 信頼性"]
        F5["Zoom<br/>暗号化誤表示<br/>→ L5 構造矛盾"]
    end

    subgraph BlindSpot["Blind Spot (4件)"]
        B1["AWS S3<br/>リージョン仮定<br/>→ L9"]
        B2["JS Date<br/>month が 0始まり<br/>→ L9"]
        B3["UTF-8 BOM<br/>不可視文字<br/>→ L9"]
        B4["浮動小数点<br/>0.1+0.2 金額計算<br/>→ L9"]
    end

    style Ghost fill:#2d1b4e,stroke:#a855f7,color:#f3e8ff
    style Fragile fill:#431407,stroke:#f97316,color:#fff7ed
    style BlindSpot fill:#172554,stroke:#3b82f6,color:#eff6ff
```

> **L8 + L9 が 12件中 8件。** 本番で初めて発覚するタイプ。
> 開発環境のテストでは絶対に見つからない。

---

## 対応フレームワーク

スタック非依存。プロジェクトを自動検出してクエリを適応。

| Frontend | Backend | Build |
|----------|---------|-------|
| Vue / Nuxt | Node / Express | pnpm |
| React / Next.js | Nitro / Hono | npm / yarn / bun |
| Svelte / Kit | Fastify / tRPC | cargo |
| Angular | Python / FastAPI | go build / pip |
| | Go / Rust | |

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
