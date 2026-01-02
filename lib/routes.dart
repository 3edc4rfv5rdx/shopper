import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'list_screen.dart';
import 'settings_screen.dart';
import 'items_dictionary_screen.dart';
import 'welcome_screen.dart';
import 'place.dart';

class AppRoutes {
  static const String welcome = '/welcome';
  static const String home = '/';
  static const String list = '/list';
  static const String settings = '/settings';
  static const String itemsDictionary = '/items-dictionary';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case list:
        final place = routeSettings.arguments as Place;
        return MaterialPageRoute(
          builder: (_) => ListScreen(place: place),
        );

      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case itemsDictionary:
        return MaterialPageRoute(builder: (_) => const ItemsDictionaryScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${routeSettings.name}'),
            ),
          ),
        );
    }
  }
}