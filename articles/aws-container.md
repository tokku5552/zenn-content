---
title: "AWS CLIV2 Container"
emoji: "🐈"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [AWS]
published: false
---

# AWS CLI v2 を docker で作成する

AWS CLI を

# TL;DR

# Dockerfile と docker-compose

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

AWS CLI のインストール
https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/install-cliv2-linux.html

https://qiita.com/reflet/items/d322466baf9935ee2230

docker で環境変数を使う方法
https://docs.docker.jp/compose/environment-variables.html

# 利用方法
