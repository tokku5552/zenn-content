---
title: "【Flutter】freezedでフィールドに自分で作った型やDateTimeがあるとfromJsonが作れない問題"
emoji: "👌"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Flutter","freezed","dart"]
published: false
---
Flutterを使っていて
リード文
# 問題
下記の場合のように、`freezed`で定義するフィールドに自分で作った型や`DateTime`を宣言すると、`fromJson`を生成したときに上手く生成してくれません。
```dart:todo_id.dart
@freezed
class TodoId with _$TodoId {
  const factory TodoId([
    String? value,
  ]) = _TodoId;
}
```

- 使っている側はこんな感じ

```dart:todo_item.dart
@freezed
class TodoItem with _$TodoItem {
  const factory TodoItem({
    required TodoId id,
    required Title title,
    required Detail detail,
    required DateTime createdAt,
  }) = _TodoItem;

  factory TodoItem.fromJson(Map<String, dynamic> json) =>
      _$TodoItemFromJson(json);
}
```

# 解決方法
下記のように、`JsonConverter`を実装したクラスを作り、変換する処理を記載します。
```dart:todo_id.dart
@freezed
class TodoId with _$TodoId {
  const factory TodoId([
    String? value,
  ]) = _TodoId;
}

class TodoIdConverter implements JsonConverter<TodoId, String> {
  const TodoIdConverter();

  @override
  TodoId fromJson(String? value) {
    return TodoId(value);
  }

  @override
  String toJson(TodoId todoId) {
    return todoId.value ?? '';
  }
}
```
あとは、アノテーション付きで各フィールドに宣言します。
```dart:todo_item.dart
@freezed
class TodoItem with _$TodoItem {
  const factory TodoItem({
    @TodoIdConverter() required TodoId id,
    @TitleConverter() required Title title,
    @DetailConverter() required Detail detail,
    @DateTimeConverter() required DateTime createdAt,
  }) = _TodoItem;

  factory TodoItem.fromJson(Map<String, dynamic> json) =>
      _$TodoItemFromJson(json);
}
```
これを行うと、以下のように`freezed`で生成される`toJson/fromJson`のメソッド内で`Converter`をつかって変換してくれるようになります。

```dart:todo_item.g.dart
_$_TodoItem _$$_TodoItemFromJson(Map<String, dynamic> json) => _$_TodoItem(
      id: const TodoIdConverter().fromJson(json['id'] as String),
      title: const TitleConverter().fromJson(json['title'] as String),
      detail: const DetailConverter().fromJson(json['detail'] as String),
      createdAt:
          const DateTimeConverter().fromJson(json['createdAt'] as String),
    );

Map<String, dynamic> _$$_TodoItemToJson(_$_TodoItem instance) =>
    <String, dynamic>{
      'id': const TodoIdConverter().toJson(instance.id),
      'title': const TitleConverter().toJson(instance.title),
      'detail': const DetailConverter().toJson(instance.detail),
      'createdAt': const DateTimeConverter().toJson(instance.createdAt),
    };
```
ちなみに、`DateTimeConverter`は以下のように実装しています。

```dart:date_time_converter.dart
class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromJson(String json) {
    return DateTime.parse(json).toLocal();
  }

  @override
  String toJson(DateTime dateTime) {
    return dateTime.toLocal().toString();
  }
}
```
#### 参考

https://qiita.com/tetsufe/items/3c7d997f1c13c659628c#comment-5ce93b14ddfbc9ee6428

