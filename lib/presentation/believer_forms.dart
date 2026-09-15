part of '../main.dart';

class AddSheet extends StatefulWidget {
  final AppLanguage language;
  const AddSheet({super.key, required this.language});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _telegram = TextEditingController();
  final _phone = TextEditingController();
  final _testimony = TextEditingController();
  final _note = TextEditingController();
  final _customMethod = TextEditingController();
  DateTime _date = DateTime.now();
  BelieverStage _stage = BelieverStage.interested;
  EvangelismMethod _method = EvangelismMethod.fourSigns;
  LatLng? _location;
  String? _placeName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestCurrentLocation();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _telegram.dispose();
    _phone.dispose();
    _testimony.dispose();
    _note.dispose();
    _customMethod.dispose();
    super.dispose();
  }

  Future<void> _requestCurrentLocation() async {
    final tr = S(widget.language);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.locationServiceDisabled)));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.locationPermissionDenied)));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _location = LatLng(position.latitude, position.longitude);
        _placeName ??= tr.currentLocationAuto;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.locationAutoError)));
    }
  }

  String? _validateTelegram(S tr) {
    final telegram = _telegram.text.trim();
    if (telegram.isEmpty) return null;
    if (!_isValidTelegram(telegram)) return tr.telegramInvalid;
    return null;
  }

  String? _validatePhone(S tr) {
    final phone = _phone.text.trim();
    if (phone.isEmpty) return null;
    if (!_isValidPhone(phone)) return tr.phoneInvalid;
    return null;
  }

  Future<void> _pickDate() async {
    if (_isApple) {
      DateTime tempDate = _date;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: Text(S(widget.language).cancel),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: Text(S(widget.language).done),
                      onPressed: () {
                        setState(() => _date = tempDate);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _date,
                  minimumDate: DateTime(2020),
                  maximumDate: DateTime(2040),
                  onDateTimeChanged: (d) => tempDate = d,
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickLocation() async {
    final result = await showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        language: widget.language,
        initial: _location,
        initialPlace: _placeName,
      ),
    );
    if (result != null) {
      setState(() {
        _location = result.latLng;
        _placeName = result.place;
      });
    }
  }

  void _clearLocation() {
    setState(() {
      _location = null;
      _placeName = null;
    });
  }

  void _submitForm(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      NewBeliever(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        telegram: _normalizeTelegramForStorage(_telegram.text),
        phone: _normalizePhoneForStorage(_phone.text),
        testimony: _testimony.text.trim(),
        note: _note.text.trim(),
        evangelismMethod: _method,
        customEvangelismMethod: _customMethod.text.trim(),
        createdAt: _date,
        stage: _stage,
        latitude: _location?.latitude,
        longitude: _location?.longitude,
        place: _placeName,
      ),
    );
  }

  Future<void> _pickStage() async {
    final tr = S(widget.language);
    final selected = await showCupertinoModalPopup<BelieverStage>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr.stage),
        actions: BelieverStage.values
            .map(
              (s) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dot(stage: s, size: 10),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        stageFull(s, widget.language),
                        style: TextStyle(
                          fontWeight: s == _stage
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr.cancel),
        ),
      ),
    );
    if (selected != null) setState(() => _stage = selected);
  }

  Future<void> _pickMethod() async {
    final tr = S(widget.language);
    final selected = await showCupertinoModalPopup<EvangelismMethod>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr.evangelismMethod),
        actions: EvangelismMethod.values
            .map(
              (m) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(m),
                child: Text(
                  evangelismMethodLabel(m, tr),
                  style: TextStyle(
                    fontWeight: m == _method
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr.cancel),
        ),
      ),
    );
    if (selected != null) setState(() => _method = selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_isApple) return _buildApple(context);
    return _buildMaterial(context);
  }

  Widget _buildApple(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final hasLocation = _location != null;
    final locationValue = hasLocation
        ? (_placeName?.trim().isNotEmpty == true
              ? _placeName!.trim()
              : '${_location!.latitude.toStringAsFixed(4)}, '
                    '${_location!.longitude.toStringAsFixed(4)}')
        : null;

    return Container(
      height: mq.size.height * 0.94,
      decoration: BoxDecoration(
        color: _iosBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3.resolveFrom(context),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    tr.cancel,
                    style: TextStyle(
                      fontSize: 17,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    tr.add,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  onPressed: () => _submitForm(context),
                  child: Text(
                    tr.save,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  4,
                  0,
                  mq.viewInsets.bottom + 32,
                ),
                children: [
                  _AppleSection(
                    header: tr.name,
                    dividerIndent: 58,
                    children: [
                      _AppleInputRow(
                        icon: CupertinoIcons.person_alt,
                        iconBackground: const Color(0xFF34C759),
                        placeholder: tr.name,
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? tr.nameReq : null,
                      ),
                      _AppleInputRow(
                        icon: CupertinoIcons.at,
                        iconBackground: const Color(0xFF0A84FF),
                        placeholder: tr.telegramHint,
                        controller: _telegram,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_@./:?=&-]'),
                          ),
                        ],
                        validator: (_) => _validateTelegram(tr),
                      ),
                      _AppleInputRow(
                        icon: CupertinoIcons.phone_fill,
                        iconBackground: const Color(0xFFFF9F0A),
                        placeholder: tr.phoneHint,
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+()\-\s]'),
                          ),
                          _PhoneInputFormatter(),
                        ],
                        validator: (_) => _validatePhone(tr),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.stage,
                    children: [
                      _AppleTapRow(
                        icon: CupertinoIcons.calendar,
                        iconBackground: const Color(0xFFFF3B30),
                        title: tr.date,
                        value: fmtDate(_date, widget.language),
                        onTap: _pickDate,
                      ),
                      _AppleTapRow(
                        icon: CupertinoIcons.flag_fill,
                        iconBackground: stageColor(_stage),
                        title: tr.stage,
                        value: stageFull(_stage, widget.language),
                        onTap: _pickStage,
                      ),
                      _AppleTapRow(
                        icon: CupertinoIcons.book_fill,
                        iconBackground: const Color(0xFFAF52DE),
                        title: tr.evangelismMethod,
                        value: evangelismMethodLabel(_method, tr),
                        onTap: _pickMethod,
                      ),
                      if (_method == EvangelismMethod.custom)
                        _AppleInputRow(
                          icon: CupertinoIcons.pencil,
                          iconBackground: const Color(0xFF8E8E93),
                          placeholder: tr.customMethodHint,
                          controller: _customMethod,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (value) {
                            if (_method != EvangelismMethod.custom) return null;
                            if (value == null || value.trim().isEmpty) {
                              return tr.customMethodReq;
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.testimony,
                    footer: tr.testimonyHint,
                    children: [
                      _AppleInputRow(
                        placeholder: tr.testimony,
                        controller: _testimony,
                        minLines: 3,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.note,
                    children: [
                      _AppleInputRow(
                        placeholder: tr.noteHint,
                        controller: _note,
                        minLines: 3,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.location,
                    children: [
                      _AppleTapRow(
                        icon: CupertinoIcons.location_fill,
                        iconBackground: const Color(0xFFFF3B30),
                        title: tr.location,
                        value: locationValue,
                        placeholder: tr.tapToPlace,
                        onTap: _pickLocation,
                        trailingExtra: hasLocation
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _clearLocation,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 4,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    size: 18,
                                    color: CupertinoColors.systemGrey3
                                        .resolveFrom(context),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                mq.viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.addSub,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: tr.name,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? tr.nameReq : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telegram,
                      decoration: InputDecoration(
                        labelText: tr.telegram,
                        hintText: tr.telegramHint,
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                      ),
                      keyboardType: TextInputType.url,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_@./:?=&-]'),
                        ),
                      ],
                      validator: (_) => _validateTelegram(tr),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: tr.phone,
                        hintText: tr.phoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+()\-\s]'),
                        ),
                        _PhoneInputFormatter(),
                      ],
                      validator: (_) => _validatePhone(tr),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: tr.date,
                          prefixIcon: const Icon(Icons.calendar_today_rounded),
                          suffixIcon: const Icon(Icons.expand_more_rounded),
                        ),
                        child: Text(fmtDate(_date, widget.language)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BelieverStage>(
                      value: _stage,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr.stage,
                        prefixIcon: const Icon(Icons.flag_outlined),
                      ),
                      items: BelieverStage.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  _Dot(stage: s, size: 10),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(stageFull(s, widget.language)),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _stage = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<EvangelismMethod>(
                      value: _method,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr.evangelismMethod,
                        prefixIcon: const Icon(Icons.menu_book_rounded),
                      ),
                      items: EvangelismMethod.values
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(evangelismMethodLabel(method, tr)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _method = value);
                      },
                    ),
                    if (_method == EvangelismMethod.custom) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customMethod,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: tr.customMethod,
                          hintText: tr.customMethodHint,
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 28),
                            child: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        validator: (value) {
                          if (_method != EvangelismMethod.custom) return null;
                          if (value == null || value.trim().isEmpty) {
                            return tr.customMethodReq;
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _testimony,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: tr.testimony,
                        hintText: tr.testimonyHint,
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.auto_stories_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: tr.note,
                        hintText: tr.noteHint,
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.auto_stories_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LocationField(
                      tr: tr,
                      location: _location,
                      placeName: _placeName,
                      onPick: _pickLocation,
                      onClear: _clearLocation,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _submitForm(context),
                        icon: const Icon(Icons.save_rounded),
                        label: Text(tr.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION PICKER
// ─────────────────────────────────────────────────────────────────────────────

class LocationPickerSheet extends StatefulWidget {
  final AppLanguage language;
  final LatLng? initial;
  final String? initialPlace;
  const LocationPickerSheet({
    super.key,
    required this.language,
    this.initial,
    this.initialPlace,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class PickedLocation {
  final LatLng latLng;
  final String? place;
  const PickedLocation({required this.latLng, this.place});
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  static const _fallbackCenter = LatLng(55.7558, 37.6173);
  late final MapController _mapController;
  late final TextEditingController _placeCtrl;
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selected = widget.initial;
    _placeCtrl = TextEditingController(text: widget.initialPlace ?? '');
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() => _selected = point);
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final initialCenter = widget.initial ?? _fallbackCenter;

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.pickOnMap,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr.tapToPlace,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _isApple
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 28,
                          color: CupertinoColors.systemGrey3,
                        ),
                      )
                    : IconButton(
                        tooltip: tr.cancel,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: widget.initial != null ? 13 : 4,
                      minZoom: 2,
                      maxZoom: 18,
                      onTap: _onMapTap,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.time_to_go_app',
                        maxNativeZoom: 19,
                      ),
                      if (_selected != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selected!,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: _PinIcon(color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: Colors.white.withOpacity(0.7),
                      child: Text(
                        tr.attribution,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  if (_isApple)
                    CupertinoTextField(
                      controller: _placeCtrl,
                      placeholder: tr.placeName,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(
                          CupertinoIcons.location,
                          size: 20,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground.resolveFrom(
                          context,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.separator.resolveFrom(context),
                        ),
                      ),
                    )
                  else
                    TextField(
                      controller: _placeCtrl,
                      decoration: InputDecoration(
                        labelText: tr.placeName,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _isApple
                            ? CupertinoButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(tr.cancel),
                              )
                            : OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(tr.cancel),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isApple
                            ? CupertinoButton.filled(
                                borderRadius: BorderRadius.circular(12),
                                onPressed: _selected == null
                                    ? null
                                    : () {
                                        final placeText = _placeCtrl.text
                                            .trim();
                                        Navigator.of(context).pop(
                                          PickedLocation(
                                            latLng: _selected!,
                                            place: placeText.isEmpty
                                                ? null
                                                : placeText,
                                          ),
                                        );
                                      },
                                child: Text(tr.done),
                              )
                            : FilledButton.icon(
                                onPressed: _selected == null
                                    ? null
                                    : () {
                                        final placeText = _placeCtrl.text
                                            .trim();
                                        Navigator.of(context).pop(
                                          PickedLocation(
                                            latLng: _selected!,
                                            place: placeText.isEmpty
                                                ? null
                                                : placeText,
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.check_rounded),
                                label: Text(tr.done),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  final Color color;
  final double size;
  const _PinIcon({required this.color, this.size = 36});
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.location_on_rounded,
          color: color,
          size: size,
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        Positioned(
          top: size * 0.22,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP PAGE
// ─────────────────────────────────────────────────────────────────────────────
