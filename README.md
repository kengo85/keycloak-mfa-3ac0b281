# Keycloak MFA Server

OTP（TOTP）によるMFA（多要素認証）を必須化したKeycloakサーバーのセットアップです。

---

## 必要環境

- Docker 20.10 以上
- Docker Compose（オプション）

---

## クイックスタート

### 1. イメージのビルド

```bash
docker build -t keycloak-mfa .
```

### 2. コンテナの起動

```bash
docker run -d \
  --name keycloak-mfa \
  -p 80:80 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin1234 \
  keycloak-mfa
```

### 3. 起動確認

ブラウザで以下のURLにアクセスしてください。

```
http://localhost/
```

起動完了まで約30〜60秒かかる場合があります。

---

## Docker Compose を使う場合

```yaml
version: "3.9"
services:
  keycloak:
    build: .
    container_name: keycloak-mfa
    ports:
      - "80:80"
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin1234
    restart: unless-stopped
```

```bash
docker compose up -d
```

---

## 初期管理者アカウント

| 項目 | 値 |
|------|-----|
| 管理コンソールURL | http://localhost/admin |
| ユーザー名 | `admin` |
| パスワード | `admin1234` |

> ⚠️ 本番環境では必ず `KEYCLOAK_ADMIN_PASSWORD` を強力なパスワードに変更してください。

---

## レルム設定

### インポートされるレルム

コンテナ起動時に `realm-export.json` が自動的にインポートされ、以下の設定が適用されます。

| 項目 | 値 |
|------|-----|
| レルム名 | `mfa-realm` |
| MFA方式 | OTP（TOTP） |
| MFA適用 | **全ユーザーに必須** |
| OTPアルゴリズム | HmacSHA1 |
| OTP桁数 | 6桁 |
| OTP有効期間 | 30秒 |

### 初期テストユーザー

| 項目 | 値 |
|------|-----|
| ユーザー名 | `testuser` |
| パスワード | `testuser1234` |
| メールアドレス | `testuser@example.com` |
| MFA | 初回ログイン時にOTP設定が必須 |

---

## MFA（TOTP）のログインフロー

1. `http://localhost/realms/mfa-realm/account` にアクセス
2. ユーザー名・パスワードを入力してログイン
3. **初回ログイン時** はOTPアプリの設定画面が表示される
4. 以下のいずれかのOTPアプリでQRコードをスキャン
   - [Google Authenticator](https://support.google.com/accounts/answer/1066447)
   - [Authy](https://authy.com/)
   - [Microsoft Authenticator](https://www.microsoft.com/ja-jp/security/mobile-authenticator-app)
5. アプリに表示された6桁のワンタイムパスワードを入力
6. 次回ログイン以降はパスワード＋OTPコードの2段階認証が必要

---

## クライアント設定

インポートされるOIDCクライアントの情報です。

| 項目 | 値 |
|------|-----|
| クライアントID | `mfa-client` |
| クライアントタイプ | OpenID Connect (Public) |
| 有効なリダイレクトURI | `http://localhost/*` |
| Webオリジン | `http://localhost` |

### 認証エンドポイント

```
# OpenID Connect Discovery
http://localhost/realms/mfa-realm/.well-known/openid-configuration

# 認可エンドポイント
http://localhost/realms/mfa-realm/protocol/openid-connect/auth

# トークンエンドポイント
http://localhost/realms/mfa-realm/protocol/openid-connect/token

# ユーザー情報エンドポイント
http://localhost/realms/mfa-realm/protocol/openid-connect/userinfo
```

---

## 管理コンソールでの追加設定

### 新しいユーザーの追加

1. `http://localhost/admin` にログイン
2. 左メニューで `mfa-realm` レルムを選択
3. **Users** → **Add user** をクリック
4. ユーザー情報を入力して **Create**
5. **Credentials** タブでパスワードを設定

新規ユーザーは初回ログイン時にTOTPの設定を求められます。

### MFA設定の確認・変更

1. 管理コンソールで `mfa-realm` を選択
2. **Authentication** → **Flows** → `browser` フローを確認
3. **OTP Form** が `Required` になっていることを確認

### MFAを任意（Optional）に変更する場合

1. **Authentication** → **Flows** → `browser` を選択
2. **Browser - Conditional OTP** → **Conditional OTP** の条件を `Optional` に変更

---

## ログの確認

```bash
# コンテナログをリアルタイムで確認
docker logs -f keycloak-mfa

# 起動完了の確認（以下のメッセージが出れば完了）
# Keycloak 2x.x.x on JVM (powered by Quarkus ...) started in ...
```

---

## コンテナの停止・削除

```bash
# 停止
docker stop keycloak-mfa

# 停止＆削除
docker rm -f keycloak-mfa

# イメージも削除する場合
docker rmi keycloak-mfa
```

---

## セキュリティに関する注意事項

> ⚠️ このセットアップは **開発・検証用途** を想定しています。

本番環境で利用する場合は以下の点を必ず対応してください。

- [ ] `start-dev` モードではなく `start` モード（本番モード）を使用する
- [ ] HTTPS（TLS/SSL）を設定する
- [ ] 管理者パスワードを強力なものに変更する
- [ ] テストユーザーを削除または無効化する
- [ ] データベースを外部の永続化ストレージ（PostgreSQL等）に切り替える
- [ ] ファイアウォールで管理コンソールへのアクセスを制限する

---

## トラブルシューティング

### コンテナが起動しない

```bash
docker logs keycloak-mfa
```

ログを確認してエラーの詳細を把握してください。

### ポート80が使用中

ホスト側のポートを変更して起動してください。

```bash
docker run -d -p 8080:80 --name keycloak-mfa keycloak-mfa
# → http://localhost:8080/ でアクセス
```

### レルムがインポートされていない

コンテナを再作成してください。

```bash
docker rm -f keycloak-mfa
docker run -d -p 80:80 --name keycloak-mfa keycloak-mfa
```

### OTPコードが認証されない

- スマートフォンの時刻が正確であることを確認してください
- OTPアプリとサーバーの時刻差が30秒以上あると認証に失敗します
- デバイスの時刻を自動同期（NTP）に設定してください

---

## ライセンス

このプロジェクトはMITライセンスのもとで公開されています。  
Keycloak本体は [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) に従います。