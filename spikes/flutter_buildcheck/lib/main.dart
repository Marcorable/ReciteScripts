import 'package:flutter/cupertino.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      home: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('ReciteScripts')),
        child: SafeArea(child: Center(child: Text('양 플랫폼 환경 준비 완료'))),
      ),
    );
  }
}
