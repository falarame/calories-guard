import 'package:flutter/material.dart';

class RulerSlider extends StatefulWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final double step;
  final ValueChanged<double> onChanged;
  final String unit;
  final bool showDecimals;
  final String? displayUnit; // Display unit (e.g., 'สัปดาห์' for weeks)
  final double?
      displayDivisor; // Divisor for display (e.g., 7 for weeks from days)

  const RulerSlider({
    super.key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.step,
    required this.onChanged,
    this.unit = '',
    this.showDecimals = true,
    this.displayUnit,
    this.displayDivisor,
  });

  @override
  State<RulerSlider> createState() => _RulerSliderState();
}

class _RulerSliderState extends State<RulerSlider> {
  late ScrollController _scrollController;
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _scrollController = ScrollController();

    // Scroll to initial value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToValue(_currentValue);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToValue(double value) {
    final index = ((value - widget.minValue) / widget.step).round();
    final offset = index * 60.0; // 60 = width of each scale item
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onScroll() {
    // Calculate value based on scroll position
    final offset = _scrollController.offset;
    final index = (offset / 60.0).round();
    final newValue = (widget.minValue + (index * widget.step))
        .clamp(widget.minValue, widget.maxValue);

    if ((newValue - _currentValue).abs() >= widget.step * 0.9) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onChanged(_currentValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount =
        ((widget.maxValue - widget.minValue) / widget.step).ceil() + 1;

    // Calculate display value
    double displayValue = _currentValue;
    String displayUnit = widget.unit;
    if (widget.displayDivisor != null && widget.displayUnit != null) {
      displayValue = _currentValue / widget.displayDivisor!;
      displayUnit = widget.displayUnit!;
    }

    return Column(
      children: [
        // Display selected value
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Text(
                widget.showDecimals
                    ? '${displayValue.toStringAsFixed(1)} $displayUnit'
                    : '${displayValue.toStringAsFixed(0)} $displayUnit',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),

        // Ruler slider
        Center(
          child: Column(
            children: [
              // Center indicator
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: 3,
                      height: 20,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF628141),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable ruler
              SizedBox(
                height: 80,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    _onScroll();
                    return true;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      final value = widget.minValue + (index * widget.step);
                      final isMajor = (index % 5) == 0;

                      return SizedBox(
                        width: 60,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              width: isMajor ? 2 : 1,
                              height: isMajor ? 30 : 20,
                              color: isMajor
                                  ? const Color(0xFF628141)
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 4),
                            if (isMajor)
                              Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
