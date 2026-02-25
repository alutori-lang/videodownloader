import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/download_provider.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const QuickSaveApp());
}

class QuickSaveApp extends StatelessWidget {
  const QuickSaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DownloadProvider(),
      child: MaterialApp(
        title: 'QuickSave',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEA580C),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFFFF7ED),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFF7ED),
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Color(0xFFEA580C),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: IconThemeData(color: Color(0xFFEA580C)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFFEA580C),
            unselectedItemColor: Color(0xFFFED7AA),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
          fontFamily: 'Roboto',
        ),
        home: const MainScreen(),
      ),
    );
  }
}
