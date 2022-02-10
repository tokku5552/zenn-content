---
title: "laravel"
emoji: "🎢"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS","githubactions","laravel"]
published: false
---

ローリングアップデートでの`CI/CD`構築に先駆けて、PHPのデプロイツールである`deployer`を使って`Laravel`アプリを`EC2`にデプロイしてみました。
今回の環境は以下の手順でサクッと作りました。

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


# ほげ

![シークレットの作成方法](https://storage.googleapis.com/zenn-user-upload/c4ca1ea55d9b-20220210.png)
![AWS_ACCESS_KEY_ID](https://storage.googleapis.com/zenn-user-upload/cc1bd8ce272c-20220210.png)
![SSH_DEPLOY_KEY](https://storage.googleapis.com/zenn-user-upload/e9d2a0d08c8e-20220210.png)

## Rolling Updateにする
![initial draining](https://storage.googleapis.com/zenn-user-upload/96a376e1a0f7-20220210.png)


# テスト
![LARAVEL_ENV](https://storage.googleapis.com/zenn-user-upload/78d8100ffd97-20220210.png)


https://zenn.dev/hdmt/scraps/db91ecc16f3b10

https://qiita.com/koyablue/items/a809f86ca934de52f206