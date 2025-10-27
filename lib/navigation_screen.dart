// import 'package:custom_navigation_bar/custom_navigation_bar.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:mollie/features/settings/presentation/settings_screen.dart';
// import 'package:mollie/features/theme/presentation/theme_screen.dart';

// import '/gen/assets.gen.dart';
// import 'features/home/presentaion/home_screen.dart';
// import 'gen/colors.gen.dart';
// import 'helpers/helper_methods.dart';

// class NavigationScreen extends StatefulWidget {
//   final Widget? pageNum;
//   const NavigationScreen({
//     super.key,
//     this.pageNum,
//   });

//   @override
//   State<NavigationScreen> createState() => _NavigationScreenState();
// }

// class _NavigationScreenState extends State<NavigationScreen> {
//   int _currentIndex = 0;

//   final bool _isFisrtBuild = true;
//   // bool _navigationOn = true;

//   final List<StatefulWidget> _screens = [
//     const HomeScreen(),
//     const ThemeScreen(),
//     const SettingsScreen(),
//   ];

//   @override
//   void initState() {
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     Object? args;
//     StatefulWidget? screenPage;
//     if (_isFisrtBuild) {
//       args = ModalRoute.of(context)!.settings.arguments;
//     }
//     if (args != null) {
//       screenPage = args as StatefulWidget;
//       var newColorindex = -1;

//       for (var element in _screens) {
//         newColorindex++;
//         if (element.toString() == screenPage.toString()) {
//           _currentIndex = newColorindex;
//           break;
//         }
//       }
//     }

//     return PopScope(
//       canPop: false,
//      onPopInvokedWithResult: (bool didPop, _)  async {
//         showMaterialDialog(context);
//       },
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         extendBody: true,
//         // onDrawerChanged: (isOpened) => setState(() {
//         //   _navigationOn = !isOpened;
//         // }),
//         body: Center(
//           child: (screenPage != null)
//               ? screenPage
//               : _screens.elementAt(_currentIndex),
//         ),
//         bottomNavigationBar: Padding(
//           padding: EdgeInsets.only(
//               bottom: 16.h,
//               right: 16.w,
//               left: 16.w), // Add padding from the bottom
//           child: Container(
//             height: 66.h,
//             decoration: BoxDecoration(
//               color: AppColors.c02BF65,
//               borderRadius: BorderRadius.all(Radius.circular(50.r)),
//             ),
//             child: Padding(
//               padding: EdgeInsets.all(0.sp),
//               child: CustomNavigationBar(
//                 borderRadius: Radius.circular(50.r),
//                 iconSize: 38.r,
//                 selectedColor: Colors.red,
//                 strokeColor: AppColors.c02BF65,
//                 unSelectedColor: Colors.black,
//                 backgroundColor:
//                     AppColors.c02BF65, // Make background transparent
//                 items: [
//                   CustomNavigationBarItem(
//                     icon: Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         _currentIndex == 0
//                             ? Image.asset(Assets.icons.iconBang.path)
//                             : const SizedBox.shrink(),
//                         Center(
//                           child: Image.asset(Assets.icons.generalIcon.path,
//                               color: AppColors.cFFFFFF),
//                         ),
//                       ],
//                     ),
//                     title: const Text(
//                       "General",
//                       style: TextStyle(color: AppColors.cFFFFFF),
//                     ),
//                   ),
//                   CustomNavigationBarItem(
//                     icon: Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         _currentIndex == 1
//                             ? Image.asset(Assets.icons.iconBang.path)
//                             : const SizedBox.shrink(),
//                         Center(
//                           child: Image.asset(Assets.icons.themeIcon.path,
//                               width: 18.w, color: AppColors.cFFFFFF),
//                         ),
//                       ],
//                     ),
//                     title: const Text(
//                       "Theme",
//                       style: TextStyle(color: AppColors.cFFFFFF),
//                     ),
//                   ),
//                   CustomNavigationBarItem(
//                     icon: Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         _currentIndex == 2
//                             ? Image.asset(Assets.icons.iconBang.path)
//                             : const SizedBox.shrink(),
//                         Center(
//                           child: Image.asset(Assets.icons.settingsIcon.path,
//                               width: 28.w, color: AppColors.cFFFFFF),
//                         ),
//                       ],
//                     ),
//                     title: const Text(
//                       "Settings",
//                       style: TextStyle(color: AppColors.cFFFFFF),
//                     ),
//                   ),
//                 ],
//                 currentIndex: _currentIndex,
//                 onTap: (index) {
//                   setState(() {
//                     _currentIndex = index;
//                   });
//                 },
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
