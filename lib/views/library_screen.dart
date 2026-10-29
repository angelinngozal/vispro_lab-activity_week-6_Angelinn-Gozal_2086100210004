import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/loan.dart';
import '../viewmodels/library_view_model.dart';

enum _LoanFilter { all, borrowed, overdue, missing, returned }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.viewModel});

  final LibraryViewModel viewModel;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  _LoanFilter _filter = _LoanFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final books = _filteredBooks;
        final loans = _filteredLoans;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 24,
            title: const Row(
              children: [
                Icon(Icons.local_library_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Perpustakaan Kampus',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  children: [
                    Text(
                      'Selamat datang',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kelola buku dan peminjaman mahasiswa dalam satu tempat.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SummaryRow(viewModel: widget.viewModel),
                    const SizedBox(height: 30),
                    _SectionHeading(
                      title: 'Katalog buku',
                      subtitle: '${books.length} buku ditemukan',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cari judul atau nama penulis',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (books.isEmpty)
                      const _EmptyState(
                        icon: Icons.menu_book_outlined,
                        message: 'Buku tidak ditemukan.',
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 600
                              ? 2
                              : 1;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  mainAxisExtent: 206,
                                ),
                            itemCount: books.length,
                            itemBuilder: (context, index) => _BookCard(
                              book: books[index],
                              available: widget.viewModel.isBookAvailable(
                                books[index].id,
                              ),
                              onBorrow: () => _showBorrowDialog(books[index]),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 34),
                    _SectionHeading(
                      title: 'Daftar peminjaman',
                      subtitle: '${loans.length} catatan',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _LoanFilter.values.map((filter) {
                        return ChoiceChip(
                          label: Text(_filterLabel(filter)),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    if (loans.isEmpty)
                      const _EmptyState(
                        icon: Icons.assignment_outlined,
                        message: 'Belum ada peminjaman pada kategori ini.',
                      )
                    else
                      ...loans.map(
                        (loan) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LoanCard(
                            loan: loan,
                            book: widget.viewModel.bookById(loan.bookId),
                            status: widget.viewModel.getOverdueStatus(loan),
                            fine: widget.viewModel.calculateFine(loan),
                            onReturn: loan.isActive
                                ? () => _returnBook(loan)
                                : null,
                            onMarkMissing:
                                loan.isActive &&
                                    widget.viewModel.getOverdueStatus(loan) !=
                                        LoanStatus.missing
                                ? () => _markBookMissing(loan)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Book> get _filteredBooks {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.viewModel.books;
    return widget.viewModel.books
        .where(
          (book) =>
              book.title.toLowerCase().contains(query) ||
              book.author.toLowerCase().contains(query),
        )
        .toList();
  }

  List<Loan> get _filteredLoans {
    final query = _searchController.text.trim().toLowerCase();
    return widget.viewModel.loans.where((loan) {
      final status = widget.viewModel.getOverdueStatus(loan);
      final matchesFilter = switch (_filter) {
        _LoanFilter.all => true,
        _LoanFilter.borrowed => status == LoanStatus.borrowed,
        _LoanFilter.overdue => status == LoanStatus.overdue,
        _LoanFilter.missing => status == LoanStatus.missing,
        _LoanFilter.returned => status == LoanStatus.returned,
      };
      final book = widget.viewModel.bookById(loan.bookId);
      final matchesSearch =
          query.isEmpty ||
          loan.studentId.toLowerCase().contains(query) ||
          (book?.title.toLowerCase().contains(query) ?? false);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  String _filterLabel(_LoanFilter filter) => switch (filter) {
    _LoanFilter.all => 'Semua',
    _LoanFilter.borrowed => 'Dipinjam',
    _LoanFilter.overdue => 'Terlambat',
    _LoanFilter.missing => 'Hilang',
    _LoanFilter.returned => 'Dikembalikan',
  };

  Future<void> _showBorrowDialog(Book book) async {
    final formKey = GlobalKey<FormState>();
    var enteredStudentId = '';
    final studentId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pinjam buku'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title),
              const SizedBox(height: 16),
              TextFormField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'NIM mahasiswa',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'NIM wajib diisi.'
                    : null,
                onSaved: (value) => enteredStudentId = value!.trim(),
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    Navigator.of(dialogContext).pop(enteredStudentId);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.of(dialogContext).pop(enteredStudentId);
              }
            },
            child: const Text('Pinjam'),
          ),
        ],
      ),
    );

    if (studentId == null || !mounted) return;
    final result = widget.viewModel.borrowBook(book.id, studentId);
    final message = switch (result) {
      BorrowResult.success => 'Buku berhasil dipinjam.',
      BorrowResult.emptyStudentId => 'NIM wajib diisi.',
      BorrowResult.unavailable => 'Semua salinan buku sedang dipinjam.',
      BorrowResult.duplicateLoan =>
        'Mahasiswa ini sudah meminjam buku tersebut.',
    };
    _showMessage(message);
  }

  Future<void> _returnBook(Loan loan) async {
    final today = widget.viewModel.currentDate;
    final lastSelectableDate = widget.viewModel.latestReturnDate(loan);
    final initialDate = today.isBefore(loan.borrowedAt)
        ? loan.borrowedAt
        : today.isAfter(lastSelectableDate)
        ? lastSelectableDate
        : today;
    final returnedAt = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: loan.borrowedAt,
      lastDate: lastSelectableDate,
      helpText: 'Pilih tanggal pengembalian',
      cancelText: 'Batal',
      confirmText: 'Pilih tanggal',
    );
    if (returnedAt == null || !mounted) return;

    final returned = widget.viewModel.returnBook(
      loan.id,
      returnedAt: returnedAt,
    );
    if (returned) {
      final fine = widget.viewModel.calculateFine(
        widget.viewModel.loanById(loan.id)!,
      );
      _showMessage(
        fine.total > 0
            ? 'Buku dikembalikan. Total tagihan Rp${_formatAmount(fine.total)} tercatat di ringkasan.'
            : 'Buku berhasil dikembalikan.',
      );
    } else {
      _showMessage('Tanggal pengembalian tidak valid.');
    }
  }

  Future<void> _markBookMissing(Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tandai buku hilang?'),
        content: const Text(
          'Buku tidak akan ditambahkan kembali ke stok. Tagihan mencakup '
          'harga buku pengganti dan denda keterlambatan yang berlaku.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tandai hilang'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final marked = widget.viewModel.markBookMissing(loan.id);
    if (marked) {
      final fine = widget.viewModel.calculateFine(
        widget.viewModel.loanById(loan.id)!,
      );
      _showMessage(
        'Buku ditandai hilang. Tagihan buku pengganti '
        'Rp${_formatAmount(fine.replacementCharge)} dan denda '
        'Rp${_formatAmount(fine.overdueFine)} tercatat.',
      );
    } else {
      _showMessage('Peminjaman ini tidak dapat ditandai hilang.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.viewModel});

  final LibraryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        final items = [
          _SummaryItem(
            label: 'Judul buku',
            value: '${viewModel.books.length}',
            icon: Icons.menu_book_outlined,
          ),
          _SummaryItem(
            label: 'Salinan tersedia',
            value: '${viewModel.availableCopyCount}',
            icon: Icons.check_circle_outline,
          ),
          _SummaryItem(
            label: 'Terlambat / hilang',
            value: '${viewModel.overdueLoanCount + viewModel.missingLoanCount}',
            icon: Icons.schedule_outlined,
          ),
          _SummaryItem(
            label: 'Denda keterlambatan',
            value: 'Rp${_formatAmount(viewModel.totalOverdueFines)}',
            icon: Icons.payments_outlined,
          ),
          _SummaryItem(
            label: 'Buku pengganti',
            value: 'Rp${_formatAmount(viewModel.totalReplacementCharges)}',
            icon: Icons.menu_book_outlined,
          ),
          _SummaryItem(
            label: 'Total tagihan',
            value: 'Rp${_formatAmount(viewModel.totalOutstanding)}',
            icon: Icons.receipt_long_outlined,
          ),
        ];
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 96,
          children: items,
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.available,
    required this.onBorrow,
  });

  final Book book;
  final bool available;
  final VoidCallback onBorrow;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                _StatusBadge(
                  label: available ? 'Tersedia' : 'Dipinjam',
                  color: available ? const Color(0xFF26714D) : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${book.availableCopies} dari ${book.totalCopies} salinan',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: available ? onBorrow : null,
                  child: const Text('Pinjam'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.book,
    required this.status,
    required this.fine,
    required this.onReturn,
    required this.onMarkMissing,
  });

  final Loan loan;
  final Book? book;
  final LoanStatus status;
  final FineBreakdown fine;
  final VoidCallback? onReturn;
  final VoidCallback? onMarkMissing;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LoanStatus.borrowed => ('Dipinjam', const Color(0xFF315C4B)),
      LoanStatus.overdue => ('Terlambat', Colors.deepOrange),
      LoanStatus.missing => ('Hilang', Colors.red),
      LoanStatus.returned => ('Dikembalikan', Colors.blueGrey),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 12,
          spacing: 24,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book?.title ?? 'Buku tidak ditemukan',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('NIM ${loan.studentId}'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.returnedAt != null
                      ? 'Tanggal kembali'
                      : loan.missingAt != null
                      ? 'Tanggal dinyatakan hilang'
                      : 'Tanggal jatuh tempo',
                ),
                Text(
                  _formatDate(
                    loan.returnedAt ?? loan.missingAt ?? loan.dueDate,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Denda keterlambatan: Rp${_formatAmount(fine.overdueFine)}',
                ),
                Text(
                  'Buku pengganti: Rp${_formatAmount(fine.replacementCharge)}',
                ),
                Text(
                  'Total: Rp${_formatAmount(fine.total)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusBadge(label: label, color: color),
                if (onReturn != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onReturn,
                    child: const Text('Kembalikan'),
                  ),
                ],
                if (onMarkMissing != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onMarkMissing,
                    icon: const Icon(Icons.report_gmailerrorred_outlined),
                    label: const Text('Tandai hilang'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}

String _formatAmount(int amount) {
  final digits = amount.toString();
  final grouped = StringBuffer();
  for (var index = digits.length - 1; index >= 0; index--) {
    grouped.write(digits[index]);
    if ((digits.length - index) % 3 == 0 && index != 0) grouped.write('.');
  }
  return grouped.toString().split('').reversed.join();
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day.toString().padLeft(2, '0')} '
      '${months[date.month - 1]} ${date.year}';
}
