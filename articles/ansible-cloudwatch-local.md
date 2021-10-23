---
title: "自宅サーバーにansibleでCloudWatch Agentの設定をしてCloudWatchで監視できるようにした"
emoji: "👋"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS","Ansible","Docker","CloudWatch"]
published: false
---
自宅サーバーにCloudWatch Agentを入れてCloudWatch側で監視をしようと思い立ったので、メモ。
以前からAnsibleで管理しているので、今回も頑張ってAnsibleで入れました。
# 環境
- Local
  - Windows 10 Pro
  - Mac Book Pro (not M1)
  - Docker version 20.10.8, build 3967b7d

# 事前準備
- Ansibleの実行環境  
  AnsibleはDockerの中に構築してそれを使っています。
  本記事の内容とはそれるので、詳しく知りたい方は以下を参照してください。  

https://tokku-engineer.tech/build_docker_ansible_devenv/

- IAMユーザーの追加
  サーバーに入れたCloudWatchAgentからAWS側に情報を送信するために、あらかじめIAMユーザーを作成しておく必要があります。
  これも本記事と内容がそれるので、詳細は以下を参照ください。  

https://tokku-engineer.tech/how-to-add-iam-user/

# Ansibleプレイブック
事前準備が整ったので実際のプレイブックを見ていきます。  
フォルダ構成はベストプラクティスに沿って各々用意してください。  
大きく分けて

- AWSCLIv2のインストールと設定
- CloudWatch Agentのインストールと設定  

の2つです。
## AWSCLIv2
インストール方法は以前書いたこちらの記事を参考に、Ansbileのプレイブックに起こしました。  
https://zenn.dev/tokku5552/articles/aws-container

## CloudWatch Agent
# 結果
# 参考
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-premise.html
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/create-iam-roles-for-cloudwatch-agent.html#create-iam-roles-for-cloudwatch-agent-users
https://qiita.com/murata-tomohide/items/3e66d63b21c08d6481a2