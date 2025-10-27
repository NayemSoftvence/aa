// ignore_for_file: unused_element

import 'package:flutter/cupertino.dart';

final class Routes {
  static final Routes _routes = Routes._internal();
  Routes._internal();
  static Routes get instance => _routes;

  static const String logInScreen = '/logIn';
  static const String signUpScreen = '/signUp';
  static const String home = '/home';
  static const String search = '/search';
  static const String dailyRemainder = '/DailyRemainderScreen';
  static const String editRemainder = '/EditRemainderScreen';
  static const String pricingPlanScreen = '/PricingPlanScreen';
  static const String makeMixScreen = '/MakeMixScreen';
  static const String pricingListScreen = '/PricingListScreen';
  static const String homeScreenWidget = '/HomeScreenWidget';
  static const String setPassword = '/SetPassword';
  static const String addQuoteScreen = '/AddQuoteScreen';
  static const String previewScreen = '/PreviewScreen';
  static const String quoteScreen = '/QuoteScreen';
  static const String collectionScreen = '/CollectionScreen';
  static const String favouriteScreen = '/FavouriteScreen';
  static const String insertEmailScreen = '/InsertEmailScreen';
  static const String setNewPasswordScreen = '/SetNewPasswordScreen';
  static const String verifyOtpFPScreen = '/VerifyOtpFPScreen';
  // static const String addCard = '/Addcard';
  static const String profile = '/Profile';
  static const String loadingScreen = '/loading';
  static const String otpScreen = '/OtpScreen';
  static const String webview = '/webview';
  static const String categorySearchScreen = '/CategorySearchScreen';
  static const String forgotPWScreen = '/ForgotPWScreen';

  static const String navigationScreen = '/NavigationScreen';
  // static const String privacyTermScreen = '/privacy_terms_Screen';
  // static const String myContributionScreen = '/MyContributionScreen';
  // static const String myCollectionScreen = '/myCollectionScreen';
  // static const String createCollection = '/createCollectionScreen';
  // static const String editCollection = '/editCollectionScreen';
  // static const String editProfile = '/editProfileScreen';
  // static const String collectionDetails = '/CollectionDetailsScreen';
  // static const String makeAContributionsScreen = '/MakeAContributionsScreen';
  static const String policiesTerms = '/PoliciesTermsScreen';
  static const String generalSetting = '/general_setting';
  static const String homeScreen = '/home_screen';
  static const String theme = '/theme';
  static const String setting = '/setting';
  static const String contentCategories = '/content_categories';
  static const String reminderScreen = '/reminders_screen';
}

final class RouteGenerator {
  static final RouteGenerator _routeGenerator = RouteGenerator._internal();
  RouteGenerator._internal();
  static RouteGenerator get instance => _routeGenerator;

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // case Routes.signUpScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(widget: SignUpScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => SignUpScreen());
      // // case Routes.categorySearchScreen:
      // //   return Platform.isAndroid
      // //       ? _FadedTransitionRoute(
      // //           widget: const CategoryScreen(), settings: settings)
      // //       : CupertinoPageRoute(builder: (context) => const CategoryScreen());
      // case Routes.pricingPlanScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const PricingPlanScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const PricingPlanScreen());
      // case Routes.dailyRemainder:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const SetRemainderScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const SetRemainderScreen());
      // case Routes.pricingListScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const PricingListScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const PricingListScreen());
      // case Routes.makeMixScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const MakeMixScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const MakeMixScreen());
      // case Routes.homeScreenWidget:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const HomeScreenWidget(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const HomeScreenWidget());
      // case Routes.navigationScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const NavigationScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const NavigationScreen());
      // case Routes.homeScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const HomeScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const HomeScreen());
      // case Routes.theme:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const ThemeScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const ThemeScreen());
      // case Routes.setting:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const SettingsScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const SettingsScreen());
      // case Routes.generalSetting:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const GeneralSettingScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const GeneralSettingScreen());
      // case Routes.contentCategories:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const ContentCategoriesScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const ContentCategoriesScreen());
      // case Routes.reminderScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const RemindersScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const RemindersScreen());
      // case Routes.setPassword:
      //   final args = settings.arguments as Map;
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: SetPasswordScreen(
      //             name: args['name'],
      //             email: args['email'],
      //           ),
      //           settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => SetPasswordScreen(
      //                 name: args['name'],
      //                 email: args['email'],
      //               ));
      // case Routes.otpScreen:
      //   final args = settings.arguments as Map;
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: OtpScreen(
      //             isFromLogin: args['isFromLogin'],
      //           ),
      //           settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => OtpScreen(
      //                 isFromLogin: args['isFromLogin'],
      //               ));
      // case Routes.addQuoteScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const AddQuoteScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const AddQuoteScreen());
      // case Routes.quoteScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const QuoteScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const QuoteScreen());
      // case Routes.collectionScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const CollectionScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const CollectionScreen());
      // case Routes.favouriteScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const FavouriteScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const FavouriteScreen());
      // case Routes.previewScreen:
      //   final args = settings.arguments as Map;
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: PreviewScreen(quote: args['quote'], name: args['name']),
      //           settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) =>
      //               PreviewScreen(quote: args['quote'], name: args['name']));
      // case Routes.setNewPasswordScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: SetNewPasswordScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => SetNewPasswordScreen());
      // // case Routes.previewScreen:
      // //   return Platform.isAndroid
      // //       ? _FadedTransitionRoute(widget: PreviewScreen(), settings: settings)
      // //       : CupertinoPageRoute(builder: (context) => PreviewScreen());
      // case Routes.insertEmailScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: InsertEmailScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => InsertEmailScreen());
      // case Routes.logInScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const LoginScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const LoginScreen());

      // case Routes.verifyOtpFPScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const VerifyOtpFPScreen(), settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => const VerifyOtpFPScreen());
      // case Routes.loadingScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(widget: const Loading(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const Loading());

      // case Routes.editRemainder:
      //   final args = settings.arguments as Map;
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: EditRemainderScreen(
      //             id: args['id'],
      //             itemCount: args['itemCount'],
      //             startTime: args['startTime'],
      //             endTime: args['endTime'],
      //             isRemaiderOn: args['isRemaiderOn'],
      //           ),
      //           settings: settings)
      //       : CupertinoPageRoute(
      //           builder: (context) => EditRemainderScreen(
      //                 id: args['id'],
      //                 itemCount: args['itemCount'],
      //                 startTime: args['startTime'],
      //                 endTime: args['endTime'],
      //                 isRemaiderOn: args['isRemaiderOn'],
      //               ));
      // case Routes.signUpScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const SignUpScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const SignUpScreen());
      // case Routes.forgotPWScreen:
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget: const ForgotPWScreen(), settings: settings)
      //       : CupertinoPageRoute(builder: (context) => const ForgotPWScreen());

      // case Routes.sliderWebViewPage:
      //   final args = settings.arguments as Map;
      //   return Platform.isAndroid
      //       ? _FadedTransitionRoute(
      //           widget:
      //               SliderWebViewPage(title: args["title"], url: args["url"]),
      //           settings:
      //               settings) //_FadedTransitionRoute(builder: (context)=> const SobrenosScreen())
      //       : CupertinoPageRoute(
      //           builder: (context) =>
      //               SliderWebViewPage(title: args["title"], url: args["url"]));

      default:
        return null;
    }
  }
}

//  weenAnimationBuilder(
//   child: Widget,
//   tween: Tween<double>(begin: 0, end: 1),
//   duration: Duration(milliseconds: 1000),
//   curve: Curves.bounceIn,
//   builder: (BuildContext context, double _val, Widget child) {
//     return Opacity(
//       opacity: _val,
//       child: Padding(
//         padding: EdgeInsets.only(top: _val * 50),
//         child: child
//       ),
//     );
//   },
// );

class _FadedTransitionRoute extends PageRouteBuilder {
  final Widget widget;
  @override
  final RouteSettings settings;

  _FadedTransitionRoute({required this.widget, required this.settings})
      : super(
          settings: settings,
          reverseTransitionDuration: const Duration(milliseconds: 1),
          pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) {
            return widget;
          },
          transitionDuration: const Duration(milliseconds: 1),
          transitionsBuilder: (BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.ease,
              ),
              child: child,
            );
          },
        );
}

class ScreenTitle extends StatelessWidget {
  final Widget widget;

  const ScreenTitle({super.key, required this.widget});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: .5, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.bounceIn,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: widget,
    );
  }
}
