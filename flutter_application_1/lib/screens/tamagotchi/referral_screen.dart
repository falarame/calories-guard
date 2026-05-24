import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/services/api_client.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  static const _green = Color(0xFF4C6414);
  static const _greenLight = Color(0xFFE8EFCF);

  String? _myCode;
  bool _buffActive = false;
  int _buffMultiplier = 1;
  String? _buffExpiresAt;
  bool _loading = true;
  String? _loadError;

  final _codeCtrl = TextEditingController();
  bool _redeeming = false;
  String? _redeemError;
  bool _redeemSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await ApiClient().get('/referral/status');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _myCode = data['code']?.toString();
          _buffActive = data['buff_active'] == true;
          _buffMultiplier = (data['gem_buff_multiplier'] as num?)?.toInt() ?? 1;
          _buffExpiresAt = data['buff_expires_at']?.toString();
        });
      } else {
        setState(() => _loadError = 'status ${res.statusCode}: ${res.body}');
      }
      if (_myCode == null && _loadError == null) {
        final genRes = await ApiClient().post('/referral/generate', body: {});
        if (genRes.statusCode == 200) {
          final d = jsonDecode(genRes.body) as Map<String, dynamic>;
          setState(() => _myCode = d['code']?.toString());
        } else {
          setState(() =>
              _loadError = 'generate ${genRes.statusCode}: ${genRes.body}');
        }
      }
    } catch (e) {
      setState(() => _loadError = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _redeeming = true;
      _redeemError = null;
      _redeemSuccess = false;
    });
    try {
      final res =
          await ApiClient().post('/referral/redeem', body: {'code': code});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _redeemSuccess = true;
          _buffActive = true;
          _buffMultiplier = 2;
          _buffExpiresAt = data['buff_expires_at']?.toString();
        });
        _codeCtrl.clear();
      } else {
        final err = jsonDecode(res.body);
        setState(() =>
            _redeemError = (err['detail'] ?? 'เกิดข้อผิดพลาด').toString());
      }
    } catch (_) {
      setState(() => _redeemError = 'ไม่สามารถเชื่อมต่อได้');
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _formatExpiry(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('🎁 ชวนเพื่อน',
            style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _myCode == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('โหลดข้อมูลไม่ได้',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(_loadError!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadStatus,
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองใหม่'),
                      ),
                    ]),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMyCodeCard(),
                      const SizedBox(height: 20),
                      if (_buffActive) _buildBuffCard(),
                      if (_buffActive) const SizedBox(height: 20),
                      _buildRedeemCard(),
                      const SizedBox(height: 24),
                      _buildHowItWorksCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMyCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('โค้ดชวนเพื่อนของคุณ',
              style: TextStyle(
                  color: Colors.white70, fontSize: 13, fontFamily: 'Inter')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                _myCode ?? '...',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Inter',
                    letterSpacing: 2),
              ),
            ),
            IconButton(
              onPressed: _myCode == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _myCode!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('คัดลอกโค้ดแล้ว ✅'),
                          duration: Duration(seconds: 2)));
                    },
              icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'เพื่อนที่กรอกโค้ดนี้ตอนสมัคร → คุณได้ 50 🌾',
              style: TextStyle(
                  color: Colors.white, fontSize: 12, fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuffCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(children: [
        const Text('✨', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('บัฟ ×$_buffMultiplier เมล็ดข้าว กำลังทำงาน!',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'Inter')),
            if (_buffExpiresAt != null)
              Text('หมดอายุ: ${_formatExpiry(_buffExpiresAt)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontFamily: 'Inter')),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRedeemCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('กรอกโค้ดชวนเพื่อน',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                fontFamily: 'Inter')),
        const SizedBox(height: 4),
        Text(
          'ใช้ได้เฉพาะบัญชีที่สมัครไม่เกิน 7 วัน',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'RICE-1234',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        if (_redeemError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_redeemError!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        if (_redeemSuccess)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
              SizedBox(width: 6),
              Text('รับโบนัสสำเร็จ! 🎉 +30 🌾 + บัฟ ×2 เป็นเวลา 7 วัน',
                  style: TextStyle(color: Colors.green, fontSize: 13)),
            ]),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _redeeming ? null : _redeem,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _redeeming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('ใช้โค้ด',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontFamily: 'Inter')),
          ),
        ),
      ]),
    );
  }

  Widget _buildHowItWorksCard() {
    final steps = [
      ('🔗', 'แชร์โค้ดของคุณให้เพื่อนที่ยังไม่เคยใช้แอป'),
      ('📲', 'เพื่อนสมัครบัญชีใหม่ แล้วกรอกโค้ดในหน้านี้'),
      ('🌾', 'คุณได้ 50 เมล็ดข้าว ทันที'),
      ('✨', 'เพื่อนได้ 30 เมล็ดข้าว + บัฟ ×2 เป็นเวลา 7 วัน'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('วิธีใช้งาน',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _green,
                  fontFamily: 'Inter')),
          const SizedBox(height: 12),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(s.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontFamily: 'Inter'))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
