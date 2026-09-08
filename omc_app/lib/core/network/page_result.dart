/// Read-only continuation metadata. Keep records and pagination together.
class PageResult<T> {
  const PageResult(this.items, this.nextStart);
  final List<T> items;
  final int? nextStart;
}

int? readNextStart(
  Map<dynamic, dynamic> data, {
  required int start,
  required int count,
  required int limit,
  bool requireMetadata = false,
}) {
  if (start < 0 || count < 0 || count > limit) {
    throw const FormatException('Invalid page size.');
  }
  if (!data.containsKey('has_more')) {
    if (requireMetadata) {
      throw const FormatException('Missing page continuation.');
    }
    // Only legacy responses without metadata retain the original fallback.
    return count == limit ? start + count : null;
  }
  final flag = data['has_more'];
  final bool hasMore;
  if (flag == true || flag == 1 || flag == '1' || flag == 'true') {
    hasMore = true;
  } else if (flag == false || flag == 0 || flag == '0' || flag == 'false') {
    hasMore = false;
  } else {
    throw const FormatException('Invalid page continuation flag.');
  }
  if (!hasMore) {
    if (data['next_start'] != null) {
      throw const FormatException('Conflicting page continuation.');
    }
    return null;
  }
  final value = data['next_start'];
  final next = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (count == 0 || next == null || next != start + count || next <= start) {
    throw const FormatException('Invalid page continuation offset.');
  }
  return next;
}
