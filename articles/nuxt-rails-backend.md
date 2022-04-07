---
title: "【Nuxt x Rails】サンプルTODOアプリ - Rails編"
emoji: "🔥"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: true
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

# Railsアプリの作成
今回はRailsアプリの作成からdocker上で行いましたが、ローカルに直接インストールしたrubyを使っても構築は可能です。
<!-- docker編のURL -->
Railsがインストールされた状態で以下のコマンドを使ってRailsのアプリをAPIモードで作成します。
```
rails new api --database=mysql --skip-bundle --api
```

- その後dbの環境も構築が終わっていれば以下のコマンドで環境構築は完了です。(dockerの場合はそのままコマンド実行でOK)
```
bundle install
bundle exec rails db:create
```

- 以下のコマンドでモデルの追加を行います。todoというテーブルを作成します。
```bash:
$ rails g model todo
Running via Spring preloader in process 633
      invoke  active_record
      create    db/migrate/20220321130738_create_todos.rb
      create    app/models/todo.rb
      invoke    test_unit
      create      test/models/todo_test.rb
      create      test/fixtures/todo.yml
```

- 作成された`api/db/migrate/20220321130738_create_todos.rb`ファイルを編集してスキーマを定義します。
```ruby:api/db/migrate/20220321130738_create_todos.rb
class CreateTodos < ActiveRecord::Migration[6.1]
  def change
    create_table :todos do |t|
      t.string  :content # 追加
      t.string  :state # 追加
      t.timestamps
    end
  end
end
```

- 上記のマイグレーションファイルを実行します
```
$ rake db:migrate
== 20220405004625 CreateTests: migrating ======================================
-- create_table(:tests)
   -> 0.0933s
== 20220405004625 CreateTests: migrated (0.0937s) =============================
```

- すると`schema.rb`が以下のように変更されます。
```ruby:api/db/schema.rb
ActiveRecord::Schema.define(version: 2022_03_21_130738) do

  create_table "todos", charset: "utf8mb4", force: :cascade do |t|
    t.string "content"
    t.string "state"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end
```

- また、環境を動かす際に予め値が入っておいたほうが都合が良い場合は`seeds.rb`に記載しておきます。
```ruby:api/db/seeds.rb
todos = Todo.create([{content: 'テスト', state: '作業中'}])
```

- これをdbに流すために以下のコマンドを実施します。
```bash:
rails db:seed
```

- 次にコントローラーを追加します。
```bash:
$ rails g controller v1/todos
Running via Spring preloader in process 690
      create  app/controllers/v1/todos_controller.rb
      invoke  test_unit
      create    test/controllers/v1/todos_controller_test.rb
```

- 作成されたコントローラーを修正します。今回は単純なCRUDのみを記載しています。
```ruby:api/app/controllers/v1/todos_controller.rb
class V1::TodosController < ApplicationController
    before_action :set_post, only: %i[show destroy update]

    def index
        todos = Todo.all.order(:id)
        render json: todos
    end

    def show
        render json: @todo
    end

    def create
        todo = Todo.new(todo_params)
        if todo.save
            render json: todo
        else
            render json: todo.errors
        end
    end

    def update
      if @todo.update(todo_params)
        render json: @todo
      else
        render json: @todo.errors
      end
    end
    
    def destroy
      if @todo.destroy
        render json: @todo
      else
        render json: @todo.errors
      end
    end
    
    private

    def set_post
      @todo = Todo.find(params[:id])
    end
  
    def todo_params
      params.require(:todo).permit(:content, :state)
    end
end
```

- さらにルーティングを以下のように追加します。各メソッドに対して許可しています。
```ruby:api/config/routes.rb
Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  namespace :v1 do
    resources :todos, only: %i[index show create update destroy]
  end
end
```

# 実行
- 完成したら`rails s`コマンドで起動して実行してみましょう。
```bash:
$ rails s -p 8000 -b '0.0.0.0'
=> Booting Puma
=> Rails 6.1.5 application starting in development 
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Puma version: 5.6.4 (ruby 2.6.6-p146) ("Birdie's Version")
*  Min threads: 5
*  Max threads: 5
*  Environment: development
*          PID: 626
* Listening on http://0.0.0.0:8000
Use Ctrl-C to stop
```
上記の様に表示されたら別のターミナルからリクエストを送ってみます。
今回のスキーマに合わせてテスト用のjsonを以下のように用意しています。
```json:api/message_body/body.json
{
    "todo": {
        "content": "テスト from json",
        "state": "作業中"
    }
}
```
それぞれ期待した値が返却されることをここで確認しておきましょう。

- get
```bash:
$ curl -X GET http://localhost:8000/v1/todos
```

- show
```bash:
curl -X GET http://localhost:8000/v1/todos/1
```

- create
```bash:
curl -H "Accept: application/json" \
     -H "Content-Type: application/json" \
     -d @message_body/body.json \
     -X POST http://localhost:8000/v1/todos
```

- update
```bash:
curl -H "Accept: application/json" \
     -H "Content-Type: application/json" \
     -d @message_body/body.json \
     -X PUT http://localhost:8000/v1/todos/1
```

- delete
```bash:
curl -H "Accept: application/json" \
     -H "Content-Type: application/json" \
     -d @message_body/body.json \
     -X DELETE http://localhost:8000/v1/todos/1
```

- `rails s`したターミナルではログが表示されます。
![](https://storage.googleapis.com/zenn-user-upload/6d9bf89620c8-20220405.png)

# Capistranoの定義
- Gemfileの`group :development do`の中に以下を追加します。
```ruby:api/Gemfile
group :development do
  gem 'listen', '~> 3.3'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem "capistrano", "~> 3.10", require: false
  gem "capistrano-rails", "~> 1.6", require: false
  gem 'capistrano-rbenv', '~> 2.2'
  gem 'capistrano-rbenv-vars', '~> 0.1'
  gem 'capistrano3-puma'
end
```

- bundle installします
```bash:
bundle install
bundle exec cap install STAGES=production
```

- 作成された`Capfile`に以下を追加します。
```ruby:api/Capfile
require 'capistrano/rbenv'
require 'capistrano/bundler'
require 'capistrano/rails/migrations'
require 'capistrano/puma'
install_plugin Capistrano::Puma
install_plugin Capistrano::Puma::Systemd
install_plugin Capistrano::Puma::Nginx
```

- deployの設定ファイルを修正します。
  - `application`、`repo_url`、`branch`、`deploy_to`はご自身の物に読み替えてください。
```ruby:api/config/deploy.rb
set :application, "api"
set :repo_url, "git@github.com:tokku5552/nuxt-rails-sample.git"
set :rbenv_ruby, File.read('.ruby-version').strip
set :branch, ENV['BRANCH'] || "main"
set :nginx_config_name, "#{fetch(:application)}.conf"
set :nginx_sites_enabled_path, "/etc/nginx/conf.d"
set :deploy_to, '/var/www/api'
```

- 接続情報を記載します。今回ターゲットはcdkでEC2を作り直すたびに変わるので、環境変数で受け取っています。
```ruby:api/config/deploy/production.rb
server ENV['TARGET_INSTANCE_ID'], user: "ec2-user", roles: %w{app db web}

require 'net/ssh/proxy/command'
set :ssh_options, {
  proxy: Net::SSH::Proxy::Command::new("aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"),
  keys: %w(~/.ssh/MyKeypair.pem),
  forward_agent: true,
  auth_methods: %w(publickey),
}
```
今回SSM経由でのSSH接続を行うので、`require 'net/ssh/proxy/command'`を追加した上で、`ssh_options`に`proxy`のコマンドを渡しています。
参考：[ステップ 8: (オプション) Session Manager を通して SSH 接続のアクセス許可を有効にして制御する - AWS Systems Manager](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)
また、環境変数は`api/.env.sample`をコピーして`api/.env`を作成し、実際のターゲットを記載します。
```ini:api/.env
TARGET_INSTANCE_ID=i-xxxxxxxxxxxxxxxxx
```

- DBへの接続情報を記載します。以下のコマンドで`api/config/credentials.yml.enc`に暗号化された状態で接続情報を記載できます。
  - このファイルは`master.key`がないと復号できない様になっており、`credentials.yml.enc`自体はgit管理下にしておいてdeployの設定ファイルで指定したブランチにプッシュしておきます。
```bash:
EDITOR=vi rails credentials:edit
# viが開くので以下のように編集して :wq で上書き保存
db:
  password: RDSのパスワード
  hostname: RDSのエンドポイント
```
RDSのパスワードは今回の私の構成と同じCDKを使いたい場合はSSMに保存してあるはずなので、以下で取得します。
```bash
aws ssm get-parameter --name "RailsApiRDS" --with-decryption
```
<!-- TODO: ここのパラメータストアの説明記事を書いても良いかもしれない -->
エンドポイントは`RDS -> データベース -> DB識別子`のページの`接続とセキュリティ`タブから確認できます。
![](https://storage.googleapis.com/zenn-user-upload/713105cd93fa-20220406.png)

- 初回に一度デプロイを実行して必要なファイルを作成しておきます。
```
source .env
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production deploy
```

- 上記だとおそらく`master.key`が存在しないエラーが出るので配置してから再度デプロイを実行します。
  - 鍵を指定しながらのscpだとうまく行かなかったので、`~/.ssh/config`に接続情報を記載しておいて、定義したホスト名のみでアクセスできるようにしておきます。
```
Host railstest
  Hostname i-xxxxxxxxxxxxxxx
  User ec2-user
  IdentityFile キーペア名
  ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```
上記の設定はsshやscpでサーバー名に`railstest`と指定した場合、実際には`ec2-user@i-xxxxxxxxxxxxxxx -i キーペア名`でProxyCommandで指定したコマンドをプロキシとして実行しながら接続しに行きます。

- 改めて`master.key`を配置して`puma`のコンフィグを実行します。
```
scp config/master.key your_server_name:/var/www/api/shared/config
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production puma:config
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production puma:systemd:config puma:systemd:enable
```
上記コマンドの`your_server_name`は`~/.ssh/config`で指定したサーバー名に変更して実行ください。

- 再度デプロイすれば成功するはずです。
```
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production deploy
```

- デプロイは今後上記のコマンドを実行するだけで良いですが、実際に動作させるには更にnginxの設定を行います。
```bash:ec2
cd /etc/nginx
sudo mkdir sites-available
```
```bash:local
bundle exec cap production puma:nginx_config
```
```bash:ec2
sudo systemctl restart nginx
curl -X GET http://localhost/v1/todos -v
```
上記の`curl`コマンドで200が返ってくればOK

# まとめ
今回始めてAPIモードでのRailsに触れたのですが、かなり簡単に実装できました。
CRUDしか実装しませんでしたが、Rails自体はフルスタックなWebフレームワークなので実際にはもっと自由度が高いです。
どうしてもコード量が多くなってしまいますが、Laravelともフォルダ構造が似ているので、慣れればわかりやすいのかなと思いました。

### 参考
- [【Nuxt x Rails】サンプルTODOアプリ - 概要](https://zenn.dev/tokku5552/articles/nuxt-rails-sample)
- [サルでもできる!? Rails6 のアプリをAWS EC2にデプロイするまでの全手順【前半】（VPC, RDS, EC2, Capistrano） - Qiita](https://qiita.com/take18k_tech/items/5710ad9d00ea4c13ce36#6-%E3%83%87%E3%83%97%E3%83%AD%E3%82%A4capistrano)
- [ステップ 8: (オプション) Session Manager を通して SSH 接続のアクセス許可を有効にして制御する - AWS Systems Manager](https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)