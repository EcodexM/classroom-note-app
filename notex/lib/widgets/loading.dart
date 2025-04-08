import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const LoadingButton({
    Key? key,
    required this.isLoading,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.deepPurple,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
      child:
          isLoading
              ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    foregroundColor ?? Colors.white,
                  ),
                ),
              )
              : child,
    );
  }
}
