---
title: "CloudFunctionでALB+EC2+RDSのLaravel環境を構築する"
emoji: "🐕"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [php,CloudFunction,Laravel,EC2]
published: false
---

# CloudFormationでAWS周りの設定
![](https://storage.googleapis.com/zenn-user-upload/b40c572da10c-20220103.png)

![](https://storage.googleapis.com/zenn-user-upload/a431141a98a8-20220103.png)

![](https://storage.googleapis.com/zenn-user-upload/49e8d6efdbb2-20220103.png)

```bash:
% ssh ec2-user@18.183.126.192 -i .ssh/MyKeypair.pem
The authenticity of host '18.183.126.192 (18.183.126.192)' can't be established.
ED25519 key fingerprint is SHA256:zMdl2FYM+226o5KCJG825lzlY1GmkuNlSkzFEqh3V60.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '18.183.126.192' (ED25519) to the list of known hosts.

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
6 package(s) needed for security, out of 16 available
Run "sudo yum update" to apply all updates.
[ec2-user@ip-10-0-1-112 ~]$
```

# EC2にPHP/Laravelの環境を構築
```bash:
sudo yum update -y
sudo amazon-linux-extras enable php7.4
sudo yum install php-cli php-pdo php-fpm php-json php-mysqlnd -y
sudo yum install php-bcmath php-mbstring php-xml -y
sudo systemctl enable php-fpm
```
- composerのインストール
```bash:
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer
```

- nginxのインストール
```bash:
sudo amazon-linux-extras enable nginx1
sudo yum install nginx -y
sudo systemctl status nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

- mysqlのインストール
```bash:
sudo yum install mysql -y
```

- gitのインストール
```bash:
sudo yum install git -y
```

https://qiita.com/ntm718/items/f896c8e4fb801777954b

- nginxとphp-fpmの設定