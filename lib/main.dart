// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnr/pages/home_page.dart';
import 'package:mnr/pages/login_page.dart';
import 'package:mnr/pages/warning_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// import 'firebase_options.dart';
import 'models/app_state.dart';
// import 'models/error_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Portrait only
    // DeviceOrientation.portraitDown, // Optional: Reverse portrait if needed
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);

  await Supabase.initialize(
      url: 'https://raldbhdfedggcwgyzknk.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJhbGRiaGRmZWRnZ2N3Z3l6a25rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ4MjAyMjIsImV4cCI6MjA2MDM5NjIyMn0.An1ievbDN6AZMbD6GzEZj2o5uqnstKQrXh0CVIPSF4k'
  );

  // Initialize Error Logger
  // await ErrorLogger.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );

}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Convise',
      debugShowCheckedModeBanner: false,

      home: LoginPage(),
    );
  }
}

extension ContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : Theme.of(this).snackBarTheme.backgroundColor,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int myIndex = 0;

  // Remove the third widget from the widgetList
  List<Widget> widgetList = [
    const HomePage(), // Use the HomeScreen class
    const WarningPage(), // Use the PlanPage class
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: myIndex == 0, // Allow pop only on HomePage
      onPopInvoked: (didPop) {
        if (!didPop) { // Only handle if pop was not handled by Navigator
          if (myIndex != 0) {
            setState(() {
              myIndex = 0;
            });
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: myIndex,
          children: widgetList,
        ),
        // bottomNavigationBar: Container(
        //   decoration: BoxDecoration(
        //     borderRadius: const BorderRadius.only(
        //       topLeft: Radius.circular(20),
        //       topRight: Radius.circular(20),
        //     ),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withOpacity(0.1),
        //         spreadRadius: 2,
        //         blurRadius: 10,
        //       ),
        //     ],
        //   ),
        //   child: ClipRRect(
        //     // borderRadius: const BorderRadius.only(
        //     //   topLeft: Radius.circular(20),
        //     //   topRight: Radius.circular(20),
        //     // ),
        //     child: BottomNavigationBar(
        //       type: BottomNavigationBarType.fixed,
        //       selectedFontSize: 14,
        //       unselectedFontSize: 12,
        //       showUnselectedLabels: true,
        //       elevation: 10,
        //       backgroundColor: Colors.purple.shade700,
        //       currentIndex: myIndex,
        //       onTap: (index) {
        //         setState(() {
        //           myIndex = index;
        //         });
        //       },
        //       selectedItemColor: Colors.white,
        //       unselectedItemColor: Colors.purpleAccent.shade100,
        //       items: const [
        //         BottomNavigationBarItem(
        //           icon: Icon(Icons.home_outlined),
        //           activeIcon: Icon(Icons.home),
        //           label: 'Home',
        //         ),
        //         BottomNavigationBarItem(
        //           icon: Icon(Icons.warning_outlined),
        //           activeIcon: Icon(Icons.warning),
        //           label: 'Alerts',
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
      ),
    );
  }

}