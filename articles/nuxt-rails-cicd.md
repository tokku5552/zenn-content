---
title: "【Nuxt x Rails】サンプルTODOアプリ - CI/CD編"
emoji: "💨"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: false
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

# .github/workflows/workflow.yml
今回はjobを`deploy_cdk`,`deploy_rails`,`deploy_nuxt`の3つに分けて、直列に実行させています。
- 全コード
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