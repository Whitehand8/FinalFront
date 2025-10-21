// services/navigation_service.dart
import 'package:flutter/material.dart';
import '../models/room.dart';
import '../routes.dart';

class NavigationService {
  // Navigator의 상태에 접근하기 위한 전역 키
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // 지정된 경로로 이동하고 필요한 경우 인자 전달
  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      return navigator.pushNamed(routeName, arguments: arguments);
    }
    throw Exception('Navigator not available');
  }

  // Room 객체를 받아 방 화면으로 이동
  static Future<dynamic>? navigateToRoom(Room room) {
    // room.id가 null이 아닌지 확인
    if (room.id == null) return null;
    return navigateTo(Routes.roomById(room.id!), arguments: room);
  }

  // 이전 화면으로 돌아가기
  static void goBack() {
    navigatorKey.currentState?.pop();
  }

  // 현재 화면을 새로운 화면으로 교체
  static void pushReplacement(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }

  // 모든 화면을 제거하고 새로운 화면으로 이동
  static void pushAndRemoveUntil(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName,
      (route) => false, // 모든 이전 라우트를 제거
      arguments: arguments,
    );
  }

  // 조건에 따라 화면 스택 정리 후 이동
  static void pushNamedAndRemoveUntilPredicate(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName,
      predicate,
      arguments: arguments,
    );
  }

  // 뒤로 갈 수 있는지 확인
  static bool canPop() {
    final navigator = navigatorKey.currentState;
    return navigator?.canPop() ?? false;
  }

  // 현재 화면을 닫고 결과 반환
  static void popAndReturn([dynamic result]) {
    navigatorKey.currentState?.pop(result);
  }

  // 모달 다이얼로그 표시 (이름 충돌 방지를 위해 showDialog 대신 showCustomDialog 사용)
  static Future<T?> showCustomDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      return showDialog<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
      );
    }
    throw Exception('Navigation context not available');
  }
}
