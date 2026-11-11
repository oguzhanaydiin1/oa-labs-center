import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account.dart';
import 'android_bg.dart';
import 'desktop.dart';
import 'i18n.dart';
import 'oa_theme.dart';
import 'settings.dart';
import 'version.dart';
import 'widgets.dart';

/// Hesap ve ayarlar: e-postaya gelen kodla giriş, hesap bilgisi, oturumlar, uygulama ayarları.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.account, required this.wide, required this.onSettingsChanged});
  final OAAccount account;
  final bool wide;

  /// Beta ya da dil değişince listeler yenilensin.
  final VoidCallback onSettingsChanged;

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
    return ListenableBuilder(
      listenable: Listenable.merge([Settings.i, Desktop.i]),
      builder: (context, _) => PageFrame(wide: widget.wide, children: [
        PageTitle(t('Hesap ve ayarlar')),
        if (account.loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (account.signedIn)
          ..._signedIn(context)
        else
          _signIn(context),
        _settings(),
        Text(
          appVersion == '0.0.0' ? t('OA Labs Center · geliştirme derlemesi') : 'OA Labs Center $appVersion',
          style: oaBody(13, color: OA.faint),
        ),
      ]),
    );
  }

  Widget _settings() {
    final s = Settings.i;
    final d = Desktop.i;
    final rows = <Widget>[
      SwitchRow(
        title: t('Deneme sürümlerini al'),
        subtitle: t('Yeni özellikler yayından önce gelir; ara sıra hata çıkabilir. Kapatınca bir sonraki kararlı sürümü beklersin.'),
        value: s.beta,
        onChanged: (v) async {
          await s.setBeta(v);
          widget.onSettingsChanged();
        },
      ),
      if (Platform.isWindows) ...[
        const Divider(height: 1, color: OA.line),
        SwitchRow(
          title: t('Windows açılışında arka planda çalış'),
          subtitle: t('Güncellemeleri 6 saatte bir denetler, yenisi çıkınca haber verir. Pencere kapanınca saat yanındaki simgeye iner.'),
          value: d.background,
          onChanged: d.setBackground,
        ),
        const Divider(height: 1, color: OA.line),
        SwitchRow(
          title: t('Güncellemeleri kendiliğinden kur'),
          subtitle: t('Arka planda kurar; o an açık olan uygulamayı kapatmamak için ona dokunmaz, yalnız haber verir.'),
          value: d.autoUpdate,
          onChanged: d.background ? d.setAutoUpdate : null,
        ),
      ],
      if (Platform.isAndroid) ...[
        const Divider(height: 1, color: OA.line),
        SwitchRow(
          title: t('Güncelleme ve duyuru bildirimleri'),
          subtitle: t('Günde bir kez yeni sürümleri ve OA Labs duyurularını denetler, varsa bildirim gösterir.'),
          value: s.androidNotify,
          onChanged: (v) async {
            await s.setAndroidNotify(v);
            await AndroidBackground.apply();
          },
        ),
      ],
      const Divider(height: 1, color: OA.line),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Text(t('Dil'), style: oaBody(17, weight: FontWeight.w600))),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: OA.surface2,
              foregroundColor: OA.text,
              selectedBackgroundColor: OA.amber,
              selectedForegroundColor: OA.amberInk,
              side: const BorderSide(color: OA.border),
            ),
            segments: [
              ButtonSegment(value: 'auto', label: Text(t('Cihaz'))),
              const ButtonSegment(value: 'tr', label: Text('Türkçe')),
              const ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {s.lang},
            onSelectionChanged: (v) async {
              await s.setLang(v.first);
              widget.onSettingsChanged();
            },
          ),
        ]),
      ),
    ];
    return OACard(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Ayarlar'), style: oaDisplay(22)),
        const SizedBox(height: 4),
        ...rows,
      ]),
    );
  }

  Widget _signIn(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: OACard(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(t('Giriş yap'), style: oaDisplay(24)),
            const SizedBox(height: 6),
            Text(
              _codeSent
                  ? t('{email} adresine 6 haneli bir kod gönderdik.', {'email': _email.text.trim()})
                  : t('Şifre yok: e-posta adresini yaz, sana bir giriş kodu gönderelim. Giriş yapınca Pusula Browser da girişli açılır.'),
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
                decoration: InputDecoration(labelText: t('E-posta adresin'), hintText: 'ornek@eposta.com'),
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
                decoration: InputDecoration(labelText: t('Giriş kodu'), hintText: t('6 haneli kod')),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: oaBody(15, color: OA.danger)),
            ],
            const SizedBox(height: 18),
            OAButton(
              _busy ? t('Bekle…') : (_codeSent ? t('Giriş yap') : t('Kod gönder')),
              kind: OAButtonKind.primary,
              big: true,
              onPressed: _busy ? null : (_codeSent ? _verify : _send),
            ),
            const SizedBox(height: 10),
            if (_codeSent)
              OAButton(
                t('Başka e-posta kullan'),
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
                t('Üyeliğin yok mu? oalabs.dev’de üye ol'),
                onPressed: () => openLink(L.en ? 'https://oalabs.dev/en/uye/' : 'https://oalabs.dev/uye/'),
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
          UserAvatar(account, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(u.name, style: oaDisplay(20), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(u.email, style: oaBody(15, color: OA.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => openLink('https://oalabs.dev/hesabim/'),
                style: TextButton.styleFrom(foregroundColor: OA.amber, padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                child: Text(account.avatar == null ? t('Fotoğraf ekle') : t('Fotoğrafı değiştir')),
              ),
            ]),
          ),
        ]),
      ),
      if (account.sessions.isNotEmpty)
        OACard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(t('Oturumlar'), style: oaDisplay(20)),
            const SizedBox(height: 4),
            Text(t('Hesabınla giriş yapılmış uygulamalar ve tarayıcılar.'), style: oaBody(15, color: OA.text2)),
            for (final s in account.sessions) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: OA.line),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.device, style: oaBody(17)),
                    Text(s.current ? t('Bu oturum') : t('son görülme {ago}', {'ago': agoText(s.lastSeen)}),
                        style: oaBody(13, color: OA.muted)),
                  ]),
                ),
                if (!s.current) OAButton(t('Çıkış yaptır'), onPressed: () => account.dropSession(s)),
              ]),
            ],
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OAButton(t('Çıkış yap'), kind: OAButtonKind.danger, big: true, onPressed: () => account.logout()),
      ),
    ];
  }
}
