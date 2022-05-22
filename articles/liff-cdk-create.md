---
title: "AWS CDK x React でLIFFアプリを作る"
emoji: "📑"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["aws"]
published: false
---

```
mkdir liff-cdk-sample
npx cdk init app--language typescript
```
- `.gitignore`が作成されなかったので作って`node_modules`を追加しておく
- create-liff-appを実行
```vim:
% npx @line/create-liff-app
Welcome to the Create LIFF App
? Enter your project name:  liff-app
? Which template do you want to use? react
? JavaScript or TypeScript? TypeScript
? Please enter your LIFF ID: 
 Don't you have LIFF ID? Check out https://developers.line.biz/ja/docs/liff/getting-started/ liffId
? Do you want to install it now with package manager? Yes
? Which package manager do you want to use? yarn
yarn install v1.22.18
warning package.json: No license field
warning ../package.json: No license field
info No lockfile found.
warning liff-app@0.0.0: No license field
[1/4] 🔍  Resolving packages...
[2/4] 🚚  Fetching packages...
[3/4] 🔗  Linking dependencies...
[4/4] 🔨  Building fresh packages...
success Saved lockfile.
✨  Done in 18.74s.


Done! Now run: 

  cd liff-app
  yarn dev
```