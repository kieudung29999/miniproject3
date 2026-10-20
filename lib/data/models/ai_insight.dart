class AiInsight {
  const AiInsight({
    this.id,
    required this.month,
    required this.content,
    required this.model,
    required this.createdAt,
  });

  final int? id;
  final String month; // yyyy-MM
  final String content;
  final String model;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'month': month,
        'content': content,
        'model': model,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory AiInsight.fromMap(Map<String, Object?> m) => AiInsight(
        id: m['id'] as int?,
        month: m['month'] as String,
        content: m['content'] as String,
        model: (m['model'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
