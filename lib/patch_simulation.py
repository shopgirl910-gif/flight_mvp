#!/usr/bin/env python3
"""
simulation_screen.dart パッチスクリプト
使い方: python patch_simulation.py lib/simulation_screen.dart
"""
import sys

if len(sys.argv) < 2:
    print("使い方: python patch_simulation.py lib/simulation_screen.dart")
    sys.exit(1)

filepath = sys.argv[1]

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

changes = 0

# === 修正1: _optSeatClass状態変数追加 ===
old1 = "  String _optFareType = '';\n  bool _optSearching = false;"
new1 = "  String _optFareType = '';\n  String _optSeatClass = '普通席';\n  bool _optSearching = false;"
if old1 in content:
    content = content.replace(old1, new1)
    changes += 1
    print("✅ 1. _optSeatClass状態変数追加")
else:
    print("❌ 1. 見つからない or 適用済み")

# === 修正2: 航空会社変更時に座席クラスリセット ===
old2 = "                              _optAirline = v!;\n                              _optFareType = '';\n                            }),"
new2 = "                              _optAirline = v!;\n                              _optFareType = '';\n                              _optSeatClass = '普通席';\n                            }),"
if old2 in content:
    content = content.replace(old2, new2)
    changes += 1
    print("✅ 2. 航空会社変更時リセット")
else:
    print("❌ 2. 見つからない or 適用済み")

# === 修正3: 座席クラスドロップダウン追加 ===
old3 = """                            onChanged: (v) =>
                                setState(() => _optFareType = v ?? ''),
                          ),
                        ),
                      ],"""
new3 = """                            onChanged: (v) =>
                                setState(() => _optFareType = v ?? ''),
                          ),
                        ),
                        _optInputSection(
                          '座席クラス',
                          120,
                          DropdownButton<String>(
                            value: _optSeatClass,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: (seatClassesByAirline[_optAirline] ?? [])
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _optSeatClass = v ?? '普通席'),
                          ),
                        ),
                      ],"""
if old3 in content:
    content = content.replace(old3, new3)
    changes += 1
    print("✅ 3. 座席クラスドロップダウン追加")
else:
    print("❌ 3. 見つからない or 適用済み")

# === 修正4: _transferToFreeDesignでfareType/seatClass転送 ===
old4 = """      setState(() {
        legs[legIndex]['airline'] = _optAirline;
        legs[legIndex]['departureAirport'] = f.departureCode;
        legs[legIndex]['arrivalAirport'] = f.arrivalCode;
      });"""
new4 = """      setState(() {
        legs[legIndex]['airline'] = _optAirline;
        legs[legIndex]['departureAirport'] = f.departureCode;
        legs[legIndex]['arrivalAirport'] = f.arrivalCode;
        legs[legIndex]['fareType'] = _optFareType;
        legs[legIndex]['seatClass'] = _optSeatClass;
      });"""
if old4 in content:
    content = content.replace(old4, new4)
    changes += 1
    print("✅ 4. fareType/seatClass転送追加")
else:
    print("❌ 4. 見つからない or 適用済み")

# === 修正5: ボタン名「予定に追加」に変更 ===
count = content.count('修行ログに追加')
if count > 0:
    content = content.replace('修行ログに追加', '予定に追加')
    changes += 1
    print(f"✅ 5. ボタン名変更 ({count}箇所)")
else:
    print("❌ 5. 見つからない or 適用済み")

# 保存
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n完了: {changes}件の修正を適用しました → {filepath}")
