// import 'dart:developer';
// import 'package:dio/dio.dart';
// import 'package:rxdart/rxdart.dart';
// import '../../../../../networks/rx_base.dart';
// import '../../../../common_widgets/custom_toast.dart';
// import 'api.dart';

// final class GetExampleRx extends RxResponseInt {
//   final api = GetExampleApi.instance;

//   GetExampleRx({required super.empty, required super.dataFetcher});

//   ValueStream get fileData => dataFetcher.stream;

//   Future<bool> featchExample() async {
//     try {
//       Map data = await api.getExampleData();
//        return await handleSuccessWithReturn(data);
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
//     }
//     customToastMessage('Error', message);
//     return false;

//   }
// }
