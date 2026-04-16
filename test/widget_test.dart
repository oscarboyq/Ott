import 'package:flutter_test/flutter_test.dart';
import 'package:video/app/app.dart';
import 'package:video/app/di/injection_container.dart';

void main() {
  testWidgets('shows OTT home content', (WidgetTester tester) async {
    setupDependencies();

    await tester.pumpWidget(const OttApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Spotlight Rail'), findsOneWidget);
    expect(find.text('Coastline Notes'), findsOneWidget);
  });

  testWidgets('opens admin dashboard from home', (WidgetTester tester) async {
    setupDependencies();

    await tester.pumpWidget(const OttApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Panel'), findsOneWidget);
    expect(find.text('Create New Title'), findsOneWidget);
    expect(find.text('Manage Library'), findsOneWidget);
  });
}
