import 'package:flutter/material.dart';

import '../data/models/profile.dart';

enum ItemSlot { ribbon, hat, face }

extension ItemSlotLabel on ItemSlot {
  String get label => switch (this) {
        ItemSlot.ribbon => '리본',
        ItemSlot.hat => '모자',
        ItemSlot.face => '꾸미기',
      };
}

/// 김다조이 꾸미기 아이템 — 별 조각으로 구매.
/// 별 조각은 학습 세션에서만 나오므로, 꾸미고 싶으면 공부하게 된다.
class ShopItem {
  final String id;
  final String name;
  final String emoji;
  final ItemSlot slot;
  final int price;
  final Color? color; // 리본 색상 교체용

  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.slot,
    required this.price,
    this.color,
  });
}

const List<ShopItem> shopCatalog = [
  // 리본 (기본은 분홍 — 무료 장착 상태)
  ShopItem(id: 'ribbon_blue', name: '하늘 리본', emoji: '🎀', slot: ItemSlot.ribbon, price: 10, color: Color(0xFF64B5F6)),
  ShopItem(id: 'ribbon_yellow', name: '노랑 리본', emoji: '🎀', slot: ItemSlot.ribbon, price: 10, color: Color(0xFFFFD54F)),
  ShopItem(id: 'ribbon_purple', name: '보라 리본', emoji: '🎀', slot: ItemSlot.ribbon, price: 15, color: Color(0xFFBA68C8)),
  // 모자
  ShopItem(id: 'hat_wizard', name: '마법사 모자', emoji: '🧙', slot: ItemSlot.hat, price: 20),
  ShopItem(id: 'hat_crown', name: '반짝 왕관', emoji: '👑', slot: ItemSlot.hat, price: 30),
  ShopItem(id: 'hat_flower', name: '꽃 핀', emoji: '🌸', slot: ItemSlot.hat, price: 15),
  // 얼굴 꾸미기
  ShopItem(id: 'face_glasses', name: '동글 안경', emoji: '👓', slot: ItemSlot.face, price: 12),
  ShopItem(id: 'face_star', name: '별 스티커', emoji: '⭐', slot: ItemSlot.face, price: 8),
];

ShopItem? findItem(String id) {
  for (final item in shopCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

/// 구매: 별 조각이 충분하고 미보유일 때만. 성공 시 자동 장착.
bool buyItem(Profile profile, ShopItem item) {
  if (profile.ownedItems.contains(item.id)) return false;
  if (profile.starPieces < item.price) return false;
  profile.starPieces -= item.price;
  profile.ownedItems.add(item.id);
  profile.equipped[item.slot.name] = item.id;
  return true;
}

/// 장착/해제 토글. 해제하면 기본 모습으로.
void toggleEquip(Profile profile, ShopItem item) {
  if (!profile.ownedItems.contains(item.id)) return;
  if (profile.equipped[item.slot.name] == item.id) {
    profile.equipped.remove(item.slot.name);
  } else {
    profile.equipped[item.slot.name] = item.id;
  }
}
