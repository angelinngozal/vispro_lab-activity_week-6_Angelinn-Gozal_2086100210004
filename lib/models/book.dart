class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.replacementPrice,
    required this.totalCopies,
    required this.availableCopies,
  });

  final String id;
  final String title;
  final String author;
  final int replacementPrice;
  final int totalCopies;
  final int availableCopies;

  Book copyWith({int? availableCopies}) {
    return Book(
      id: id,
      title: title,
      author: author,
      replacementPrice: replacementPrice,
      totalCopies: totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
    );
  }
}
