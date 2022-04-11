---
title: "【Nuxt x Rails】サンプルTODOアプリ - Docker編"
emoji: "📑"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: true
---
今回検証目的でフロントにNuxt、バックエンドにRails、インフラにAWSを使って以下のようなTODOアプリを作りました。
![](https://storage.googleapis.com/zenn-user-upload/cbc16aa9e5c1-20220405.png)
この記事ではDockerに関する解説を行います🙋‍♂️
- 以下の記事で全体の解説を行っています。

https://zenn.dev/tokku5552/articles/nuxt-rails-sample

- 全ソースコードはこちら

https://github.com/tokku5552/nuxt-rails-sample

# 環境
- ローカル(docker)
```bash:
# docker -v
Docker version 20.10.12, build e91ed57
```

- インフラ構成図

![](https://storage.googleapis.com/zenn-user-upload/f1ae25c170be-20220403.png)

# 全体像
![](https://storage.googleapis.com/zenn-user-upload/fc423b98d038-20220407.png)
コンテナとしては3環境立ち上げるようにしていて、それぞれ`web`、`app`、`db`というサービス名となっています。
先に`docker-compose.yml`の解説をしておきます。
```yaml:docker-compose.yml
version: '3'
services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: root
    ports:
      - "3306:3306"
    volumes:
      - ./tmp/db:/var/lib/mysql
  app:
    build: docker/app
    tty: true
    volumes:
      - ./api:/api
      - ~/.ssh:/root/.ssh
    ports:
      - "8000:8000"
    depends_on:
      - db
    environment:
      AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
      AWS_DEFAULT_REGION: ap-northeast-1
  web:
    build: docker/web
    ports:
      - "3000:3000"
    volumes:
      - ./front:/var/www/html
    tty: true
```
webとappはDockerefileから立ち上げるようにしていますが、dbはmysqlのイメージをそのまま使っています。
ローカル環境ということもあり、パスワードなどはベタ書きしています。

特筆すべきことはあまりないですが、`app`はdockerの中からcapistranoを使ってデプロイを行いたかったので、AWSCLIの設定を行っています。
また、sshの設定をローカルのMacのものと共有させるために`~/.ssh:/root/.ssh`というようにそのままマウントしています。

## `app`
RubyをDockerで立ち上げています。
本番環境はpumaとnginxを使っていますが、ここでは単純に`rails s`で立ち上げるのみとしています。
起動前にいかの環境変数を定義しておく必要があります。
```ini:
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```
- Dockerfile
```Dockerfile:docker/app/Dockerfile
FROM ruby:2.6.6
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    default-mysql-client \
    nodejs \
    sudo \
    vim

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    sudo ./aws/install

RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
    sudo dpkg -i session-manager-plugin.deb

RUN mkdir /api
WORKDIR /api
COPY Gemfile /api/
COPY Gemfile.lock /api/
RUN bundle install
```
rubyのイメージはsuffixをつけない場合debianになるようです。
bash and aptが使えます。
参考：[Ruby - Official Image | Docker Hub](https://hub.docker.com/_/ruby)

- 起動用のGemfile
bundle installを行うために、Gemfileが必要だったので`docker/app/Gemfile`と`docker/app/Gemfile.lock`を配置しています。
.lockの方は空ファイルですが、`Gemfile`はrailsのみ記載しています。
```ruby:docker/app/Gemfile
source 'https://rubygems.org'
gem 'rails', '~> 6.1.4'
```

## `web`
Nuxtを動かすためのコンテナです。
`yarn dev`で動かすため、ただ`node`を入れているだけです。
```Dockerfile:docker/web/Dockerfile
FROM node:16-alpine3.14

WORKDIR /var/www/html

RUN apk update && \
    npm install -g npm 

EXPOSE 3000
ENV HOST 0.0.0.0
```
alpineベースの軽量なものを使っているのでbashが使えません

## 起動方法(`Makefile`による短縮コマンド)
この技最近良く使うのですが、`Makefile`をコンパイル用ではなく、単なる短縮コマンドの定義用に使用しています。
例えば
```
make up
make bash
```
とかで`app`コンテナに入れますし、起動したいときは
```
make up
make web
make app
```
と打てば環境が起動します。(`make web`と`make app`は別ターミナルで実行)

```Makefile:Makefile
up:
	docker compose up -d
build:
	docker compose build --no-cache --force-rm
remake:
	@make destroy
	@make up
stop:
	docker compose stop
down:
	docker compose down --remove-orphans
restart:
	@make down
	@make up
destroy:
	docker compose down --rmi all --volumes --remove-orphans
destroy-volumes:
	docker compose down --volumes --remove-orphans
ps:
	docker compose ps
logs:
	docker compose logs
log-app:
	docker compose logs app
log-app-watch:
	docker compose logs --follow app
ash:
	docker compose exec web ash
bash:
	docker compose exec app bash
web:
	docker compose exec web yarn dev
app:
	docker compose exec app bundle install
	docker compose exec app bundle exec rails s -p 8000 -b '0.0.0.0'
db:
	docker compose exec db mysql -h localhost -ppassword
```
もちろん`Makefile`を使わなくても、上記のコマンドをそのまま打てば全く同じことができます。
私は上から`logs`くらいまでは固定で使いまわしています。

# まとめ
割と簡易的な説明になりましたが、このファイル類を置いとくだけで環境構築できるのはありがたいですね。
`app`は`web`からでなくても`curl`コマンドなどで直接実行することもできるので、かなり便利です。