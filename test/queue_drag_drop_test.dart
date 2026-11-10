import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Queue drag and drop renders elevated Material proxy without crash', (tester) async {
    final List<String> items = List.generate(5, (i) => 'Track $i');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverReorderableList(
                itemCount: items.length,
                proxyDecorator: (Widget child, int index, Animation<double> animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? animChild) {
                      return Material(
                        elevation: 8.0,
                        color: const Color(0xFF262938),
                        shadowColor: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        child: animChild,
                      );
                    },
                    child: child,
                  );
                },
                // ignore: deprecated_member_use
                onReorder: (oldIdx, newIdx) {
                  if (oldIdx < newIdx) newIdx -= 1;
                  final item = items.removeAt(oldIdx);
                  items.insert(newIdx, item);
                },
                itemBuilder: (context, index) {
                  return Material(
                    key: ValueKey('queue_item_$index'),
                    color: Colors.transparent,
                    child: Dismissible(
                      key: ValueKey('dismiss_queue_$index'),
                      direction: DismissDirection.horizontal,
                      child: ReorderableDelayedDragStartListener(
                        index: index,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            child: ListTile(
                              title: Text(items[index]),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial state
    expect(find.text('Track 0'), findsOneWidget);
    expect(find.text('Track 1'), findsOneWidget);

    // Perform long-press on Track 0 to trigger ReorderableDelayedDragStartListener
    final gesture = await tester.startGesture(tester.getCenter(find.text('Track 0')));
    await tester.pump(const Duration(milliseconds: 600));

    // Move Track 0 down by 120 pixels
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();

    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify no exception occurred and items are rendered
    expect(tester.takeException(), isNull);
  });
}
