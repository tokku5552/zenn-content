# Zenn CLI

- [📘 How to use](https://zenn.dev/zenn/articles/zenn-cli-guide)

## docker の起動関連

- コンテナを起動して shell に接続する

```
make up
```

- 起動済みのコンテナに接続するとき

```
make bash
```

- コンテナを停止するとき

```
make down
```

- コンテナの再起動
```
make restart
```

- コンテナの破棄
```
make destroy
```

# ファイル配置

- articles
  - example-article1.md
  - example-article2.md

# 記事作成
- コンテナ外から
```
make new-article
```
- コンテナのシェルから
```
npx zenn new:article --slug <slug> --title タイトル --type idea --emoji ✨
```

# プレビューする
- コンテナ外から
```
make preview
```

- コンテナのシェルから
```
npx zenn preview
```

# topic 一覧
こちらで探すと良い
https://zenn.dev/search

["AWS","React","Python","TypeScript","Docker","Flutter","GitHub","Next.js","Node.js","Android","Linux","Firebase","VSCode","Dart","Kotlin","Lambda","Ubuntu","Terraform"]
