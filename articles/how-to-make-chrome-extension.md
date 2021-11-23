---
title: "Reactでサクッとchromeの拡張機能をつくる"
emoji: "👌"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["React","chrome","JavaScript","TypeScript","GitHub"]
published: true
---
現在エンジニアの採用に関わる仕事をやることがあるのですが、その際にGitHubのページのリンクを貼ってくれているのはいいものの、どんな言語が得意なのか、などの指標がなく[GitHub Readme Stats](https://github.com/anuraghazra/github-readme-stats)をみんなはってくれたらいいのにな～  
と思ったので、chrome拡張機能で表示できるようにしました
![screen](https://user-images.githubusercontent.com/69064290/142964241-0e132aa8-4317-45d1-a3b3-a55ecc0fffbc.png)

- 作った拡張機能
  - GitHub Language Stats

https://github.com/tokku5552/github-language-extension

- 使い方

現在審査に出している最中なので、上記のリポジトリをクローンしていただき、`npm install`した後`npm run build`でビルドすると、`dist`フォルダが出来上がります。
`dist`フォルダをchromeの拡張機能の`パッケージ化されていない拡張機能を読み込む`というところで指定すると、使えるようになります。

:::message alert
注意点としてchromeの拡張機能の管理画面で画面右上にある`デベロッパーモード`をONにしておく必要があります。
:::

## React + TypeScriptで作る
Chrome拡張は所詮JavaScriptなので、TypeScriptで開発出来ますし、VueやReactも使えます。
今回は簡単な機能しかないものの、簡潔に書けるReactで作ることにしました。
[こちらのレポジトリ](https://github.com/tokku5552/chrome-extension-sample)をコピーすると`npm + webpack`でReactを使ったChrome拡張のサンプルが出来ますので、Starterのように使っていただければと思います。

- manifest.json

chrome拡張では、`manifest.json`で、名前やバージョンの他、いつ起動するか、どんな権限が必要か等を設定することが出来ます。
どのようなことが設定できるかは[公式のドキュメント](https://developer.chrome.com/docs/extensions/)を参考にしてください。

私が作った拡張機能では以下のように設定しています。
```json:manifest.json
{
  "manifest_version": 3,

  "name": "GitHub Language Stats",
  "description": "Chrome Extension Sample",
  "version": "1.0",

  "action": {
    "default_icon": "icon.png",
    "default_popup": "popup.html"
  },
  "content_scripts": [
      {
          "matches": ["<all_urls>"],
          "js": ["js/vendor.js", "js/content_script.js"]
      }
  ],

  "host_permissions": [
    "<all_urls>"
  ]
}

```

popupが開くだけの簡単なものです。URLを見てGitHubのページかどうか判断してユーザー名を取得しているので、`host_permissions`を`<all_urls>`としています。

## Reactで作っている部分
かなり突貫で作ったので、いらないものも色々と残っていますが、機能しているのは実質`popup.tsx`のみです。

以下がコードになります。ところどころ解説コメントをいれています。

```tsx:popup.tsx
import React, { useEffect, useState } from "react";
import ReactDOM from "react-dom";
import axios, { AxiosResponse } from "axios"; // APIを叩くのにaxiosを使用
import { useForm } from "react-hook-form"; // formを使うためにreact-hook-formを使用

// GitHubのユーザー名を取得するための型
// GitHubのページに居れば自動的にユーザー名を取得し
// それ以外のページではフォームにユーザー名を入力すれば、結果を表示することが出来る。
type FormData = {
  username: string;
};

const Popup = () => {
  const [username, setUsername] = useState<string>("");
  const [currentStats, setCurrentStats] = useState<AxiosResponse>();
  const [currentTopLanguage, setCurrentTopLanguage] = useState<AxiosResponse>();
  const {
    register,
    setValue,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>();

  // フォームに直接ユーザー名を入れてsubmitしたときに走る関数
  const onSubmit = handleSubmit((data) => {
    console.log(data["username"]);
    setUsername(data["username"]);
  });

  // useEffectは2つに分けている。こちらは初期化時のみに発火
  useEffect(() => {
    // chrome.**でchrome extension特有の動作を行える。詳しくは公式ドキュメント参照。
    // ここではアクティブなタブのURLを取得して
    // GitHubのユーザー名を取得してusernameにセットしている
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      const currentURL = tabs[0].url as string;
      const name = getGitHubUsername(currentURL) as string;
      setUsername(name);
      setValue("username", name);
    });
  }, []);

  // こちらはusernameを監視しているuseEffect
  // useEffect内で非同期処理したいときは、関数を別にして後から呼ぶようにする
  useEffect(() => {
    const fetch = async (username: string) => {
      const stats = await getGitHubStats(username);
      const lang = await getGitHubTopLanguage(username);
      setCurrentTopLanguage(lang);
      setCurrentStats(stats);
    };
    console.log(username);
    // usernameが空かundefinedの時はfetchしないようにする
    // これやらないと初回のusernameのfetch処理と、username取得後のfetchと
    // 処理が2回走って、たいていはエラーになる方が後から返却されるので
    // 表示もエラーになる
    if (username !== "" && username !== undefined) {
      console.log(username);
      fetch(username);
    }
  }, [username]);

  // statsのAPI叩いているだけ。将来的には他のパラメータを選択出来るようにしたい。
  const getGitHubStats = async (username: string) => {
    const response = await axios.get(
      `https://github-readme-stats.vercel.app/api?username=${username}&count_private=true&show_icons=true`
    );
    return response;
  };

  // top-langsのAPI叩いているだけ。こちらもレイアウトとか変えれるようにすると良さそう。
  const getGitHubTopLanguage = async (username: string) => {
    const response = await axios.get(
      `https://github-readme-stats.vercel.app/api/top-langs/?username=${username}&layout=compact`
    );
    return response;
  };

  // ここはchrome.tab~~で受け取ったurlをstring -> urlObjに変換して、hostnameを取得
  // そのあともしそれがgithub.comだったらその次のURLに含まれるユーザー名を取得している
  // GitHubじゃなかったらundefined
  const getGitHubUsername = (url: string) => {
    const urlObj = new URL(url);
    console.log(urlObj.hostname);
    if (urlObj.hostname === "github.com") {
      return urlObj.pathname.split("/")[1];
    }
  };

  return (
    <>
      <h1>GitHub Language Stats Extension</h1>
      <div dangerouslySetInnerHTML={{ __html: currentStats?.data }} />
      <div dangerouslySetInnerHTML={{ __html: currentTopLanguage?.data }} />
      <form onSubmit={onSubmit}>
        <label>GitHub username </label>
        <!-- ここでreact-hook-formを使っている -->
        <input {...register("username")} placeholder="GitHub username" />
        <input type="submit" />
      </form>
    </>
  );
};

ReactDOM.render(
  <React.StrictMode>
    <Popup />
  </React.StrictMode>,
  document.getElementById("root")
);
```

## まとめ
フォームが生HTMLのままという何とも言えない感じなので、そのうち`Chakra UI`でも当てて綺麗にしようと思います。
Chrome拡張機能の公開自体も他に記事がたくさんあるし、それを見てれば基本困ることはなかったので、特にこの記事では言及しません。**$5**くらいかかります。

[publicリポジトリとして公開している](https://github.com/tokku5552/github-language-extension)ので、気に入った方はお使いいただくなり、PR送ったりして頂けると嬉しいです！
Issueでのバグ報告もお待ちしております!

## 参考

https://qiita.com/RyBB/items/32b2a7b879f21b3edefc

https://github.com/tokku5552/github-language-extension