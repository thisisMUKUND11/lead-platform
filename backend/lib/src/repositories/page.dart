/// A page of results plus the total count of matching rows.
class Page<T> {
  const Page({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;

  int get totalPages => limit == 0 ? 0 : (total + limit - 1) ~/ limit;

  Map<String, dynamic> toJson(Object? Function(T) itemToJson) => {
        'data': items.map(itemToJson).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': totalPages,
        },
      };
}
