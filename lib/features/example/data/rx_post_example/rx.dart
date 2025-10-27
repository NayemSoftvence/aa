// import 'dart:developer';
// import 'package:dio/dio.dart';
// import 'package:rxdart/rxdart.dart';

// import '../../../../common_widgets/custom_toast.dart';
// import '../../../../networks/rx_base.dart';
// import 'api.dart';

// final class PostLoginRx extends RxResponseInt {
//   final api = PostLoginApi.instance;
//   String message = "Something went wrong";
//   PostLoginRx({required super.empty, required super.dataFetcher});

//   ValueStream get getPostLoginRes => dataFetcher.stream;

//   Future<bool> postLogin() async {
//     try {
//       Map<String, dynamic> data = {
//         // "email": email,

//       };
//       Map resdata = await api.postLogIn(data);
//       return await handleSuccessWithReturn(resdata);
//     } catch (error) {
//       return await handleErrorWithReturn(error);
//     }
//   }

//   @override
//   handleSuccessWithReturn(data) async {

//     return true;
//   }

//   @override
//   handleErrorWithReturn(error) {
//     String message = 'Something went wrong';
//     log(error.toString());
//     if (error is DioException) {
//       message = error.response?.data["message"] ?? "Something went wrong";
//       if (error.type == DioExceptionType.connectionError) {
//         message = "Check Your Network Connection";
//       }
//       // log("Error: $message, Code: $code");
//     }
//     customToastMessage('Error', message);
//     return false;
//     //return super.handleErrorWithReturn(message);
//   }
// }
