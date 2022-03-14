---
title: "LINE APIの個人検証環境を作る"
emoji: "🦁"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["line","手順","web","api","個人開発"]
published: true
---

## LINEのプロバイダーとチャネル作成方法
- LINEアカウントでLINE Developersにログインする

![](https://storage.googleapis.com/zenn-user-upload/b75a38d71428-20220314.png)

- 上記画面中央ほどにある`Providers->Create`をクリックする。

- Create a new providerでProvider nameを入力。今回は`個人検証`

![](https://storage.googleapis.com/zenn-user-upload/53e581d344c1-20220304.png)

- Chanelを作成する。取り敢えず`Create a Messaging API channel`をクリック

![](https://storage.googleapis.com/zenn-user-upload/0f4f44b3172a-20220304.png)

- `Create a new channel(新規チャネル作成)`で必要事項を入力する。(ここで気づきましたが右下の`English`のところを`日本語`に変えると表示言語が日本語に切り替わります。)

![](https://storage.googleapis.com/zenn-user-upload/a2763ca4dece-20220304.png)

| 入力項目                   | 値                     |
| -------------------------- | ---------------------- |
| チャネルの種類             | Messaging API          |
| プロバイダー               | 個人検証               |
| 会社・事業者の所在国・地域 | Japan                  |
| チャネルアイコン           | <未設定>               |
| チャネル名                 | 何でも検証環境         |
| チャネル説明               | 何でも検証環境         |
| 大業種                     | 個人                   |
| 小業種                     | 個人（その他）         |
| メールアドレス             | <自分のメールアドレス> |
| プライバシーポリシーURL    | <未設定>               |
| サービス利用規約URL        | <未設定>               |

- 規約への同意にチェックを入れて`作成`をクリック
- 更に確認画面が2度出てくるので`OK`をクリックして進む

![](https://storage.googleapis.com/zenn-user-upload/e032d5ab03b2-20220304.png)

- 無事`LINE Channel`が作成されました🎉

![](https://storage.googleapis.com/zenn-user-upload/c860ecdd56cd-20220304.png)
