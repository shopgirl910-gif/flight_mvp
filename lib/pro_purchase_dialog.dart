import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Pro版購入ダイアログを表示
/// 各画面から呼び出し: showProPurchaseDialog(context);
Future<void> showProPurchaseDialog(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _ProPurchaseDialog(),
  );
}

class _ProPurchaseDialog extends StatefulWidget {
  const _ProPurchaseDialog();

  @override
  State<_ProPurchaseDialog> createState() => _ProPurchaseDialogState();
}

class _ProPurchaseDialogState extends State<_ProPurchaseDialog> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.workspace_premium, color: Colors.amber[700], size: 28),
          const SizedBox(width: 8),
          Text(
            isJapanese ? 'Pro版にアップグレード' : 'Upgrade to Pro',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 価格表示
            _PriceDisplay(isJapanese: isJapanese),

            const SizedBox(height: 16),

            // 機能一覧
            _FeatureItem(
              icon: Icons.all_inclusive,
              text: isJapanese ? 'レグ追加 無制限' : 'Unlimited legs',
            ),
            _FeatureItem(
              icon: Icons.save,
              text: isJapanese ? '旅程保存 無制限' : 'Unlimited saved itineraries',
            ),
            _FeatureItem(
              icon: Icons.auto_awesome,
              text: isJapanese ? 'おまかせ最適化 全結果表示' : 'All optimization results',
            ),
            _FeatureItem(
              icon: Icons.file_download,
              text: isJapanese ? 'CSVエクスポート' : 'CSV export',
            ),
            _FeatureItem(
              icon: Icons.email,
              text: isJapanese ? 'AIメール解析入力（準備中）' : 'AI email parsing (coming)',
            ),

            const SizedBox(height: 12),

            // 1年有効期限表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isJapanese
                          ? '有効期限1年・自動更新なし・更新時も同価格'
                          : '1-year validity, no auto-renewal, same price on renewal',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(isJapanese ? '閉じる' : 'Close'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _startCheckout(isJapanese),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  isJapanese ? '購入する' : 'Purchase',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Future<void> _startCheckout(bool isJapanese) async {
    final user = Supabase.instance.client.auth.currentUser;

    // 匿名ユーザー or 未ログイン
    if (user == null || user.isAnonymous) {
      setState(() {
        _error = isJapanese
            ? 'Pro版の購入にはログインが必要です'
            : 'Please log in to purchase Pro';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Supabase Edge Function を呼び出し
      final response = await Supabase.instance.client.functions.invoke(
        'create-checkout-session',
        body: {},
      );

      if (response.status != 200) {
        final errorData = response.data;
        throw Exception(errorData?['error'] ?? 'Unknown error');
      }

      final data = response.data;
      final checkoutUrl = data['url'] as String?;

      if (checkoutUrl == null) {
        throw Exception('Checkout URL not received');
      }

      // Stripe Checkout ページにリダイレクト
      html.window.location.href = checkoutUrl;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = isJapanese
            ? '決済の開始に失敗しました: ${e.toString().replaceAll('Exception: ', '')}'
            : 'Failed to start checkout: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }
}

/// 価格表示ウィジェット（先着枠情報付き）
class _PriceDisplay extends StatefulWidget {
  final bool isJapanese;
  const _PriceDisplay({required this.isJapanese});

  @override
  State<_PriceDisplay> createState() => _PriceDisplayState();
}

class _PriceDisplayState extends State<_PriceDisplay> {
  int? _remainingSlots;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final response = await Supabase.instance.client
          .from('pro_purchase_stats')
          .select()
          .single();
      if (mounted) {
        setState(() {
          _remainingSlots = response['remaining_slots'] as int? ?? 0;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _remainingSlots = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final isEarlyBird = (_remainingSlots ?? 0) > 0;
    final showSlots = (_remainingSlots ?? 0) <= 20;
    final price = isEarlyBird ? 100 : 480;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEarlyBird
              ? [Colors.purple[50]!, Colors.amber[50]!]
              : [Colors.grey[100]!, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEarlyBird ? Colors.amber[300]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          if (isEarlyBird) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[600],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.isJapanese
                    ? (showSlots
                          ? '🎉 リリース記念価格（残り${_remainingSlots}枠）'
                          : '🎉 リリース記念価格')
                    : (showSlots
                          ? '🎉 Launch price (${_remainingSlots} spots left)'
                          : '🎉 Launch price'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (isEarlyBird)
                Text(
                  '¥480/年',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              if (isEarlyBird) const SizedBox(width: 8),
              Text(
                '¥$price',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isEarlyBird ? Colors.purple[700] : Colors.grey[800],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                widget.isJapanese ? '/年（税込）' : '/year (tax incl.)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 機能アイテムウィジェット
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.purple[600]),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
