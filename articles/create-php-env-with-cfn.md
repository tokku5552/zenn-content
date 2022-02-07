---
title: "CloudFormationとAnsibleでALB+EC2+RDSのLaravel環境を構築する(手順編)"
emoji: "🐕"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [AWS,php,Laravel,cloudformation,EC2]
published: true
---
検証用にphp/LaravelのアプリケーションをAWSへ素早くデプロイしたかったので、CFnとAnsibleを使って爆速でALB+EC2+RDSの環境を作れるようにしました。

解説編はこちら
https://zenn.dev/tokku5552/articles/create-php-env-explanation

構成はこんな感じ
![](https://storage.googleapis.com/zenn-user-upload/f6248c2f7d89-20220130.png)

### 動作環境
- macOS Monterey 12.1(Intel)

# 手順
サンプルリポジトリ。こちらにCFnの定義、ansibleの定義、Laravelのアプリがまとまっています。

https://github.com/tokku5552/php-docker-nginx-postgresql

- 作業概要
  - 1.ローカルへリポジトリをクローン
  - 2.Cloud FormationでAWS側の構築
  - 3.AnsibleでEC2側の構築
  - 4.アプリケーションのデプロイ(手動)
  - 5.Laravelの設定


## 事前準備
以下が事前に済んでいることが必要です。
- AWSCLIのインストールと設定
- dockerのインストール
- EC2へアクセスするためのキーペアの作成

## 1.ローカルへリポジトリをクローン

```shell:ローカルのターミナル
cd <プロジェクトを配置するお好みの場所>
git clone git@github.com:tokku5552/php-docker-nginx-postgresql.git

# 確認
ls -l php-docker-nginx-postgresql
total 32
drwxr-xr-x   5 username  staff   160 12 30 23:58 CFn
-rw-r--r--   1 username  staff  1104 10  9 17:01 LICENSE
-rw-r--r--   1 username  staff  3993 12 30 13:18 Makefile
-rw-r--r--   1 username  staff  2141 10 10 00:40 README.md
drwxr-xr-x  14 username  staff   448  1  6 22:48 ansible
drwxr-xr-x   5 username  staff   160 10  9 16:50 docker
-rw-r--r--   1 username  staff  2127 10 10 00:34 docker-compose.yml
drwxr-xr-x   3 username  staff    96 12 30 17:57 docs
drwxr-xr-x  26 username  staff   832 10  9 23:52 src
```

## 2.Cloud FormationでAWS側の構築
- `CFn/application.yml`の`EC2`の各サーバーの`Properties->KeyName`の部分を、用意したEC2接続用のキーペアにしておく。
```yaml:CFn/application.yml#L80あたり
  # ------------------------------------------------------------#
  #  EC2
  # ------------------------------------------------------------#
  LaravelWeb1:
    Type: AWS::EC2::Instance
    Properties:
      KeyName: <EC2接続用のキーペア>
      ImageId: ami-0218d08a1f9dac831
      InstanceType: t2.micro
      Monitoring: false
```

- 以下のコマンドを順次実行する。
```shell:
cd CFn

# NetworkStack
aws cloudformation deploy --template-file network.yml --stack-name LaravelNetwork

# ApplicationStack
aws cloudformation deploy --template-file application.yml --stack-name LaravelApplication
```

- 確認
`AWSマネジメントコンソール->CloudFormation->スタック`から該当のスタックを選択して`イベント`を確認する。
![](https://storage.googleapis.com/zenn-user-upload/b40c572da10c-20220103.png)

- `LaravelApplication`側のスタックの`リソース`タブをクリックして、`LaravelWeb1`のインスタンスIDをクリックする。
![](https://storage.googleapis.com/zenn-user-upload/a431141a98a8-20220103.png)

- `EC2`が正常に作成されていることを確認する。
    - パブリックPアドレスをメモしておく
![](https://storage.googleapis.com/zenn-user-upload/49e8d6efdbb2-20220103.png)

- `EC2`への接続確認をしておく。
```bash:
% ssh ec2-user@18.183.126.192 -i <EC2接続用のキーペア>
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

- 他にも`LaravelApplication`側の他のリソースが正しく作成されているか確認しておく。

## 3.AnsibleでEC2側の構築

- 先程メモしたIPアドレスを`ansible/inventory.txt`の各ホスト名の下に記載しておく。合わせてキーペアも設定しておく。
```
[LaravelWeb1]
18.183.126.192

[LaravelWeb2]
54.92.127.85

[LaravelWeb1:vars]
ansible_port=22
ansible_user=ec2-user
ansible_ssh_private_key_file=<EC2接続用のキーペア>

[LaravelWeb2:vars]
ansible_port=22
ansible_user=ec2-user
ansible_ssh_private_key_file=<EC2接続用のキーペア>
```

- 以下のコマンドを順次実行する。
```
cd ansible
make up
make run

~~省略~~

TASK [php74 : restart & enable nginx] ****************************************************************************************************************
ok: [18.183.126.192]
ok: [54.92.127.85]

TASK [php74 : install other packages] ****************************************************************************************************************
ok: [18.183.126.192]
ok: [54.92.127.85]

PLAY RECAP *******************************************************************************************************************************************
18.183.126.192             : ok=19   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
54.92.127.85               : ok=19   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```
`ok`か`changed`のみ数字があれば成功。`failed`や`unreachable`があれば失敗。

## 4.アプリケーションのデプロイ(手動)

:::message alert
後ほど`deployer`で権限周りと毎回のデプロイ先は整理するため、今回は暫定の設定。
:::


- プロジェクトのクローンと移動。
```shell:
ssh ec2-user@18.183.126.192 -i <EC2接続用のキーペア>
git clone https://github.com/tokku5552/php-docker-nginx-postgresql.git
sudo mv php-docker-nginx-postgresql /var/www/
cd /var/www/php-docker-nginx-postgresql/src
chmod 777 -R ./
composer install
```

### 5.Laravelの設定
- AWSコンソールマネージャーの検索窓で`Secrets Manager`と入力して`Secrets Manager`を開く。
![](https://storage.googleapis.com/zenn-user-upload/be08316eaa75-20220130.png)

- CFnで作成されたシークレットをクリックし、`シークレットの値を取得する`をクリック。
![](https://storage.googleapis.com/zenn-user-upload/fe6a80736022-20220130.png)

- シークレットの値の`password`と`host`を控えておく。
![](https://storage.googleapis.com/zenn-user-upload/1c35e857bb9c-20220130.png)


- サーバーに戻り、`/var/www/.env`ファイルを作成し記載
```shell:
pwd # /var/www/php-docker-nginx-postgresql/src
vim .env
```

- 以下のサンプルの中の`DB_HOST`を控えた`host`に、`DB_PASSWORD`を控えた`password`に修正する。

```ini:src/.env.example
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DRIVER=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1

MIX_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
MIX_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"

```

- php artisan migrate実行

```shell:
php artisan migrate
```

- php-fpmとnginxの再起動
```shell:
sudo systemctl stop nginx
sudo systemctl restart php-fpm
sudo systemctl start nginx
```

- 以下のように`curl`で200番が返ってくればOK
```shell:
curl --head localhost
HTTP/1.1 200 OK
Server: nginx/1.20.0
Content-Type: text/html; charset=UTF-8
Connection: keep-alive
X-Powered-By: PHP/7.4.26
...
```
- `EC2->ターゲットグループ->LaravelTargetGroup`をクリックし、設定した`EC2`の`Health status`が`healthy`になっていればOK
![](https://storage.googleapis.com/zenn-user-upload/71819f858ebc-20220130.png)

- 上記のデプロイ作業をもう一台のEC2でも行っておく。
:::message alert
ただし、.envは設定済みのEC2からコピーし、`php artisan migrate`も行わない。
:::

## 環境削除
CloudFormationのスタックを削除すれば環境一括削除ができます。

- awscliコマンドからそれぞれスタックを削除する
```bash:
cd CFn

# ApplicationStack
aws cloudformation delete-stack --stack-name LaravelApplication

# NetworkStack(ApplicationStackの削除完了後に実施)
aws cloudformation delete-stack --stack-name LaravelNetwork
```

- Cloud Formationのコンソールから該当のスタックが削除されることを確認します。
![](https://storage.googleapis.com/zenn-user-upload/fdd3ec8992f0-20220130.png)

# まとめ
Cloud FormationとAnsibleを使ってAWS上にLaravelの環境を構築する手順でした。手順だけでかなり長くなってしまったので、解説は別の記事で書こうと思います。


### 参考
https://qiita.com/ntm718/items/f896c8e4fb801777954b