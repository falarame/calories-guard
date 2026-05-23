import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show cos, sqrt, asin;
import '../config/secrets.dart';
import '../constants/constants.dart';
import '../widget/web_unsupported_placeholder.dart';

class RestaurantMapScreen extends StatefulWidget {
  final double remainingCalories;

  const RestaurantMapScreen({
    super.key,
    required this.remainingCalories,
  });

  @override
  State<RestaurantMapScreen> createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen> {
  static const Color _green = Color(0xFF628141);
  static const Color _greenL = Color(0xFFE8EFCF);
  static const Color _orange = Color(0xFFD76A3C);
  static const Color _orangeL = Color(0xFFFFF3E0);
  static const Color _blue = Color(0xFF1565C0);
  static const Color _bg = Color(0xFFF2F7F4);
  static const Color _red = Color(0xFFD32F2F);

  static const String _apiKey = Secrets.googleMapsApiKey;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _filteredRestaurants = [];
  bool _isLoading = true;
  int _radiusMeters = 1000;
  String _selectedFilter = 'ทั้งหมด';
  String _selectedKeyword = 'ทั้งหมด';
  Map<String, dynamic>? _selectedRestaurant;

  final List<String> _filters = ['ทั้งหมด', 'เปิดอยู่', '⭐4.0+'];
  final List<String> _keywords = [
    'ทั้งหมด',
    'สลัด',
    'อาหารญี่ปุ่น',
    'ข้าวต้ม',
    'ผัดผัก'
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initLocation();
    }
  }

  String _apiBase() {
    final u = AppConstants.baseUrl.trim();
    if (u.isEmpty) return '';
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('กรุณาเปิดบริการตำแหน่ง (GPS) เพื่อค้นหาร้านใกล้คุณ'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ต้องอนุญาตตำแหน่งเพื่อแสดงร้านใกล้คุณ'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('การอนุญาตตำแหน่งถูกปิดถาวร กรุณาเปิดในการตั้งค่าแอป'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      await _fetchNearbyRestaurants();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถระบุตำแหน่งได้ กรุณาเปิดใช้งาน GPS'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchNearbyRestaurants() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);

    try {
      http.Response response;
      final base = _apiBase();
      if (base.isNotEmpty) {
        final q = <String, String>{
          'lat': '${_currentPosition!.latitude}',
          'lng': '${_currentPosition!.longitude}',
          'radius': '$_radiusMeters',
        };
        if (_selectedKeyword != 'ทั้งหมด') {
          q['keyword'] = _selectedKeyword;
        }
        final uri =
            Uri.parse('$base/places/nearby').replace(queryParameters: q);
        response = await http.get(uri);
        // Backend ไม่มีคีย์ → ลองเรียก Google โดยตรง (เดฟ / fallback)
        if (response.statusCode == 503) {
          final keywordParam = _selectedKeyword != 'ทั้งหมด'
              ? '&keyword=${Uri.encodeComponent(_selectedKeyword)}'
              : '';
          response = await http.get(Uri.parse(
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&radius=$_radiusMeters'
            '&type=restaurant'
            '&language=th'
            '$keywordParam'
            '&key=$_apiKey',
          ));
        }
      } else {
        final keywordParam = _selectedKeyword != 'ทั้งหมด'
            ? '&keyword=${Uri.encodeComponent(_selectedKeyword)}'
            : '';
        response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&radius=$_radiusMeters'
          '&type=restaurant'
          '&language=th'
          '$keywordParam'
          '&key=$_apiKey',
        ));
      }

      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('ไม่สามารถโหลดร้านได้ (รหัส ${response.statusCode})'),
              backgroundColor: _red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        final err = (data['error_message'] as String?)?.trim() ?? status;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                err.isEmpty
                    ? 'ไม่สามารถค้นหาร้านได้ กรุณาลองใหม่'
                    : 'ค้นหาร้านไม่สำเร็จ: $err',
              ),
              backgroundColor: _red,
            ),
          );
        }
        setState(() {
          _restaurants = [];
          _filteredRestaurants = [];
          _markers = {};
          _isLoading = false;
        });
        return;
      }

      final results = (data['results'] as List?) ?? [];

      setState(() {
        _restaurants = results.map((r) {
          final lat = r['geometry']['location']['lat'];
          final lng = r['geometry']['location']['lng'];
          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            lat,
            lng,
          );

          return {
            'place_id': r['place_id'],
            'name': r['name'],
            'vicinity': r['vicinity'] ?? '',
            'rating': r['rating']?.toDouble() ?? 0.0,
            'user_ratings_total': r['user_ratings_total'] ?? 0,
            'lat': lat,
            'lng': lng,
            'distance': distance,
            'open_now': r['opening_hours']?['open_now'] ?? false,
            'has_opening_hours': r['opening_hours'] != null,
            'photos': r['photos'],
          };
        }).toList();

        _filteredRestaurants = List.from(_restaurants);
        _applyFilters();
        _updateMarkers();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: _red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  void _applyFilters() {
    _filteredRestaurants = _restaurants.where((r) {
      if (_selectedFilter == 'เปิดอยู่') {
        // Only filter when opening_hours data is available
        if (r['has_opening_hours'] == true && !r['open_now']) return false;
      }
      if (_selectedFilter == '⭐4.0+' && r['rating'] < 4.0) return false;
      return true;
    }).toList();

    _filteredRestaurants.sort((a, b) => a['distance'].compareTo(b['distance']));
  }

  void _updateMarkers() {
    _markers = _filteredRestaurants.map((restaurant) {
      return Marker(
        markerId: MarkerId(restaurant['place_id']),
        position: LatLng(restaurant['lat'], restaurant['lng']),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
        onTap: () {
          setState(() {
            _selectedRestaurant = restaurant;
          });
        },
        infoWindow: InfoWindow(
          title: restaurant['name'],
          snippet: '${restaurant['distance'].toStringAsFixed(0)}m',
        ),
      );
    }).toSet();
  }

  String _getPhotoUrl(dynamic photos) {
    if (photos == null) return '';
    if (photos is! List || photos.isEmpty) return '';
    final photoRef = photos[0]['photo_reference'];
    if (photoRef == null) return '';
    final ref = Uri.encodeComponent(photoRef.toString());
    final base = _apiBase();
    if (base.isNotEmpty) {
      return '$base/places/photo?maxwidth=400&photo_reference=$ref';
    }
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$ref&key=$_apiKey';
  }

  String _getAICalorieHint(double remainingCal) {
    if (remainingCal > 800) {
      return 'คุณมีแคลอรี่เหลือเยอะ เลือกได้อิสระ!';
    } else if (remainingCal > 500) {
      return 'แนะนำเมนูปานกลาง หรือแบ่งปัน';
    } else if (remainingCal > 300) {
      return 'เลือกเมนูเบา เช่น สลัด หรือซุป';
    } else if (remainingCal > 0) {
      return 'แคลอรี่เหลือน้อย ควรเลือกของว่าง';
    } else {
      return 'แคลอรี่เกินแล้ว ควรหลีกเลี่ยงอาหารหนัก';
    }
  }

  Widget _buildSafeImage(String url,
      {required double width, required double height, double iconSize = 24}) {
    return FutureBuilder<http.Response>(
      future: http.get(Uri.parse(url)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
              width: width,
              height: height,
              color: _greenL,
              child: const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: _green, strokeWidth: 2))));
        }
        if (snapshot.hasData &&
            snapshot.data!.statusCode == 200 &&
            snapshot.data!.headers['content-type']?.startsWith('image') ==
                true) {
          return Image.memory(snapshot.data!.bodyBytes,
              width: width, height: height, fit: BoxFit.cover);
        }
        return Container(
            width: width,
            height: height,
            color: _greenL,
            child: Icon(Icons.restaurant, color: _green, size: iconSize));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebUnsupportedPlaceholder(
        title: 'แผนที่ร้านอาหาร',
        message:
            'แผนที่ร้านอาหารใกล้คุณใช้งานได้เฉพาะบนแอปมือถือ\nกรุณาดาวน์โหลดแอปเพื่อใช้งาน',
        icon: Icons.map_rounded,
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),
          if (_isLoading) _buildLoadingOverlay(),
          _buildRestaurantList(),
          if (_selectedRestaurant != null) _buildDetailPanel(),
          _buildRadiusToggle(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_currentPosition == null) {
      return Container(
        color: _bg,
        child: const Center(
          child: CircularProgressIndicator(color: _green),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
        // ignore: deprecated_member_use
        controller.setMapStyle('''
        [
          {
            "featureType": "all",
            "elementType": "geometry",
            "stylers": [{"color": "#E8EFCF"}]
          },
          {
            "featureType": "water",
            "elementType": "geometry",
            "stylers": [{"color": "#AFD198"}]
          },
          {
            "featureType": "road",
            "elementType": "geometry",
            "stylers": [{"color": "#ffffff"}]
          },
          {
            "featureType": "poi.park",
            "elementType": "geometry",
            "stylers": [{"color": "#628141"}]
          }
        ]
        ''');
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'ร้านอาหารใกล้ฉัน',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: _green),
                  onPressed: _fetchNearbyRestaurants,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFilterChips(),
            const SizedBox(height: 12),
            _buildKeywordScroll(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: _filters.map((filter) {
        final isSelected = _selectedFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = filter;
                _applyFilters();
                _updateMarkers();
              });
            },
            backgroundColor: Colors.white,
            selectedColor: _greenL,
            labelStyle: TextStyle(
              color: isSelected ? _green : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected ? _green : Colors.grey.shade300,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeywordScroll() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _keywords.length,
        itemBuilder: (context, index) {
          final keyword = _keywords[index];
          final isSelected = _selectedKeyword == keyword;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(keyword),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedKeyword = keyword;
                });
                _fetchNearbyRestaurants();
              },
              backgroundColor: Colors.white,
              selectedColor: _orange.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? _orange : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? _orange : Colors.grey.shade300,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: CircularProgressIndicator(color: _green),
      ),
    );
  }

  Widget _buildRestaurantList() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: _green.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'พบ ${_filteredRestaurants.length} ร้าน',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'เหลือ ${widget.remainingCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredRestaurants.length,
                  itemBuilder: (context, index) {
                    return _buildRestaurantCard(_filteredRestaurants[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final photoUrl = _getPhotoUrl(restaurant['photos']);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRestaurant = restaurant;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(restaurant['lat'], restaurant['lng']),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photoUrl.isNotEmpty
                  ? _buildSafeImage(photoUrl, width: 80, height: 80)
                  : Container(
                      width: 80,
                      height: 80,
                      color: _greenL,
                      child: const Icon(Icons.restaurant, color: _green),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant['vicinity'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: _orange),
                      const SizedBox(width: 4),
                      Text(
                        restaurant['rating'].toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on, size: 16, color: _blue),
                      const SizedBox(width: 4),
                      Text(
                        '${(restaurant['distance'] / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: restaurant['open_now']
                              ? _greenL
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          restaurant['open_now'] ? 'เปิดอยู่' : 'ปิดแล้ว',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: restaurant['open_now'] ? _green : _red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    final restaurant = _selectedRestaurant!;
    final photoUrl = _getPhotoUrl(restaurant['photos']);
    final aiHint = _getAICalorieHint(widget.remainingCalories);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (photoUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildSafeImage(photoUrl,
                            width: double.infinity, height: 200, iconSize: 64),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant['name'],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: restaurant['open_now']
                                ? _greenL
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            restaurant['open_now'] ? 'เปิดอยู่' : 'ปิดแล้ว',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: restaurant['open_now'] ? _green : _red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatChip(
                          Icons.star,
                          '${restaurant['rating'].toStringAsFixed(1)}',
                          _orange,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          Icons.location_on,
                          '${(restaurant['distance'] / 1000).toStringAsFixed(1)} km',
                          _blue,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          Icons.local_fire_department,
                          '${widget.remainingCalories.toStringAsFixed(0)} kcal',
                          _orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _orangeL,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: _orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, color: _orange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              aiHint,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      restaurant['vicinity'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final placeId = restaurant['place_id'];
                          final uri = Uri.parse(
                              'https://www.google.com/maps/place/?q=place_id:$placeId');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon:
                            const Icon(Icons.map_rounded, color: Colors.white),
                        label: const Text(
                          'เปิดใน Google Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusToggle() {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).size.height * 0.35,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'radius_500',
            mini: true,
            backgroundColor: _radiusMeters == 500 ? _green : Colors.white,
            onPressed: () {
              setState(() {
                _radiusMeters = 500;
              });
              _fetchNearbyRestaurants();
            },
            child: Text(
              '500m',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _radiusMeters == 500 ? Colors.white : _green,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'radius_1000',
            mini: true,
            backgroundColor: _radiusMeters == 1000 ? _green : Colors.white,
            onPressed: () {
              setState(() {
                _radiusMeters = 1000;
              });
              _fetchNearbyRestaurants();
            },
            child: Text(
              '1km',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _radiusMeters == 1000 ? Colors.white : _green,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'radius_2000',
            mini: true,
            backgroundColor: _radiusMeters == 2000 ? _green : Colors.white,
            onPressed: () {
              setState(() {
                _radiusMeters = 2000;
              });
              _fetchNearbyRestaurants();
            },
            child: Text(
              '2km',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _radiusMeters == 2000 ? Colors.white : _green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
