# Zenn CLI

- [📘 How to use](https://zenn.dev/zenn/articles/zenn-cli-guide)

## docker の起動関連

- 起動してコンテナを起動する

```
docker-compose up
docker-compose run -p 8000:8000 node-container-zenn /bin/bash
```

- 起動済みのコンテナに接続するとき

```
docker ps
docker exec -i -t <CONTAINER ID> /bin/bash
```

- コンテナを停止するとき

```
docker-compose down
```

# ファイル配置

- articles
  - example-article1.md
  - example-article2.md

# 記事作成

```
npx zenn new:article
npx zenn new:article --slug <slug> --title タイトル --type idea --emoji ✨
```

# プレビューする

```
npx zenn preview
```

# topic 一覧

["AWS","React","Python","TypeScript","Docker","Flutter","GitHub","Next.js","Node.js","Android","Linux","Firebase","VSCode","Dart","Kotlin","Lambda","Ubuntu","Terraform"]
