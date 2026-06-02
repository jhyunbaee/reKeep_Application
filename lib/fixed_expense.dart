class FixedExpense {
  final String id;
  final String name;
  final int amount;
  final int day;
  final String category;

  FixedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.day,
    required this.category,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'amount': amount,
    'day': day,
    'category': category,
  };
}
