# Detection Patterns — L1-L6 レイヤー別クエリ集

スタック非依存。各パターンにマルチフレームワーク対応の grep/glob クエリを付記。
実例アーカイブは `case-archive.md` を参照。

---

## L1: 契約不一致 (Contract Mismatch)

### P1.1: ID サフィックス不一致
外部サービスが `:latest` / `v1` 等を付与し、内部設定は省略する。
```bash
# 設定ファイルの ID/名前
Grep "model.*[:=]|name.*[:=]|id.*[:=]" glob="*.config.*,*.json,*.yaml,*.toml,.env*"
# API レスポンスの ID フィールドと突合
# → 文字列の正規化関数が境界にあるか確認
```

### P1.2: 型定義 vs 実データ乖離
```bash
# 型定義ファイルを探索 (マルチフレームワーク)
Glob "types/**/*.ts" OR Glob "shared/types/**/*.ts" OR Glob "src/types/**/*.ts"
Glob "interfaces/**/*.ts" OR Glob "models/**/*.ts"
# interface/type のフィールドを列挙
Grep "export (interface|type) " glob="*.ts"
# API レスポンスの return 型と突合
Grep "return " path="server/" glob="*.ts"
Grep "return " path="api/" glob="*.ts"
Grep "return " path="src/routes/" glob="*.ts"
# → optional (?) がないが実際は undefined になるフィールド
```

### P1.3: ハードコード定数の不一致
```bash
# サーバー側定数
Grep "const\s+\w+\s*=" path="server/" glob="*.ts,*.js"
Grep "const\s+\w+\s*=" path="api/" glob="*.ts,*.js"
Grep "const\s+\w+\s*=" path="src/lib/" glob="*.ts,*.js"
# 同一文字列がフロントにもハードコードされていないか
Grep "'same-value'" glob="*.vue,*.jsx,*.tsx,*.svelte"
```

### P1.4: HTTP ステータスコード不一致
```bash
# サーバーが返すステータスコード (マルチフレームワーク)
Grep "statusCode|status\s*[:=]\s*[0-9]|\.status\([0-9]" path="server/" glob="*.ts,*.js"
Grep "createError|HttpException|BadRequest|NotFound" path="server/" glob="*.ts,*.js"
# フロントが期待するステータスコード
Grep "status\s*===\s*[0-9]|response\.ok|\.status\s*[!=]" glob="*.ts,*.js,*.vue,*.jsx,*.tsx"
```

### P1.5: API エンドポイント不一致
```bash
# サーバー側のルート定義
Glob "server/api/**/*.ts"              # Nitro/Nuxt
Glob "app/api/**/*.ts"                 # Next.js
Glob "src/routes/**/*.ts"              # SvelteKit/Express
Grep "router\.\w+\(['\"]/" glob="*.ts,*.js"  # Manual routing
# クライアント側の API 呼び出し
Grep "fetch\(['\"]|ofetch\(['\"]|\$fetch\(['\"]|axios\.\w+\(['\"]" glob="*.ts,*.js,*.vue,*.jsx,*.tsx"
# → サーバーにないパスをクライアントが呼んでいる
```

---

## L2: サイレント失敗 (Silent Failure)

### P2.1: 空 catch ブロック
```bash
Grep "catch\s*\(\s*\)\s*\{" glob="*.ts,*.js"       # catch() {}
Grep "catch\s*\{" glob="*.ts,*.js"                  # catch {} (TS/Swift)
Grep "\.catch\(\s*\(\s*\)\s*=>" glob="*.ts,*.js"    # .catch(() =>
Grep "\.catch\(\s*\(\s*_?\s*\)\s*=>\s*\{\s*\}\)" glob="*.ts,*.js"  # .catch((_) => {})
# Python
Grep "except.*:\s*$|except.*:.*pass" glob="*.py"
# Go
Grep "if err != nil \{" -A 1 glob="*.go"            # → 次行が return nil なら隠蔽
# Rust
Grep "\.unwrap_or|\.ok\(\)" glob="*.rs"
```

### P2.2: fire-and-forget 非同期
```bash
# await なしの非同期呼び出し (JS/TS)
Grep "^\s+fetch\(" glob="*.ts,*.js"
Grep "^\s+\$fetch\(" glob="*.ts,*.js"
Grep "^\s+ofetch\(" glob="*.ts,*.js"
# Python の fire-and-forget
Grep "asyncio\.create_task\(|\.delay\(" glob="*.py"
# → 結果を await/then で受け取っていないもの
```

### P2.3: エラーログなし catch
```bash
# catch 後の3行を確認 — ログ/throw/report がないブロック
Grep "catch" -A 3 glob="*.ts,*.js" output_mode="content"
# → console.error / logger / throw / report がない = silent
# Python
Grep "except" -A 3 glob="*.py" output_mode="content"
```

### P2.4: フォールバック隠蔽
```bash
# try-catch で代替値を返すが元のエラーを記録しない
Grep "catch.*return.*\[\]" glob="*.ts,*.js"          # 空配列
Grep "catch.*return.*null" glob="*.ts,*.js"           # null
Grep "catch.*return.*false" glob="*.ts,*.js"          # false
Grep "catch.*return.*\{\}" glob="*.ts,*.js"           # 空オブジェクト
Grep "catch.*return.*undefined" glob="*.ts,*.js"      # undefined
Grep "catch.*return.*''" glob="*.ts,*.js"             # 空文字列
```

---

## L3: 状態同期バグ (State Sync Bug)

### P3.1: イベント定義 vs 購読 (マルチフレームワーク)
```bash
# イベント定義/送信側 (サーバー)
Grep "emit\(|broadcast\(|publish\(|\.send\(|\.write\(" path="server/" glob="*.ts,*.js"
Grep "io\.emit|socket\.emit|ws\.send" path="server/" glob="*.ts,*.js"
# イベント購読側 (クライアント)
Grep "\.on\(|subscribe\(|addEventListener|useSubscription" glob="*.ts,*.js,*.vue,*.jsx,*.tsx,*.svelte"
# → emit されるがどこからも listen されていないイベント = dead path
```

### P3.2: サーバー送信 vs クライアント受信
```bash
# Server-Sent Events
Grep "res\.write\(|event:" path="server/" glob="*.ts,*.js"
# WebSocket メッセージタイプ
Grep "type.*[:=].*['\"]|event.*[:=].*['\"]" path="server/" glob="*.ts,*.js"
# クライアント側の受信フィルタ
Grep "\.on\(.*type|addEventListener.*message|onmessage" glob="*.ts,*.js,*.vue,*.jsx,*.tsx"
# → サーバーが送信するタイプのうちクライアントが listen していないもの
```

### P3.3: 重複検知ロジックの脆弱性
```bash
# タイムスタンプ・ID による重複チェック
Grep "lastProcessed|lastTimestamp|dedup|===.*timestamp|duplicate" glob="*.ts,*.js"
# Date.now() を一意キーとして使用
Grep "Date\.now\(\)|\.toISOString\(\)" glob="*.ts,*.js"
# → Map/Set のキーに使われていないか確認
```

### P3.4: ポーリングと push の競合
```bash
# ポーリング
Grep "setInterval|usePolling|polling|refetch.*interval|refreshInterval" glob="*.ts,*.js,*.vue,*.jsx,*.tsx"
# WebSocket/SSE リアルタイム更新
Grep "WebSocket|EventSource|socket\.on|useSubscription" glob="*.ts,*.js,*.vue,*.jsx,*.tsx"
# → 同じデータを両方で更新している場合 = 競合
```

---

## L4: 死んだ機能 (Dead Feature)

### P4.1: 空ハンドラ (マルチフレームワーク)
```bash
# Vue
Grep "@click=\"|@submit=\"|@change=\"" glob="*.vue"
# React/Next
Grep "onClick=\{|onSubmit=\{|onChange=\{" glob="*.jsx,*.tsx"
# Svelte
Grep "on:click=\{|on:submit=\{" glob="*.svelte"
# Angular
Grep "\(click\)=\"|\(submit\)=\"" glob="*.html,*.component.ts"
# → ハンドラ関数が空 / TODO / noop か確認
Grep "TODO|FIXME|noop|\{\s*\}|function\s*\(\s*\)\s*\{\s*\}" glob="*.ts,*.js"
```

### P4.2: 常時非表示の UI
```bash
# Vue
Grep "v-if=\"|v-show=\"" glob="*.vue"
# React
Grep "\{.*&&|.*\?.*:.*null|isVisible|isHidden|display.*none" glob="*.jsx,*.tsx"
# Svelte
Grep "\{#if " glob="*.svelte"
# → 条件が常に false になるかを追跡 (初期値 false で変更なし)
```

### P4.3: 到達不能ルート
```bash
# ファイルベースルーティング (フレームワーク自動検出)
Glob "pages/**/*.vue"                  # Nuxt
Glob "app/**/page.tsx"                 # Next.js App Router
Glob "pages/**/*.tsx"                  # Next.js Pages Router
Glob "src/routes/**/*.svelte"          # SvelteKit
# 設定ベースルーティング
Grep "path:\s*['\"]/" glob="router*.ts,routes*.ts,*routing*.ts"
# リンク元 (マルチフレームワーク)
Grep "to=\"|href=\"|navigateTo|router\.push|navigate\(|Link " glob="*.vue,*.jsx,*.tsx,*.svelte,*.html"
# → 定義はあるがどこからもリンクされていない = orphan route
```

### P4.4: 未使用モジュール/フック
```bash
# 定義されたカスタムフック/composable
Glob "composables/use*.ts"             # Nuxt/Vue
Glob "hooks/use*.ts"                   # React
Glob "hooks/use*.tsx"                  # React
Glob "lib/use*.ts"                     # Generic
# import されているか確認
Grep "from.*composables/use|from.*hooks/use|import.*use[A-Z]" glob="*.ts,*.js,*.vue,*.jsx,*.tsx"
# → 定義はあるが import されていない = dead module
```

### P4.5: 未使用エクスポート
```bash
# export された関数/定数
Grep "export (const|function|class|enum) " glob="*.ts,*.js"
# → 同名が他ファイルで import されているか
# 注: 正確な検出は knip / ts-prune 等のツールが有効
```

---

## L5: 構造矛盾 (Structural Contradiction)

### P5.1: コメント vs 実装の乖離
```bash
# TODO / FIXME / HACK / DEPRECATED コメント
Grep "TODO|FIXME|HACK|DEPRECATED|XXX|WORKAROUND" glob="*.ts,*.js,*.py,*.go,*.rs,*.vue,*.jsx,*.tsx"
# → 古い TODO が放置されていないか (git blame で日付確認)
```

### P5.2: 設定値の散在
```bash
# 環境変数の使用箇所 (マルチフレームワーク)
Grep "process\.env\." glob="*.ts,*.js"
Grep "import\.meta\.env\." glob="*.ts,*.js,*.vue"
Grep "Deno\.env" glob="*.ts,*.js"
Grep "os\.environ|os\.getenv" glob="*.py"
Grep "os\.Getenv" glob="*.go"
Grep "std::env::var" glob="*.rs"
# 環境変数の定義箇所
Grep "^\w+=" glob=".env*"
Grep "environment:" glob="docker-compose.yml,docker-compose.yaml"
# → 使われているが未定義、または定義されているが未使用
```

### P5.3: 命名不一致
```bash
# camelCase vs snake_case 混在 (型定義内)
Grep "[a-z]+_[a-z]+" path="types/" glob="*.ts"
Grep "[a-z]+[A-Z][a-z]+" path="types/" glob="*.ts"
# → 同じスコープ内に両方の命名規則が混在
# 同一概念の複数命名
Grep "user_id|userId|user\.id" glob="*.ts,*.js"
```

### P5.4: import の循環
```bash
# 相互 import の検出 (同一ディレクトリ内)
Grep "from ['\"]\./" path="server/utils/" glob="*.ts"
Grep "from ['\"]\./" path="src/lib/" glob="*.ts"
Grep "from ['\"]\./" path="src/utils/" glob="*.ts"
# → A → B → A の循環パターン
# 注: 正確な検出は madge / dpdm 等のツールが有効
```

### P5.5: デッドコード参照
```bash
# コメントアウトされたコード (import/関数呼び出し)
Grep "//\s*import|//\s*const|//\s*function|#\s*import|#\s*def " glob="*.ts,*.js,*.py"
# → 削除すべきか復活すべきか不明なコメントアウト
```

---

## L6: リソース浪費 (Resource Waste)

### P6.1: ループ内 fetch (N+1 問題)
```bash
# ループ内の HTTP/DB 呼び出し
Grep "for.*\{" -A 10 path="server/" glob="*.ts,*.js"
# → ループ内に fetch / await / query が含まれるか
# Python
Grep "for.*:" -A 5 glob="*.py"
# → ループ内に requests.get / await / session.query が含まれるか
```

### P6.2: 巨大ペイロード
```bash
# 一覧 API がフィルタなしで全件返す
Grep "return.*\.map\(|return.*\.filter\(" path="server/" glob="*.ts,*.js"
Grep "return.*\.map\(|return.*\.filter\(" path="api/" glob="*.ts,*.js"
# → map/filter 前に limit / pagination / select がないか
Grep "limit|offset|skip|take|cursor|select\(" path="server/" glob="*.ts,*.js"
```

### P6.3: 不要な再計算 (マルチフレームワーク)
```bash
# Vue computed
Grep "computed\(\(\) =>" glob="*.vue,*.ts"
# React useMemo / useCallback 欠如
Grep "useMemo|useCallback" glob="*.jsx,*.tsx"
# → 大きなリストを毎回 .map() で再生成していないか
Grep "\.map\(.*\.map\(|\.filter\(.*\.map\(" glob="*.ts,*.js,*.vue,*.jsx,*.tsx"
```

### P6.4: 不要な再レンダリング
```bash
# React: インライン関数/オブジェクトを props として渡す
Grep "onClick=\{\(\) =>|style=\{\{" glob="*.jsx,*.tsx"
# Vue: リアクティブオブジェクトの不要な展開
Grep "toRefs\(|\.value\." glob="*.vue,*.ts"
# → レンダリング最適化の欠如
```

### P6.5: バンドルサイズ肥大化
```bash
# 巨大ライブラリの全インポート
Grep "import.*from ['\"]lodash['\"]" glob="*.ts,*.js"       # lodash 全体
Grep "import.*from ['\"]moment['\"]" glob="*.ts,*.js"        # moment (重い)
Grep "import \* as" glob="*.ts,*.js"                         # namespace import
# → lodash/get, date-fns 等の tree-shakeable 代替を使うべき
```
