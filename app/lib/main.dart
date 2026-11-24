import 'package:material_ui/material_ui.dart';

import 'screens/join_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveKitMeetApp());
}

class LiveKitMeetApp extends StatelessWidget {
  const LiveKitMeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiveKit Meet',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const JoinScreen(),
    );
  }
}
