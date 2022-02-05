---
title: "ALB"
emoji: "🌟"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS"]
published: false
---
AWSでALBを使って負荷分散している状況で、片系ずつデプロイやメンテナンスを行いたい場合にAWSCLIからターゲットグループを外す方法を紹介します。

検証環境は以下の記事で解説したものを使います。

https://zenn.dev/tokku5552/articles/create-php-env-with-cfn

https://zenn.dev/tokku5552/articles/create-php-env-explanation


構成はこんな感じ
![](https://storage.googleapis.com/zenn-user-upload/f6248c2f7d89-20220130.png)

### 実行環境
- macOS Monterey バージョン12.1(Intel)

## 流れと解説
`ALB`を使って冗長化しているので、片方を`ALB`から切り離してもう片方でサービスを継続させたまま、`EC2`のメンテナンスやコードのデプロイを行う事ができます。

1. `ALB`から1台目の`EC2`を切り離す
2. 1台目の`EC2`でメンテナンスやコードのデプロイを行う
3. 1台目の`EC2`を`ALB`に再登録する
4. `ALB`から2台目の`EC2`を切り離す
5. 2台目の`EC2`でメンテナンスやコードのデプロイを行う
6. 2台目の`EC2`を`ALB`に再登録する

2台以上で冗長化している場合も、1台ずつ同じように切り離しと再登録を繰り返せば良いです。
このようなデプロイ方式を**ローリングアップデート**と呼びます。
デプロイ方式には他に**ブルーグリーンデプロイ**があり、AWSの`CodePipeline`で`CI/CD`環境を構築する場合はこちらを使用することになります。

**ローリングアップデート**ではデプロイ作業中に一時的に処理する台数が減るため、トラフィックが落ち着いている時間に実施するなど工夫する必要があります。
また、コードのデプロイにロールバック機能を持ったツール、例えば`capistrano`や`deployer`などを使用していない場合、切り戻しに時間がかかってしまいます。
対して**ブルーグリーンデプロイ**方式では同じ台数でアップデート済みの`EC2`を別に用意しておいて、両系を稼働させたままネットワーク的に瞬時に切り替えるので、
デプロイ時の負担が少なく、切り替えや切り戻しが簡単に行なえます。

https://aws.amazon.com/jp/quickstart/architecture/blue-green-deployment/

ではなぜ今回**ローリングアップデート**を採用するかというと、これを使わなければいけないような場合があるからです。例えば以下のような場合です。
- 現在稼働している`EC2`の構成が正しく管理されておらず、AMIにしてクローンした場合に正しく動作する保証がない。
- 内部のIPアドレスが変わると困る。
- `CI/CD`を組み込む際に何らかの理由により、`CodePipeline`が使えず、かつ`CI/CD`ツールからAWSのリソースを制御することができない。

上記のような制約がある場合は、`EC2`を全く新しく作成する必要があるブルーグリーンデプロイを採用することはできず、必然的にローリングアップデートを行うことになるのかなと思います。

## ALBからの切り離し&再登録手順
`ALB`から`EC2`を切り離す手順を紹介します。
AWSマネジメントコンソールからGUIで行う手順と、AWSCLIを用いてコマンドで行う方法の2つを解説します。

### AWSマネジメントコンソールからの手順
- AWSマネジメントコンソールから`EC2`の画面を開き、`ロードバランシング -> ターゲットグループ`を選択し、対象のターゲットグループの画面を開きます。
![](https://storage.googleapis.com/zenn-user-upload/86ce4f3d41ad-20220205.png)

- `Registered targets`に表示されている`EC2`インスタンスのうち、切り離したいインスタンスにチェックを入れて、`Deregister`をクリックします。
  - `Health status`が`draining`になっていれば切り離された状態です。
![](https://storage.googleapis.com/zenn-user-upload/c89d24e07dd3-20220205.png)

- 再登録する際は、同じ画面から`Register targets`をクリックします。
- 登録する`EC2`インスタンスにチェックを入れ、ポートを入力し、`Include as pending below`をクリックします。
![](https://storage.googleapis.com/zenn-user-upload/e85fe386d792-20220205.png)
- `Review targets`に`Pending`として追加されますので、確認して`Register pending targets`をクリックします。
![](https://storage.googleapis.com/zenn-user-upload/afe394bebd70-20220205.png)

- 登録直後は`Health status`が`initial`と表示されますが、しばらくして`healthy`に変われば完了です。
![](https://storage.googleapis.com/zenn-user-upload/4d49194b1796-20220205.png)

### AWSCLIを用いた手順
- `target group`のARNと`EC2`のインスタンスIDを確認しておきます。
![](https://storage.googleapis.com/zenn-user-upload/2b838da35fef-20220205.png)
- `target group`のARNと`EC2`のインスタンスIDを予め環境変数にセットしておきます。
```
export TARGET_GROUP_ARN=arn:aws:elasticloadbalancing:ap-northeast-1:294892136588:targetgroup/LaravelTargetGroup/43da03d4197425a6
export INSTANCE_ID=i-07e4b8df05bf7fca1
```

- 現在の状態を確認する
```shell:
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
表示例)
{
    "TargetHealthDescriptions": [
        {
            "Target": {
                "Id": "i-07e4b8df05bf7fca1",
                "Port": 80
            },
            "HealthCheckPort": "80",
            "TargetHealth": {
                "State": "healthy"
            }
        },
        {
            "Target": {
                "Id": "i-04b45b695f79c20fd",
                "Port": 80
            },
            "HealthCheckPort": "80",
            "TargetHealth": {
                "State": "healthy"
            }
        }
    ]
}
```

- `target group`から切り離し
```shell:
aws elbv2 deregister-targets   --target-group-arn $TARGET_GROUP_ARN --targets Id=$INSTANCE_ID
```

- もう一度状態を取得し、対象のインスタンスの`TargetHealth -> State`が`draining`になっていることを確認する。
```shell:
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
表示例)
{
    "TargetHealthDescriptions": [
        {
            "Target": {
                "Id": "i-07e4b8df05bf7fca1",
                "Port": 80
            },
            "HealthCheckPort": "80",
            "TargetHealth": {
                "State": "draining",
                "Reason": "Target.DeregistrationInProgress",
                "Description": "Target deregistration is in progress"
            }
        },
        {
            "Target": {
                "Id": "i-04b45b695f79c20fd",
                "Port": 80
            },
            "HealthCheckPort": "80",
            "TargetHealth": {
                "State": "healthy"
            }
        }
    ]
}
```

- デプロイやメンテナンス後は、再登録を行う。
```shell:
aws elbv2 register-targets --target-group-arn $TARGET_GROUP_ARN --targets Id=$INSTANCE_ID,Port=80 
```

- 状態を何度か取得し、対象のインスタンスの`TargetHealth -> State`が`initial -> healthy`に変わることを確認する。
```shell:
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
表示例)
{
    "TargetHealthDescriptions": [
        {
            "Target": {
                "Id": "i-07e4b8df05bf7fca1",
                "Port": 80
            },
            "HealthCheckPort": "80",
            "TargetHealth": {
                "State": "initial",
                "Reason": "Elb.RegistrationInProgress",
                "Description": "Target registration is in progress"
            }
        },
        {
            "Target": {
                "Id": "i-04b45b695f79c20fd",
                "Port": 80
            },
            "HealthCheckPort": "80",
            "TargetHealth": {
                "State": "healthy"
            }
        }
    ]
}
```

# まとめ
ローリングアップデートを行う際の、GUIでのALBからの切り離し方法とAWSCLIでの切り離し方法を解説しました。
個人的にはコマンドで行って手順化しておいたほうが、ミスも少なくなって良いかなと思います。
次はこのコマンドを使って`CI/CD`への組み込みを検証したいと思います。

### 参考
- [CloudFormationとAnsibleでALB+EC2+RDSのLaravel環境を構築する(解説編)](https://zenn.dev/tokku5552/articles/create-php-env-explanation)
- [CloudFormationとAnsibleでALB+EC2+RDSのLaravel環境を構築する(手順編)](https://zenn.dev/tokku5552/articles/create-php-env-with-cfn)
- [ターゲットグループへのターゲットの登録 - Elastic Load Balancing](https://docs.aws.amazon.com/ja_jp/elasticloadbalancing/latest/application/target-group-register-targets.html)