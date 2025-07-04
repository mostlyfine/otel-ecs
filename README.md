# OpenTelemetry Observability Stack on AWS ECS

本プロジェクトは、AWS ECS上でOpenTelemetryを使用した包括的な可観測性スタックを構築するためのTerraformコードです。

## アーキテクチャ

このスタックには以下のコンポーネントが含まれます：

- **Grafana**: メトリクス、ログ、トレースの可視化
- **Mimir**: Prometheusメトリクスの長期保存
- **Loki**: ログの集約と検索
- **Tempo**: 分散トレーシングバックエンド
- **OpenTelemetry Collector**: テレメトリデータの収集と処理

## インフラストラクチャ

### ネットワーク
- 3つのAvailability Zone (ap-northeast-1a, 1c, 1d) にわたるVPC
- パブリックサブネットとプライベートサブネット
- インターネットアクセス用のNATゲートウェイ

### コンピューティング
- AWS Fargate上で実行されるECSクラスター
- 各サービス用の個別のECSサービス

### ストレージ
- Mimir、Loki、Tempo用のS3バケット
- ライフサイクルポリシーによる自動データ管理

### ロードバランシング
- Grafanaへのパブリックアクセス用のApplication Load Balancer
- 内部サービス通信用の内部Application Load Balancer

## デプロイ手順

### 前提条件

1. AWS CLIの設定
2. Terraformのインストール (>= 1.0)
3. 適切なAWS権限の設定

### 環境変数の設定

```bash
export AWS_REGION=ap-northeast-1
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
```

### デプロイ

1. リポジトリのクローン:
```bash
git clone <repository-url>
cd otel-ecs
```

2. Terraformの初期化:
```bash
cd terraform
terraform init
```

3. 設定の確認:
```bash
terraform plan
```

4. インフラストラクチャのデプロイ:
```bash
terraform apply
```

### アクセス

デプロイ完了後、Grafanaには以下のURLでアクセスできます：
- URL: `http://<alb-dns-name>`
- 初期ログイン: admin / 環境変数で設定したパスワード

## 設定

### 変数

主要な設定可能変数：

- `vpc_cidr`: VPCのCIDRブロック (デフォルト: 10.2.0.0/16)
- `environment`: 環境名 (デフォルト: development)
- `grafana_admin_password`: Grafanaの管理者パスワード

### S3バケット

各サービスのデータ保持期間：
- **Tempo**: 30日 (トレースデータ)
- **Loki**: 90日 (ログデータ)
- **Mimir**: 365日 (メトリクスデータ)

## セキュリティ

### ネットワークセキュリティ
- プライベートサブネット内でのサービス実行
- セキュリティグループによる最小権限アクセス
- 内部通信用の専用ロードバランサー

### IAMセキュリティ
- サービス固有のIAMロール
- S3バケットへの最小権限アクセス
- CloudWatchログへの書き込み権限

## モニタリング

### メトリクス
- MimirでPrometheusメトリクスを保存
- GrafanaでMetricsダッシュボードを提供

### ログ
- Lokiでアプリケーションログを集約
- GrafanaでLogダッシュボードを提供

### トレース
- Tempoで分散トレーシングデータを保存
- GrafanaでTraceダッシュボードを提供

## トラブルシューティング

### よくある問題

1. **ECSサービスが起動しない**
   - CloudWatchログを確認
   - セキュリティグループの設定を確認
   - IAM権限を確認

2. **S3アクセスエラー**
   - IAMポリシーを確認
   - S3バケットポリシーを確認

3. **ネットワーク接続エラー**
   - セキュリティグループのルールを確認
   - サブネットルーティングを確認

### ログの確認

```bash
# ECSサービスのログを確認
aws logs describe-log-groups --log-group-name-prefix "/aws/ecs/otel-ecs"
aws logs get-log-events --log-group-name "/aws/ecs/otel-ecs" --log-stream-name <stream-name>
```

## メンテナンス

### アップデート
- コンテナイメージのバージョン更新はlocals.tfで設定
- terraform apply で新しいバージョンをデプロイ

### バックアップ
- S3バケットはバージョニングが有効
- 重要なデータは定期的にバックアップを推奨

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。
