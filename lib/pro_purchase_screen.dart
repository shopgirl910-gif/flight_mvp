import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pro_service.dart';
import 'auth_screen.dart';

class ProPurchaseScreen extends StatefulWidget {
  const ProPurchaseScreen({super.key});

  @override
  State<ProPurchaseScreen> createState() => _ProPurchaseScreenState();
}

class _ProPurchaseScreenState extends State<ProPurchaseScreen> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isPro = false;
  int _proCount = 0;
  static const int _earlyBirdLimit = 200;
  String? _errorMessage;

  // パスコード関連
  bool _showPasscodeInput = false;
  final _passcodeController = TextEditingController();
  bool _isRedeeming = false;
  String? _passcodeError;
  String? _passcodeSuccess;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final proService = ProService();
      final isPro = await proService.isPro();

      // pro_purchase_statsビューから購入者数を取得
      int proCount = 0;
      try {
        final result = await Supabase.instance.client
            .from('pro_purchase_stats')
            .select('pro_count')
            .single();
        proCount = result['pro_count'] ?? 0;
      } catch (e) {
        // ビューがない場合はuser_profilesから直接カウント
        try {
          final result = await Supabase.instance.client
              .from('user_profiles')
              .select('id')
              .eq('is_pro', true);
          proCount = (result as List).length;
        } catch (_) {
          proCount = 0;
        }
      }

      if (mounted) {
        setState(() {
          _isPro = isPro;
          _proCount = proCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'データの読み込みに失敗しました';
        });
      }
    }
  }

  bool get _isEarlyBird => _proCount < _earlyBirdLimit;
  int get _currentPrice => _isEarlyBird ? 100 : 480;
  int get _remainingSlots => (_earlyBirdLimit - _proCount).clamp(0, _earlyBirdLimit);

  bool get _isLoggedIn {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      // TODO: Stripe決済連携
      // 1. サーバーサイドでStripe Checkout Sessionを作成
      // 2. ユーザーをStripe決済ページにリダイレクト
      // 3. 決済成功コールバックでactivatePro()を呼ぶ
      //
      // 仮実装：直接Pro化（Stripe実装後に置き換え）
      final proService = ProService();
      await proService.activatePro();

      if (mounted) {
        setState(() {
          _isPro = true;
          _isPurchasing = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = '購入処理に失敗しました: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _redeemPasscode() async {
    final code = _passcodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _passcodeError = 'パスコードを入力してください');
      return;
    }

    setState(() {
      _isRedeeming = true;
      _passcodeError = null;
      _passcodeSuccess = null;
    });

    try {
      // Supabase RPCでパスコード検証＋Pro有効化を一括実行
      final result = await Supabase.instance.client
          .rpc('redeem_promo_code', params: {
        'input_code': code,
        'input_user_id': Supabase.instance.client.auth.currentUser!.id,
      });

      if (result != null && result['success'] == true) {
        if (mounted) {
          setState(() {
            _isRedeeming = false;
            _isPro = true;
            _passcodeSuccess = result['message'] ?? 'Pro版が有効になりました！';
          });
          _passcodeController.clear();
          // 少し待ってから成功ダイアログ
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _showSuccessDialog();
          });
        }
      } else {
        setState(() {
          _isRedeeming = false;
          _passcodeError = result?['message'] ?? 'パスコードが無効です';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _passcodeError = 'パスコードの検証に失敗しました';
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Pro版 有効化完了！'),
          ],
        ),
        content: const Text(
          'すべてのPro機能が利用可能になりました。\n修行計画を存分にお楽しみください！',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ダイアログを閉じる
              Navigator.of(context).pop(); // 購入画面を閉じる
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro版アップグレード'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // エラーメッセージ
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(_errorMessage!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
                    ),

                  // 既にPro版の場合
                  if (_isPro) ...[
                    _buildProActiveCard(),
                  ] else ...[
                    // 先着カウンター
                    if (_isEarlyBird) _buildEarlyBirdBanner(),
                    const SizedBox(height: 16),
                    // 価格カード
                    _buildPriceCard(),
                    const SizedBox(height: 20),
                    // 機能比較テーブル
                    _buildFeatureComparison(),
                    const SizedBox(height: 20),
                    // 購入ボタン
                    _buildPurchaseButton(),
                    const SizedBox(height: 12),
                    // 注意事項
                    _buildDisclaimer(),
                    const SizedBox(height: 20),
                    // パスコード入力（ログイン時のみ）
                    if (_isLoggedIn) _buildPasscodeSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildProActiveCard() {
    return Card(
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.verified, color: Colors.green[700], size: 48),
            const SizedBox(height: 12),
            Text(
              'Pro版 有効',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800]),
            ),
            const SizedBox(height: 8),
            Text(
              'すべてのPro機能をご利用いただけます',
              style: TextStyle(fontSize: 14, color: Colors.green[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarlyBirdBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[700]!, Colors.orange[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text(
                'リリース記念価格',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(width: 6),
              Icon(Icons.local_fire_department, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _remainingSlots <= 20
                ? '先着$_earlyBirdLimit名限定 — 残り $_remainingSlots 名'
                : '先着$_earlyBirdLimit名限定',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          if (_remainingSlots <= 20) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _proCount / _earlyBirdLimit,
                minHeight: 8,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple[50]!, Colors.purple[100]!],
          ),
        ),
        child: Column(
          children: [
            const Text('MRP Pro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('買い切り・追加課金なし', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isEarlyBird) ...[
                  Text(
                    '¥480',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[500],
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '¥$_currentPrice',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            if (_isEarlyBird)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '79%OFF',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('機能比較', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _featureRow('FOP/PP計算', '6レグ/日', '無制限', true),
            _featureRow('おまかせ最適化', '結果1件', '全ランキング', true),
            _featureRow('修行ログ保存', '5旅程まで', '無制限', true),
            _featureRow('CSVエクスポート', '—', '✓', true),
            _featureRow('AIメール解析', '—', '✓', true),
            _featureRow('クイズ', '✓', '✓', false),
            _featureRow('チェックイン', '✓', '✓', false),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(String feature, String free, String pro, bool isProAdvantage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(feature, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              pro,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isProAdvantage ? FontWeight.bold : FontWeight.normal,
                color: isProAdvantage ? Colors.purple[700] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    // 未ログイン時はログインボタンを表示
    if (!_isLoggedIn) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '購入にはログインが必要です',
                    style: TextStyle(color: Colors.orange[800], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(
                      onAuthSuccess: () {
                        Navigator.pop(context); // AuthScreenを閉じる
                        setState(() {}); // ログイン状態を反映
                        _loadData(); // Pro状態を再読み込み
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('ログインして購入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isPurchasing ? null : _handlePurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isPurchasing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                '¥$_currentPrice で購入する',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '• 買い切り型です。月額料金は発生しません。\n'
        '• 購入後、すぐにすべてのPro機能が有効になります。\n'
        '• お支払いはStripeによる安全な決済です。',
        style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.6),
      ),
    );
  }

  Widget _buildPasscodeSection() {
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
                'パスコードをお持ちの方',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // パスコード入力フォーム（展開時）
        if (_showPasscodeInput)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _passcodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'パスコード',
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
                    onSubmitted: (_) => _redeemPasscode(),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _isRedeeming ? null : _redeemPasscode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('パスコードを使用', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
