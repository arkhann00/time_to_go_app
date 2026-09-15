part of '../main.dart';

Color stageColor(BelieverStage s) => switch (s) {
  BelieverStage.interested => const Color(0xFF4D90FE),
  BelieverStage.receivedJesus => const Color(0xFF9B6DFF),
  BelieverStage.joinedCommunity => const Color(0xFF00A896),
  BelieverStage.baptised => const Color(0xFFF4A261),
  BelieverStage.evangelist => const Color(0xFF43AA5C),
};

String stageFull(BelieverStage s, AppLanguage l) => switch (s) {
  BelieverStage.interested =>
    l == AppLanguage.ru ? 'Интересуется верой' : 'Interested in faith',
  BelieverStage.receivedJesus =>
    l == AppLanguage.ru ? 'Принял Иисуса' : 'Received Jesus',
  BelieverStage.joinedCommunity =>
    l == AppLanguage.ru ? 'Пришёл в церковь / группу' : 'Joined community',
  BelieverStage.baptised => l == AppLanguage.ru ? 'Крестился' : 'Got baptised',
  BelieverStage.evangelist =>
    l == AppLanguage.ru ? 'Проповедует Евангелие' : 'Preaches the gospel',
};

String stageShort(BelieverStage s, AppLanguage l) => switch (s) {
  BelieverStage.interested => l == AppLanguage.ru ? 'Интерес' : 'Interested',
  BelieverStage.receivedJesus => l == AppLanguage.ru ? 'Принял' : 'Received',
  BelieverStage.joinedCommunity => l == AppLanguage.ru ? 'Группа' : 'Community',
  BelieverStage.baptised => l == AppLanguage.ru ? 'Крещение' : 'Baptised',
  BelieverStage.evangelist => l == AppLanguage.ru ? 'Служит' : 'Serving',
};

EvangelismMethod methodFromBackendName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return EvangelismMethod.custom;
  if ((normalized.contains('4') && normalized.contains('знак')) ||
      normalized.contains('four signs')) {
    return EvangelismMethod.fourSigns;
  }
  if (normalized.contains('двер') || normalized.contains('door')) {
    return EvangelismMethod.jesusAtDoor;
  }
  return EvangelismMethod.custom;
}

String evangelismMethodLabel(EvangelismMethod method, S tr) => switch (method) {
  EvangelismMethod.fourSigns => tr.methodFourSignsTab,
  EvangelismMethod.jesusAtDoor => tr.methodJesusDoorTab,
  EvangelismMethod.custom => tr.methodCustom,
};

const _latestTestimonyPreviewLimit = 120;

bool _needsTestimonyPreview(String text) =>
    text.length > _latestTestimonyPreviewLimit;

String _testimonyPreview(String text) {
  if (!_needsTestimonyPreview(text)) return text;
  return '${text.substring(0, _latestTestimonyPreviewLimit).trimRight()}…';
}

String _telegramUrl(String value) {
  final handle = _extractTelegramHandle(value);
  if (handle == null) return '';
  return 'https://t.me/$handle';
}

Future<void> openTelegram(String value) async {
  final uri = Uri.tryParse(_telegramUrl(value));
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> callPhone(String value) async {
  final cleaned = _normalizePhoneForStorage(value);
  if (cleaned.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: cleaned);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String? _extractTelegramHandle(String value) {
  var raw = value.trim();
  if (raw.isEmpty) return null;

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (host == 't.me' || host == 'telegram.me') {
      raw = uri!.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    }
  } else if (raw.startsWith('t.me/') || raw.startsWith('telegram.me/')) {
    final parts = raw.split('/');
    raw = parts.isNotEmpty ? parts.last : '';
  }

  raw = raw.startsWith('@') ? raw.substring(1) : raw;
  raw = raw.split('?').first.split('#').first.trim();
  if (raw.isEmpty) return null;
  return raw;
}

bool _isValidTelegram(String value) {
  final handle = _extractTelegramHandle(value);
  if (handle == null) return false;
  return RegExp(r'^[a-zA-Z0-9_]{5,32}$').hasMatch(handle);
}

String _normalizeTelegramForStorage(String value) {
  final handle = _extractTelegramHandle(value);
  if (handle == null) return '';
  return '@$handle';
}

bool _isValidPhone(String value) {
  final digits = _phoneDigits(value);
  return digits.length >= 10 && digits.length <= 15;
}

String _phoneDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _formatPhoneForInput(String value) {
  var digits = _phoneDigits(value);
  if (digits.isEmpty) return '';
  if (digits.length > 15) digits = digits.substring(0, 15);

  final ruCandidate =
      digits.length <= 11 && (digits.startsWith('7') || digits.startsWith('8'));
  if (ruCandidate) {
    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    final rest = digits.substring(1);
    final b = StringBuffer('+7');
    if (rest.isNotEmpty) {
      b.write(' (${rest.substring(0, rest.length.clamp(0, 3))}');
    }
    if (rest.length >= 4) {
      b.write(') ${rest.substring(3, rest.length.clamp(3, 6))}');
    }
    if (rest.length >= 7) {
      b.write('-${rest.substring(6, rest.length.clamp(6, 8))}');
    }
    if (rest.length >= 9) {
      b.write('-${rest.substring(8, rest.length.clamp(8, 10))}');
    }
    return b.toString();
  }

  final b = StringBuffer('+');
  for (var i = 0; i < digits.length; i++) {
    b.write(digits[i]);
    if (i == 2 || i == 5 || i == 8 || i == 11) {
      if (i != digits.length - 1) b.write(' ');
    }
  }
  return b.toString().trim();
}

String _normalizePhoneForStorage(String value) {
  var digits = _phoneDigits(value);
  if (digits.isEmpty) return '';
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  if (digits.length > 15) digits = digits.substring(0, 15);
  return '+$digits';
}

String formatPhoneForDisplay(String value) => _formatPhoneForInput(value);

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatPhoneForInput(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String fmtDate(DateTime d, AppLanguage l) {
  try {
    return DateFormat(
      l == AppLanguage.ru ? 'dd.MM.yyyy' : 'MMM d, yyyy',
      l == AppLanguage.ru ? 'ru_RU' : 'en_US',
    ).format(d);
  } catch (_) {
    return DateFormat('dd.MM.yyyy').format(d);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STRINGS
// ─────────────────────────────────────────────────────────────────────────────

class S {
  final AppLanguage lang;
  S(this.lang);
  bool get _ru => lang == AppLanguage.ru;

  String get appTitle => _ru ? "Время идти" : "Time To Go";
  String get statisticsHeader => _ru ? 'Статистика' : 'Statistics';
  String get personalStatsHeader =>
      _ru ? 'Личная статистика' : 'Personal stats';
  String get appearance => _ru ? 'Оформление' : 'Appearance';
  String get accountSection => _ru ? 'Аккаунт' : 'Account';
  String get dashSub => _ru
      ? 'Учёт новых верующих и этапов духовного роста'
      : 'Track new believers and their growth';
  String get homeWitnessSub => _ru
      ? 'Последнее свидетельство и ключевые цифры'
      : 'Latest testimony and key numbers';
  String get latestTestimony =>
      _ru ? 'Последнее свидетельство' : 'Latest testimony';
  String get latestTestimoniesTitle =>
      _ru ? 'Последние свидетельства' : 'Latest testimonies';
  String get noLatestTestimonies =>
      _ru ? 'Пока нет свидетельств.' : 'No testimonies yet.';
  String get showFull => _ru ? 'Показать полностью' : 'Show full';
  String get back => _ru ? 'Назад' : 'Back';
  String get salvationCountLabel =>
      _ru ? 'Всего принял Иисуса' : 'Total Salvation';
  String get acceptedJesusCountLabel =>
      _ru ? 'Человек приняло Иисуса' : 'People accepted Jesus';
  String get heroTitle => _ru
      ? 'Время идти\nи благовествовать'
      : 'Time to go\nand preach the gospel';
  String get heroSub => _ru
      ? 'Ведите учёт людей, отслеживайте этапы роста и готовьтесь к труду.'
      : 'Track people, follow growth stages, prepare for ministry.';
  String get total => _ru ? 'Всего' : 'Total';
  String get inProgress => _ru ? 'В пути' : 'In progress';
  String get serving => _ru ? 'Служат' : 'Serving';
  String get sections => _ru ? 'Разделы' : 'Sections';
  String get recent => _ru ? 'Недавние' : 'Recent';
  String get believers => _ru ? 'Новые верующие' : 'New believers';
  String get savedPeople => _ru ? 'Спасенные' : 'Saved';
  String get believersSub => _ru
      ? 'Добавляйте людей и переводите по этапам'
      : 'Add people and move through stages';
  String get list => _ru ? 'Список' : 'List';
  String get methods => _ru ? 'Методы' : 'Methods';
  String get methodsSub => _ru
      ? 'Четыре знака и «Иисус у двери»'
      : 'Four signs and “Jesus at the door”';
  String get methodsPageTitle =>
      _ru ? 'Методы евангелизации' : 'Evangelism methods';
  String get methodsPageSub => _ru
      ? 'Переключайтесь между способами и используйте схемы в беседе.'
      : 'Switch between methods and use the visuals in conversation.';
  String get authSub => _ru
      ? 'Войдите, чтобы синхронизировать данные между устройствами.'
      : 'Sign in to sync your data across devices.';
  String get methodFourSignsTab => _ru ? '4 знака' : 'Four signs';
  String get methodFourSignsDesc => _ru
      ? '«Четыре символа» — это отличный способ донести Евангелие простым и понятным способом. Вы можете начать разговор, задав человеку вопрос: «Вы когда-нибудь слышали историю о четырёх символах?» Затем вы показываете ему эти четыре символа и объясняете Евангелие, опираясь на них.'
      : '"The Four" is a great way to share the Gospel in a simple and clear way. You can start a conversation by asking: "Have you ever heard the story of the four symbols?" Then you show them these four symbols and explain the Gospel based on them.';
  String get methodJesusDoorTab => _ru ? 'Иисус у двери' : 'Jesus at the door';
  String get methodJesusDoorDesc => _ru
      ? '«Иисус у двери» — это очень креативный метод благовестия, представляющий собой полностью прописанный диалог. Он работает только в том случае, если вы уделите время и усилия, чтобы выучить весь разговор слово в слово. Используйте изображение Иисуса, стучащего в дверь, и пройдите через весь этот диалог.'
      : '"Jesus at the Door" is a very creative evangelism method that consists of a fully scripted dialogue. It only works if you take the time and effort to learn the entire conversation word for word. Use the image of Jesus knocking at the door and go through this entire dialogue.';
  String get methodCustom => _ru ? 'Свой метод' : 'My method';
  String get imageMissing =>
      _ru ? 'Не удалось загрузить изображение' : 'Could not load image';
  String get map => _ru ? 'Карта' : 'Map';
  String get settings => _ru ? 'Настройки' : 'Settings';
  String get settingsSub => _ru ? 'Тема и язык' : 'Theme and language';
  String get account => _ru ? 'Аккаунт' : 'Account';
  String get home => _ru ? 'Главная' : 'Home';
  String get add => _ru ? 'Добавить' : 'Add';
  String get saved => _ru ? 'Сохранено локально' : 'Saved locally';
  String get testimonies => _ru ? 'Свидетельства' : 'Testimonies';
  String get achievements => _ru ? 'Достижения' : 'Achievements';
  String get trackSub => _ru ? 'Учёт и статусы' : 'Tracking & status';
  String get soon => _ru ? 'Скоро' : 'Coming soon';
  String get regionAlertTitle =>
      _ru ? 'Проверьте подключение' : 'Check your connection';
  String get close => _ru ? 'Закрыть' : 'Close';
  String get mapHint => _ru
      ? 'Карта точек служения появится в следующем обновлении.'
      : 'Ministry map is coming in a future update.';
  String get themeLabel => _ru ? 'Тема' : 'Theme';
  String get sys => _ru ? 'Авто' : 'Auto';
  String get light => _ru ? 'Светло' : 'Light';
  String get dark => _ru ? 'Темно' : 'Dark';
  String get langLabel => _ru ? 'Язык' : 'Language';
  String get signIn => _ru ? 'Войти' : 'Sign in';
  String get signUp => _ru ? 'Регистрация' : 'Sign up';
  String get signOut => _ru ? 'Выйти' : 'Sign out';
  String get signOutConfirmTitle =>
      _ru ? 'Выйти из аккаунта?' : 'Sign out of account?';
  String get signOutConfirmBody => _ru
      ? 'Вы уверены, что хотите выйти?'
      : 'Are you sure you want to sign out?';
  String get deleteAccountConfirm => _ru ? 'Удалить аккаунт' : 'Delete account';
  String get deleteAccountTitle => _ru ? 'Удалить аккаунт?' : 'Delete account?';
  String get deleteAccountBody => _ru
      ? 'Все ваши данные (верующие, статистика, методы) будут удалены безвозвратно. Это действие нельзя отменить.'
      : 'All your data (believers, statistics, methods) will be permanently deleted. This cannot be undone.';
  String get continueOffline =>
      _ru ? 'Продолжить без входа' : 'Continue without sign in';
  String get authEmail => _ru ? 'Email' : 'Email';
  String get authPassword => _ru ? 'Пароль' : 'Password';
  String get authInvalidEmail =>
      _ru ? 'Введите корректный email' : 'Enter a valid email';
  String get authPasswordRule => _ru
      ? 'Пароль должен быть не короче 6 символов'
      : 'Password must be at least 6 characters';
  String get authWrongCredentials =>
      _ru ? 'Неверный email или пароль' : 'Invalid email or password';
  String get authEmailExists => _ru
      ? 'Пользователь с таким email уже существует'
      : 'Email already exists';
  String get authInvalidInput =>
      _ru ? 'Проверьте корректность введенных данных' : 'Check input fields';
  String get authNetworkError =>
      _ru ? 'Не удалось подключиться к серверу' : 'Could not connect to server';
  String get authUnknownError =>
      _ru ? 'Не удалось выполнить авторизацию' : 'Authorization failed';

  String get addSub => _ru
      ? 'Данные хранятся локально на устройстве.'
      : 'Data is stored locally on your device.';
  String get name => _ru ? 'Имя' : 'Name';
  String get contact => _ru ? 'Контакт' : 'Contact';
  String get telegram => _ru ? 'Telegram' : 'Telegram';
  String get phone => _ru ? 'Телефон' : 'Phone number';
  String get telegramHint =>
      _ru ? '@username или t.me/username' : '@username or t.me/username';
  String get phoneHint => _ru ? '+7 (999) 123-45-67' : '+1 555 123 45 67';
  String get contactReqEither => _ru
      ? 'Укажите Telegram или номер телефона'
      : 'Enter Telegram or phone number';
  String get telegramInvalid => _ru
      ? 'Неверный Telegram. Пример: @username'
      : 'Invalid Telegram. Example: @username';
  String get phoneInvalid =>
      _ru ? 'Неверный номер телефона' : 'Invalid phone number';
  String get date => _ru ? 'Дата' : 'Date';
  String get stage => _ru ? 'Этап' : 'Stage';
  String get evangelismMethod =>
      _ru ? 'Метод евангелизации' : 'Evangelism method';
  String get customMethod => _ru ? 'Свой метод' : 'Custom method';
  String get customMethodHint => _ru
      ? 'Опишите ваш метод евангелизации'
      : 'Describe your evangelism method';
  String get customMethodReq =>
      _ru ? 'Введите описание своего метода' : 'Describe your custom method';
  String get testimony => _ru ? 'Свидетельство' : 'Testimony';
  String get testimonyHint => _ru
      ? 'Что произошло в этой встрече?'
      : 'What happened during this meeting?';
  String get note => _ru ? 'Заметка' : 'Note';
  String get noteHint =>
      _ru ? 'Краткая заметка о человеке' : 'Short note about this person';
  String get save => _ru ? 'Сохранить' : 'Save';
  String get nameReq => _ru ? 'Введите имя' : 'Enter a name';
  String get emptyTitle => _ru ? 'Пока никого нет' : 'No believers yet';
  String get emptySub => _ru
      ? 'Добавь первого человека, чтобы начать вести учёт.'
      : 'Add the first person to start tracking.';

  String get believersNav => _ru ? 'Верующие' : 'Believers';
  String get homeNav => _ru ? 'Главная' : 'Home';
  String get methodsNav => _ru ? 'Методы' : 'Methods';
  String get mapNav => _ru ? 'Карта' : 'Map';
  String get settingsNav => _ru ? 'Настройки' : 'Settings';
  String get profileNav => _ru ? 'Профиль' : 'Profile';

  String get profile => _ru ? 'Профиль' : 'Profile';
  String get profileSub =>
      _ru ? 'Информация о вас и вашем служении' : 'About you and your ministry';
  String get profileNeedAuth =>
      _ru ? 'Войдите, чтобы открыть профиль' : 'Sign in to view your profile';
  String get profileNeedAuthSub => _ru
      ? 'После входа здесь появится ваш профиль и статистика.'
      : 'After sign in your profile and statistics will appear here.';
  String get editAccountProfile =>
      _ru ? 'Редактировать аккаунт' : 'Edit account profile';
  String get changeAvatar => _ru ? 'Изменить фото' : 'Change photo';
  String get editProfile => _ru ? 'Редактировать' : 'Edit profile';
  String get fillProfile => _ru ? 'Заполнить профиль' : 'Fill profile';
  String get yourName => _ru ? 'Ваше имя' : 'Your name';
  String get church => _ru ? 'Церковь / община' : 'Church / community';
  String get bio => _ru ? 'О служении' : 'About ministry';
  String get bioHint => _ru
      ? 'Где вы служите, к чему призваны?'
      : 'Where do you serve, what are you called to?';
  String get about => _ru ? 'О себе' : 'About';
  String get serverAccount => _ru ? 'Профиль аккаунта' : 'Account profile';
  String get serverAccountUnavailable => _ru
      ? 'Не удалось загрузить профиль. Проверьте соединение.'
      : 'Could not load profile. Check your connection.';
  String get accountInfo => _ru ? 'Данные аккаунта' : 'Account info';
  String get noProfile => _ru ? 'Профиль не заполнен' : 'Profile is empty';
  String get noProfileSub => _ru
      ? 'Добавьте информацию о себе и вашем служении.'
      : 'Add information about yourself and your ministry.';
  String get noName => _ru ? 'Без имени' : 'No name';

  String get location => _ru ? 'Место' : 'Location';
  String get locationOptional =>
      _ru ? 'Место (необязательно)' : 'Location (optional)';
  String get currentLocationAuto =>
      _ru ? 'Текущее местоположение' : 'Current location';
  String get locationServiceDisabled => _ru
      ? 'Включите геолокацию на устройстве'
      : 'Enable location services on your device';
  String get locationPermissionDenied => _ru
      ? 'Разрешите доступ к геолокации, чтобы автоматически отметить свидетельство'
      : 'Allow location access to auto-mark the testimony';
  String get locationAutoError => _ru
      ? 'Не удалось определить текущую геолокацию'
      : 'Could not determine current location';
  String get pickOnMap => _ru ? 'Отметить на карте' : 'Pick on map';
  String get changeLocation => _ru ? 'Изменить место' : 'Change location';
  String get clearLocation => _ru ? 'Убрать место' : 'Clear location';
  String get placeName =>
      _ru ? 'Название места (необязательно)' : 'Place name (optional)';
  String get tapToPlace => _ru
      ? 'Нажмите на карту, чтобы поставить метку'
      : 'Tap the map to place a marker';
  String get done => _ru ? 'Готово' : 'Done';
  String get cancel => _ru ? 'Отмена' : 'Cancel';
  String get mapTitle => _ru ? 'Карта свидетельств' : 'Testimony map';
  String get mapSub =>
      _ru ? 'Где Бог встретил этих людей' : 'Places where God met these people';
  String get noPlaces =>
      _ru ? 'Пока нет отмеченных мест' : 'No places marked yet';
  String get noPlacesSub => _ru
      ? 'Отметьте человека на карте при добавлении или редактировании.'
      : 'Mark a person on the map when adding or editing.';
  String get withLocation => _ru ? 'С местом' : 'With location';
  String get viewProfile => _ru ? 'Открыть карточку' : 'Open card';
  String get attribution => '© OpenStreetMap contributors';

  // Outreach statistics
  String get outreachStatsHeader =>
      _ru ? 'Статистика аутрича' : 'Outreach stats';
  String get gospelsTold => _ru ? 'Поделились Евангелием' : 'Gospels told';
  String get salvationPrayedUnreachable =>
      _ru ? 'Помолились молитвой покаяния' : 'Prayed, unreachable';
  String get scripturesDistributed =>
      _ru ? 'Роздано Евангелий от Иоана' : 'Gospels of John distributed';
  String get fathersLettersDistributed =>
      _ru ? 'Роздано Писем Отца' : "Father's Letters distributed";
  String get healingsDeliverances =>
      _ru ? 'Исцелений / освобождений' : 'Healings & deliverances';
  String get addOutreachStats => _ru ? 'Добавить аутрич' : 'Add outreach';
  String get editOutreachStats => _ru ? 'Редактировать' : 'Edit';
  String get testimonyLabel => _ru ? 'Свидетельство' : 'Testimony';
  String get testimonyPlaceholder =>
      _ru ? 'Напишите ваше свидетельство...' : 'Write your testimony...';
  String get deleteTestimony =>
      _ru ? 'Удалить свидетельство' : 'Delete testimony';
  String get outreachStatsEmpty =>
      _ru ? 'Нет статистики аутрича' : 'No outreach stats yet';
  String get outreachStatsSaved => _ru ? 'Статистика сохранена' : 'Stats saved';
  String get outreachStatsError =>
      _ru ? 'Не удалось сохранить' : 'Could not save stats';
  String get noStatsYet => _ru ? 'Нет данных аутрича' : 'No outreach data yet';
  String get resetStats => _ru ? 'Сбросить' : 'Reset';
  String get resetStatsTitle => _ru ? 'Сбросить статистику?' : 'Reset stats?';
  String get resetStatsBody => _ru
      ? 'Все счётчики будут обнулены. Это действие нельзя отменить.'
      : 'All counters will be set to zero. This cannot be undone.';
  // Summary stats labels
  String get generalStats => _ru ? 'Общая' : 'General';
  String get personalStats => _ru ? 'Личная' : 'Personal';
  String get totalSalvation => _ru ? 'Услышали Евангелие' : 'Heard the Gospel';
  String get totalSaved => _ru ? 'Спасено' : 'Saved';
  String get contactsTaken => _ru ? 'Есть контакт' : 'Has contact';
  String get personalStatsUnavailable => _ru
      ? 'Войдите в аккаунт, чтобы видеть личную статистику'
      : 'Sign in to view personal statistics';
}
