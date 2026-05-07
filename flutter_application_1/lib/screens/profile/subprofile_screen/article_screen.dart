// import 'package:flutter/material.dart';

// class ArticleScreen extends StatelessWidget {
//   const ArticleScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFE8EFCF), // พื้นหลังสีครีมเขียว
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 37), // Top margin

//             // --- Header ---
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   // ปุ่มย้อนกลับ (ซ้ายสุด)
//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: IconButton(
//                       icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//                       onPressed: () => Navigator.pop(context),
//                     ),
//                   ),
//                   // ชื่อหน้า (ตรงกลาง)
//                   const Text(
//                     'บทความ',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontFamily: 'Inter',
//                       fontSize: 24,
//                       fontWeight: FontWeight.w400,
//                       color: Colors.black,
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // --- ปุ่ม "ทั้งหมด" (ขวาบน) ---
//             Align(
//               alignment: Alignment.centerRight,
//               child: Container(
//                 margin: const EdgeInsets.only(right: 20, top: 10),
//                 width: 72,
//                 height: 28,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF4C6414), // สีเขียวเข้ม
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//                 alignment: Alignment.center,
//                 child: const Text(
//                   'ทั้งหมด',
//                   style: TextStyle(
//                     fontFamily: 'Inter',
//                     fontSize: 16, // ปรับลดลงนิดนึงให้ใส่พอดี
//                     fontWeight: FontWeight.w400,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 10),

//             // --- หมวด 1: การกิน ---
//             _buildSectionHeader('การกิน'),
//             _buildHorizontalList([
//               _buildArticleCard(
//                 imagePath: 'assets/images/article/20อาหารคลีนที่คนนิยมบริโภค.png',
//                 title: '20 อาหารคลีนที่คนนิยมบริโภค',
//               ),
//               _buildArticleCard(
//                 imagePath: 'assets/images/article/อาหารดองมีผลเสียอะไรหรือไม่.png',
//                 title: 'อาหารดองมีผลเสียอะไรหรือไม่',
//               ),
//             ]),

//             const SizedBox(height: 20),

//             // --- หมวด 2: การออกกำลังกาย ---
//             _buildSectionHeader('การออกกำลังกาย'),
//             _buildHorizontalList([
//               _buildArticleCard(
//                 imagePath: 'assets/images/article/ประโยชน์ของการเดินตอนเช้า.png',
//                 title: 'ประโยชน์ของการเดินตอนเช้า',
//               ),
//               _buildArticleCard(
//                 imagePath: 'assets/images/article/โยคะช่วยอะไร.png',
//                 title: 'โยคะช่วยอะไร???', // ใส่เครื่องหมาย ? ตาม CSS
//               ),
//             ]),

//             const SizedBox(height: 20),

//             // --- หมวด 3: อื่นๆ ---
//             _buildSectionHeader('อื่นๆ'),
//             _buildHorizontalList([
//               _buildArticleCard(
//                 imagePath: 'assets/images/article/สาเหตุของอาการออฟฟิศซินโดรม.png',
//                 title: 'สาเหตุของอาการออฟฟิศซินโดรม',
//               ),
//               _buildArticleCard(
//                 imagePath: 'assets/images/article/การตรวจเบาหวาน.png',
//                 title: 'การตรวจเบาหวาน',
//               ),
//             ]),

//             const SizedBox(height: 40),
//           ],
//         ),
//       ),
//     );
//   }

//   // --- Helper: หัวข้อหมวดหมู่ ---
//   Widget _buildSectionHeader(String title) {
//     return Padding(
//       padding: const EdgeInsets.only(left: 31, top: 10, bottom: 10),
//       child: Text(
//         title,
//         style: const TextStyle(
//           fontFamily: 'Inter',
//           fontSize: 20,
//           fontWeight: FontWeight.w400,
//           color: Colors.black,
//         ),
//       ),
//     );
//   }

//   // --- Helper: รายการแนวนอน ---
//   Widget _buildHorizontalList(List<Widget> children) {
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       padding: const EdgeInsets.only(left: 21),
//       child: Row(
//         children: children.map((item) {
//           return Padding(
//             padding: const EdgeInsets.only(right: 15),
//             child: item,
//           );
//         }).toList(),
//       ),
//     );
//   }

//   // --- Helper: การ์ดบทความ (แก้ไขให้เหมือน CSS) ---
//   Widget _buildArticleCard({required String imagePath, required String title}) {
//     return Stack(
//       alignment: Alignment.bottomCenter,
//       children: [
//         // กล่องรูปภาพ
//         Container(
//           width: 224, // ตาม CSS
//           height: 150, // ตาม CSS
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(30), // ตาม CSS
//             image: DecorationImage(
//               image: AssetImage(imagePath), // ใช้รูปในเครื่อง
//               fit: BoxFit.cover,
//             ),
//             boxShadow: [ // (Optional) ใส่เงาให้นิดนึงจะสวยขึ้น
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.1),
//                 blurRadius: 5,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//         ),

//         // แถบชื่อเรื่อง (ทับด้านล่าง)
//         Positioned(
//           bottom: 25, // ขยับขึ้นมาจากขอบล่างนิดนึงตามรูปตัวอย่าง (หรือปรับเป็น 0 ถ้าอยากให้ติดขอบ)
//           child: Container(
//             width: 224,
//             height: 35, // กำหนดความสูงให้พอดีข้อความ
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               // ทำให้ขอบล่างมนเท่ากับรูป
//               borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
//             ),
//             alignment: Alignment.centerLeft,
//             padding: const EdgeInsets.symmetric(horizontal: 15),
//             child: Text(
//               title,
//               style: const TextStyle(
//                 fontFamily: 'Inter',
//                 fontSize: 14, // ลดขนาดนิดนึงให้แสดงผลไม่ล้น (CSS บอก 16)
//                 fontWeight: FontWeight.w400,
//                 color: Colors.black,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
