---
title: "SSMEC"
emoji: "🎉"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS"]
published: false
---

Session Managerで
![](https://storage.googleapis.com/zenn-user-upload/5613227ca453-20220223.png)

```
Telnet

telnet ssm.ap-northeast-1.amazonaws.com 443
telnet ec2messages.ap-northeast-1.amazonaws.com 443
telnet ssmmessages.ap-northeast-1.amazonaws.com 443
成功した接続の例:

root@111800186:~# telnet ssm.us-east-1.amazonaws.com 443
Trying 52.46.141.158...
Connected to ssm.us-east-1.amazonaws.com.
Escape character is '^]'.
Telnet を終了するには、Ctrl キーを押しながら、] キーを押します。quit と入力し、Enter キーを押します。
```
[Amazon EC2 インスタンスが Systems Manager コンソールの [マネージドインスタンス] に表示されない理由のトラブルシューティング](https://aws.amazon.com/jp/premiumsupport/knowledge-center/systems-manager-ec2-instance-not-appear/)


- Session Managerプラグインのインストール
```
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/session-manager-plugin.pkg" -o "session-manager-plugin.pkg"
sudo installer -pkg session-manager-plugin.pkg -target /
sudo ln -s /usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/session-manager-plugin
```
[(オプション) AWS CLI 用の Session Manager プラグインをインストールする - AWS Systems Manager](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-macos)

```
% aws ssm start-session --target i-056ebb2d3efbf9744

Starting session with SessionId: awscli-user-08e89a412a617720b
sh-4.2$
```

```
% ssh ec2-user@i-056ebb2d3efbf9744 -i .ssh/MyKeypair.pem
The authenticity of host 'i-056ebb2d3efbf9744 (<no hostip for proxy command>)' can't be established.
ED25519 key fingerprint is SHA256:cw/gVKiU5VklZeHlZPSZZqXNeivZUFkDlsjKVV+j6VI.
This host key is known by the following other names/addresses:
    ~/.ssh/known_hosts:43: 18.183.82.122
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'i-056ebb2d3efbf9744' (ED25519) to the list of known hosts.
Last failed login: Wed Feb 23 13:47:13 UTC 2022 on pts/0
There was 1 failed login attempt since the last successful login.
Last login: Wed Feb 23 13:31:02 2022 from fp5a95061d.knge119.ap.nuro.jp

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
8 package(s) needed for security, out of 14 available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-0-1-142 ~]$ whoami
```

- 試しに22を閉じてみる
```
% ssh ec2-user@i-056ebb2d3efbf9744 -i .ssh/MyKeypair.pem
Last login: Wed Feb 23 13:49:33 2022 from localhost

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
8 package(s) needed for security, out of 14 available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-0-1-142 ~]$
```

相変わらず接続可能

## プライベートサブネットにしてみる
[ステップ 6: (オプション) AWS PrivateLink を使用して Session Manager の VPC エンドポイントを設定する - AWS Systems Manager](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-getting-started-privatelink.html)
先にVPCのDNSホスト名有効化
[Systems Manager を使用したインターネットアクセスなしでのプライベート EC2 インスタンスの管理](https://aws.amazon.com/jp/premiumsupport/knowledge-center/ec2-systems-manager-vpc-endpoints/)
上をやったあと、EC2を一旦停止して、VPCからインターネットゲートウェイをデタッチ
EC2のセキュリティグループのインバウンドルールでHTTPS VPC CIDRを追加する
VPCのルーティングに