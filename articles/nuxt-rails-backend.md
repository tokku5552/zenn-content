---
title: "【Nuxt x Rails】サンプルTODOアプリ - Rails編"
emoji: "🔥"
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
# まとめ