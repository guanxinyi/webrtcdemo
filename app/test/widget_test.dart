import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_meet/main.dart';

void main() {
  testWidgets('shows the join form', (tester) async {
    await tester.pumpWidget(const LiveKitMeetApp());

    expect(find.text('LiveKit Meet'), findsOneWidget);
    expect(find.text('加入房间'), findsOneWidget);
    expect(find.text('房间号'), findsOneWidget);
  });
}
