---
title: "CloudFunctionでALB+EC2+RDSのLaravel環境を構築する"
emoji: "🐕"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [php,CloudFunction,Laravel,EC2]
published: false
---
aaa

# EC2にPHP/Laravelの環境を構築
```
sudo yum update
sudo amazon-linux-extras enable php7.4
sudo yum install php-cli php-pdo php-fpm php-json php-mysqlnd
sudo yum install php-bcmath php-mbstring php-xml -y
sudo systemctl enable php-fpm
```
- composerのインストール
```
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer
```

- nginxのインストール
```
sudo amazon-linux-extras enable nginx1
sudo yum install nginx
sudo systemctl status nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```