---
title: "dep"
emoji: "📌"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["PHP","Laravel","AWS","deployer","EC2"]
published: false
---

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

# deployerのインストールとdep init
#### deployerのインストール
プロジェクトルートで以下のコマンドを実行します。
```shell:
composer require deployer/deployer --dev
```
`composer.json`の`require-dev`に`deployer/deployer`が追加されていればOKです。

#### dep initの実行

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

# deploy.phpの編集

- 初期状態
```php:
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

- 初回のデプロイでartisan:migrateで以下のエラーが出る。
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

`EC2`にログインし、`.env`を書き換えればOK

[GitHub Actions × Laravel × Deployerで自動デプロイ - Qiita](https://qiita.com/koyablue/items/a809f86ca934de52f206)
[Deployerでサブディレクトリをデプロイする - Qiita](https://qiita.com/grohiro/items/ec516762e61d9dbdf126)