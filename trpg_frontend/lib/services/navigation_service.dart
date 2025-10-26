// import 'package:flutter/widgets.dart';
// import 'package:go_router/go_router.dart';

// import '../router/app_router.dart';

// class NavigationService {
//   static late final GlobalKey<NavigatorState> navigatorKey;

//   static void init(GoRouter router) {
//     navigatorKey = router.navigatorKey!;
//   }

//   // go_router와 호환되도록 go만 허용
//   static void go(String location) {
//     navigatorKey.currentState?.pushNamedAndRemoveUntil(
//       location,
//       (route) => false,
//     );
//   }
// }
