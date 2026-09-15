import 'dart:convert';
import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'backend_api.dart';
import 'user_profile_cache.dart';

import 'core/models/app_enums.dart';
import 'data/local/user_profile_cache.dart';
import 'data/remote/backend_api.dart';
import 'data/notifications/push_notification_service.dart';
import 'domain/models/models.dart';

part 'presentation/apple_ui.dart';
part 'presentation/app_shell.dart';
part 'presentation/auth.dart';
part 'presentation/home.dart';
part 'presentation/dashboard.dart';
part 'presentation/believers.dart';
part 'presentation/methods.dart';
part 'presentation/settings.dart';
part 'presentation/profile.dart';
part 'presentation/believer_forms.dart';
part 'presentation/map.dart';
part 'presentation/shared_widgets.dart';
part 'presentation/helpers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await initializeDateFormatting('ru_RU', null);
  await initializeDateFormatting('en_US', null);
  await PushNotificationService().initialize();
  runApp(const TimeToGoApp());
}
