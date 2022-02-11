---
title: "GitHub ActionsでLaravelプロジェクトをCI/CDする"
emoji: "🎢"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS","githubactions","deployer","laravel","laravel"]
published: true
---
[前回の記事](https://zenn.dev/tokku5552/articles/deployer-local)で`deployer`を使って`Laravel`アプリをローカルから`EC2`へデプロイしたので、今回は`GitHub Actions`にのせて`CI/CD`を組んでいきます。

今回の検証環境は以下の手順ですぐに作れます。

https://zenn.dev/tokku5552/articles/create-php-env-with-cfn

### 環境
- OS
  - macOS Monterey バージョン12.1(Intel)
- docker
```
% docker -v
Docker version 20.10.11, build dea9396
```
- docker内のphp/composer
```shell:
# php -v
PHP 7.3.33 (cli) (built: Dec 21 2021 22:11:19) ( NTS )
Copyright (c) 1997-2018 The PHP Group
Zend Engine v3.3.33, Copyright (c) 1998-2018 Zend Technologies

# composer -v
   ______
  / ____/___  ____ ___  ____  ____  ________  _____
 / /   / __ \/ __ `__ \/ __ \/ __ \/ ___/ _ \/ ___/
/ /___/ /_/ / / / / / / /_/ / /_/ (__  )  __/ /
\____/\____/_/ /_/ /_/ .___/\____/____/\___/_/
                    /_/
Composer version 2.1.14 2021-11-30 10:51:43
```

コードはGitHubで公開しています。

https://github.com/tokku5552/php-docker-nginx-postgresql

構成はこんな感じ
![](https://storage.googleapis.com/zenn-user-upload/f6248c2f7d89-20220130.png)

# GitHub ActionsでCI/CD
最終的なワークフローはこんな感じになりました。
流れとしては`job`が`unit-test`と`deploy`に分かれていて、`deploy`の方で`needs: unit-test`と指定することで、先に`unit-test`を実行させています。
どちらも`ubuntu-latest`で動作させています。

```yml:.github/workflows/deploy.yml
name: deploy stg

on:
  push:
    branches:
      - main

jobs:
  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup PHP 7.4
        run: sudo update-alternatives --set php /usr/bin/php7.4

      - name: cache vendor
        id: cache
        uses: actions/cache@v1
        with:
          ref: main
          path: ./vendor
          key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
          restore-keys: |
            ${{ runner.os }}-composer-

      - name: composer install
        if: steps.cache.outputs.cache-hit != 'true'
        run: composer install
        working-directory: ./src

      - name: set laravel env
        run: echo "${{ secrets.LARAVEL_ENV }}" > .env
        working-directory: ./src

      - name: run unit test
        run: vendor/bin/phpunit tests/
        working-directory: ./src

  deploy:
    runs-on: ubuntu-latest
    needs: unit-test
    steps:
      - uses: actions/checkout@v2
      - name: Setup PHP 7.4
        run: sudo update-alternatives --set php /usr/bin/php7.4

      - name: cache vendor
        id: cache
        uses: actions/cache@v1
        with:
          ref: main
          path: ./vendor
          key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
          restore-keys: |
            ${{ runner.os }}-composer-

      - name: composer install
        if: steps.cache.outputs.cache-hit != 'true'
        run: composer install
        working-directory: ./src

      - name: install awscli
        working-directory: ./src
        run: |
          # AWS CLIインストール
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install --update
          aws --version

      - name: setup ssh
        working-directory: ./src
        run: |
          # sshキーをコピー
          mkdir -p /home/runner/.ssh
          touch /home/runner/.ssh/MyKeypair.pem
          echo "${{ secrets.SSH_DEPLOY_KEY }}" > /home/runner/.ssh/MyKeypair.pem
          chmod 600 /home/runner/.ssh/MyKeypair.pem
          # known_hostsに追加
          ssh-keyscan 13.112.197.49 >> ~/.ssh/known_hosts
          ssh-keyscan 18.181.224.249 >> ~/.ssh/known_hosts

      - name: deploy to EC2 with rolling updates
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
        working-directory: ./src
        run: |
          # デプロイ
          vendor/bin/dep deploy LaravelWeb1 -vvv
          vendor/bin/dep deploy LaravelWeb2 -vvv
```

## 共通部分 - phpのセットアップとcomposer install
php7.4を指定してセットアップしたあと、composer installを実行しています。
`./vendor`は毎回`composer install`してると時間がかかるので、キャッシュを使うようにしています。
```yml:.github/workflows/deploy.yml
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup PHP 7.4
        run: sudo update-alternatives --set php /usr/bin/php7.4

      - name: cache vendor
        id: cache
        uses: actions/cache@v1
        with:
          ref: main
          path: ./vendor
          key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
          restore-keys: |
            ${{ runner.os }}-composer-

      - name: composer install
        if: steps.cache.outputs.cache-hit != 'true'
        run: composer install
        working-directory: ./src
```
今回のプロジェクトでは`src`の下に`laravel`のコードがあるので、そちらで必要な動作を行うように`working-directory: ./src`を指定しています。
例えば上記なら`run: cd ./src && composer install`とやるのと同じ意味です。

## deploy
次にデプロイ部分のステップについて説明します。
流れとしては、AWSCLIインストール -> sshキーのセットアップ -> deployerでデプロイ
という感じになります。

### awscliのインストール
AWSCLIをインストールします。
こちらは公式のv2のインストール方法に従ってインストールしています。
後で環境変数に必要事項を設定するので、この時点で`aws configure`は不要です。
```yml:
      - name: install awscli
        working-directory: ./src
        run: |
          # AWS CLIインストール
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install --update
          aws --version
```
はじめ`sudo ./aws/install`でインストールを実施したら`Found preexisting AWS CLI installation: /usr/local/aws-cli/v2/current. Please rerun install script with --update flag.`というエラーが出てしまったので、以下の記事を参考に`--update`をつけました。
https://zenn.dev/hdmt/scraps/db91ecc16f3b10

### sshのセットアップ
次にsshのセットアップを行います。sshの鍵はGitHubのシークレットに保存しておいて、読み込みます。
- 対象リポジトリの`Settings -> Actions -> New repository secret`をクリックします。

![シークレットの作成方法](https://storage.googleapis.com/zenn-user-upload/c4ca1ea55d9b-20220210.png)

- `Name`を`SSH_DEPLOY_KEY`に設定し、鍵の中身をコピーして`Value`に貼り付け`Add secret`をクリックします。

![SSH_DEPLOY_KEY](https://storage.googleapis.com/zenn-user-upload/e9d2a0d08c8e-20220210.png)

これで`{{ secrets.SSH_DEPLOY_KEY}}`で取得できるようになったので、以下のようにキーペアとして書き出してパーミッションを600にしてやります。
```yml:
      - name: setup ssh
        working-directory: ./src
        run: |
          # sshキーをコピー
          mkdir -p /home/runner/.ssh
          touch /home/runner/.ssh/MyKeypair.pem
          echo "${{ secrets.SSH_DEPLOY_KEY }}" > /home/runner/.ssh/MyKeypair.pem
          chmod 600 /home/runner/.ssh/MyKeypair.pem
          # known_hostsに追加
          ssh-keyscan 13.112.197.49 >> ~/.ssh/known_hosts
          ssh-keyscan 18.181.224.249 >> ~/.ssh/known_hosts
```



### deployerでのデプロイ
次はローリングアップデートの部分です。
今回の`deploy.php`ではAWSCLIを使ってALBの制御を行っているので、AWSCLIで必要なシークレットを設定しておきます。
![AWS_ACCESS_KEY_ID](https://storage.googleapis.com/zenn-user-upload/cc1bd8ce272c-20220210.png)
同様にして`AWS_SECRET_ACCESS_KEY`も設定しておきます。
`AWS_DEFAULT_REGION`と`AWS_DEFAULT_OUTPUT`は特に秘匿する必要もないので直接書いていますが、秘匿したい場合は同様にシークレットに保存しておけば良いと思います。
```yml:
      - name: deploy to EC2 with rolling updates
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
        working-directory: ./src
        run: |
          # デプロイ
          vendor/bin/dep deploy LaravelWeb1 -vvv
          vendor/bin/dep deploy LaravelWeb2 -vvv
```
デプロイ自体は`vendor/bin/dep deploy LaravelWeb1`コマンドのみで、ログに詳細出力させるために`-vvv`オプションを付与しています。


### Rolling Updateにする
[前回の記事](https://zenn.dev/tokku5552/articles/deployer-local)の状態の`deploy.php`で上記のように順番にデプロイすると、以下のように一方が`initial`でもう一方が`draining`の状態となり、一時的にサービスダウンしてしまうことになります。
![initial draining](https://storage.googleapis.com/zenn-user-upload/96a376e1a0f7-20220210.png)

これを防ぐために、`deploy.php`にターゲットの状態が`healthy`になるまで待機するタスクを追加しました。

```php:deploy.php
after('register-targets', 'describe-target-health');
task('describe-target-health', function () {
  $retry_count = 10;
  $i = 0;
  while ($i <= $retry_count) {
    $result = runLocally('aws elbv2 describe-target-health --target-group-arn {{target_group_arn}}');
    $obj = json_decode($result);
    foreach ($obj->TargetHealthDescriptions as $val) {
      if ($val->Target->Id === get('instance_id')) {
        if ($val->TargetHealth->State != 'healthy') {
          if ($i == $retry_count) {
            writeln('The preparation was not completed. Please try later');
            exit(1);
          }
          writeln('waiting...');
          break;
        } else {
          writeln('{{instance_id}} is healthy');
          return;
        };
      } else {
        break;
      }
    }
    sleep(1);
    $i++;
  }
});
```

条件がいくつもあって分かりづらいですが、`aws elbv2 describe-target-health`でターゲットグループの情報を取得し、デプロイ対象インスタンスの状態が`healthy`かどうかを`$retry_count`だけ確かめて、回数オーバーしたら終了ステータス1で終了させるようにしました。
これを`after('register-targets', 'describe-target-health');`としておくことで、ターゲットグループへの再登録後に実施するようになり、サービスダウンなくデプロイを行うことができるようになりました。

# テスト
今回検証したリポジトリはLaravelのほうはほぼプロジェクト作成後いじっていないのであまり意味ないですが、`CI/CD`ということでちゃんとテストも自動化しておきます。
Laravelでユニットテストを動かすために、`.env`ファイルを配置してやる必要があったので、こちらも`secrts`に設定しておきます。
![LARAVEL_ENV](https://storage.googleapis.com/zenn-user-upload/78d8100ffd97-20220210.png)

あとは簡単で、`./src`の直下に`.env`ファイルを作成して、`vendor/bin/phpunit tests/`を実行することでユニットテストを実施します。
```yaml:
      - name: set laravel env
        run: echo "${{ secrets.LARAVEL_ENV }}" > .env
        working-directory: ./src

      - name: run unit test
        run: vendor/bin/phpunit tests/
        working-directory: ./src
```

ターゲットブランチに`push`すると、無事passすることができました🎉
![](https://storage.googleapis.com/zenn-user-upload/30b5efe9e388-20220211.png)

# まとめ
4記事かけて検証しましたが、インフラも`IaC`で管理して`CI/CD`で自動化するとかなり気持ちよく開発をすすめることができると思います。
もっと開発者体験を高めるには例えばカバレッジを可視化してSlackに自動通知したりすると、更に開発意欲がまして良さそうだなと思いました。

### 参考

- [Found preexisting AWS CLI installation: /usr/local/aws-cli/v2/current. の対処](https://zenn.dev/hdmt/scraps/db91ecc16f3b10)
- [GitHub Actions × Laravel × Deployerで自動デプロイ - Qiita](https://qiita.com/koyablue/items/a809f86ca934de52f206)
- [CloudFormationとAnsibleでALB+EC2+RDSのLaravel環境を構築する(手順編)](https://zenn.dev/tokku5552/articles/create-php-env-with-cfn)
- [CloudFormationとAnsibleでALB+EC2+RDSのLaravel環境を構築する(解説編)](https://zenn.dev/tokku5552/articles/create-php-env-explanation)
- [【AWS】ALBからの切り離しと再登録手順](https://zenn.dev/tokku5552/articles/aws-target-group-desc)
- [Laravelプロジェクトをdeployerを使ってEC2にデプロイする](https://zenn.dev/tokku5552/articles/deployer-local)