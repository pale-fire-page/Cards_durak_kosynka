import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'durak/durak_page.dart';
import 'klondike/klondike_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CardsApp());
}

class CardsApp extends StatelessWidget {
  const CardsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Карты: Дурак и Косынка',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1E6B3A), useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton.styleFrom(
      minimumSize: const Size(220, 52),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E6B3A),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF1E6B3A),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Карты', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
          const SizedBox(height: 32),
          FilledButton(
            style: btn,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KlondikePage())),
            child: const Text('Косынка'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: btn,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DurakPage())),
            child: const Text('Дурак'),
          ),
        ]),
      ),
    );
  }
}
