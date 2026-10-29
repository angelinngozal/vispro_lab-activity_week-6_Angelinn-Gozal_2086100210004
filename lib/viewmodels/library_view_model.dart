import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../models/loan.dart';

enum LoanStatus { borrowed, overdue, missing, returned }

enum BorrowResult { success, emptyStudentId, unavailable, duplicateLoan }

class FineBreakdown {
  const FineBreakdown({
    required this.overdueFine,
    required this.replacementCharge,
  });

  final int overdueFine;
  final int replacementCharge;

  int get total => overdueFine + replacementCharge;
}

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    DateTime Function()? clock,
    List<Book>? initialBooks,
    List<Loan>? initialLoans,
  }) : _clock = clock ?? DateTime.now {
    _books = initialBooks == null ? _createBooks() : List.of(initialBooks);
    _loans = initialLoans == null ? [] : List.of(initialLoans);
  }

  static const int weeklyFine = 5000;
  static const int replacementFineWeeks = 26;
  static const int loanDurationDays = 14;
  static const int fineGraceDays = 7;

  final DateTime Function() _clock;
  late List<Book> _books;
  late List<Loan> _loans;
  int _nextLoanId = 1;

  List<Book> get books => List.unmodifiable(_books);
  List<Loan> get loans => List.unmodifiable(_loans);
  List<Loan> get activeLoans =>
      List.unmodifiable(_loans.where((loan) => loan.isActive));

  int get availableCopyCount =>
      _books.fold(0, (total, book) => total + book.availableCopies);

  int get overdueLoanCount => activeLoans
      .where((loan) => getOverdueStatus(loan) == LoanStatus.overdue)
      .length;

  int get missingLoanCount => activeLoans
      .where((loan) => getOverdueStatus(loan) == LoanStatus.missing)
      .length;

  int get totalOutstanding =>
      _loans.fold(0, (total, loan) => total + calculateFine(loan).total);

  int get totalOverdueFines =>
      _loans.fold(0, (total, loan) => total + calculateFine(loan).overdueFine);

  int get totalReplacementCharges => _loans.fold(
    0,
    (total, loan) => total + calculateFine(loan).replacementCharge,
  );

  DateTime get currentDate => _dateOnly(_clock());

  DateTime latestReturnDate(Loan loan) => addCalendarMonths(loan.dueDate, 6);

  Book? bookById(String bookId) {
    for (final book in _books) {
      if (book.id == bookId) return book;
    }
    return null;
  }

  bool isBookAvailable(String bookId) {
    final book = bookById(bookId);
    return book != null && book.availableCopies > 0;
  }

  Loan? loanById(String loanId) {
    for (final loan in _loans) {
      if (loan.id == loanId) return loan;
    }
    return null;
  }

  bool canBorrow(String bookId, String studentId) {
    final book = bookById(bookId);
    if (book == null || book.availableCopies <= 0 || studentId.trim().isEmpty) {
      return false;
    }
    return !_loans.any(
      (loan) =>
          loan.isActive &&
          loan.bookId == bookId &&
          loan.studentId == studentId.trim(),
    );
  }

  BorrowResult borrowBook(String bookId, String studentId) {
    final normalizedStudentId = studentId.trim();
    if (normalizedStudentId.isEmpty) return BorrowResult.emptyStudentId;

    final bookIndex = _books.indexWhere((book) => book.id == bookId);
    if (bookIndex == -1 || _books[bookIndex].availableCopies <= 0) {
      return BorrowResult.unavailable;
    }
    if (_loans.any(
      (loan) =>
          loan.isActive &&
          loan.bookId == bookId &&
          loan.studentId == normalizedStudentId,
    )) {
      return BorrowResult.duplicateLoan;
    }

    final borrowedAt = _dateOnly(_clock());
    _books[bookIndex] = _books[bookIndex].copyWith(
      availableCopies: _books[bookIndex].availableCopies - 1,
    );
    _loans.add(
      Loan(
        id: 'L${_nextLoanId++}',
        bookId: bookId,
        studentId: normalizedStudentId,
        borrowedAt: borrowedAt,
        dueDate: borrowedAt.add(const Duration(days: loanDurationDays)),
      ),
    );
    notifyListeners();
    return BorrowResult.success;
  }

  bool returnBook(String loanId, {DateTime? returnedAt}) {
    final loanIndex = _loans.indexWhere((loan) => loan.id == loanId);
    if (loanIndex == -1 || !_loans[loanIndex].isActive) return false;

    final loan = _loans[loanIndex];
    final bookIndex = _books.indexWhere((book) => book.id == loan.bookId);
    if (bookIndex == -1) return false;
    final actualReturnDate = _dateOnly(returnedAt ?? _clock());
    if (actualReturnDate.isBefore(_dateOnly(loan.borrowedAt)) ||
        actualReturnDate.isAfter(latestReturnDate(loan))) {
      return false;
    }

    _loans[loanIndex] = loan.copyWith(returnedAt: actualReturnDate);
    _books[bookIndex] = _books[bookIndex].copyWith(
      availableCopies: (_books[bookIndex].availableCopies + 1)
          .clamp(0, _books[bookIndex].totalCopies)
          .toInt(),
    );
    notifyListeners();
    return true;
  }

  bool markBookMissing(String loanId, {DateTime? missingAt}) {
    final loanIndex = _loans.indexWhere((loan) => loan.id == loanId);
    if (loanIndex == -1 || !_loans[loanIndex].isActive) return false;

    final loan = _loans[loanIndex];
    if (loan.missingAt != null) return false;
    final missingDate = _dateOnly(missingAt ?? _clock());
    if (missingDate.isBefore(_dateOnly(loan.borrowedAt))) return false;

    _loans[loanIndex] = loan.copyWith(missingAt: missingDate);
    notifyListeners();
    return true;
  }

  LoanStatus getOverdueStatus(Loan loan, {DateTime? asOf}) {
    if (!loan.isActive) return LoanStatus.returned;
    if (loan.missingAt != null) return LoanStatus.missing;
    final effectiveDate = _dateOnly(asOf ?? _clock());
    if (!effectiveDate.isAfter(_dateOnly(loan.dueDate))) {
      return LoanStatus.borrowed;
    }
    if (!effectiveDate.isBefore(addCalendarMonths(loan.dueDate, 6))) {
      return LoanStatus.missing;
    }
    return LoanStatus.overdue;
  }

  FineBreakdown calculateFine(Loan loan, {DateTime? asOf}) {
    final effectiveDate = _dateOnly(
      loan.returnedAt ?? loan.missingAt ?? asOf ?? _clock(),
    );
    final dueDate = _dateOnly(loan.dueDate);
    final sixMonthThreshold = addCalendarMonths(dueDate, 6);
    final isMissing =
        loan.missingAt != null || !effectiveDate.isBefore(sixMonthThreshold);

    var overdueFine = 0;
    if (!effectiveDate.isBefore(sixMonthThreshold)) {
      overdueFine = weeklyFine * replacementFineWeeks;
    } else if (effectiveDate.isAfter(dueDate)) {
      final daysAfterDueDate = effectiveDate.difference(dueDate).inDays;
      final completedFineWeeks = (daysAfterDueDate - fineGraceDays) ~/ 7;
      overdueFine = completedFineWeeks * weeklyFine;
    }

    var replacementCharge = 0;
    if (isMissing) {
      final book = bookById(loan.bookId);
      if (book == null) {
        throw StateError('Buku untuk pinjaman ${loan.id} tidak ditemukan.');
      }
      replacementCharge = book.replacementPrice;
    }

    return FineBreakdown(
      overdueFine: overdueFine,
      replacementCharge: replacementCharge,
    );
  }

  static DateTime addCalendarMonths(DateTime date, int months) {
    final targetMonth = date.month + months;
    final targetYear = date.year + (targetMonth - 1) ~/ 12;
    final normalizedMonth = (targetMonth - 1) % 12 + 1;
    final lastDayOfMonth = DateTime(targetYear, normalizedMonth + 1, 0).day;
    return DateTime(
      targetYear,
      normalizedMonth,
      date.day > lastDayOfMonth ? lastDayOfMonth : date.day,
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static List<Book> _createBooks() => [
    const Book(
      id: 'BK001',
      title: 'Laut Bercerita',
      author: 'Leila S. Chudori',
      replacementPrice: 125000,
      totalCopies: 4,
      availableCopies: 4,
    ),
    const Book(
      id: 'BK002',
      title: 'Bumi Manusia',
      author: 'Pramoedya Ananta Toer',
      replacementPrice: 110000,
      totalCopies: 3,
      availableCopies: 3,
    ),
    const Book(
      id: 'BK003',
      title: 'Filosofi Teras',
      author: 'Henry Manampiring',
      replacementPrice: 98000,
      totalCopies: 2,
      availableCopies: 2,
    ),
    const Book(
      id: 'BK004',
      title: 'Atomic Habits',
      author: 'James Clear',
      replacementPrice: 135000,
      totalCopies: 2,
      availableCopies: 2,
    ),
    const Book(
      id: 'BK005',
      title: 'Pulang',
      author: 'Tere Liye',
      replacementPrice: 105000,
      totalCopies: 2,
      availableCopies: 2,
    ),
    const Book(
      id: 'BK006',
      title: 'Sebuah Seni untuk Bersikap Bodo Amat',
      author: 'Mark Manson',
      replacementPrice: 92000,
      totalCopies: 1,
      availableCopies: 1,
    ),
  ];
}
