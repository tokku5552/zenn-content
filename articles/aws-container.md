---
title: "AWS CLI v2 をdockerで使えるようにする"
emoji: "🐈"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS", "Docker", "awscli", "VSCode"]
published: true
---

AWS CLI を手元の環境を汚さずに docker で作成したかったのでやり方をメモ

# TL;DR

- **AWS CLI v2** がインストールされた docker image を作成
- **VS Code** のターミナルから **docker-compose** コマンドでコンテナを作成
- S3 バケットへコードをデプロイする環境を作る

### 環境

Windows マシンですが、docker が入っていれば MacOS でも同様に出来るかと思います

```shell:
> docker --version
Docker version 20.10.7, build f0df350
```

# Dockerfile と docker-compose

公式の aws-cli イメージはコマンドをそのまま実行する環境としては便利ですが、作った shell などを動かしたいときに不便に感じたので、別のイメージから作成するようにしました。
less と vim はお好みで、curl,unzip,sudo は必須です。

```Dockerfile:aws-cli/Dockerfile
# AWS CLI2 を利用するDockerfile
FROM python:3.9

# 前提パッケージのインストール
RUN apt-get update && apt-get install -y less vim curl unzip sudo

# aws cli v2 のインストール
# https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/install-cliv2-linux.html
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN sudo ./aws/install

WORKDIR /workdir
```

aws cli のインストールは公式ページを参照して実行しています。
https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/install-cliv2-linux.html

次に**docker-compose.yml**です
コンテナ内の`/workdir`を、プロジェクトのルートにマウントするように指定しています。
また、環境変数として、`AWS_DEFAULT_REGION`と`AWS_DEFAULT_OUTPUT`をそれぞれ指定しています。

```yaml:docker-compose.yml
version: "3"
services:
  aws-cli-container:
    build: ./aws-cli
    container_name: awscli-container
    volumes:
      - .:/workdir
    env_file:
      - .env
    environment:
      AWS_DEFAULT_REGION: ap-northeast-1
      AWS_DEFAULT_OUTPUT: json
```

`AWS_ACCESS_KEY_ID`と`AWS_SECRET_ACCESS_KEY`は`.env`というファイルに書いておき、ローカルで読み込みます。
GitHub のリポジトリを公開する場合は、このファイルは`.gitignore`に追加して、git の管理から外しておくのを忘れないようにします。
以下はサンプルです

```shell:.env
AWS_ACCESS_KEY_ID='YOUR_AWS_ACCESS_KEY_ID'
AWS_SECRET_ACCESS_KEY='YOUR_AWS_SECRET_ACCESS_KEY'

```

# 利用方法

VS Code でターミナルを開き、docker-compose コマンドで起動する(Win/Mac 同じ)

```
docker-compose up
docker-compose run --rm aws-cli-container /bin/bash
```

起動したら dokcer の中の bash を実行しているので、ここでは試しに S3 のバケットを作って、適当なファイルをアップロードしてみる

```shell:
[root@xxxxxxxxxxxx:/workdir]# aws s3 mb s3://test-20210711
make_bucket: test-20210711
[root@xxxxxxxxxxxx:/workdir]# aws s3 ls
2021-07-11 09:46:05 test-20210711
[root@xxxxxxxxxxxx:/workdir]# aws s3 cp .env_sample s3://test-20210711/
upload: ./.env_sample to s3://test-20210711/.env_sample
```

無事にアップロードできました
![s3test](https://user-images.githubusercontent.com/69064290/125190590-eb813b00-e278-11eb-9c4b-6ed762e39e1f.png)

# 参考

https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/install-cliv2-linux.html

https://qiita.com/reflet/items/d322466baf9935ee2230

https://docs.docker.jp/compose/environment-variables.html
