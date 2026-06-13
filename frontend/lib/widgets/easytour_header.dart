import 'package:flutter/material.dart';

class EasyTourHeader extends StatelessWidget {
  final IconData? rightIcon;
  final VoidCallback? onRightIconTap;

  const EasyTourHeader({
    super.key,
    this.rightIcon,
    this.onRightIconTap,
  });

  static const Color orange = Color(0xFFF58A00);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Image.asset(
              'assets/images/easytour_logo2.jpg',
              height: 82,
              fit: BoxFit.contain,
            ),

            const Spacer(),

            if (rightIcon != null)
              InkWell(
                onTap: onRightIconTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    rightIcon,
                    color: orange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}