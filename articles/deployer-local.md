---
title: "Laravelプロジェクトをdeployerを使ってEC2にデプロイする"
emoji: "📌"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["PHP","Laravel","AWS","deployer","EC2"]
published: true
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

# deployerのインストールとdep init
#### deployerのインストール
プロジェクトルートで以下のコマンドを実行します。
```shell:
composer require deployer/deployer --dev
```
`composer.json`の`require-dev`に`deployer/deployer`が追加されていればOKです。

#### dep initの実行
deployerがインストールできたら、`vendor/bin/dep init`を実行し初期化します。
今回は最初のproject typeは`1`を選択し、Repositoryは空のまま、統計情報の収集の許可的なものは`no`を選択しています。
```shell:
# vendor/bin/dep init

                                            
  Welcome to the Deployer config generator  
                                            


 This utility will walk you through creating a deploy.php file.
 It only covers the most common items, and tries to guess sensible defaults.
 
 Press ^C at any time to quit.

 Please select your project type [Common]:
  [0 ] Common
  [1 ] Laravel
  [2 ] Symfony
  [3 ] Yii
  [4 ] Yii2 Basic App
  [5 ] Yii2 Advanced App
  [6 ] Zend Framework
  [7 ] CakePHP
  [8 ] CodeIgniter
  [9 ] Drupal
  [10] TYPO3
 > 1

 Repository []:
 > 

 Contribute to the Deployer Development
 
 In order to help development and improve the features in Deployer,
 Deployer has a setting for usage data collection. This function
 collects anonymous usage data and sends it to Deployer. The data is
 used in Deployer development to get reliable statistics on which
 features are used (or not used). The information is not traceable
 to any individual or organization. Participation is voluntary,
 and you can change your mind at any time.
 
 Anonymous usage data contains Deployer version, php version, os type,
 name of the command being executed and whether it was successful or not,
 exception class name, count of hosts and anonymized project hash.
 
 If you would like to allow us to gather this information and help
 us develop a better tool, please add the code below.
 
     set('allow_anonymous_stats', true);
 
 This function will not affect the performance of Deployer as
 the data is insignificant and transmitted in a separate process.

 Do you confirm? (yes/no) [yes]:
 > no

Successfully created: /work/src/deploy.php
```

以上の初期化が終わると、以下のような`deploy.php`が生成されます。

```php:deploy.php
<?php
namespace Deployer;

require 'recipe/laravel.php';

// Project name
set('application', 'my_project');

// Project repository
set('repository', '');

// [Optional] Allocate tty for git clone. Default value is false.
set('git_tty', true); 

// Shared files/dirs between deploys 
add('shared_files', []);
add('shared_dirs', []);

// Writable dirs by web server 
add('writable_dirs', []);
set('allow_anonymous_stats', false);

// Hosts

host('project.com')
    ->set('deploy_path', '~/{{application}}');    
    
// Tasks

task('build', function () {
    run('cd {{release_path}} && build');
});

// [Optional] if deploy fails automatically unlock.
after('deploy:failed', 'deploy:unlock');

// Migrate database before symlink new release.

before('deploy:symlink', 'artisan:migrate');

```

# deploy.phpの編集
この`deploy.php`に必要情報を定義していきます。
ターゲット情報を`server.yml`として外だししたため、不要な情報を削除して、最低限必要な情報のみ修正します。

```php:deploy.php
<?php
namespace Deployer;

require 'recipe/laravel.php';

// Project name
set('application', 'php-docker-nginx-postgresql');

// [Optional] Allocate tty for git clone. Default value is false.
set('git_tty', false); 

// Shared files/dirs between deploys 
add('shared_files', []);
add('shared_dirs', []);

// Writable dirs by web server 
add('writable_dirs', []);
set('allow_anonymous_stats', false);
    
inventory('servers.yml');

// Tasks

task('build', function () {
    run('cd {{release_path}} && build');
});

// [Optional] if deploy fails automatically unlock.
after('deploy:failed', 'deploy:unlock');

// Migrate database before symlink new release.

before('deploy:symlink', 'artisan:migrate');

after('deploy:update_code', 'set_release_path');
task('set_release_path',function() {
    $newReleasePath = get('release_path') . '/src';
  set('release_path', $newReleasePath);
});
```

`inventory('servers.yml');`とすることで、yamlファイルにターゲットの情報を記載することができます。
また、今回プロジェクトルートからlaravelのソースまで、1階層下る必要があったので、`set_release_path`というタスクで`release_path`を書き換えています。

`sever.yml`はこんな感じで定義します。(ALBの操作を後で入れるので、target_group_arnとinstance_idもセットしておきます。)
使う場合は`hostname`のIPアドレスや`target_group_arn`、`instance_id`はそれぞれご自身のものに書き換えてください。
```yaml:server.yml
LaravelWeb1:
  hostname: 111.111.111.111
  stage: LaravelWeb1
  user: ec2-user
  port: 22
  identityFile: ~/.ssh/MyKeypair.pem
  deploy_path: /var/www/
  branch: main
  repository: https://github.com/tokku5552/php-docker-nginx-postgresql.git
  target_group_arn: arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  instance_id: i-xxxxxxxxxxxxxxxxx
LaravelWeb2:
  hostname: 222.222.222.222
  stage: LaravelWeb2
  user: ec2-user
  port: 22
  identityFile: ~/.ssh/MyKeypair.pem
  deploy_path: /var/www/
  branch: main
  repository: https://github.com/tokku5552/php-docker-nginx-postgresql.git
  target_group_arn: arn:aws:elasticloadbalancing:ap-northeast-1:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  instance_id: i-xxxxxxxxxxxxxxxxx
```

`deployer`では`stage`ごとにデプロイを行えるのですが、今回はローリングアップデートを行いたいので、1台ずつデプロイできるようにターゲットと`stage`を同じにしています。

この状態で一度`vendor/bin/dep deploy LaravelWeb1`コマンドを実行して、デプロイしてみます。
すると`artisan:migrate`で以下のようなエラーが出ます。
```shell:
In Client.php line 103:
                                                                                       
  The command "/usr/bin/php /var/www//releases/1/src/artisan migrate --force" failed.  
                                                                                       
  Exit Code: 1 (General error)                                                         
                                                                                       
  Host Name: LaravelWeb1                                                               
                                                                                       
  ================                                                                     
                                                                                       
  In Connection.php line 703:                                                          
                                                                                       
    SQLSTATE[HY000] [2002] Connection refused (SQL: select * from information_s        
    chema.tables where table_schema = forge and table_name = migrations and tab        
    le_type = 'BASE TABLE')                                                            
                                                                                       
                                                                                       
  In Connector.php line 70:                                                            
                                                                                       
    SQLSTATE[HY000] [2002] Connection refused                                          
```
これはただしくRDSに接続できていないということですので、`EC2`にログインし、`.env`を書き換えてあげます。
```shell:
cd /var/www/shared
vim .env
```
もう一度実行すれば正しくデプロイが通ると思います。

# ドキュメントルートの変更
一度`EC2`でデプロイされた場所を見てみます。
```shell:/var/www
[ec2-user@ip-10-0-1-146 www]$ ll
合計 0
lrwxrwxrwx 1 ec2-user ec2-user  10  2月  7 12:50 current -> releases/3
drwxrwxr-x 5 ec2-user ec2-user 176  1月 30 09:14 php-docker-nginx-postgresql
drwxrwxr-x 5 ec2-user ec2-user  33  2月  7 12:50 releases
drwxrwxr-x 3 ec2-user ec2-user  33  2月  5 16:22 shared
```

もともと`php-docker-nginx-postgresql`というフォルダの`src/public`をドキュメントルートとしていましたが、deployerでは`deploy_path`の下に`current`,`releases`,`shared`というフォルダが作成され、最新版は常に`current`に置かれることになります。ですのでドキュメントルートも`current`の下を指すように修正する必要があります。

`nginx`の設定ファイルを以下のように書き換えてあげます。
```ini:nginx.conf
    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root          /var/www/current/src/public;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;
```

ちなみに`shared`にはデプロイを行っても常に共有されるファイル(先程の.envファイルや、ログファイルなど)が置かれ、`releases`にはデプロイされたフォルダが順番に置かれ一定個数保持されます。(デフォルト5つ)

# ALBからの切り離しと再登録を前後に挟む


deployerでもローリングアップデートが行いたいので、ALBからの切り離しと再登録を前後にはさむよう修正します。`AWSCLI`のコマンドは以下の記事を参考にします。

https://zenn.dev/tokku5552/articles/aws-target-group-desc

```php:deploy.php
before('deploy:info', 'deregister-targets');
task('deregister-targets', function () {
  runLocally('aws elbv2 deregister-targets --target-group-arn {{target_group_arn}} --targets Id={{instance_id}}');
});

after('deploy:unlock', 'register-targets');
task('register-targets', function () {
  runLocally('aws elbv2 register-targets --target-group-arn {{target_group_arn}} --targets Id={{instance_id}},Port=80 ');
});
```

deployerでは上記の様に`task()`を使って自分でタスクを定義することができます。`runLocally()`はサーバー側ではなくローカル側でコマンドを実行します。
`{{target_group_arn}}`のように2つのカッコでくくって変数を呼び出します。`server.yml`に定義すれば他の変数も使うことができます。

`deregister`の方は`deploy:info`の前に実行、`register`の方は`deploy:unlock`のあとに実行しています。
どのタイミングで差し込むかについては、以下にLaravelのレシピが乗っているので、こちらをみるとdeployコマンドの中で実際にどんなタスクが実行されているのかを確認することができ、差し込む場所を決める参考になります。

https://github.com/deployphp/deployer/blob/6.x/recipe/laravel.php

## 実行
1台ずつALBから切り離し->デプロイ->ALBへ再登録を行うことができます。
以下は実行例です。(コンテナ内から実行しています)

```shell:
root@a17eaed259b0:/work/src# vendor/bin/dep deploy LaravelWeb2
✔ Executing task deregister-targets
✈︎ Deploying main on 18.181.224.249
✔ Executing task deploy:prepare
✔ Executing task deploy:lock
✔ Executing task deploy:release
✔ Executing task deploy:update_code
✔ Executing task set_release_path
✔ Executing task deploy:shared
✔ Executing task deploy:vendors
✔ Executing task deploy:writable
✔ Executing task artisan:storage:link
✔ Executing task artisan:view:cache
✔ Executing task artisan:config:cache
✔ Executing task artisan:optimize
✔ Executing task artisan:migrate
✔ Executing task deploy:symlink
✔ Executing task deploy:unlock
✔ Executing task register-targets
✔ Executing task cleanup
Successfully deployed!
```

# まとめ
ローカル環境からdeployerを使って`EC2`へローリングアップデートを行う方法を紹介しました。
次は、これを`GitHub Actions`に乗せて`CI/CD`を組みたいと思います。

### 参考

- [GitHub Actions × Laravel × Deployerで自動デプロイ - Qiita](https://qiita.com/koyablue/items/a809f86ca934de52f206)
- [Deployerでサブディレクトリをデプロイする - Qiita](https://qiita.com/grohiro/items/ec516762e61d9dbdf126)
- [deployer/laravel.php at 6.x · deployphp/deployer](https://github.com/deployphp/deployer/blob/6.x/recipe/laravel.php)
- [CloudFormationとAnsibleでALB+EC2+RDSのLaravel環境を構築する(手順編)](https://zenn.dev/tokku5552/articles/create-php-env-with-cfn)
- [AWS CLI v2 をdockerで使えるようにする](https://zenn.dev/tokku5552/articles/aws-container)