enum TxType { expense, income }

class AppTransaction {
  const AppTransaction({
    this.id,
    required this.amount,
    required this.type,
    this.categoryId,
    this.merchant,
    this.note,
    required this.date,
    required this.source,
    this.imagePath,
    this.rawText,
    this.confidence = 1.0,
    required this.createdAt,
  });

  final int? id;
  final double amount;
  final TxType type;
  final int? categoryId;
  final String? merchant;
  final String? note;
  final DateTime date;

  /// regex | gemini | manual
  final String source;
  final String? imagePath;
  final String? rawText;
  final double confidence;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'type': type.name,
        'category_id': categoryId,
        'merchant': merchant,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'source': source,
        'image_path': imagePath,
        'raw_text': rawText,
        'confidence': confidence,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory AppTransaction.fromMap(Map<String, Object?> m) => AppTransaction(
        id: m['id'] as int?,
        amount: (m['amount'] as num).toDouble(),
        type: (m['type'] as String) == 'income' ? TxType.income : TxType.expense,
        categoryId: m['category_id'] as int?,
        merchant: m['merchant'] as String?,
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        source: (m['source'] as String?) ?? 'manual',
        imagePath: m['image_path'] as String?,
        rawText: m['raw_text'] as String?,
        confidence: ((m['confidence'] as num?) ?? 1).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
