import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'common_widgets/loading_indicators.dart';
import 'gen/assets.gen.dart';
import 'gen/colors.gen.dart';

final class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: double.infinity,
        width: double.infinity,
        //decoration: const BoxDecoration(color: AppColors.allPrimaryColor),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 40.h,
              ),
              Image.asset(
                Assets.images.placeholderImage.path,
                height: 100.h,
                width: 100.w,
              ),
              SizedBox(
                height: 10.h,
              ),
              SizedBox(
                child: shimmer(
                    context: context,
                    name: Assets.lottie.loadingSpinner,
                    size: 150.sp,
                    color: AppColors.allPrimaryColor),
              )
            ]),
      ),
    );
  }
}
