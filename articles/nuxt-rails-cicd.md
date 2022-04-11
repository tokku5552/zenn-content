---
title: "【Nuxt x Rails】サンプルTODOアプリ - CI/CD編"
emoji: "💨"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: true
---
今回検証目的でフロントにNuxt、バックエンドにRails、インフラにAWSを使って以下のようなTODOアプリを作りました。
![](https://storage.googleapis.com/zenn-user-upload/cbc16aa9e5c1-20220405.png)
この記事ではGitHub Actionsに関する解説を行います🙋‍♂️
- 以下の記事で全体の解説を行っています。

https://zenn.dev/tokku5552/articles/nuxt-rails-sample

- 全ソースコードはこちら

https://github.com/tokku5552/nuxt-rails-sample

# 環境
- インフラ構成図

![](https://storage.googleapis.com/zenn-user-upload/f1ae25c170be-20220403.png)

# GitHub Actionsのワークフロー
今回はjobを`deploy_cdk`,`deploy_rails`,`deploy_front`の3つに分けて、直列に実行させています。
:::details 全コード
```yaml:.github/workflows/workflow.yml
name: deploy prd

on:
  push:
    branches:
      - main

jobs:
  deploy_cdk:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup Node
        uses: actions/setup-node@v1
        with:
          node-version: "16.13.2"
      - name: cache
        uses: actions/cache@v2
        with:
          path: ./cdk/node_modules
          key: ${{ runner.OS }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.OS }}-node-
            ${{ runner.OS }}-
      - name: npm install
        working-directory: ./cdk
        run: npm install
      - name: cdk deploy
        working-directory: ./cdk
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          CDK_ENV: ${{ secrets.CDK_ENV }}
        run: |
          echo "$CDK_ENV" > .env
          npx cdk deploy --all
  deploy_rails:
    runs-on: ubuntu-latest
    needs: deploy_cdk
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: cache vendor
        id: cache
        uses: actions/cache@v2
        with:
          path: api/vendor/bundle
          key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
          restore-keys: |
            ${{ runner.os }}-gems-
      # Ruby をインストールする
      - name: Set up Ruby 2.6.6
        uses: ruby/setup-ruby@8f312efe1262fb463d906e9bf040319394c18d3e # v1.92
        with:
          ruby-version: 2.6.6
      # バンドラーをインストールし、初期化する
      - name: Bundle install
        working-directory: ./api
        run: |
          gem install bundler
          bundle config path vendor/bundle
          bundle install --jobs 4 --retry 3
      # awscliのインストール
      - name: install awscli
        working-directory: ./api
        run: |
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install --update
          aws --version
          curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
          sudo dpkg -i session-manager-plugin.deb
      - name: setup ssh
        working-directory: ./api
        run: |
          # sshキーをコピー
          mkdir -p /home/runner/.ssh
          touch /home/runner/.ssh/MyKeypair.pem
          echo "${{ secrets.SSH_DEPLOY_KEY }}" > /home/runner/.ssh/MyKeypair.pem
          chmod 600 /home/runner/.ssh/MyKeypair.pem
      - name: deploy to EC2
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          RAILS_ENV: ${{ secrets.RAILS_ENV }}
        working-directory: ./api
        run: |
          echo "$RAILS_ENV" > .env
          source .env
          TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production deploy
  deploy_front:
    runs-on: ubuntu-latest
    needs: deploy_rails
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup Node
        uses: actions/setup-node@v1
        with:
          node-version: "16.13.2"
      - name: cache
        uses: actions/cache@v2
        with:
          path: ./front/node_modules
          key: ${{ runner.OS }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.OS }}-node-
            ${{ runner.OS }}-
      - name: npm install
        working-directory: ./front
        run: |
          npm install -g yarn
          yarn install
      - name: front deploy
        working-directory: ./front
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          FRONT_ENV: ${{ secrets.FRONT_ENV }}
        run: |
          echo "$FRONT_ENV" > .env
          source .env
          yarn generate
          aws s3 sync dist s3://nuxt.s3bucket/ --include "*"
          aws cloudfront create-invalidation --distribution-id ${{ secrets.DISTRIBUTIN_ID }} --paths "/*"
```
:::

### 冒頭と全体の流れ
冒頭部分ですが名前つけとトリガーの設定を行っています。
mainブランチが更新されたときにキックされるようになっています。
```yaml:.github/workflows/workflow.yml
name: deploy prd

on:
  push:
    branches:
      - main

jobs:
  deploy_cdk:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
...
```
テストはなしで、ビルドもジョブを分けていないですが、より実践的にはビルドを並列で実行してデプロイは選択式にするとより良いと思います。
参考：[ワークフローの手動実行 - GitHub Docs](https://docs.github.com/ja/actions/managing-workflow-runs/manually-running-a-workflow)

### deploy_cdk
AWS CDKv2によるインフラ部分です。
nodeを入れてnode_modulesをキャッシュしています。
AWSCLIは入れていないですが、AWSCLIが使えるような状態を環境変数で設定してやる必要があります。`AWS_ACCESS_KEY_ID`,`AWS_SECRET_ACCESS_KEY`
```yaml:.github/workflows/workflow.yml
jobs:
  deploy_cdk:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup Node
        uses: actions/setup-node@v1
        with:
          node-version: "16.13.2"
      - name: cache
        uses: actions/cache@v2
        with:
          path: ./cdk/node_modules
          key: ${{ runner.OS }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.OS }}-node-
            ${{ runner.OS }}-
      - name: npm install
        working-directory: ./cdk
        run: npm install
      - name: cdk deploy
        working-directory: ./cdk
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          CDK_ENV: ${{ secrets.CDK_ENV }}
        run: |
          echo "$CDK_ENV" > .env
          npx cdk deploy --all
```
その他、ホストゾーンIDなど、今回の構成で必要な情報をGitHubのシークレットに保存しておき、cdk deploy実行前に`.env`に書き出しています。
cdk側で`dotenv`による環境変数の自動読み込みを設定しているんので、`.env`に書き出すだけでOKです。
スタックを分けているので`--all`のオプションが必要です。

CDKの詳細に関しては以下を御覧ください。

https://zenn.dev/tokku5552/articles/nuxt-rails-cdk

### deploy_rails
Rails側ですが、Rubyをバージョン指定でインストールし、bundle installを行います。
capistranoでデプロイを行いますが、そのためにAWSCLIのインストールとSSHの鍵の配置を行っています。
```yaml:.github/workflows/workflow.yml
  deploy_rails:
    runs-on: ubuntu-latest
    needs: deploy_cdk
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: cache vendor
        id: cache
        uses: actions/cache@v2
        with:
          path: api/vendor/bundle
          key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
          restore-keys: |
            ${{ runner.os }}-gems-
      # Ruby をインストールする
      - name: Set up Ruby 2.6.6
        uses: ruby/setup-ruby@8f312efe1262fb463d906e9bf040319394c18d3e # v1.92
        with:
          ruby-version: 2.6.6
      # バンドラーをインストールし、初期化する
      - name: Bundle install
        working-directory: ./api
        run: |
          gem install bundler
          bundle config path vendor/bundle
          bundle install --jobs 4 --retry 3
      # awscliのインストール
      - name: install awscli
        working-directory: ./api
        run: |
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install --update
          aws --version
          curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
          sudo dpkg -i session-manager-plugin.deb
      - name: setup ssh
        working-directory: ./api
        run: |
          # sshキーをコピー
          mkdir -p /home/runner/.ssh
          touch /home/runner/.ssh/MyKeypair.pem
          echo "${{ secrets.SSH_DEPLOY_KEY }}" > /home/runner/.ssh/MyKeypair.pem
          chmod 600 /home/runner/.ssh/MyKeypair.pem
      - name: deploy to EC2
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          RAILS_ENV: ${{ secrets.RAILS_ENV }}
        working-directory: ./api
        run: |
          echo "$RAILS_ENV" > .env
          source .env
          TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production deploy
```
注意すべき点なのは、今回の構成ではEC2へはSSM経由でSSH接続したいので、AWSCLIを通常通りインストールしたあと、`session-manager-plugin`を別途インストールする必要があります。
SSHの鍵はシークレットから生成しておいて、接続の設定（プロキシコマンドなど）はcapistrano側に記載してあるので、ここではセットする必要はありません。
例のごとくRAILSで必要な環境変数は`.env`に書き出して読み込んでいます。

capistranoの設定に関しては以下を御覧ください。

https://zenn.dev/tokku5552/articles/nuxt-rails-backend

### deploy_front
最後にフロント側のデプロイです。
フロント側ではyarnを使っているので、yarn installしたあとにデプロイ作業を行っています。
```yaml:.github/workflows/workflow.yml
  deploy_front:
    runs-on: ubuntu-latest
    needs: deploy_rails
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup Node
        uses: actions/setup-node@v1
        with:
          node-version: "16.13.2"
      - name: cache
        uses: actions/cache@v2
        with:
          path: ./front/node_modules
          key: ${{ runner.OS }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.OS }}-node-
            ${{ runner.OS }}-
      - name: npm install
        working-directory: ./front
        run: |
          npm install -g yarn
          yarn install
      - name: front deploy
        working-directory: ./front
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          FRONT_ENV: ${{ secrets.FRONT_ENV }}
        run: |
          echo "$FRONT_ENV" > .env
          source .env
          yarn generate
          aws s3 sync dist s3://nuxt.s3bucket/ --include "*"
          aws cloudfront create-invalidation --distribution-id ${{ secrets.DISTRIBUTIN_ID }} --paths "/*"
```
デプロイはawscliでS3バケットへのアップロードとCloudFrontのキャッシュ削除を行っています。
`yarn generate`で`nuxt generate`が走り、SPAモードで`dist`にビルドされた結果が出力されます。
それをオリジンに指定しているS3バケットにアップロードして、その後全てのパスのキャッシュを削除しているという流れです。

<!-- Nuxt側の解説はこちら。

https://zenn.dev/tokku5552/articles/nuxt-rails-frontend -->

# まとめ
今回の構成では事前にAWS CDKでインフラを構築したあと、EC2の設定を行って、更に必要な情報(EC2のインスタンスID、CroudFrontのDISTRIBUTION ID、S3のバケット名)を取得しておく必要があります。(つまりCDK側の変更箇所によってはEC2が再作成されて、環境変数を再設定しないとCI/CDが動かなくなる...)
本来はEC2側は手動で設定済みのEC2からAMIを作成しておいて、それを使ってインスタンスを生成し上記の情報はCDKからパラメータストアかどこかに保持しておいて、コードのデプロイ時にはそれを都度参照したほうがより良いと思います。