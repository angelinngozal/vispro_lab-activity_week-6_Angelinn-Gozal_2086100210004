import 'package:flutter_test/flutter_test.dart';

import 'package:lab_activity_week6/models/loan.dart';
import 'package:lab_activity_week6/viewmodels/library_view_model.dart';

void main() {
  group('LibraryViewModel borrowing', () {
    test('only lends available copies and prevents duplicate active loans', () {
      final viewModel = LibraryViewModel(clock: () => DateTime(2026, 10, 29));

      expect(viewModel.borrowBook('BK001', 'STUDENT-1'), BorrowResult.success);
      expect(
        viewModel.borrowBook('BK001', 'STUDENT-1'),
        BorrowResult.duplicateLoan,
      );
      expect(viewModel.borrowBook('BK001', 'STUDENT-2'), BorrowResult.success);
      expect(viewModel.borrowBook('BK001', 'STUDENT-3'), BorrowResult.success);
      expect(viewModel.borrowBook('BK001', 'STUDENT-4'), BorrowResult.success);
      expect(viewModel.isBookAvailable('BK001'), isFalse);
      expect(
        viewModel.borrowBook('BK001', 'STUDENT-5'),
        BorrowResult.unavailable,
      );
      expect(viewModel.bookById('BK001')?.availableCopies, 0);
    });

    test('sets the due date to fourteen calendar days after borrowing', () {
      final viewModel = LibraryViewModel(
        clock: () => DateTime(2026, 10, 29, 18),
      );

      viewModel.borrowBook('BK001', 'STUDENT-1');

      expect(viewModel.activeLoans.single.borrowedAt, DateTime(2026, 10, 29));
      expect(viewModel.activeLoans.single.dueDate, DateTime(2026, 11, 12));
    });

    test('return date can be selected to record overdue fines', () {
      final viewModel = LibraryViewModel(clock: () => DateTime(2026, 10, 29));
      viewModel.borrowBook('BK001', 'STUDENT-1');
      final loan = viewModel.activeLoans.single;

      expect(
        viewModel.returnBook(loan.id, returnedAt: DateTime(2026, 11, 26)),
        isTrue,
      );

      expect(viewModel.loanById(loan.id)?.returnedAt, DateTime(2026, 11, 26));
      expect(viewModel.bookById('BK001')?.availableCopies, 4);
      expect(viewModel.totalOutstanding, 5000);
    });

    test('rejects return dates outside the allowed simulation range', () {
      final viewModel = LibraryViewModel(clock: () => DateTime(2026, 10, 29));
      viewModel.borrowBook('BK001', 'STUDENT-1');
      final loan = viewModel.activeLoans.single;

      expect(
        viewModel.returnBook(
          loan.id,
          returnedAt: viewModel
              .latestReturnDate(loan)
              .add(const Duration(days: 1)),
        ),
        isFalse,
      );
      expect(viewModel.loanById(loan.id)?.isActive, isTrue);
      expect(viewModel.bookById('BK001')?.availableCopies, 3);
    });

    test(
      'marking a book missing charges replacement and keeps it unavailable',
      () {
        var now = DateTime(2026, 10, 29);
        final viewModel = LibraryViewModel(clock: () => now);
        viewModel.borrowBook('BK001', 'STUDENT-1');
        final loan = viewModel.activeLoans.single;
        now = DateTime(2026, 11, 28);

        expect(viewModel.markBookMissing(loan.id), isTrue);
        expect(
          viewModel.getOverdueStatus(viewModel.loanById(loan.id)!),
          LoanStatus.missing,
        );
        expect(viewModel.bookById('BK001')?.availableCopies, 3);
        expect(viewModel.totalReplacementCharges, 125000);
        expect(viewModel.totalOverdueFines, 5000);
        expect(viewModel.totalOutstanding, 130000);
      },
    );
  });

  group('LibraryViewModel fines', () {
    final dueDate = DateTime(2026, 10, 1);
    final viewModel = LibraryViewModel(clock: () => DateTime(2026, 10, 1));
    final loan = Loan(
      id: 'TEST-1',
      bookId: 'BK001',
      studentId: 'STUDENT-1',
      borrowedAt: DateTime(2026, 9, 17),
      dueDate: dueDate,
    );

    test('allows seven full grace days after the due date', () {
      expect(viewModel.calculateFine(loan, asOf: dueDate).total, 0);
      expect(
        viewModel.calculateFine(loan, asOf: DateTime(2026, 10, 7)).total,
        0,
      );
      expect(
        viewModel.calculateFine(loan, asOf: DateTime(2026, 10, 8)).total,
        0,
      );
    });

    test('starts the first fine two weeks after the due date', () {
      expect(
        viewModel.calculateFine(loan, asOf: DateTime(2026, 10, 14)).total,
        0,
      );
      expect(
        viewModel.calculateFine(loan, asOf: DateTime(2026, 10, 15)).total,
        5000,
      );
      expect(
        viewModel.calculateFine(loan, asOf: DateTime(2026, 10, 22)).total,
        10000,
      );
    });

    test('matches the November 14 due-date grace-period example', () {
      final novemberLoan = Loan(
        id: 'TEST-NOV',
        bookId: 'BK001',
        studentId: 'STUDENT-NOV',
        borrowedAt: DateTime(2026, 10, 31),
        dueDate: DateTime(2026, 11, 14),
      );

      expect(
        viewModel
            .calculateFine(novemberLoan, asOf: DateTime(2026, 11, 14))
            .total,
        0,
      );
      expect(
        viewModel
            .calculateFine(novemberLoan, asOf: DateTime(2026, 11, 21))
            .total,
        0,
      );
      expect(
        viewModel
            .calculateFine(novemberLoan, asOf: DateTime(2026, 11, 28))
            .total,
        5000,
      );
    });

    test('at six months charges book replacement plus the six-month fine', () {
      final threshold = LibraryViewModel.addCalendarMonths(dueDate, 6);
      final fine = viewModel.calculateFine(loan, asOf: threshold);

      expect(
        viewModel.getOverdueStatus(loan, asOf: threshold),
        LoanStatus.missing,
      );
      expect(fine.overdueFine, 26 * LibraryViewModel.weeklyFine);
      expect(fine.replacementCharge, 125000);
      expect(fine.total, 255000);
      final summaryViewModel = LibraryViewModel(
        clock: () => threshold,
        initialBooks: viewModel.books,
        initialLoans: [loan],
      );
      expect(summaryViewModel.totalOverdueFines, 130000);
      expect(summaryViewModel.totalReplacementCharges, 125000);
      expect(summaryViewModel.totalOutstanding, 255000);
      expect(
        viewModel
            .calculateFine(loan, asOf: threshold.add(const Duration(days: 30)))
            .total,
        fine.total,
      );
    });

    test('calendar-month threshold clamps to the last day of the month', () {
      expect(
        LibraryViewModel.addCalendarMonths(DateTime(2026, 8, 31), 6),
        DateTime(2027, 2, 28),
      );
    });

    test('returning a missing book restores stock but retains its charge', () {
      var now = DateTime(2026, 10, 1);
      final returningViewModel = LibraryViewModel(clock: () => now);
      returningViewModel.borrowBook('BK001', 'STUDENT-1');
      final borrowedLoan = returningViewModel.activeLoans.single;
      now = LibraryViewModel.addCalendarMonths(borrowedLoan.dueDate, 6);

      expect(
        returningViewModel.getOverdueStatus(borrowedLoan),
        LoanStatus.missing,
      );
      expect(returningViewModel.returnBook(borrowedLoan.id), isTrue);
      expect(returningViewModel.bookById('BK001')?.availableCopies, 4);
      expect(returningViewModel.totalOutstanding, 255000);
      expect(
        returningViewModel.getOverdueStatus(
          returningViewModel.loanById(borrowedLoan.id)!,
        ),
        LoanStatus.returned,
      );
    });
  });
}
