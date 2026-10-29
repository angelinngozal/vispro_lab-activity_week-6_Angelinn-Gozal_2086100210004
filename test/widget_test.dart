import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lab_activity_week6/viewmodels/library_view_model.dart';
import 'package:lab_activity_week6/views/library_screen.dart';

void main() {
  testWidgets('catalogue borrowing creates a loan and updates stock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewModel = LibraryViewModel(clock: () => DateTime(2026, 10, 29));
    await tester.pumpWidget(
      MaterialApp(home: LibraryScreen(viewModel: viewModel)),
    );

    expect(find.text('Laut Bercerita'), findsOneWidget);
    final borrowButton = find.widgetWithText(FilledButton, 'Pinjam').first;
    await tester.ensureVisible(borrowButton);
    await tester.pumpAndSettle();
    await tester.tap(borrowButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2086022510004');
    await tester.tap(find.widgetWithText(FilledButton, 'Pinjam').last);
    await tester.pumpAndSettle();

    expect(viewModel.activeLoans, hasLength(1));
    expect(viewModel.bookById('BK001')?.availableCopies, 3);
    expect(find.text('Buku berhasil dipinjam.'), findsOneWidget);
  });
}
