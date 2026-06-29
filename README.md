# PHP + Apache サンプルアプリ

`php:8.2-apache` と MySQL を Docker Compose で動かす、フレームワークなし（素のPHP）のウェブアプリです。

## ディレクトリ構成

```text
phptest/
├── docker-compose.yml          # web(php-apache) と db(mysql) の2サービス
├── docker/
│   ├── php/
│   │   ├── Dockerfile.base      # ベースイメージ（PHP拡張/Apache設定 + src を焼き込み）
│   │   ├── Dockerfile          # アプリイメージ（ベースをFROMして public をCOPY）
│   │   └── php.ini             # PHP設定（タイムゾーン/エラー表示など）
│   └── apache/
│       └── 000-default.conf    # DocumentRoot を public/ に変更
├── public/                     # 公開ディレクトリ（DocumentRoot）
│   ├── index.php               # エントリポイント
│   ├── assets/                 # css/js/画像
│   └── .htaccess               # ルーティング/書き換え
├── src/                        # 非公開のアプリコード
│   ├── Config/database.php     # DB接続(PDO)設定
│   ├── Controllers/            # 画面/処理ごとのロジック
│   └── Views/                  # テンプレート(HTML部分)
├── db/
│   └── init/01_schema.sql      # 初回起動時に流す初期スキーマ
├── .env.example                # DB認証情報などのサンプル
├── .gitignore
└── README.md
```

## 起動方法

1. 環境変数ファイルを用意します。

```bash
cp .env.example .env
```

2. ベースイメージをビルドします（初回、または PHP拡張/設定/`src` を変更したときだけ）。

```bash
docker build -f docker/php/Dockerfile.base -t phptest-base:latest .
```

3. コンテナをビルドして起動します。

```bash
docker compose up -d --build
```

4. ブラウザで以下にアクセスします。

```text
http://localhost:8080
```

DBに接続できていれば、MySQLから取得した初期メッセージが表示されます。

## ビルド構成（2段イメージ）

変更の多い `public/` の更新を高速化するため、イメージを2段に分割しています。

- ベースイメージ（`docker/php/Dockerfile.base`）: PHP拡張・Apache設定・`php.ini`・`src/` を焼き込んだ、変化の少ない基盤。
- アプリイメージ（`docker/php/Dockerfile`）: ベースイメージを `FROM` して `public/` をCOPYするだけ。

### ベースイメージのビルド（初回 / 基盤や `src` を変えたときだけ）

```bash
docker build -f docker/php/Dockerfile.base -t phptest-base:latest .
```

### `public/` 変更時（高速。COPYレイヤーのみ再ビルド）

```bash
docker compose build web && docker compose up -d
```

> `BASE_IMAGE` のタグは `docker-compose.yml` の `web.build.args` で指定しています（既定: `phptest-base:latest`）。

## 停止 / クリーンアップ

```bash
# 停止
docker compose down

# DBのデータごと削除（初期スキーマを再投入したいとき）
docker compose down -v
```

## ポイント

- Apache の DocumentRoot を `public/` に設定し、`src/` や設定ファイルは Web から直接アクセスできないようにしています。
- DB接続情報は `.env`（Compose の environment 経由）で渡し、`src/Config/database.php` の PDO 接続で参照します。Compose 内ではDBホスト名はサービス名 `db` です。
- `db/init/*.sql` は MySQL コンテナ初回起動時に自動実行されます（データボリュームが空のときのみ）。

## CI/CD（GitHub Actions で ECR/ECS デプロイ）

ローカルの2段イメージ構成をそのまま CI に対応させ、2本のワークフローで運用します。

- `.github/workflows/build-base.yml`: **手動実行のみ**（`workflow_dispatch`）。`docker/php/Dockerfile.base` をビルドして ECR の `phptest-base` に push します。PHP拡張・Apache設定・`src/` など基盤を変えたときに実行します。
- `.github/workflows/deploy.yml`: `main` への **push 時**に実行。ECR の `phptest-base:latest` を `FROM` して `docker/php/Dockerfile`（`public/` のみ COPY）をビルドし、`phptest-app` に push 後、ECS サービスへデプロイします。デプロイは不変性のため `${GITHUB_SHA}` タグ基準で行います。

```mermaid
flowchart TD
  dev[開発者] -->|push to main| deploy[deploy.yml]
  dev -->|手動実行| base[build-base.yml]
  base -->|Dockerfile.base| ecrBase[(ECR: phptest-base)]
  deploy -->|Dockerfile + BASE_IMAGE| ecrApp[(ECR: phptest-app)]
  ecrBase -.FROM.-> deploy
  ecrApp -->|task def 更新| ecs[ECS Service]
```

### 事前準備（AWS 側）

ワークフローが必要とする AWS リソースは `terraform/` で管理します（後述の「インフラ構築（Terraform）」を参照）。`terraform apply` で以下が作成されます。

- IAM の OIDC プロバイダ（`token.actions.githubusercontent.com`）。
- このリポジトリ（`tsuchiya12345-wq/phptest`）を信頼する IAM ロール（ECR push / ECS 更新権限付き）。
- ECR リポジトリ 2つ（`phptest-base`, `phptest-app`）。
- ECS クラスター / サービス / タスク定義、ALB、タスク実行ロール、CloudWatch Logs グループ。

### GitHub に設定する Variables / Secrets

**Repository variables**（Settings → Secrets and variables → Actions → Variables）

| 名前 | 例 | 用途 |
| --- | --- | --- |
| `AWS_REGION` | `ap-northeast-1` | リージョン |
| `ECR_BASE_REPO` | `phptest-base` | ベースイメージの ECR リポジトリ名 |
| `ECR_APP_REPO` | `phptest-app` | アプリイメージの ECR リポジトリ名 |
| `ECS_CLUSTER` | `phptest-cluster` | ECS クラスター名 |
| `ECS_SERVICE` | `phptest-service` | ECS サービス名 |
| `ECS_TASK_FAMILY` | `phptest-task` | タスク定義ファミリー名 |
| `CONTAINER_NAME` | `phptest-web` | タスク定義内のコンテナ名 |

**Repository secrets**

| 名前 | 用途 |
| --- | --- |
| `AWS_ROLE_ARN` | OIDC で引き受ける IAM ロールの ARN |
| `AWS_ACCOUNT_ID` | AWS アカウントID（必要に応じて利用） |

### タスク定義テンプレート

`.aws/task-definition.json` をデプロイ時のひな形として利用します。`<AWS_ACCOUNT_ID>` / `<AWS_REGION>` のプレースホルダは実値に合わせて編集してください（実行ロール ARN は `arn:aws:iam::<AWS_ACCOUNT_ID>:role/phptest-ecs-execution-role`、`awslogs-region` は `<AWS_REGION>`）。`image` は CI が `${GITHUB_SHA}` タグへ自動で差し替えます。

## インフラ構築（Terraform）

AWS 側のリソースは `terraform/` ディレクトリで管理します。構成は「デフォルト VPC を利用、ALB で公開、DB は対象外、state はローカル」です。

### 作成されるリソース

- ECR リポジトリ: `phptest-base` / `phptest-app`
- GitHub OIDC プロバイダ ＋ デプロイ用 IAM ロール（`phptest-gha-deploy-role`）
- ECS タスク実行ロール（`phptest-ecs-execution-role`）
- ECS クラスター / サービス / 初期タスク定義（Fargate）
- ALB・ターゲットグループ・リスナー（:80）・セキュリティグループ
- CloudWatch Logs グループ（`/ecs/phptest-task`）

> ECS サービスは `lifecycle { ignore_changes = [task_definition, desired_count] }` を設定しているため、初回は仮イメージ（`bootstrap_image`）で起動し、以後の継続デプロイは GitHub Actions（`.aws/task-definition.json`）が担います。Terraform と CI が衝突しません。

### 手順

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### apply 後にやること

1. `terraform output` の値を GitHub に設定します。

```bash
terraform output github_variables      # Repository variables へ
terraform output github_actions_role_arn  # Secret: AWS_ROLE_ARN へ
terraform output aws_account_id            # Secret: AWS_ACCOUNT_ID へ
```

2. `.aws/task-definition.json` の `<AWS_ACCOUNT_ID>` / `<AWS_REGION>` を実値へ置換します。
3. GitHub Actions の `build-base.yml`（手動）→ `deploy.yml`（main push）の順で実行すると、ALB の DNS 名（`terraform output alb_dns_name`）でアプリにアクセスできます。

### 注意

- `terraform.tfstate` などの state ファイルと `.terraform/` は `.gitignore` 済みです（機密を含むためコミットしないでください）。
- OIDC プロバイダはアカウントに未作成である前提で新規作成します。既に他用途で作成済みの場合は `aws_iam_openid_connect_provider.github` を data 参照に変更してください。
