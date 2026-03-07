import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class SparklineChart extends StatelessWidget {
  final List<double> values; // 0.0 to 1.0
  final double height;

  const SparklineChart({
    super.key,
    required this.values,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final isHigh = v >= maxVal * 0.75;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                height: (height * v).clamp(3, height),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                  gradient: isHigh
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.green,
                            AppColors.green.withOpacity(0.2),
                          ],
                        )
                      : null,
                  color: isHigh ? null : AppColors.green.withOpacity(0.15),
                  boxShadow: isHigh
                      ? [
                          BoxShadow(
                            color: AppColors.greenGlow,
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
