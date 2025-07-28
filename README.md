# AWS教育コンテンツ - CloudFormation IaC設計書

## アーキテクチャ概要

本設計は教育目的のAWSインフラストラクチャを構築するためのCloudFormation IaCです。

### システム構成
- **APサーバー**: Windows Server 2022 + IIS (パブリックサブネット)
- **DBサーバー**: Amazon Linux 2023 (プライベートサブネット)
- **NATゲートウェイ**: プライベートサブネットからのインターネットアウトバウンド通信用

## スタック分割方針

| スタック名 | 含まれるリソース | 理由・目的 |
|------------|------------------|------------|
| **network-stack** | • VPC<br>• パブリックサブネット<br>• プライベートサブネット<br>• インターネットゲートウェイ<br>• NATゲートウェイ<br>• Elastic IP（NAT用）<br>• ルートテーブル（パブリック・プライベート） | • ネットワーク基盤の独立管理<br>• 他のスタックから参照可能<br>• 再利用性の向上<br>• プライベートサブネットのアウトバウンド通信確保 |
| **security-stack** | • APサーバー用セキュリティグループ<br>• DBサーバー用セキュリティグループ<br>• IAMロール・ポリシー<br>• キーペア | • セキュリティ設定の一元管理<br>• セキュリティ要件の明確化<br>• 監査しやすい構造 |
| **ap-server-stack** | • EC2インスタンス（Windows2022）<br>• EBSボリューム（Cドライブ30GB、Dドライブ50GB）<br>• UserDataスクリプト（IIS設定、index.html配置）<br>• Elastic IP（APサーバー用） | • APサーバーの独立したライフサイクル管理<br>• スケールアウト時の対応容易<br>• 設定変更の影響範囲限定 |
| **db-server-stack** | • EC2インスタンス（Amazon Linux2023）<br>• EBSボリューム（1TB）<br>• UserDataスクリプト（DB初期設定） | • DBサーバーの独立したライフサイクル管理<br>• データ保護の観点から分離<br>• バックアップ戦略の独立実装 |

## 各スタック詳細設計

### network-stack

| リソースタイプ | リソース名 | 設定内容 |
|----------------|------------|----------|
| AWS::EC2::VPC | MainVPC | CIDR: 10.0.0.0/16 |
| AWS::EC2::Subnet | PublicSubnet | CIDR: 10.0.1.0/24, AZ: ap-northeast-1a |
| AWS::EC2::Subnet | PrivateSubnet | CIDR: 10.0.2.0/24, AZ: ap-northeast-1a |
| AWS::EC2::InternetGateway | MainIGW | VPCにアタッチ |
| AWS::EC2::EIP | NATGatewayEIP | NATゲートウェイ用固定IPアドレス |
| AWS::EC2::NatGateway | MainNATGateway | パブリックサブネットに配置、NATGatewayEIPを関連付け |
| AWS::EC2::RouteTable | PublicRouteTable | パブリックサブネット用 |
| AWS::EC2::RouteTable | PrivateRouteTable | プライベートサブネット用 |
| AWS::EC2::Route | PublicRoute | 0.0.0.0/0 → IGW |
| AWS::EC2::Route | PrivateRoute | 0.0.0.0/0 → NATGateway |
| AWS::EC2::SubnetRouteTableAssociation | PublicSubnetAssociation | パブリックサブネット関連付け |
| AWS::EC2::SubnetRouteTableAssociation | PrivateSubnetAssociation | プライベートサブネット関連付け |

### security-stack

| リソースタイプ | リソース名 | 設定内容 |
|----------------|------------|----------|
| AWS::EC2::SecurityGroup | APServerSecurityGroup | インバウンド: HTTP(80), HTTPS(443), RDP(3389)<br>アウトバウンド: すべて許可 |
| AWS::EC2::SecurityGroup | DBServerSecurityGroup | インバウンド: MySQL(3306), SSH(22) APサーバーからのみ<br>アウトバウンド: HTTP(80), HTTPS(443) NATゲートウェイ経由 |
| AWS::IAM::Role | EC2Role | EC2基本権限 |
| AWS::IAM::InstanceProfile | EC2InstanceProfile | EC2Roleを関連付け |
| AWS::EC2::KeyPair | MainKeyPair | SSH/RDP接続用キーペア |

### ap-server-stack

| リソースタイプ | リソース名 | 設定内容 |
|----------------|------------|----------|
| AWS::EC2::Instance | APServer | AMI: Windows Server 2022, インスタンスタイプ: t3.medium |
| AWS::EC2::Volume | CVolume | サイズ: 30GB, タイプ: gp3 |
| AWS::EC2::Volume | DVolume | サイズ: 50GB, タイプ: gp3 |
| AWS::EC2::VolumeAttachment | CVolumeAttachment | CボリュームをEC2にアタッチ |
| AWS::EC2::VolumeAttachment | DVolumeAttachment | DボリュームをEC2にアタッチ |
| AWS::EC2::EIP | APServerEIP | 固定IPアドレス |
| AWS::EC2::EIPAssociation | APServerEIPAssociation | EIPをEC2に関連付け |

### db-server-stack

| リソースタイプ | リソース名 | 設定内容 |
|----------------|------------|----------|
| AWS::EC2::Instance | DBServer | AMI: Amazon Linux 2023, インスタンスタイプ: t3.medium |
| AWS::EC2::Volume | DBVolume | サイズ: 1TB(1024GB), タイプ: gp3 |
| AWS::EC2::VolumeAttachment | DBVolumeAttachment | DBボリュームをEC2にアタッチ |

## ネットワークフロー図

```
インターネット
    ↓
インターネットゲートウェイ
    ↓
パブリックサブネット (10.0.1.0/24)
    ├── APサーバー (双方向通信)
    └── NATゲートウェイ
            ↓
プライベートサブネット (10.0.2.0/24)
    └── DBサーバー (アウトバウンドのみ)
```

## スタック依存関係

| スタック | 依存するスタック | 参照するExports |
|----------|------------------|-----------------|
| security-stack | network-stack | VPC ID |
| ap-server-stack | network-stack, security-stack | パブリックサブネットID, APサーバーSG ID |
| db-server-stack | network-stack, security-stack | プライベートサブネットID, DBサーバーSG ID |

## UserData設定内容

| サーバー | UserData処理内容 |
|----------|------------------|
| APServer | • IISインストール・有効化<br>• index.htmlファイル作成・配置<br>• Dドライブのフォーマット・マウント<br>• Windows Updateの実行 |
| DBServer | • システム更新（yum update）<br>• 1TBボリュームのフォーマット・マウント<br>• MySQL/MariaDBインストール（オプション）<br>• パッケージの最新化 |

## デプロイ順序

1. **network-stack** - ネットワーク基盤の構築（VPC、サブネット、IGW、NATゲートウェイ）
2. **security-stack** - セキュリティ設定の構築
3. **ap-server-stack** - APサーバーの構築
4. **db-server-stack** - DBサーバーの構築

## 分割のメリット

- **独立したデプロイ**: 各コンポーネントを個別に更新可能
- **再利用性**: ネットワークスタックは他の環境でも利用可能
- **障害影響の局所化**: 一つのスタックの問題が他に波及しない
- **権限管理**: スタック単位でのアクセス制御が可能
- **教育効果**: 各レイヤーの役割が明確になり学習しやすい
- **セキュアなアウトバウンド通信**: プライベートサブネットからの安全なインターネットアクセス

## コスト考慮事項

- **NATゲートウェイ料金**: 時間料金 + データ処理料金が発生
- **Elastic IP料金**: NATゲートウェイ用のEIPは使用中のため課金なし
- **データ転送料金**: NATゲートウェイ経由のアウトバウンドトラフィックに課金

## 注意事項

- プライベートサブネットは専用のルートテーブルを使用してNATゲートウェイ経由でアウトバウンド通信
- NATゲートウェイによりプライベートサブネットからのインターネットアクセスが可能
- セキュリティグループでアウトバウンド通信を適切に制限
- 教育目的のため、基本的なセキュリティ設定で構成