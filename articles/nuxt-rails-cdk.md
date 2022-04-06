---
title: "【Nuxt x Rails】サンプルTODOアプリ - AWSCDK編"
emoji: "⛳"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: false
---
今回検証目的でフロントにNuxt、バックエンドにRails、インフラにAWSを使って以下のようなTODOアプリを作りました。
![](https://storage.googleapis.com/zenn-user-upload/cbc16aa9e5c1-20220405.png)
この記事ではRailsに関する解説を行います🙋‍♂️
- 以下の記事で全体の解説を行っています。

https://zenn.dev/tokku5552/articles/nuxt-rails-sample

- 全ソースコードはこちら

https://github.com/tokku5552/nuxt-rails-sample

# 環境
- ローカル(docker)
```bash:
# ruby -v
ruby 2.6.6p146 (2020-03-31 revision 67876) [x86_64-linux]
# rails -v
Rails 6.1.5
# bundle -v
Bundler version 1.17.2
# gem -v
3.0.3
```

- インフラ構成図

![](https://storage.googleapis.com/zenn-user-upload/f1ae25c170be-20220403.png)