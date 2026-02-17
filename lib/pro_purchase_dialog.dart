import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'auth_screen.dart';

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

  // パスコード関連
  bool _showPasscodeInput = false;
  final _passcodeController = TextEditingController();
  bool _isRedeeming = false;
  String? _passcodeError;
  String? _passcodeSuccess;

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  void _navigateToLogin(bool isJapanese) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (newContext) => AuthScreen(
          onAuthSuccess: () {
            Navigator.pop(newContext);
            showProPurchaseDialog(newContext);
          },
        ),
      ),
    );
  }

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
        child: SingleChildScrollView(
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

              // 買い切り表示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isJapanese
                          ? '1年間有効・同額で更新可・自動課金なし'
                          : '1 year license, same price renewal, no auto-charge',
                        style: TextStyle(fontSize: 12, color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ),

              // パスコードセクション
              const SizedBox(height: 12),
              _buildPasscodeSection(isJapanese),

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

  Widget _buildPasscodeSection(bool isJapanese) {
    return Column(
      children: [
        // 「パスコードをお持ちの方」トグルリンク
        TextButton(
          onPressed: () => setState(() => _showPasscodeInput = !_showPasscodeInput),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showPasscodeInput ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                isJapanese ? 'パスコードをお持ちの方' : 'Have a passcode?',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // パスコード入力フォーム（展開時）
        if (_showPasscodeInput)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _passcodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: isJapanese ? 'パスコード' : 'Passcode',
                    hintText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: _isRedeeming
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  enabled: !_isRedeeming,
                  onSubmitted: (_) => _redeemPasscode(isJapanese),
                ),
                if (_passcodeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_passcodeError!, style: TextStyle(color: Colors.red[600], fontSize: 12)),
                  ),
                if (_passcodeSuccess != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_passcodeSuccess!, style: TextStyle(color: Colors.green[600], fontSize: 12)),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _isRedeeming ? null : () => _redeemPasscode(isJapanese),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isJapanese ? 'パスコードを使用' : 'Use Passcode',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _redeemPasscode(bool isJapanese) async {
    // 未ログイン → ログイン画面へ
    if (!_isLoggedIn) {
      _navigateToLogin(isJapanese);
      return;
    }

    final code = _passcodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _passcodeError = isJapanese ? 'パスコードを入力してください' : 'Please enter passcode');
      return;
    }

    setState(() {
      _isRedeeming = true;
      _passcodeError = null;
      _passcodeSuccess = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      // Supabase RPCでパスコード検証＋Pro有効化を一括実行
      final result = await Supabase.instance.client
          .rpc('redeem_promo_code', params: {
        'input_code': code,
        'input_user_id': user.id,
      });

      if (result != null && result['success'] == true) {
        if (mounted) {
          setState(() {
            _isRedeeming = false;
            _passcodeSuccess = result['message'] ?? (isJapanese ? 'Pro版が有効になりました！' : 'Pro activated!');
          });
          _passcodeController.clear();
          // 少し待ってからダイアログを閉じる
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) Navigator.pop(context);
          });
        }
      } else {
        setState(() {
          _isRedeeming = false;
          _passcodeError = result?['message'] ?? (isJapanese ? 'パスコードが無効です' : 'Invalid passcode');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _passcodeError = isJapanese ? 'パスコードの検証に失敗しました' : 'Passcode verification failed';
        });
      }
    }
  }

  Future<void> _startCheckout(bool isJapanese) async {
    // 未ログイン → ログイン画面へ
    if (!_isLoggedIn) {
      _navigateToLogin(isJapanese);
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

    final isEarlyBird = false;
    final showSlots = false;
    final price = 100;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
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
                widget.isJapanese ? '（税込）' : '(tax incl.)',
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
