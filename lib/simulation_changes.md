# Simulation画面の変更点

## 1. 保存ボタンのラベル変更

**ファイル:** `simulation_screen.dart`
**行:** 852付近

### 変更前:
```dart
ElevatedButton.icon(onPressed: _saveItinerary, icon: const Icon(Icons.save, size: 14), label: Text(l10n.save), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 11))),
```

### 変更後:
```dart
ElevatedButton.icon(onPressed: _saveItinerary, icon: const Icon(Icons.add_chart, size: 14), label: Text(l10n.addToLog), style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), textStyle: const TextStyle(fontSize: 11))),
```

---

## 2. ARBファイルに新キー追加

**app_ja.arb に追加:**
```json
"addToLog": "修行ログに追加",
```

**app_en.arb に追加:**
```json
"addToLog": "Add to Log",
```

---

## 3. 保存成功時のスナックバー変更（オプション）

**行:** 491付近

### 変更前:
```dart
if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「$title」を保存しました'), backgroundColor: Colors.green));
```

### 変更後:
```dart
if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addedToLog(title)), backgroundColor: Colors.green));
```

**ARBファイルに追加:**
```json
// app_ja.arb
"addedToLog": "「{title}」を修行ログに追加しました",
"@addedToLog": {
  "placeholders": {
    "title": {"type": "String"}
  }
},

// app_en.arb
"addedToLog": "Added \"{title}\" to Flight Log",
"@addedToLog": {
  "placeholders": {
    "title": {"type": "String"}
  }
},
```

---

## 4. main.dartの変更

`history_screen.dart` のインポートを `flight_log_screen.dart` に変更:

### 変更前:
```dart
import 'history_screen.dart';
```

### 変更後:
```dart
import 'flight_log_screen.dart';
```

クラス名も変更:
- `HistoryScreen` → `FlightLogScreen`
- `HistoryScreenState` → `FlightLogScreenState`
