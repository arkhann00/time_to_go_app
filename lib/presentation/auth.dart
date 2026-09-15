part of '../main.dart';

class AuthScreen extends StatefulWidget {
  final AppLanguage language;
  final BackendApi backendApi;
  final void Function(String token, bool migrateLocal) onAuthSuccess;
  final VoidCallback onContinueOffline;
  const AuthScreen({
    super.key,
    required this.language,
    required this.backendApi,
    required this.onAuthSuccess,
    required this.onContinueOffline,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  int _tab = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _submit() async {
    final tr = S(widget.language);
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();

    if (_tab == 1 && name.isEmpty) {
      setState(() => _error = tr.nameReq);
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = tr.authInvalidEmail);
      return;
    }
    if (password.length < 6) {
      setState(() => _error = tr.authPasswordRule);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_tab == 1) {
        await widget.backendApi.register(
          name: name,
          email: email,
          password: password,
        );
      }
      final token = await widget.backendApi.login(
        email: email,
        password: password,
      );
      if (token.isEmpty) {
        setState(() => _error = tr.authUnknownError);
        return;
      }
      if (!mounted) return;
      widget.onAuthSuccess(token, _tab == 1);
    } on BackendApiException catch (e) {
      setState(() => _error = _humanAuthError(tr, e));
    } catch (_) {
      setState(() => _error = tr.authNetworkError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanAuthError(S tr, BackendApiException e) {
    if (e.statusCode == 409) return tr.authEmailExists;
    if (e.statusCode == 401) return tr.authWrongCredentials;
    if (e.statusCode == 422) return tr.authInvalidInput;
    if (e.message.isNotEmpty) return e.message;
    return tr.authUnknownError;
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);

    if (_isApple) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  Text(
                    tr.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr.authSub,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _tab,
                      children: {
                        0: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(tr.signIn),
                        ),
                        1: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(tr.signUp),
                        ),
                      },
                      onValueChanged: (v) {
                        if (_busy) return;
                        setState(() {
                          _tab = v ?? 0;
                          _error = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_tab == 1) ...[
                    CupertinoTextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_busy,
                      placeholder: tr.yourName,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(
                          CupertinoIcons.person,
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
                    ),
                    const SizedBox(height: 12),
                  ],
                  CupertinoTextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    placeholder: tr.authEmail,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        CupertinoIcons.at,
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
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    placeholder: tr.authPassword,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        CupertinoIcons.lock,
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
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: CupertinoColors.destructiveRed.resolveFrom(
                          context,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _busy ? null : _submit,
                      borderRadius: BorderRadius.circular(12),
                      child: _busy
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : Text(_tab == 0 ? tr.signIn : tr.signUp),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: _busy ? null : widget.onContinueOffline,
                    child: Text(
                      tr.continueOffline,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  tr.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr.authSub,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(tr.signIn),
                      icon: const Icon(Icons.login_rounded),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(tr.signUp),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: _busy
                      ? null
                      : (next) {
                          setState(() {
                            _tab = next.first;
                            _error = null;
                          });
                        },
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        if (_tab == 1) ...[
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: tr.yourName,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: tr.authEmail,
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: tr.authPassword,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _submit,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _tab == 0
                                        ? Icons.login_rounded
                                        : Icons.person_add_alt_1_rounded,
                                  ),
                            label: Text(_tab == 0 ? tr.signIn : tr.signUp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : widget.onContinueOffline,
                  child: Text(tr.continueOffline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
