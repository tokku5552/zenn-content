---
title: "Session Manager経由でSSH接続する方法"
emoji: "🔐"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS","ec2","ssh","linux","mac"]
published: true
---

今回はSession Managerを使ってEC2にSSH接続する方法をご紹介します。
対象のEC2がパブリックサブネットにいる場合(Internet Gatewayがある場合)と、プライベートサブネット上にいる場合の2種類の設定方法を記載します。
- 構成図(まず左のパブリックサブネットからやってみて、その後プライベートサブネットでやってみます)
![](https://storage.googleapis.com/zenn-user-upload/d2854d297841-20220303.png)

## パブリックサブネットでやってみる

- IAMロールを作っておく。
  - `AmazonSSMManagedInstanceCore`のポリシーを含むロールを作成します。

![](https://storage.googleapis.com/zenn-user-upload/1a7af9a4f2c3-20220227.png)

- 対象のEC2を選択し、`アクション -> セキュリティ -> IAMロールを変更`をクリックして今作ったロールを割り当てます。

![](https://storage.googleapis.com/zenn-user-upload/1adf0bad1b0e-20220227.png)

- EC2空SSMと通信できているか確認します。(以下はtelnetで確認する例。)

```bash:EC2上のターミナル
telnet ssm.ap-northeast-1.amazonaws.com 443
telnet ec2messages.ap-northeast-1.amazonaws.com 443
telnet ssmmessages.ap-northeast-1.amazonaws.com 443

# 成功した接続の例)
root@111800186:~$ telnet ssm.us-east-1.amazonaws.com 443
Trying 52.46.141.158...
Connected to ssm.us-east-1.amazonaws.com.
Escape character is '^]'.
Telnet を終了するには、Ctrl キーを押しながら、] キーを押します。quit と入力し、Enter キーを押します。
```
参考：[Amazon EC2 インスタンスが Systems Manager コンソールの [マネージドインスタンス] に表示されない理由のトラブルシューティング](https://aws.amazon.com/jp/premiumsupport/knowledge-center/systems-manager-ec2-instance-not-appear/)


- ローカルマシンにSession Managerプラグインをインストールします(以下はMacOSでの例)。
```bash:
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/session-manager-plugin.pkg" -o "session-manager-plugin.pkg"
sudo installer -pkg session-manager-plugin.pkg -target /
sudo ln -s /usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/session-manager-plugin
```
参考：[(オプション) AWS CLI 用の Session Manager プラグインをインストールする - AWS Systems Manager](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-macos)

- ひとまずSession Managerで接続してみます。

```bash:
% aws ssm start-session --target i-XXXXXXXXXXXXXXX

Starting session with SessionId: awscli-user-XXXXXXXXXXXXXXXXX
sh-4.2$
```

- `System Manager -> Session Manager`の画面で以下のようにセッションができていたらOK

![](https://storage.googleapis.com/zenn-user-upload/26a099c50437-20220227.png)

- sshをSession Manager経由にするために、ローカルマシンの`.ssh/config`に以下を追記します。
```ini:
host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```

- sshで接続してみます。接続するホスト名はインスタンスIDを指定します。

```shell:
% ssh ec2-user@i-XXXXXXXXXXXXXXX -i .ssh/<your key>
The authenticity of host 'i-XXXXXXXXXXXXXXX (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.
This host key is known by the following other names/addresses:
    ~/.ssh/known_hosts:43: XXX.XXX.XXX.XXX
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'i-XXXXXXXXXXXXXXX' (ED25519) to the list of known hosts.
Last failed login: Wed Feb 23 13:47:13 UTC 2022 on pts/0
There was 1 failed login attempt since the last successful login.
Last login: Wed Feb 23 13:31:02 2022 from xxxxxxxx.xxxxxx.xx.xxxx.jp

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
8 package(s) needed for security, out of 14 available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-0-1-142 ~]$ 
```

- 試しにPort:22を閉じてみます。

![](https://storage.googleapis.com/zenn-user-upload/6c547fbe6187-20220227.png)

- 再度接続してみて、ちゃんと接続されることを確認。

```bash:
% ssh ec2-user@i-XXXXXXXXXXXXXXX -i .ssh/<your key>
Last login: Wed Feb 23 13:49:33 2022 from localhost

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
8 package(s) needed for security, out of 14 available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-0-1-142 ~]$
```

これでパブリックサブネットの場合は完了。

## プライベートサブネットにしてみる
以下の公式ドキュメントにしたがって実施します。  
[ステップ 6: (オプション) AWS PrivateLink を使用して Session Manager の VPC エンドポイントを設定する - AWS Systems Manager](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-getting-started-privatelink.html)

- 先にVPCのDNSホスト名有効化しておきます。

![](https://storage.googleapis.com/zenn-user-upload/25f65624d47b-20220227.png)

- DNSホスト名の有効化を行ったあと、プライベートVPCからのアクセスを確認するためにEC2を一旦停止して、VPCからインターネットゲートウェイをデタッチします。
- EC2のセキュリティグループのインバウンドルールで`タイプ ： HTTPS`、`ソース ： カスタム -> VPCのCIDR`を追加します。

![](https://storage.googleapis.com/zenn-user-upload/3a98c4517edd-20220227.png)

- 次にエンドポイントを3つ作成します。
  - まずssmのエンドポイントに対して作成します。`VPC -> エンドポイント -> エンドポイントを作成`をクリックし、適当に名前をつけ`サービスカテゴリ`を`AWSのサービス`にします。

![](https://storage.googleapis.com/zenn-user-upload/9d1bfbce6c1b-20220227.png)

- サービス選択画面で`com.amazonaws.ap-northeast-1.ssm`を選択します。(リージョンが異なる場合は該当のリージョンを選択)

![](https://storage.googleapis.com/zenn-user-upload/f496b8a24a40-20220227.png)

- EC2が存在するVPCを選択しAZを選択、サブネットを選択します。

![](https://storage.googleapis.com/zenn-user-upload/61c1e507a5b8-20220227.png)

- セキュリティグループを選択し、`エンドポイントを作成`をクリックします。

![](https://storage.googleapis.com/zenn-user-upload/915ed53fe21a-20220227.png)


- 同様にしてあと2つ作成します。サービス：`com.amazonaws.ap-northeast-1.ec2messages`

![](https://storage.googleapis.com/zenn-user-upload/3ed1583dd1fb-20220227.png)

- サービス：`com.amazonaws.ap-northeast-1.ssmmessages`

![](https://storage.googleapis.com/zenn-user-upload/3cbdcf247830-20220227.png)

- 再度接続してみて、ちゃんと接続されることを確認します。

```bash:
% ssh ec2-user@i-XXXXXXXXXXXXXXX -i .ssh/<your key>
Last login: Wed Feb 23 13:49:33 2022 from localhost

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
8 package(s) needed for security, out of 14 available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-0-1-142 ~]$
```

これでプライベートサブネットからもアクセス可能となりました🎉

### 参考
[Systems Manager を使用したインターネットアクセスなしでのプライベート EC2 インスタンスの管理](https://aws.amazon.com/jp/premiumsupport/knowledge-center/ec2-systems-manager-vpc-endpoints/)