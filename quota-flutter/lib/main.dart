import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;

import 'package:quota/contants.dart';
import 'package:quota/pages/add_quote_page.dart';
import 'package:quota/state/quotes_model.dart';
import 'package:quota/widgets/book_args.dart';
import 'package:quota/pages/books_page.dart';
import 'package:quota/pages/book_page.dart';
import 'package:quota/pages/settings_page.dart';
import 'package:quota/pages/login_page.dart';
import 'package:quota/pages/splash_page.dart';
import 'state/books_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await api.init();
  runApp(provider.MultiProvider(
    providers: [
      provider.ChangeNotifierProvider<BooksModel>(
        create: (context) => BooksModel(context),
      ),
      provider.ChangeNotifierProvider<QuotesModel>(
        create: (context) => QuotesModel(),
      ),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'Quota Flutter',
        theme: ThemeData(
          colorScheme: lightColorScheme ??
              ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
              ),
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme ??
              ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
        ),
        initialRoute: '/',
        routes: <String, WidgetBuilder>{
          '/': (_) => const SplashPage(),
          '/login': (_) => const LoginPage(),
          '/books': (_) => const BooksPage(),
          '/book': (_) => BookArgsExtractor(
              create: (bookId, _) => BookPage(
                    bookId: bookId,
                  )),
          '/new-quote': (_) => BookArgsExtractor(
              create: (bookId, _) => AddQuotePage(bookId: bookId)),
          '/settings': (_) => BookArgsExtractor(
              create: (bookId, _) => SettingsPage(bookId: bookId))
        },
      );
    });
  }
}
