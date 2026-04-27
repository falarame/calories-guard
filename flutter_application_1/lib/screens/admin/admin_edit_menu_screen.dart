import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_client.dart';
import 'package:image_picker/image_picker.dart';

class AdminEditMenuScreen extends StatefulWidget {
  // รับข้อมูลอาหารเดิมเข้ามาทั้งก้อน
  final Map<String, dynamic> foodData;

  const AdminEditMenuScreen({super.key, required this.foodData});

  @override
  State<AdminEditMenuScreen> createState() => _AdminEditMenuScreenState();
}

class _AdminEditMenuScreenState extends State<AdminEditMenuScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  // (เพิ่ม Controller วัตถุดิบ/วิธีทำ ได้ตามต้องการ)

  XFile? _selectedImage;
  Uint8List? _selectedBytes;
  String? _currentImageUrl; // เก็บ URL รูปเดิม
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // 1. เอาข้อมูลเก่ามาใส่ในช่องกรอก
    final f = widget.foodData;
    _nameCtrl = TextEditingController(text: f['food_name']);
    _caloriesCtrl = TextEditingController(text: f['calories'].toString());
    _proteinCtrl = TextEditingController(text: f['protein'].toString());
    _carbsCtrl = TextEditingController(text: f['carbs'].toString());
    _fatCtrl = TextEditingController(text: f['fat'].toString());

    // เก็บ URL เดิมไว้ ถ้าไม่ได้เลือกรูปใหม่จะใช้ค่านี้
    _currentImageUrl = f['image_url'];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = pickedFile;
        _selectedBytes = bytes;
      });
    }
  }

  Future<void> _updateMenu() async {
    setState(() => _isUploading = true);
    String? imageUrlToSave = _currentImageUrl; // เริ่มต้นด้วยรูปเดิม

    try {
      // 2. ถ้ามีการเลือกรูปใหม่ ให้อัปโหลดและเปลี่ยน URL
      if (_selectedImage != null && _selectedBytes != null) {
        final filename = _selectedImage!.name.isNotEmpty
            ? _selectedImage!.name
            : 'menu.jpg';
        final streamRes = await ApiClient().uploadBytes(
          '/upload-image/',
          fieldName: 'file',
          bytes: _selectedBytes!,
          fileName: filename,
        );
        if (streamRes.statusCode == 200) {
          var resData = await streamRes.stream.bytesToString();
          imageUrlToSave = jsonDecode(resData)['url']; // ได้ URL ใหม่
        }
      }

      // 3. เรียก API PUT เพื่อแก้ไขข้อมูล
      final foodId = widget.foodData['food_id'];
      final res = await ApiClient().put(
        '/foods/$foodId',
        body: {
          "food_name": _nameCtrl.text,
          "calories": double.tryParse(_caloriesCtrl.text) ?? 0,
          "protein": double.tryParse(_proteinCtrl.text) ?? 0,
          "carbs": double.tryParse(_carbsCtrl.text) ?? 0,
          "fat": double.tryParse(_fatCtrl.text) ?? 0,
          "image_url": imageUrlToSave // ส่ง URL (เก่าหรือใหม่) ไป
        },
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('แก้ไขเรียบร้อย!'), backgroundColor: Colors.green));
          Navigator.pop(
              context, true); // ส่งค่า true กลับไปบอกหน้าก่อนหน้าให้รีเฟรช
        }
      } else {
        throw Exception('Failed to update: ${res.body}');
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error updating'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      appBar: AppBar(
          title: const Text("แก้ไขเมนูอาหาร"),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ส่วนแสดงรูป
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                  image: _selectedBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_selectedBytes!),
                          fit:
                              BoxFit.cover) // ✅ 2. เช็ค _selectedBytes ก่อนเสมอ
                      : (_currentImageUrl != null &&
                              _currentImageUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(_currentImageUrl!),
                              fit: BoxFit.cover)
                          : null,
                ),
                child: (_selectedBytes == null &&
                        (_currentImageUrl == null || _currentImageUrl!.isEmpty))
                    ? const Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Icon(Icons.add_a_photo,
                                size: 40, color: Colors.grey),
                            Text("เพิ่มรูปภาพ")
                          ]))
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // ช่องกรอกข้อมูล (ใส่ Controller ที่เตรียมไว้)
            _buildTextField("ชื่อเมนู", _nameCtrl),
            const SizedBox(height: 10),
            _buildTextField("แคลอรี่", _caloriesCtrl, isNumber: true),
            const SizedBox(height: 10),
            _buildTextField("โปรตีน", _proteinCtrl, isNumber: true),
            const SizedBox(height: 10),
            _buildTextField("คาร์โบไฮเดรต", _carbsCtrl, isNumber: true),
            const SizedBox(height: 10),
            _buildTextField("ไขมัน", _fatCtrl, isNumber: true),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _updateMenu,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF628141),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("บันทึกการแก้ไข",
                        style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      ),
    );
  }
}
