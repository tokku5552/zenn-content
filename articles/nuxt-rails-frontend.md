---
title: "【Nuxt x Rails】サンプルTODOアプリ - Nuxt編"
emoji: "😎"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws","nuxt","awscdk","rails","githubactions"]
published: true
---
今回検証目的でフロントにNuxt、バックエンドにRails、インフラにAWSを使って以下のようなTODOアプリを作りました。
![](https://storage.googleapis.com/zenn-user-upload/cbc16aa9e5c1-20220405.png)
この記事ではNuxtに関する解説を行います🙋‍♂️
- 以下の記事で全体の解説を行っています。

https://zenn.dev/tokku5552/articles/nuxt-rails-sample

- 全ソースコードはこちら

https://github.com/tokku5552/nuxt-rails-sample

# 環境
- ローカル(docker)
```bash:
# node -v
v16.14.2
# npm -v
8.5.5
# yarn -v
1.22.18
```

- インフラ構成図

![](https://storage.googleapis.com/zenn-user-upload/f1ae25c170be-20220403.png)

# プロジェクトの作成
Docker環境を起動したら(or node,npm,yarnをインストールしたら)以下のコマンドでプロジェクトが作成できます。
```
npx create-nuxt-app front
```

dockerについては[こちら](https://zenn.dev/tokku5552/articles/nuxt-rails-docker)の記事参照


このあといろいろと聞かれるのですが、以下の部分以外はデフォルトで回答としました。
- `Choose programing language (Use arrow keys)`
  - `TypeScript`
- `Choose rendering mode (Use arrow keys)`
  - `Single Page App`

結局`axios`や`Vuetify`を使うことにしたのですが、これらはあとから入れました。

# `front/pages/index.vue`
今回は極シンプルに、`index.vue`のみを修正して作成しています。コンポーネントに分けたりstoreを作ったりはしていません。(typeだけは別ファイルで定義しました)
style部分も定義していません。
::: details 全コード
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
:::

## template
template部分ですが、冒頭の画面のようなものを作っています。
vuetifyでのみスタイルを定義して、cssは使っていません。
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
```
## script
script部分に行く前に、型定義を載せておきます。
```ts:front/types/todo.ts
export type Todo = {
    id?: number,
    content: string
    state: string
}

export const State = {
    planning: '作業前',
    doing: '作業中',
    done: '完了'
}
```

本題のscriptですが、`Vuex`などを使ってないので、これだけシンプルな機能でも少し長くなってます。
メインの部分は`export default Vue.extend`の中です。
```vue:front/pages/index.vue
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
画面の状態としては`todos: []`と`content: ''`のみを保持しており、一覧用のリストと追加用のコンテンツ保持用です。
一通り`fetch`、`add`、`update`、`remove`を実装していて、マウント時は`fetch`が呼ばれるようになっています。

また、3つある`interface`の記載と、最後の`as ThisTypedComponentOptionsWithRecordProps<Vue, DataType, MethodType, ComputedType, PropType>)`という記述は、`vue`上でTypeScriptの型を正しく扱えるようにするための記述です。

# まとめ
勉強のためというか検証のためにNuxt(Vue)を初めて触りましたが、型にはまればかなり素早く構築できるものの、少し扱いづらいところもありました。(上記のTypeScriptに対応させる記述とか)
Reactのように、取り敢えずhooks使っておけば良いみたいなものはなく、おそらくVuexがスタンダードなんでしょうが、この規模のアプリでFlux系はしんどいなと思い、辞めました。
本当はデファクトスタンダードになりつつある状態管理手法があるのかもしれませんが、表面だけさらっと触ったくらいの私には見つけられませんでした😢