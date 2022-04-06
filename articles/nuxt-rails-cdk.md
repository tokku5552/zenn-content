---
title: "【Nuxt x Rails】サンプルTODOアプリ - AWSCDK編"
emoji: "⛳"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: true
---
今回検証目的でフロントにNuxt、バックエンドにRails、インフラにAWSを使って以下のようなTODOアプリを作りました。
![](https://storage.googleapis.com/zenn-user-upload/cbc16aa9e5c1-20220405.png)
この記事ではAWS CDKに関する解説を行います🙋‍♂️
- 以下の記事で全体の解説を行っています。

https://zenn.dev/tokku5552/articles/nuxt-rails-sample

- 全ソースコードはこちら

https://github.com/tokku5552/nuxt-rails-sample

# 環境
AWS CDKは2系を使用しています。
- package.json
```json:
"devDependencies": {
    "@types/jest": "^26.0.10",
    "@types/node": "10.17.27",
    "aws-cdk": "2.17.0",
    "jest": "^26.4.2",
    "ts-jest": "^26.2.0",
    "ts-node": "^9.0.0",
    "typescript": "~3.9.7"
  },
  "dependencies": {
    "aws-cdk-lib": "2.17.0",
    "constructs": "^10.0.0",
    "dotenv": "^16.0.0",
    "source-map-support": "^0.5.16"
  }
```

- インフラ構成図

![](https://storage.googleapis.com/zenn-user-upload/f1ae25c170be-20220403.png)

# AWS CDK
## bind/cdk.ts

AWS CDKを実行する際のエントリポイントとなるコードです。
こちらで各種環境変数を読み込んで、Rails側とNuxt側のスタックを作成しています。

```ts:cdk/bin/cdk.ts
#!/usr/bin/env node
import * as dotenv from 'dotenv';
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { RailsSampleStack } from '../lib/rails-sample-stack';
import { NuxtSampleStack } from '../lib/nuxt-sample-stack';

dotenv.config()

export interface RailsProps extends cdk.StackProps {
    certificateArn: string,
    hostedZoneId: string,
    zoneName: string,
    keyName: string
}

const app = new cdk.App();
const railsProps: RailsProps = {
    certificateArn: process.env.CERTIFICATE_ARN || 'null',
    hostedZoneId: process.env.HOSTED_ZONE_ID || 'null',
    zoneName: process.env.ZONE_NAME || 'null',
    keyName: process.env.KEY_NAME || 'null'
}
new RailsSampleStack(app, 'RailsSampleStack', railsProps);
new NuxtSampleStack(app, 'NuxtSampleStack', {})
```
`dotenv`を使用して、`cdk/.env`を読み込んでいます。
以下がサンプルです。
```ini:
HOSTED_ZONE_ID=
ZONE_NAME=
CERTIFICATE_ARN=
KEY_NAME=
```
これらはCDKでの構築対象ではなく、事前に準備が必要な項目となります。
- `HOSTED_ZONE_ID`
  - 取得済みの`Route 53`のホストゾーンのIDを記載します。
- `ZONE_NAME`
  - 取得済みの`Route 53`のホストゾーン名を記載します。
- `CERTIFICATE_ARN`
  - 取得済みの証明書のARNを記載します。
- `KEY_NAME`
  - `EC2`に設定する認証用の鍵の名前を指定します。こちらもすでにAWS上に登録されているものを指定する想定です。

## lib/nuxt-sample-stack.ts
Nuxt側のスタックです。
NuxtのコードをデプロイするS3バケットの用意と、それをオリジンにしたCloudFrontを作成します。
CloudFrontの`defaultRootObject`はCDK上は任意の設定項目ですが、入れてやらないとうまく動作しませんでした。
```ts:cdk/lib/nuxt-sample-stack.ts
import { Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';

export class NuxtSampleStack extends Stack {
    constructor(scope: Construct, id: string, props?: StackProps) {
        super(scope, id, props);

        // S3
        const bucket = new s3.Bucket(this, 'NuxtS3Bucket', {
            bucketName: 'nuxt.s3bucket'
        })

        new cloudfront.Distribution(this, 'NuxtDistribution', {
            defaultBehavior: {
                origin: new origins.S3Origin(bucket)
            },
            defaultRootObject: 'index.html'
        })
    }
}
```
お好みでCloudFront側のポリシーなんかを追加するとより実用的かなと思います。
ただ今回はCI/CDでのデプロイ時にキャッシュを毎回削除しているので、ポリシーは追加しませんでした。

## lib/rails-sample-stack.ts
Backend側である`ALB -> EC2 -> RDS`部分のスタックです。
SAMと違ってこれらがTypeScriptで構築できるのはCDKの強みですね。
長いので、コード上にコメントで解説を入れています。
```ts:cdk/lib/rails-sample-stack.ts
import { Stack, StackProps, SecretValue } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import { InstanceTarget } from 'aws-cdk-lib/aws-elasticloadbalancingv2-targets';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as acm from 'aws-cdk-lib/aws-certificatemanager';
import * as route53 from 'aws-cdk-lib/aws-route53'
import { LoadBalancerTarget } from 'aws-cdk-lib/aws-route53-targets'
import { RailsProps } from '../bin/cdk'

export class RailsSampleStack extends Stack {
  // propsはStackPropsを拡張したものを受け取っています。
  constructor(scope: Construct, id: string, props: RailsProps) { 
    super(scope, id, props);

    // create VPC
    const vpc = new ec2.Vpc(this, 'RailsVPC', {
      cidr: '10.0.0.0/21',
      subnetConfiguration: [
      // public側のサブネット
      {
        subnetType: ec2.SubnetType.PUBLIC,
        name: 'Ingress',
        cidrMask: 24
      },
      // private側のサブネット
      {
        cidrMask: 24,
        name: 'Database',
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      }],
      // 上記のように指定してやると、VPCの中で使えるcidrから勝手にサブネットを分割してくれます。
    });

    // EC2用のセキュリティグループ
    const securityGroupforEC2 = new ec2.SecurityGroup(this, 'SecurityGroupforEC2', {
      vpc,
      description: 'Allow HTTP ingress',
      allowAllOutbound: true,
    })

    // TCP:80のみ許可します。
    securityGroupforEC2.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(80),
      "Allow HTTP Access"
    )

    // IAM role for SSM Agent
    // SessionManager経由でSSHを行いたいため、Roleを付与しておきます。
    const role = new iam.Role(this, "ec2Role", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
    });
    role.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonSSMManagedInstanceCore")
    );

    // create EC2 Instance
    // これまでで定義したリソースを渡しながらEC2のインスタンスを作成します。
    const instance = new ec2.Instance(this, 'RailsInstance', {
      vpc,
      instanceName: 'RailsInstance',
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T2, ec2.InstanceSize.MICRO),
      machineImage: new ec2.AmazonLinuxImage({
        generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2
      }),
      vpcSubnets: {
        subnetType: ec2.SubnetType.PUBLIC,
      },
      securityGroup: securityGroupforEC2,
      keyName: props.keyName,
      role: role,
    })

    // create ALB
    // EC2を作ってからALBを作成します。(でないとtargetに追加できない)
    const lb = new elbv2.ApplicationLoadBalancer(this, 'LB', {
      vpc,
      internetFacing: true,
      securityGroup: securityGroupforEC2,
      loadBalancerName: 'RailsLB'
    })

    // ALBではTCP:443で待ち受けておきます。
    const listener = lb.addListener('Listener', {
      port: 443,
      open: true
    })

    // 環境変数で指定したARNをもとに証明書を取得してALBのリスナーに追加します。
    const cert = acm.Certificate.fromCertificateArn(this, 'CertificateFromArn', props.certificateArn);
    listener.addCertificates('RailsListenerCertificate', [cert])

    // EC2をターゲットに追加してALBは完了
    listener.addTargets('ApplicationFleet', {
      port: 80,
      targets: [new InstanceTarget(instance, 80)]
    })

    // add Route 53 Record
    // 証明書がドメインに紐付いているので、取得済みのドメインを管理しているホストゾーンにレコードを追加しています。
    const hostZone = route53.HostedZone.fromHostedZoneAttributes(this, 'HostedZoneAttributes', {
      hostedZoneId: props.hostedZoneId,
      zoneName: props.zoneName
    })

    new route53.ARecord(this, 'ARecord', {
      zone: hostZone,
      target: route53.RecordTarget.fromAlias(new LoadBalancerTarget(lb)),
      recordName: 'api'
    })

    // RDS
    // RDS用のセキュリティグループを追加します。
    const securityGroupforRDS = new ec2.SecurityGroup(this, 'SecurityGroupforRDS', {
      vpc,
      description: 'Allow MySQL ingress',
      allowAllOutbound: true,
    })

    // 今回MySQLを使用するのでTCP:3306を開けておきます。
    securityGroupforRDS.addIngressRule(
      ec2.Peer.securityGroupId(securityGroupforEC2.securityGroupId),
      ec2.Port.tcp(3306),
      "Allow MySQL Access"
    )
    const engine = rds.DatabaseInstanceEngine.mysql({ version: rds.MysqlEngineVersion.VER_5_7_34 })

    // ここはRails側の設定と合わせてやるひつようがあります。
    // utf8mb4を使いたいので、各種文字コードをセットしておきます。
    const parameterGroup = new rds.ParameterGroup(this, 'ParameterGroup', {
      engine: engine,
      parameters: {
        character_set_client: 'utf8',
        character_set_connection: 'utf8',
        character_set_database: 'utf8mb4',
        character_set_results: 'utf8',
        character_set_server: 'utf8mb4',
      },
    });

    // これまで定義したリソースを指定してRDSのインスタンスを作成します。
    // DBのパスワードは事前にパラメータストアに保存したものを使用します。
    const db = new rds.DatabaseInstance(this, 'RailsRDS', {
      engine,
      vpc,
      parameterGroup: parameterGroup,
      databaseName: 'api_production',
      instanceIdentifier: 'railsrds',
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
      credentials: rds.Credentials.fromPassword('api', SecretValue.ssmSecure('RailsApiRDS', '1')),
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      },
      securityGroups: [securityGroupforRDS]
    })
  }
}
```

上記コメントにも書きましたが、事前にパラメータストアにRDSのパスワードを保存しておく必要があります。
`your_db_password`をお好きなパスワードに変更して実行してください。
```bash:
aws ssm put-parameter --name "RailsApiRDS" --value "your_db_password" --type "SecureString"
```

# まとめ
AWS CDKv2は2021/12にGAとなったばかりで、ドキュメントも少ないため、基本的には公式のリファレンスをたどるしかありません。
読むコツさえつかめば、コードのサンプルが大量に記載されているので、それを使いながら構築していくことができるかと思います。
- [AWS CDK · AWS CDK Reference Documentation](https://docs.aws.amazon.com/cdk/api/v2/)