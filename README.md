# Keycloak MFA Server

OTP（TOTP）によるMFA（多要素認証）を必須化した、外部から利用される**第三者OIDC IDプロバイダ**としてのKeycloakサーバーです。

将来的にSalesforce B2C Commerce SLASなど任意のOIDC対応リライング・パーティ（RP）から「外部IDプロバイダ」として登録し、MFA必須のログインを委譲する用途を想定しています。ただし本リポジトリ自体はSLAS固有の設定を含みません。SLAS側との連携（IDP登録・redirect URI確定など）は別途行ってください。

---

## 構成

| ファイル | 役割 |
|---|---|
| `Dockerfile` | マルチステージビルド。`kc.sh build`で最適化イメージを事前生成 |
| `docker-entrypoint.sh` | `KC_MODE`に応じて`start`（本番）/`start-dev`（開発）を切り替え、本番モードでは必須環境変数を検証 |
| `docker-compose.yml` | PostgreSQL + Keycloakのステージング/本番相当構成 |
| `realm-export.json` | `mfa-realm`のレルム定義。TOTP MFA必須のブラウザフローを含む |
| `.env.example` | 必要な環境変数のテンプレート |

Keycloakバージョン: `26.7.0`（2026年7月時点の最新安定版）。

---

## 必要環境

- Docker 24以上 / Docker Compose v2
- 本番投入時: 実ドメイン + TLS証明書（Keycloak自身で終端するか、前段のロードバランサ/リバースプロキシで終端）

---

## クイックスタート（開発モード）

TLSやDBの準備なしに、まず動作だけ確認したい場合:

```bash
docker build -t keycloak-mfa .
docker run -d --name keycloak-mfa -p 8080:8080 \
  -e KC_MODE=dev \
  keycloak-mfa
```

```
http://localhost:8080/
http://localhost:8080/admin   # 初回起動時にランダムな一時管理者アカウントが発行され、ログ(docker logs)に出力されます
```

開発モードはメモリ内DBで再起動すると全データが消えます。**本番・検証共有環境では使わないでください。**

---

## 本番構成での起動（Docker Compose）

### 1. 環境変数を用意

```bash
cp .env.example .env
# .env を編集して KC_HOSTNAME / KC_DB_PASSWORD / KC_BOOTSTRAP_ADMIN_USERNAME / KC_BOOTSTRAP_ADMIN_PASSWORD を実値に変更
```

### 2. 起動

```bash
docker compose up -d --build
```

PostgreSQLへのデータ永続化、ブートストラップ管理者アカウントの作成、レルムインポートが自動的に行われます。

### 3. TLS終端はCoolifyのTraefikに任せる

`docker-compose.yml`の`keycloak`サービスは**ホストへポートを公開しません**（`ports`セクションなし）。デプロイ先はCoolifyを想定しており、CoolifyのTraefikがCoolify管理下のDockerネットワーク経由でコンテナの8080番（`Dockerfile`の`EXPOSE 8080`）に直接到達し、TLS終端・ルーティングを行います。

- Coolify側のアプリ設定で公開ポートとして`8080`を指定し、`KC_HOSTNAME`と同じドメインをTraefikのルーティング先として設定してください
- `KC_PROXY_HEADERS=xforwarded`のままにしておけば、Traefikが付与する`X-Forwarded-*`ヘッダーをKeycloakが信頼します
- 管理ポート（9000、health/metrics）もホストには公開されません。コンテナのヘルス状態は`Dockerfile`に組み込み済みのDocker `HEALTHCHECK`がコンテナ内部から9000番を叩いて判定します（`docker ps`の`STATUS`列やCoolifyのヘルスチェック表示で確認できます）。TraefikやCoolifyから9000番へ到達させる設定は不要です

> ⚠️ ポートを公開しないため、この`docker-compose.yml`単体を素の`docker compose up`でローカル実行してもホストマシンからは到達できません。ローカルで素早く動作確認したい場合は上記の「クイックスタート（開発モード）」（`docker run -p 8080:8080 -e KC_MODE=dev`）を使ってください。

> ⚠️ 万一Coolify/Traefikを介さず直接インターネットに公開する構成に変える場合は、`KC_PROXY_HEADERS=xforwarded`のままだとクライアントが`X-Forwarded-*`ヘッダーを偽装できてしまいます。その際は必ずヘッダーを上書きするリバースプロキシを前段に置くか、この設定を見直してください。

---

## 必須環境変数（本番モード / `KC_MODE=prod`、デフォルト）

| 変数 | 説明 |
|---|---|
| `KC_HOSTNAME` | 公開URL（例: `https://mfa.example.com`）。HTTPS必須 |
| `KC_DB_URL` | 例: `jdbc:postgresql://postgres:5432/keycloak` |
| `KC_DB_USERNAME` / `KC_DB_PASSWORD` | DB接続情報 |
| `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` | 初回起動時のみ使用されるブートストラップ管理者。起動後は管理コンソールから個別の管理者アカウントを作成し、このアカウントは無効化/削除することを推奨 |

いずれか未設定の場合、コンテナは起動時にエラーで終了します（`docker-entrypoint.sh`が検証）。

`KC_MODE=dev`を指定した場合はこれらの変数は不要です（開発用途のみ）。

---

## レルム設定

コンテナ起動時に`realm-export.json`が自動インポートされます。

| 項目 | 値 |
|---|---|
| レルム名 | `mfa-realm` |
| MFA方式 | OTP（TOTP、RFC 6238） |
| MFA適用 | ブラウザログインする全ユーザーに必須（`browser-with-otp`フロー） |
| OTPアルゴリズム / 桁数 / 有効期間 | HmacSHA1 / 6桁 / 30秒（Google Authenticator等主要アプリと互換） |
| ユーザー登録 | 無効（管理コンソールから個別に払い出す運用を想定） |
| ブルートフォース対策 | 有効（5回失敗でロック） |

### 登録済みクライアント

| clientId | 用途 |
|---|---|
| `external-rp` | 外部RP（SLAS等）が将来利用する confidential クライアント。**secretは未設定のままインポートされ、Keycloakが自動生成します**（リポジトリに秘密情報を残さないため）。redirect URIはプレースホルダ`https://CHANGE-ME.invalid/*`が入っているため、実際の連携先が決まり次第、管理コンソールの Clients → `external-rp` → Settings で更新してください |
| `account` / `account-console` / `security-admin-console` / `admin-cli` / `broker` | Keycloak標準の組み込みクライアント |

`external-rp`のシークレットは、管理コンソール（Clients → `external-rp` → Credentials）または Admin REST API から取得・ローテーションしてください。

> ⚠️ 本レルムではResource Owner Password Credentials（直接グラント）を全クライアントで無効化しています。TOTP未設定ユーザーが直接グラントでログインしようとすると、非対話的にQRコードを提示できないためKeycloakが500エラーを返す実装上の穴があるためです。ログインは必ずブラウザの認可コードフロー（`browser-with-otp`）経由にしてください。

---

## MFA（TOTP）のログインフロー

1. 管理コンソールでユーザーを作成（Users → Add user → Credentials でパスワード設定）
2. ユーザーが`https://<KC_HOSTNAME>/realms/mfa-realm/account`または`external-rp`経由のOIDC認可コードフローでログイン
3. 初回ログイン時、OTPアプリ（Google Authenticator / Microsoft Authenticator / Authy等）のQRコード設定画面が表示される
4. 以後は パスワード＋OTPコードの2段階認証が必須

---

## エンドポイント

```
# OpenID Connect Discovery（外部RPの登録時に使用）
https://<KC_HOSTNAME>/realms/mfa-realm/.well-known/openid-configuration

# 認可 / トークン / ユーザー情報
https://<KC_HOSTNAME>/realms/mfa-realm/protocol/openid-connect/auth
https://<KC_HOSTNAME>/realms/mfa-realm/protocol/openid-connect/token
https://<KC_HOSTNAME>/realms/mfa-realm/protocol/openid-connect/userinfo

# ヘルスチェック / メトリクス（管理ポート 9000、外部公開しないこと）
http://<内部アドレス>:9000/health/ready
http://<内部アドレス>:9000/health/live
http://<内部アドレス>:9000/metrics
```

管理ポート（9000）はロードバランサやオーケストレータのヘルスチェック専用に内部ネットワークのみへ公開し、インターネットには晒さないでください。

---

## 本番投入前チェックリスト

- [x] `start`（本番モード）を使用（`KC_MODE`未指定時のデフォルト）
- [x] 外部PostgreSQLへの永続化（`docker-compose.yml`）
- [x] ホストへのポート公開なし（`keycloak`サービスに`ports`セクションを持たない。CoolifyのTraefikが内部Dockerネットワーク経由で8080番へ到達する構成）
- [ ] CoolifyのアプリでTraefikの公開ポートを`8080`に設定し、`KC_HOSTNAME`と同じドメインをルーティング先にする
- [ ] `KC_HOSTNAME`を実ドメインに設定する
- [ ] ブートストラップ管理者を無効化し、個別の管理者アカウントに切り替える
- [ ] `external-rp`クライアントのredirect URI / secretを実際の連携先に合わせて更新する
- [ ] PostgreSQLのバックアップ・DR方針を決める
- [ ] SMTPサーバーを設定する（パスワードリセットメール等に必要。現状`smtpServer`は空）

---

## トラブルシューティング

### コンテナが起動しない

```bash
docker compose logs -f keycloak
```

`KC_MODE=prod`（デフォルト）で必須環境変数が未設定だとエラーメッセージと共に即終了します。

### OTPコードが認証されない

- スマートフォンの時刻が自動同期（NTP）になっているか確認してください
- OTPアプリとサーバーの時刻差が30秒以上あると認証に失敗します

---

## ライセンス

このプロジェクトはMITライセンスのもとで公開されています。
Keycloak本体は [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) に従います。
