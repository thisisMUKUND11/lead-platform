import 'package:backend/src/http/middleware.dart';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) => appMiddleware(handler);
