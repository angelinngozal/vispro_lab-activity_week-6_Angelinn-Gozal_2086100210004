class Loan {
  const Loan({
    required this.id,
    required this.bookId,
    required this.studentId,
    required this.borrowedAt,
    required this.dueDate,
    this.returnedAt,
    this.missingAt,
  });

  final String id;
  final String bookId;
  final String studentId;
  final DateTime borrowedAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final DateTime? missingAt;

  bool get isActive => returnedAt == null;

  Loan copyWith({DateTime? returnedAt, DateTime? missingAt}) {
    return Loan(
      id: id,
      bookId: bookId,
      studentId: studentId,
      borrowedAt: borrowedAt,
      dueDate: dueDate,
      returnedAt: returnedAt ?? this.returnedAt,
      missingAt: missingAt ?? this.missingAt,
    );
  }
}
