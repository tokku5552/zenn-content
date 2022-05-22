---
title: "AWS CDK x React でLIFFアプリを作る"
emoji: "📑"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws"]
published: false
---


https://github.com/tokku5552/liff-cdk-sample
この記事ではLINE Developers側の設定は記載しないので、[公式サイト](https://developers.line.biz/ja/docs/liff/)を御覧ください。
## プロジェクトの雛形作成
- 適当にディレクトリ作って`cdk init`します。
  - `cdk init`は空ディレクトリじゃないと実行できないので先にやります。
  - 加えてcdkでアプリ自体もデプロイする場合に、cdkのディレクトリ以下にアプリケーションのディレクトリがあったほうが都合が良いので、今回もそのようにします。
```
mkdir liff-cdk-sample
npx cdk init app--language typescript
```
`.gitignore`が作成されなかったので作って`node_modules`と`cdk.out`を追加しておきます。
- 続いて、プロジェクトルートで`create-liff-app`を実行。対話式で設定していきます。
```vim:
% npx @line/create-liff-app
Welcome to the Create LIFF App
? Enter your project name:  liff-app
? Which template do you want to use? react
? JavaScript or TypeScript? TypeScript
? Please enter your LIFF ID: 
 Don't you have LIFF ID? Check out https://developers.line.biz/ja/docs/liff/getting-started/ liffId
? Do you want to install it now with package manager? Yes
? Which package manager do you want to use? yarn
yarn install v1.22.18
warning package.json: No license field
warning ../package.json: No license field
info No lockfile found.
warning liff-app@0.0.0: No license field
[1/4] 🔍  Resolving packages...
[2/4] 🚚  Fetching packages...
[3/4] 🔗  Linking dependencies...
[4/4] 🔨  Building fresh packages...
success Saved lockfile.
✨  Done in 18.74s.


Done! Now run: 

  cd liff-app
  yarn dev
```
この時点でローカルで起動してみます。(liff-idを設定しないと`LIFF init failed.`となります。)
![](https://storage.googleapis.com/zenn-user-upload/1e38b114ba90-20220522.png)
あとからliff-idを追加する場合は`.env`に書けばOKです。

## AWS CDKでS3+CloudFrontにデプロイ
- Stack
```typescript:lib/liff-cdk-sample-stack.ts
import { Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';

export class LiffCdkSampleStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const liffAppBucket = new s3.Bucket(this, 'LiffAppBucket', {
      websiteIndexDocument: 'index.html',
      websiteErrorDocument: 'index.html'
    });

    const liffAppIdentity = new cloudfront.OriginAccessIdentity(this, 'LiffAppIdentity');

    const liffAppBucketPolicyStatement = new iam.PolicyStatement({
      actions: ['s3:GetObject'],
      effect: iam.Effect.ALLOW,
      principals: [liffAppIdentity.grantPrincipal],
      resources: [`${liffAppBucket.bucketArn}/*`]
    });

    liffAppBucket.addToResourcePolicy(liffAppBucketPolicyStatement);

    const liffAppDistribution = new cloudfront.CloudFrontWebDistribution(this, 'LiffAppDistribution', {
      errorConfigurations: [
        {
          errorCode: 403,
          errorCachingMinTtl: 300,
          responseCode: 200,
          responsePagePath: '/index.html',
        },
        {
          errorCode: 404,
          errorCachingMinTtl: 300,
          responseCode: 200,
          responsePagePath: '/index.html',
        }
      ],
      originConfigs: [
        {
          s3OriginSource: {
            s3BucketSource: liffAppBucket,
            originAccessIdentity: liffAppIdentity
          },
          behaviors: [
            {
              isDefaultBehavior: true,
            }
          ]
        }
      ],
      priceClass: cloudfront.PriceClass.PRICE_CLASS_ALL
    })

    new s3deploy.BucketDeployment(this, 'LiffAppDeploy', {
      sources: [s3deploy.Source.asset('./liff-app/dist')],
      destinationBucket: liffAppBucket,
      distribution: liffAppDistribution,
      distributionPaths: ['/*']
    })
  }
}
```

- デプロイ
```shell:
cd liff-app
yarn build
cd ..
npx cdk deploy
```

- LINE DevelopersコンソールからLIFFアプリのエンドポイントURLをCloudFrontのものに変更し、LIFF URLにアクセスすると無事LIFFアプリが起動しました🎉
![](https://storage.googleapis.com/zenn-user-upload/b492a82c669e-20220522.png =250x)