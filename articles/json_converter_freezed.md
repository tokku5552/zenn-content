---
title: "【Freezed】でフィールドに自分で作った型やDateTimeがあるとfromJsonが作れない問題"
emoji: "👌"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["Flutter"]
published: false
---
Flutterを使っていて
リード文
# 問題

```dart:todo_id.dart
@freezed
class TodoId with _$TodoId {
  const factory TodoId([
    String? value,
  ]) = _TodoId;
}
```

```dart:todo_item.dart
@freezed
class TodoItem with _$TodoItem {
  const factory TodoItem({
    required TodoId id,
    required Title title,
    required Detail detail,
    required DateTime createAt,
  }) = _TodoItem;

  factory TodoItem.fromJson(Map<String, dynamic> json) =>
      _$TodoItemFromJson(json);
}
```

# 解決方法

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

```dart:todo_item.dart
@freezed
class TodoItem with _$TodoItem {
  const factory TodoItem({
    @TodoIdConverter() required TodoId id,
    @TitleConverter() required Title title,
    @DetailConverter() required Detail detail,
    @DateTimeConverter() required DateTime createAt,
  }) = _TodoItem;

  factory TodoItem.fromJson(Map<String, dynamic> json) =>
      _$TodoItemFromJson(json);
}
```

#### 参考

https://qiita.com/tetsufe/items/3c7d997f1c13c659628c#comment-5ce93b14ddfbc9ee6428

