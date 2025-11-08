class StackCollection<E> {
  final _list = <E>[];

  void push(E value) => _list.add(value);

  E? pop() => _list.isEmpty ? null : _list.removeLast();
  E? get peek => _list.isEmpty ? null : _list.last;

  bool get isEmpty => _list.isEmpty;
  bool get isNotEmpty => _list.isNotEmpty;

  @override
  String toString() => _list.toString();
}
