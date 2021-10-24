---
title: "自宅サーバーにansibleでCloudWatch Agentの設定をしてCloudWatchで監視できるようにした"
emoji: "👋"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["AWS","Ansible","Docker","CloudWatch"]
published: true
---
自宅サーバーにCloudWatch Agentを入れてCloudWatch側で監視をしようと思い立ったので、メモ。
以前からAnsibleで管理しているので、今回も頑張ってAnsibleで入れました。  
サーバーの用途としてはGoogle Photoの写真や動画をNASに定期的にバックアップするジョブを流すのに使っています。
https://qiita.com/tokkun5552/items/38b4d678ccc3e2f796fa

# 環境
- Local
  - Windows 10 Pro
  - Mac Book Pro (not M1)
  - Docker version 20.10.8, build 3967b7d

# 事前準備
- Ansibleの実行環境  
  AnsibleはDockerの中に構築してそれを使っています。
  本記事の内容とはそれるので、詳しく知りたい方は以下を参照してください。  

https://tokku-engineer.tech/build_docker_ansible_devenv/

- IAMユーザーの追加
  サーバーに入れたCloudWatchAgentからAWS側に情報を送信するために、あらかじめIAMユーザーを作成しておく必要があります。
  これも本記事と内容がそれるので、詳細は以下を参照ください。  

https://tokku-engineer.tech/how-to-add-iam-user/

# Ansibleプレイブック
事前準備が整ったので実際のプレイブックを見ていきます。  
フォルダ構成はベストプラクティスに沿って各々用意してください。  
大きく分けて

- AWSCLIv2のインストールと設定
- CloudWatch Agentのインストールと設定  

の2つです。
## AWSCLIv2
インストール方法は以前書いたこちらの記事を参考に、Ansbileのプレイブックに起こしました。  
https://zenn.dev/tokku5552/articles/aws-container

やってることは

- which awsでコマンドがインストールされているか確認
- インストールされていなければ
  - インストーラが入っているzipファイルをダウンロード
  - zipファイルを解凍
  - インストーラを実行してインストール
- .aws/configファイルを上書き
- .aws/credentialsファイルを上書き

です。

```yaml:install_awscli.yml
# install_awscli
- name: check awscli
  command: "which aws"
  register: result
  check_mode: no
  changed_when: no
  failed_when: no

- name: download awscli installer
  get_url:
    url: https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
    dest: /tmp/awscliv2.zip
    force: yes
  when: result.rc == 1

- name: unzrchive zip
  unarchive:
    src: /tmp/awscliv2.zip
    dest: /tmp/
    copy: no
  when: result.rc == 1

- name: install awscli
  become: yes
  command:
    cmd: ./aws/install
    chdir: /tmp
  when: result.rc == 1

- name: copy config file
  become: yes
  copy:
    src: config
    dest: /root/.aws/config

- name: copy credentials file
  become: yes
  copy:
    src: credentials
    dest: /root/.aws/credentials

```

ポイントとしては、頭の`check awscli`でコマンドの有無を確認した結果を`result`に格納して、そのあとの一連のインストール処理を行うかどうかを振り分けているところです。  
yumでインストールが出来ればモジュールを使って冪等性を担保しつつ記述できるのですが、公式のインストール方法に従うと、既にインストール済みかどうかを判別する必要が出てきてしまうのが難点です...  
:::message alert
注意点として、`unzip`のインストールが必要なので事前にしておくのと、CloudWatch Agentを起動するユーザーのホームディレクトリに`.aws`フォルダを作っておく必要があります。
:::
### credentials
今回はCloudWatch Agentで使用するので、credentialsに以下のように`AmazonCloudWatchAgent`のセクションを追加してやる必要があります。  
`ACCESS_KEY_ID`と`SECRET_ACCESS_KEY`は作成したIAMユーザーのものを指定してください。
`region`はEC2の場合は指定しない場合はインスタンスが実行されているリージョンに勝手になるようですが、今回の様にAWS上のインスタンスでない場合は指定が必要なようです。
```conf:credentials
[default]
aws_access_key_id = ACCESS_KEY_ID
aws_secret_access_key = SECRET_ACCESS_KEY

[AmazonCloudWatchAgent]
aws_access_key_id=ACCESS_KEY_ID
aws_secret_access_key=SECRET_ACCESS_KEY
region = ap-northeast-1
```
## CloudWatch Agent
今回はNUCに入れるのでonPremissモードとして動作させる必要があります。  
[公式](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-premise.html)の手順に従って、Ansibleのプレイブックに起こします。  
やっていることは

- amazon-cloudwatch-agent.rpmがダウンロード済みでなければ
  - rpmをダウンロードして
  - yumでrpmをインストール
- collectdを入れるためにepelをインストール
- collectdをインストール
- amazon-cloudwatch-agent.jsonを設定

です。
```yaml:install_cloudwatch_agent.yml
# install_cloudwatch_agent

- name: confirm exists cloudwatch rpm
  stat:
    path: /tmp/amazon-cloudwatch-agent.rpm
  register: cloudwatch_rpm

- name: cloudwatch rpm download
  get_url:
    url: https://s3.amazonaws.com/amazoncloudwatch-agent/centos/amd64/latest/amazon-cloudwatch-agent.rpm
    dest: /tmp
  when: cloudwatch_rpm.stat.exists  == false

- name: install cloudwatch agent (yum)
  become: yes 
  yum: 
    name:
     - /tmp/amazon-cloudwatch-agent.rpm 
    state: present
  when: cloudwatch_rpm.stat.exists  == false

- name: install epel
  become: yes
  yum:
    name:
      - https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    state: latest
    validate_certs: no
  notify: yum clean all

- name: install collectd
  become: yes 
  yum: 
    name:
     - collectd
    enablerepo: epel
    state: present

- name: copy amazon-cloudwatch-agent.json
  become: yes
  copy:
    src: amazon-cloudwatch-agent.json
    dest: /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json 
  notify:
    - cloudwatch-agent fetch config
    - Restart CWAgent daemon
```

特筆すべきなのは、**amazon-cloudwatch-agent.json**の反映方法についてです。
オンプレミスだからなのか分かりませんが、単純に`/opt/aws/amazon-cloudwatch-agent/etc/`とか`/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/`とかに置いてサービスを再起動するだけでは認識できず、`amazon-cloudwatch-agent`の専用コマンドから設定ファイルをフェッチしてあげる必要があります。  
それが`cloudwatch-agent fetch config`のプレイブックです。
```yaml:handlers/cloudwatch-agent_fetch_config.yml
- name: cloudwatch-agent fetch config
  become: yes
  shell: |
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m onPremise \
      -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json 
```
`-m onPremise`を指定して`-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`で設定ファイルの場所を示すことで、正常に設定を読み込めました。  
ただこれをやると、Ansibleで配置した`/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`がなくなり、新たに`/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/file_amazon-cloudwatch-agent.json`というファイルに置き換わります。  
今のままのプレイブックだと、jsonに変更がなくても必ず`changed`になってしまうので少々考え物ですが、正常に動くは動くのでとりあえず放置...

### amazon-cloudwatch-agent.json

設定ファイルは以下のようにしています。  
[こちら](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-wizard.html)を参考に、`/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard`を実行して適当に作っています。

```json:amazon-cloudwatch-agent.json
{
	"agent": {
		"metrics_collection_interval": 60,
		"run_as_user": "root"
	},
	"logs": {
		"logs_collected": {
			"files": {
				"collect_list": [
					{
						"file_path": "/var/log/messages",
						"log_group_name": "/var/log/messages",
						"log_stream_name": "{hostname}"
					},
					{
						"file_path": "/var/log/google_photos_backup.log",
						"log_group_name": "/var/log/google_photos_backup.log",
						"log_stream_name": "{hostname}"
					}
				]
			}
		}
	},
	"metrics": {
		"metrics_collected": {
			"collectd": {
				"metrics_aggregation_interval": 60
			},
			"cpu": {
				"measurement": [
					"cpu_usage_idle",
					"cpu_usage_iowait",
					"cpu_usage_steal",
					"cpu_usage_guest",
					"cpu_usage_user",
					"cpu_usage_system"
				],
				"metrics_collection_interval": 60,
				"resources": [
					"*"
				],
				"totalcpu": true
			},
			"disk": {
				"measurement": [
					"used_percent"
				],
				"metrics_collection_interval": 60,
				"resources": [
					"*"
				]
			},
			"diskio": {
				"measurement": [
					"io_time",
					"write_bytes",
					"read_bytes",
					"writes",
					"reads"
				],
				"metrics_collection_interval": 60,
				"resources": [
					"*"
				]
			},
			"mem": {
				"measurement": [
					"mem_used_percent"
				],
				"metrics_collection_interval": 60
			},
			"net": {
				"measurement": [
					"bytes_sent",
					"bytes_recv",
					"packets_sent",
					"packets_recv"
				],
				"metrics_collection_interval": 60,
				"resources": [
					"*"
				]
			},
			"netstat": {
				"measurement": [
					"tcp_established",
					"tcp_time_wait"
				],
				"metrics_collection_interval": 60
			},
			"statsd": {
				"metrics_aggregation_interval": 60,
				"metrics_collection_interval": 60,
				"service_address": ":8125"
			},
			"swap": {
				"measurement": [
					"swap_used_percent"
				],
				"metrics_collection_interval": 60
			}
		}
	}
}
```
流しているジョブ自体が特に過負荷になる類のものでもないので、一応一通りのメトリクスとアプリが出力するログを取得するようにしています。  
/var/log/messagesは何となく取っています笑

# 結果
うまいこと取得できました。

![](https://storage.googleapis.com/zenn-user-upload/661da9fccb53338453fa1411.png)

一応CPUのアラームを設定しておきます。
見た感じピーク時も数%にも満たない感じなので、ほぼ意味ないですが笑

![](https://storage.googleapis.com/zenn-user-upload/90bcfff4409d9e6dbff42d4a.png)

今後もう少し有用な監視方法とアラームの設定を検討していく予定です。


# 参考
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-premise.html
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/create-iam-roles-for-cloudwatch-agent.html#create-iam-roles-for-cloudwatch-agent-users
https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-wizard.html
https://qiita.com/murata-tomohide/items/3e66d63b21c08d6481a2
https://qiita.com/tokkun5552/items/38b4d678ccc3e2f796fa