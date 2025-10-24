// lib/models/character.dart

import 'package:flutter/foundation.dart';

/// 백엔드의 CharacterSheetResponseDto에 대응하는 모델입니다.
class Character {
  /// 캐릭터 시트 고유 ID (PK)
  final int id;

  /// 이 시트가 연결된 방 참가자(participant)의 ID
  final int participantId;

  /// 이 시트의 소유자(user) ID
  final int ownerId;

  /// TRPG 룰 시스템 (예: "dnd5e", "coc7e")
  final String trpgType;

  /// 시트 데이터 (모든 스탯, 정보 포함)
  final Map<String, dynamic> data;

  /// 시트 공개 여부 (GM만 수정 가능)
  final bool isPublic;

  final DateTime createdAt;
  final DateTime updatedAt;

  Character({
    required this.id,
    required this.participantId,
    required this.ownerId,
    required this.trpgType,
    required this.data,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 서버에서 받은 JSON 응답을 Character 객체로 변환합니다.
  factory Character.fromJson(Map<String, dynamic> json) {
    // 헬퍼 함수: JSON 필드에서 int를 안전하게 파싱
    int _parseInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? fallback;
      if (value is double) return value.toInt();
      return fallback;
    }

    // 헬퍼 함수: JSON 필드에서 DateTime을 안전하게 파싱
    DateTime _parseDate(dynamic value) {
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('Error parsing date: $value');
        }
      }
      return DateTime.now(); // 파싱 실패 시 현재 시간
    }

    return Character(
      id: _parseInt(json['id']),
      participantId: _parseInt(json['participantId']),
      ownerId: _parseInt(json['ownerId']),
      trpgType: json['trpgType'] as String? ?? 'unknown',
      data: json['data'] as Map<String, dynamic>? ?? {},
      isPublic: json['isPublic'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  /// 객체 복사를 위한 copyWith 메서드
  Character copyWith({
    int? id,
    int? participantId,
    int? ownerId,
    String? trpgType,
    Map<String, dynamic>? data,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Character(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      ownerId: ownerId ?? this.ownerId,
      trpgType: trpgType ?? this.trpgType,
      data: data ?? this.data,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}