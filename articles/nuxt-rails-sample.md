---
title: "【Nuxt x Rails】サンプルTODOアプリ - 概要"
emoji: "🕌"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: true
---
今回検証目的でフロントにNuxt、バックエンドにRails、インフラにAWSを使って以下のようなTODOアプリを作りました。
![](https://storage.googleapis.com/zenn-user-upload/cbc16aa9e5c1-20220405.png)
いくつかの記事に分けて紹介しようと思います。

# インフラ
- 構成図

![](https://storage.googleapis.com/zenn-user-upload/f1ae25c170be-20220403.png)

## ローカルはdockerで環境構築
ローカル開発はdockerで行っています。  
必要な環境変数は
```ini:
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```
です。
AWSCLIのアクセスIDとシークレットアクセスキーです。
appコンテナとwebコンテナを分けて作っていて、それぞれrailsとnuxtが動くようになっています。
更に`docker-compose.yml`でdbをmysqlのイメージをプルして作っています。
`docker compose up -d`と打てば起動しますが、私の好みで`Makefile`をつかって省略コマンドを定義しています。
- ターミナルに入りたければ
```bash:
# web
make ash
# app
make bash
```
- アプリを起動したければ
```bash
# web
make web
# app
make app
```
という感じです。

これでwebへは`http://localhost:3000`、appへは`http://localhost:8000`でアクセスできます。

## AWS CDKv2を使って`ALB+EC2+RDS`と`CloudFront+S3`の構成を作成
AWS CDKでインフラを構築しています。バックエンドとフロントエンドのスタックだけ分けて、以下の変数を環境変数から受け取る形にしています。

:::message
今回は`Route 53`上にホストゾーンが存在し、証明書も取得済みの前提です。
:::

```ini:cdk/.env.sample
HOSTED_ZONE_ID=
ZONE_NAME=
CERTIFICATE_ARN=
KEY_NAME=
```

使う場合は.env.sampleをコピーして.envとしたあとで、各種値を入れてください。
- `HOSTED_ZONE_ID` : Route 53上のホストゾーンのID
- `ZONE_NAME` : Route 53上のホストゾーン名
- `CERTIFICATE_ARN` : 登録済みの証明書のARN
- `KEY_NAME` : EC2で使用するSSHの鍵の名前を指定

更に今回はRDSのデータベースのパスワードを`SystemManager`に保存しているので、CDK実行前に登録しておいてください。(`your_db_password`をお好きなパスワードに変更して実行してください。)
```bash:
aws ssm put-parameter --name "RailsApiRDS" --value "your_db_password" --type "SecureString"
```

取得は以下のコマンドでできます。忘れたらこのコマンドで見てみましょう。
```bash:
aws ssm get-parameter --name "RailsApiRDS" --with-decryption
```

上記を設定したあと、cdkのデプロイは以下の用にコマンドを打てば実行できます。
```bash:
cd cdk
npx cdk deploy --all
```

## EC2の手動構築
今回はCDKでAWS側のインフラを構築したあと、EC2上の設定は手動で行いました。  
EC2では22番ポートは開放しておらず、SSM経由でSSHするようにしています。
### Session Managerプラグインのインストール
ローカルにAWSCLIが入っていて自分のアカウントにアクセスできることに加えて、SSMのプラグインをインストールしておく必要があります。

https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

- MacOSの場合
```bash:
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

- `~/.ssh/config`にSSM用の設定を追記する
```ini:.ssh/config
host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```

これでsshしたときのホスト名がi-から始まった場合(インスタンスIDを指定した場合)はssm経由でsshするようになります。

### EC2の構築手順
- 環境変数の設定
  - Capistranoの設定をしながら行うので、Rails側の環境変数を定義しておきます。
  - `api/.env.sample`をコピーして`api/.env`を作成
```ini:api/.env
TARGET_INSTANCE_ID=i-xxxxxxxxxxxxxxxxx
```
EC2のインスタンスIDを記載しておいてください。

- EC2へSSM経由でSSH
```bash:local
ssh ec2-user@<your_ec2_instance_id> -i <your_private_key>
# 例)
ssh ec2-user@i-xxxxxxxxxxxxxxxxxx -i ~/.ssh/kepair.pem
```

- EC2でのセットアップ
  - 色々一気にやっていますが、Railsアプリに必要なパッケージをインストールし、もともと入っているmariadbを削除、nginxとmysqlをインストールしています。
```bash:server
sudo yum -y update
sudo yum -y install git make gcc-c++ patch openssl-devel libyaml-devel libffi-devel libicu-devel libxml2 libxslt libxml2-devel libxslt-devel zlib-devel readline-devel ImageMagick ImageMagick-devel
sudo amazon-linux-extras install -y nginx1
sudo systemctl enable nginx
sudo systemctl start nginx
sudo yum -y remove mariadb-libs
sudo yum localinstall -y https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
sudo yum-config-manager --disable mysql80-community
sudo yum-config-manager --enable mysql57-community
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
sudo yum -y install mysql-community-client mysql-server mysql-devel
```

- RDSへ接続
```bash:server
mysql -h <your_rds_endpoint> -u api -p
# 例)
mysql -h dbid.xxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com -u api -p
```
接続できたら`exit`で抜けます。

- Rubyのインストール
```bash:server
git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
source ~/.bash_profile
git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 2.6.6
rbenv global 2.6.6
rbenv rehash
gem install bundler
```
Rubyのインストールは結構時間がかかります。

- デプロイ先の設定
```bash:server
sudo mkdir -p /var/www/api
sudo chown `whoami`:`whoami` /var/www/api
```

- gitの設定
```bash:server
cd .ssh
ssh-keygen -t rsa -f "api_git_rsa" -N ""
cat <<EOF > ~/.ssh/config
Host github github.com
  Hostname github.com
  User git
  IdentityFile ~/.ssh/api_git_rsa
EOF
chmod 600 config
```
その後`api_git_rsa.pub`をGitHubの`Settings -> SSH and GPG keys -> New SSH key`で登録

- RDSへの接続先情報登録
```bash:local
export AWS_ACCESS_KEY_ID=your_aws_access_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_access_key
make up
make bash # 以下はdockerのシェル
bundle install
EDITOR=vi rails credentials:edit
```

- viが開いたら以下のようにRDSのパスワードとエンドポイントを記載して`:wq`
```bash:dockerのshell
db:
  password: RDSのパスワード
  hostname: RDSのエンドポイント
```

- 一度デプロイを実行して必要フォルダを作ってからmaster.keyを配置
```bash:dockerのシェル
source .env
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production deploy

# 「ERROR linked file /var/www/api/shared/config/master.key does not exist on your_servername」
```
`master.key`が存在しない旨のエラーが出る

- scpにて送信する。`your_server_name`でsshの接続設定を行っておくと良い。
```bash:dockerｎシェル
scp config/master.key your_server_name:/var/www/api/shared/config
```

- pumaの設定
```bash:dockerのシェル
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production puma:config
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production puma:systemd:config puma:systemd:enable
```

- 再度デプロイ
```
TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production deploy
```

- nginx設定用のディレクトリを作成
```bash:sever
cd /etc/nginx
sudo mkdir sites-available
```

- nginxの設定をデプロイ
```bash:local
bundle exec cap production puma:nginx_config
```

- nginxを再起動して疎通確認
```bash:server
sudo systemctl restart nginx
curl -X GET http://localhost/v1/todos -v
```
以上で200番が返ってくればデプロイ成功です。


# バックエンド
バックエンドはRailsのAPIモードで作成しました。
- DBのスキーマ
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
今回はアプリとしては簡単でよかったので、`todos`テーブルに`content`と`state`を持つだけにしました。

- コントローラー
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
`todos`テーブルに対するCRUDがただ定義されているだけです。


# フロントエンド
Nuxt(SPA)で作成しています。
- index.vue
```vue:front/pages/index.vue
<template>
  <section class="container">
    <h1 class=".title">Todoリスト</h1>
    <v-container>
      <v-row>
        <v-col cols="12" sm="12" md="10">
          <v-text-field
            v-model="content"
            placeholder="タスクを入力してください"
            outlined
          />
        </v-col>
        <v-col cols="12" md="2">
          <v-btn elevation="2" @click="add"> 追加 </v-btn>
        </v-col>
      </v-row>
    </v-container>
    <v-btn elevation="2">全て</v-btn>
    <v-btn elevation="2">作業前</v-btn>
    <v-btn elevation="2">作業中</v-btn>
    <v-btn elevation="2">完了</v-btn>

    <v-simple-table>
      <template v-slot:default>
        <thead>
          <tr>
            <th class="text-left">タスク</th>
            <th class="text-left">状態</th>
            <th class="text-left">削除</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, index) in todos" :key="index">
            <td>{{ item.content }}</td>
            <td>
              <v-btn elevation="2" @click="update(item)">{{
                item.state
              }}</v-btn>
            </td>
            <td><v-btn elevation="2" @click="remove(item)">削除</v-btn></td>
          </tr>
        </tbody>
      </template>
    </v-simple-table>
  </section>
</template>

<script lang='ts'>
import Vue from 'vue'
import { Todo, State } from '../types/todo'
import { ThisTypedComponentOptionsWithRecordProps } from 'vue/types/options'

interface DataType {
  todos: Todo[]
  content: string
}
interface MethodType {
  fetch(): void
  add(): void
  update(): void
  remove(): void
}
interface ComputedType {}
interface PropType {}

export default Vue.extend({
  data(): DataType {
    return {
      todos: [],
      content: '',
    }
  },
  methods: {
    fetch() {
      this.$axios.$get('/v1/todos').then((res) => {
        console.log(res)
        this.todos = res as Todo[]
      })
    },
    add() {
      const todo: Todo = {
        content: this.content,
        state: State.planning,
      }
      this.$axios
        .$post('/v1/todos', {
          todo: todo,
        })
        .then((res) => {
          console.log(res)
          this.fetch()
        })
        .catch((err) => {
          console.log(err)
        })
    },
    update(todo: Todo) {
      switch (todo.state) {
        case State.planning:
          todo.state = State.doing
          break
        case State.doing:
          todo.state = State.done
          break
        case State.done:
          todo.state = State.planning
          break
        default:
          console.log('State error')
          return
      }
      this.$axios
        .$put(`/v1/todos/${todo.id}`, {
          todo: todo,
        })
        .then((res) => {
          console.log(res)
          this.fetch()
        })
        .catch((err) => {
          console.log(err)
        })
    },
    remove(todo: Todo) {
      this.$axios
        .$delete(`/v1/todos/${todo.id}`, {
          todo: todo,
        } as Object)
        .then((res) => {
          console.log(res)
          this.fetch()
        })
        .catch((err) => {
          console.log(err)
        })
    },
  },
  mounted: function () {
    this.fetch()
  },
} as ThisTypedComponentOptionsWithRecordProps<Vue, DataType, MethodType, ComputedType, PropType>)
</script>
```
`Vue`で`TypeScript`を使うための小細工をしていますが、それ以外は特殊なことはおこなっていません。  
UIは`Vuetify`を使っていて、`Vuex`は使用せずに、`methods`や`mounted`に直接動作を記述しています。

# CI/CD
GitHub Actionsで自動デプロイをしています。
リポジトリの`Secrets -> Actions`に以下のように、今までローカルで定義してきた環境変数などをセットしておきます。
![](https://storage.googleapis.com/zenn-user-upload/fce25438abf6-20220405.png)
- AWS_ACCESS_KEY_ID
  - awscliのアクセスID
- AWS_SECRET_ACCESS_KEY
  - awscliのシークレットアクセスキー
- CDK_ENV
  - cdk/.envの内容をそのままコピー
- DISTRIBUTION_ID
  - CloudFrontのDISTRIBUTI ID
- FRONT_ENV
  - front/.envの内容をそのままコピー
- RAILS_ENV
  - api/.envの内容をそのままコピー
- SSH_DEPLOY_KEY
  - EC2にアクセスするための鍵

上記をセットしたらあとは`main`にマージされたタイミングで3つのデプロイプロセスが順番に走ります。

```yaml:.github/workflows/workflow.yml
name: deploy prd

on:
  push:
    branches:
      - main

jobs:
  deploy_cdk:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup Node
        uses: actions/setup-node@v1
        with:
          node-version: "16.13.2"
      - name: cache
        uses: actions/cache@v2
        with:
          path: ./cdk/node_modules
          key: ${{ runner.OS }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.OS }}-node-
            ${{ runner.OS }}-
      - name: npm install
        working-directory: ./cdk
        run: npm install
      - name: cdk deploy
        working-directory: ./cdk
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          CDK_ENV: ${{ secrets.CDK_ENV }}
        run: |
          echo "$CDK_ENV" > .env
          npx cdk deploy --all
  deploy_rails:
    runs-on: ubuntu-latest
    needs: deploy_cdk
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: cache vendor
        id: cache
        uses: actions/cache@v2
        with:
          path: api/vendor/bundle
          key: ${{ runner.os }}-gems-${{ hashFiles('**/Gemfile.lock') }}
          restore-keys: |
            ${{ runner.os }}-gems-
      # Ruby をインストールする
      - name: Set up Ruby 2.6.6
        uses: ruby/setup-ruby@8f312efe1262fb463d906e9bf040319394c18d3e # v1.92
        with:
          ruby-version: 2.6.6
      # バンドラーをインストールし、初期化する
      - name: Bundle install
        working-directory: ./api
        run: |
          gem install bundler
          bundle config path vendor/bundle
          bundle install --jobs 4 --retry 3
      # awscliのインストール
      - name: install awscli
        working-directory: ./api
        run: |
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          sudo ./aws/install --update
          aws --version
          curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
          sudo dpkg -i session-manager-plugin.deb
      - name: setup ssh
        working-directory: ./api
        run: |
          # sshキーをコピー
          mkdir -p /home/runner/.ssh
          touch /home/runner/.ssh/MyKeypair.pem
          echo "${{ secrets.SSH_DEPLOY_KEY }}" > /home/runner/.ssh/MyKeypair.pem
          chmod 600 /home/runner/.ssh/MyKeypair.pem
      - name: deploy to EC2
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
          RAILS_ENV: ${{ secrets.RAILS_ENV }}
        working-directory: ./api
        run: |
          echo "$RAILS_ENV" > .env
          source .env
          TARGET_INSTANCE_ID=$TARGET_INSTANCE_ID bundle exec cap production deploy
  deploy_frond:
    runs-on: ubuntu-latest
    needs: deploy_rails
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup Node
        uses: actions/setup-node@v1
        with:
          node-version: "16.13.2"
      - name: cache
        uses: actions/cache@v2
        with:
          path: ./front/node_modules
          key: ${{ runner.OS }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.OS }}-node-
            ${{ runner.OS }}-
      - name: npm install
        working-directory: ./front
        run: |
          npm install -g yarn
          yarn install
      - name: front deploy
        working-directory: ./front
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ap-northeast-1
          AWS_DEFAULT_OUTPUT: json
        run: |
          yarn generate
          aws s3 sync dist s3://nuxt.s3bucket/ --include "*"
          aws cloudfront create-invalidation --distribution-id ${{ secrets.DISTRIBUTIN_ID }} --paths "/*"
```
- jobs
  - deploy_cdk
    - 基本的には頑張って`cdk deploy --all`がしたいだけです。
  - deploy_rails
    - Rubyのインストール、`bundle install`、AWSCLIのインストール(SessionManagerプラグインも)したあとに
    - capistranoでデプロイしています。
  - deploy_front
    - `nuxt generate`でNuxtアプリをビルドしたあとに、S3へアップロード->CloudFrontのキャッシュを削除しています。

うまく行けばこんな感じで`Status`が`Success`と表示されます🎉
![](https://storage.googleapis.com/zenn-user-upload/b8c403dd0e6c-20220405.png)

# まとめ
この記事ではざっくり上から手順を紹介する形としました。
詳細は各章のリンクをたどっていただければと思います。
初学者の方のポートフォリオ作成とかでまぁまぁある構成かなと思ったので、作ってみました。
おそらくCDKのところはいきなりだと難しいと思うので、そこは手動で構築しても良いかなと思います。