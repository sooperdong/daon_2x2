import 'package:flutter/material.dart';

import '../core/shop_items.dart';
import '../data/game_repository.dart';
import '../data/models/profile.dart';
import '../widgets/dajoy_character.dart';

/// 꾸미기 상점 — 별 조각으로 김다조이를 꾸민다.
/// 별 조각은 학습 세션에서만 나오므로 "꾸미고 싶으면 공부한다"는
/// 선순환이 만들어진다. 내 캐릭터에 대한 애착이 매일 접속할 이유가 된다.
class ShopScreen extends StatefulWidget {
  final GameRepository repo;

  const ShopScreen({super.key, required this.repo});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  GameRepository get repo => widget.repo;

  DajoyStyle get _currentStyle => styleFromProfile(repo.profile);

  @override
  Widget build(BuildContext context) {
    final profile = repo.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('🛍️ 꾸미기 상점'), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Column(
          children: [
            // 미리보기 — 장착 즉시 반영
            DajoyCharacter(expression: DajoyExpression.happy, size: 130, style: _currentStyle),
            Text('⭐ 별 조각 ${profile.starPieces}개',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final slot in ItemSlot.values) ...[
                    Text(slot.label,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in shopCatalog.where((i) => i.slot == slot))
                          _buildItemCard(item),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(ShopItem item) {
    final profile = repo.profile;
    final owned = profile.ownedItems.contains(item.id);
    final equipped = profile.equipped[item.slot.name] == item.id;
    final affordable = profile.starPieces >= item.price;

    return GestureDetector(
      onTap: () => _onItemTap(item, owned, affordable),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: equipped ? const Color(0xFFFFE082) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: equipped ? const Color(0xFFFFB300) : Colors.black12,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 30)),
            Text(item.name, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            if (equipped)
              const Text('착용 중', style: TextStyle(fontSize: 12, color: Color(0xFFE65100)))
            else if (owned)
              const Text('입기', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)))
            else
              Text('⭐ ${item.price}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: affordable ? const Color(0xFF1565C0) : Colors.black38,
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _onItemTap(ShopItem item, bool owned, bool affordable) async {
    final profile = repo.profile;
    if (owned) {
      toggleEquip(profile, item);
    } else if (affordable) {
      buyItem(profile, item);
      await repo.logEvent('shop_buy', {'item': item.id}, DateTime.now());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('별 조각이 ${item.price - profile.starPieces}개 더 필요해! 탐험하고 모아보자 ⭐')),
      );
      return;
    }
    await repo.saveProfile();
    setState(() {});
  }
}

/// 프로필의 장착 상태 → 캐릭터 스타일 변환
DajoyStyle styleFromProfile(Profile profile) {
  final ribbonId = profile.equipped[ItemSlot.ribbon.name];
  final ribbon = ribbonId == null ? null : findItem(ribbonId);
  return DajoyStyle(
    ribbonColor: ribbon?.color ?? const Color(0xFFFF8FAB),
    hatId: profile.equipped[ItemSlot.hat.name],
    faceId: profile.equipped[ItemSlot.face.name],
  );
}
