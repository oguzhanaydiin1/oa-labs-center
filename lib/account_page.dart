import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account.dart';
import 'oa_theme.dart';
import 'version.dart';
import 'widgets.dart';

/// Hesabım: e-postaya gelen kodla giriş, hesap bilgisi, bağlı cihazlar.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.account, required this.wide});
  final OAAccount account;
  final bool wide;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  OAAccount get account => widget.account;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@') || email.length < 5) {
      setState(() => _error = accountError('eposta'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await account.start(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // "bekle": kod az önce gönderilmiş; kullanıcı onu girebilsin.
      _codeSent = err == null || err == 'bekle';
      _error = err == null ? null : accountError(err);
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = accountError('kod'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await account.verify(_email.text, code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err == null ? null : accountError(err);
      if (err == null) {
        _codeSent = false;
        _code.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(wide: widget.wide, children: [
      Text('Hesabım', style: oaDisplay(34)),
      if (account.loading)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else if (account.signedIn)
        ..._signedIn(context)
      else
        _signIn(context),
      Text(
        appVersion == '0.0.0' ? 'OA Labs Center · geliştirme derlemesi' : 'OA Labs Center $appVersion',
        style: oaBody(13, color: OA.faint),
      ),
    ]);
  }

  Widget _signIn(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: OACard(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('Giriş yap', style: oaDisplay(24)),
            const SizedBox(height: 6),
            Text(
              _codeSent
                  ? '${_email.text.trim()} adresine 6 haneli bir kod gönderdik.'
                  : 'Şifre yok: e-posta adresini yaz, sana bir giriş kodu gönderelim.',
              style: oaBody(15, color: OA.text2),
            ),
            const SizedBox(height: 18),
            if (!_codeSent)
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _send(),
                style: oaBody(17),
                decoration: const InputDecoration(labelText: 'E-posta adresin', hintText: 'ornek@eposta.com'),
              )
            else
              TextField(
                controller: _code,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verify(),
                style: oaBody(22, weight: FontWeight.w600),
                decoration: const InputDecoration(labelText: 'Giriş kodu', hintText: '6 haneli kod'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: oaBody(15, color: OA.danger)),
            ],
            const SizedBox(height: 18),
            OAButton(
              _busy ? 'Bekle…' : (_codeSent ? 'Giriş yap' : 'Kod gönder'),
              kind: OAButtonKind.primary,
              big: true,
              onPressed: _busy ? null : (_codeSent ? _verify : _send),
            ),
            const SizedBox(height: 10),
            if (_codeSent)
              OAButton(
                'Başka e-posta kullan',
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _codeSent = false;
                          _error = null;
                          _code.clear();
                        }),
              )
            else
              OAButton(
                'Üyeliğin yok mu? oalabs.dev’de üye ol',
                onPressed: () => launchUrl(Uri.parse('https://oalabs.dev/uye/'), mode: LaunchMode.externalApplication),
              ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _signedIn(BuildContext context) {
    final u = account.user!;
    return [
      OACard(
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OA.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: OA.border),
            ),
            child: Text(u.initial, style: oaDisplay(22)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(u.name, style: oaDisplay(20), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(u.email, style: oaBody(15, color: OA.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
      if (account.sessions.isNotEmpty)
        OACard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('Cihazlar', style: oaDisplay(20)),
            const SizedBox(height: 4),
            Text('Hesabınla giriş yapılmış cihazlar ve uygulamalar.', style: oaBody(15, color: OA.text2)),
            for (final s in account.sessions) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: OA.line),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.device, style: oaBody(17)),
                    Text(s.current ? 'Bu cihaz' : _seen(s.lastSeen), style: oaBody(13, color: OA.muted)),
                  ]),
                ),
                if (!s.current) OAButton('Çıkış yaptır', onPressed: () => account.dropSession(s)),
              ]),
            ],
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OAButton('Çıkış yap', kind: OAButtonKind.danger, big: true, onPressed: () => account.logout()),
      ),
    ];
  }

  String _seen(DateTime? t) {
    if (t == null) return 'Son görülme bilinmiyor';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 10) return 'Az önce görüldü';
    if (d.inHours < 1) return '${d.inMinutes} dakika önce görüldü';
    if (d.inDays < 1) return '${d.inHours} saat önce görüldü';
    return '${d.inDays} gün önce görüldü';
  }
}
