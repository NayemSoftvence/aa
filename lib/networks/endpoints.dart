// ignore_for_file: constant_identifier_names

const String url = 'https://livekitcall.netlify.app';

final class NetworkConstants {
  NetworkConstants._();
  static const ACCEPT = "Accept";
  static const APP_KEY = "App-Key";
  static const ACCEPT_LANGUAGE = "Accept-Language";
  static const ACCEPT_LANGUAGE_VALUE = "pt";
  static const APP_KEY_VALUE = String.fromEnvironment("APP_KEY_VALUE");
  static const ACCEPT_TYPE = "application/json";
  static const AUTHORIZATION = "Authorization";
  static const CONTENT_TYPE = "content-Type";
}

final class Endpoints {
  Endpoints._();
  //backend_url
  // static String signUp() => "/api/register";
  // static String logIn() => "/api/login";
  // static String getShopByCategories(String slug) =>
  //     "/api/shop-categories/$slug/";

  static String example() => "/api/";
  static String livekitToken() => '/.netlify/functions/token';
  static String livekitNotify() => '/.netlify/functions/notify';
  static String livekitEndCall() => '/.netlify/functions/endCall';
  static String livekitCallAccepted() => '/.netlify/functions/callAccepted';
  static String livekitCallDeclined() => '/.netlify/functions/callDeclined';

  // For local testing, you can temporarily switch:
  // static String netlifyBaseLocalAndroid = 'http://10.0.2.2:8888';
  // static String netlifyBaseLocalIOS = 'http://127.0.0.1:8888';
}
