import 'package:flutter/material.dart';

class RatingBar extends StatelessWidget {
  final Future<void> Function(double)? onRatingChanged;
  final double currentRating;
  final bool enabled;
  final double size;

  const RatingBar({
    Key? key,
    required this.currentRating,
    required this.onRatingChanged,
    this.enabled = true,
    this.size = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < currentRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
          onPressed:
              enabled && onRatingChanged != null
                  ? () => onRatingChanged!(index + 1)
                  : null,
        );
      }),
    );
  }
}
