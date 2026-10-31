import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/ace_client.dart';
import '../data/app_controller.dart';
import '../domain/ace.dart';
import '../domain/study_tools.dart';
import 'common.dart';
import 'group_picker.dart';
import 'motion.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

const aceDown = 'Кабинет ДонНТУ (ace.donntu.ru) не отвечает. Обычно это сбой на стороне вуза — попробуйте позже.';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _user = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  LoginResult? _result;
  bool _busy = false;
  bool _reveal = false;
  String? _error;

  @override
  void dispose() {
    _password.clear();
    _user.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final app = context.app;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final previous = _result;
      final r = await app.auth.login(
        userName: _user.text.trim(),
        password: _password.text,
        captchaKey: previous is LoginCaptcha ? previous.key : null,
        captchaCode: previous is LoginCaptcha ? _code.text.trim() : null,
        otpCode: previous is LoginTwoFactor ? _code.text.trim() : null,
      );
      if (!mounted) return;
      _code.clear();
      switch (r) {
        case LoginOk():
          _password.clear();
          setState(() => _result = r);
          await _adopt();
        case LoginError():
          setState(() {
            _result = r;
            _error = r.message;
          });
        default:
          setState(() => _result = r);
      }
    } on AceError catch (e) {
      if (mounted) setState(() => _error = e.code == 'network' ? aceDown : e.message);
    } catch (_) {
      if (mounted) setState(() => _error = aceDown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adopt() async {
    final app = context.app;
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r.isFirst);
    app.store.setPrefs((p) => p.copyWith(onboarded: true));
    try {
      final token = await app.auth.ace.token();
      if (token != null) {
        final card = await app.auth.ace.student(token);
        if (card.fullName.isNotEmpty && app.store.prefs.value.displayName.isEmpty) {
          app.store.setPrefs((p) => p.copyWith(displayName: displayFromFullName(card.fullName)));
        }
        final code = card.group;
        if (code != null) {
          String squash(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s_–—-]'), '');
          final match = app.groups.value.where((g) => squash(g.code) == squash(code)).firstOrNull;
          if (match != null) await app.chooseGroup(match.code);
        }
      }
    } catch (_) {}
    if (app.store.selection.value.group.isEmpty) navigator.push(_pickerRoute(app));
  }

  Route<void> _pickerRoute(AppController app) => QuietRoute<void>(
        builder: (_) => GroupPickerPage(controller: app, onChosen: () => app.store.setPrefs((p) => p.copyWith(onboarded: true))),
      );

  Future<void> _anotherCaptcha() async {
    try {
      final c = await context.app.auth.ace.captcha();
      if (mounted) setState(() => _result = LoginCaptcha(imageBase64: c.image, key: c.key, message: ''));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _skip() {
    final app = context.app;
    if (app.store.selection.value.group.isNotEmpty) {
      app.store.setPrefs((p) => p.copyWith(onboarded: true));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pushReplacement(_pickerRoute(app));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final result = _result;
    return PageScaffold(
      title: 'Вход',
      children: [
        VGap(MediaQuery.sizeOf(context).height * 0.05),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(24)),
            alignment: Alignment.center,
            child: AppIcon('profile', size: 36, color: c.link, focused: true),
          ),
        ),
        const VGap(16),
        Text('Кабинет студента'.cased, textAlign: TextAlign.center, style: T.display.copyWith(color: c.text, fontSize: 28, height: 1.2)),
        const VGap(4),
        Text('Войдите через университетскую учётную запись'.cased, textAlign: TextAlign.center, style: T.caption.copyWith(color: c.muted)),
        const VGap(24),
        _field(c, _user, 'Логин', autofill: const [AutofillHints.username]),
        const VGap(8),
        _field(c, _password, 'Пароль', obscure: !_reveal, autofill: const [AutofillHints.password], trailing: Tap(label: _reveal ? 'Скрыть пароль' : 'Показать пароль', onTap: () => setState(() => _reveal = !_reveal), child: SizedBox(width: 48, height: 48, child: Center(child: AppIcon('eye', size: 20, color: c.muted))))),
        if (result is LoginCaptcha) ...[
          const VGap(8),
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (result.message.isNotEmpty) Text(result.message, textAlign: TextAlign.center, style: T.body.copyWith(color: c.text)),
              const VGap(8),
              Image.memory(base64Decode(result.imageBase64.replaceFirst(RegExp(r'^data:image/[a-z]+;base64,'), '')), width: 200, height: 80, fit: BoxFit.contain),
              const VGap(8),
              _field(c, _code, 'Код с картинки'),
              const VGap(8),
              PrimaryButton(label: 'Другая картинка', secondary: true, onTap: _anotherCaptcha),
            ]),
          ),
        ],
        if (result is LoginTwoFactor) ...[
          const VGap(8),
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('Введите код из письма на ${result.email}'.cased, textAlign: TextAlign.center, style: T.body.copyWith(color: c.text)),
              const VGap(8),
              _field(c, _code, 'Код подтверждения'),
            ]),
          ),
        ],
        if (_error != null) ...[const VGap(8), ErrorBox(error: _error!)],
        const VGap(12),
        ListenableBuilder(
          listenable: Listenable.merge([_user, _password]),
          builder: (context, _) => PrimaryButton(label: _busy ? 'Подтверждаем…' : 'Войти', enabled: !_busy && _user.text.isNotEmpty && _password.text.isNotEmpty, onTap: _submit),
        ),
        const VGap(8),
        PrimaryButton(label: 'Продолжить без входа', secondary: true, enabled: !_busy, onTap: _skip),
        const VGap(12),
        Text('Пароль не сохраняется на телефоне'.cased, textAlign: TextAlign.center, style: T.caption.copyWith(color: c.muted)),
      ],
    );
  }

  Widget _field(Pal c, TextEditingController controller, String hint, {bool obscure = false, List<String> autofill = const [], Widget? trailing}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofillHints: autofill,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: T.body.copyWith(color: c.text),
      cursorColor: c.link,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: T.body.copyWith(color: c.muted),
        suffixIcon: trailing,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
