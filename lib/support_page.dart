import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account.dart';
import 'i18n.dart';
import 'oa_theme.dart';
import 'version.dart';
import 'widgets.dart';

/// OA Labs iletişim bilgileri.
class Contact {
  Contact._();
  static const email = 'destek@oalabs.dev';
  static const site = 'https://oalabs.dev';
  static String get contactPage => L.en ? '$site/en/iletisim/' : '$site/iletisim/';
  static String get help => L.en ? '$site/en/yardim/' : '$site/yardim/';
  static String get ideas => L.en ? '$site/en/geri-bildirim/#fikirler' : '$site/geri-bildirim/#fikirler';
  static String get roadmap => L.en ? '$site/en/yol-haritasi/' : '$site/yol-haritasi/';
  static String get about => L.en ? '$site/en/hakkimizda/' : '$site/hakkimizda/';
  static const developerSite = 'https://oguzhanaydin.com.tr';

  /// Kullanıcının e-postasına eklenen cihaz bilgisi (sorunu çözerken işe yarar).
  static String get device => 'OA Labs Center ${appVersion == '0.0.0' ? 'dev' : appVersion} · ${Platform.isWindows ? 'Windows' : 'Android'} ${Platform.operatingSystemVersion}';

  static String mailto({String subject = 'OA Labs Center'}) {
    final body = '\n\n—\n$device';
    return 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
  }
}

/// Destek: geri bildirim formu ve OA Labs'e ulaşma yolları.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.account, required this.wide});
  final OAAccount account;
  final bool wide;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

const _apps = [
  ('center', 'OA Labs Center'),
  ('pusula', 'Pusula Browser'),
  ('kopru', 'Pusula Köprü'),
  ('radyo', 'OA Radyo'),
  ('harrier', 'Harrier Cleaner'),
  ('site', 'oalabs.dev'),
  ('diger', null),
];

class _SupportPageState extends State<SupportPage> {
  final _text = TextEditingController();
  final _email = TextEditingController();
  String _kind = 'hata';
  String _app = 'center';
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    final email = _email.text.trim();
    if (text.length < 5) return setState(() => _error = t('Biraz daha ayrıntı yaz.'));
    if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return setState(() => _error = t('Bu e-posta adresi geçerli görünmüyor.'));
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.account.api('/v1/feedback', {
      'kind': _kind,
      'app': _app,
      'text': text,
      'email': email,
      'page': Contact.device,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r['ok'] == true) {
        _sent = true;
        _text.clear();
      } else {
        _error = switch (r['error']) {
          'kisa' => t('Biraz daha ayrıntı yaz.'),
          'eposta' => t('Bu e-posta adresi geçerli görünmüyor.'),
          'cok' => t('Çok fazla gönderim oldu, biraz sonra tekrar dene.'),
          'ag' => t('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.'),
          _ => t('Gönderilemedi. İstersen doğrudan {email} adresine yaz.', {'email': Contact.email}),
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = [_form(), _contact()];
    return PageFrame(wide: widget.wide, children: [
      PageTitle(t('Destek'), lead: t('Bir şey çalışmıyorsa ya da bir fikrin varsa bize yaz. Hepsini okuyoruz.')),
      if (widget.wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: cards[0]),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: cards[1]),
        ])
      else ...[
        cards[0],
        const SizedBox(height: 20),
        cards[1],
      ],
    ]);
  }

  Widget _form() {
    final user = widget.account.user;
    if (_sent) {
      return OACard(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle_outline, color: OA.green, size: 36),
          const SizedBox(height: 10),
          Text(t('Teşekkürler, aldık!'), style: oaDisplay(24)),
          const SizedBox(height: 6),
          Text(t('Yanıt istediysen e-postana yazacağız.'), style: oaBody(15, color: OA.text2)),
          const SizedBox(height: 16),
          OAButton(t('Bir şey daha yaz'), onPressed: () => setState(() => _sent = false)),
        ]),
      );
    }
    return OACard(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t('Bize yaz'), style: oaDisplay(24)),
        const SizedBox(height: 4),
        Text(t('Hesap gerekmez. Yanıt istersen e-postanı da ekle.'), style: oaBody(15, color: OA.text2)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in [('hata', t('Hata')), ('oneri', t('Öneri')), ('diger', t('Diğer'))])
            ChoiceChip(
              label: Text(k.$2, style: oaBody(14, weight: FontWeight.w600, color: _kind == k.$1 ? OA.amberInk : OA.text)),
              selected: _kind == k.$1,
              showCheckmark: false,
              selectedColor: OA.amber,
              backgroundColor: OA.surface2,
              side: BorderSide(color: _kind == k.$1 ? OA.amber : OA.border),
              shape: const StadiumBorder(),
              onSelected: (_) => setState(() => _kind = k.$1),
            ),
        ]),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _app, // ignore: deprecated_member_use
          dropdownColor: OA.surface2,
          decoration: InputDecoration(labelText: t('Hangi uygulama?')),
          style: oaBody(16),
          items: [for (final a in _apps) DropdownMenuItem(value: a.$1, child: Text(a.$2 ?? t('Diğer')))],
          onChanged: (v) => setState(() => _app = v ?? 'center'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 10,
          maxLength: 4000,
          style: oaBody(16),
          decoration: InputDecoration(
            labelText: t('Ne oldu? Ne olmasını isterdin?'),
            hintText: t('Örneğin: Güncelle’ye basınca…'),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          style: oaBody(16),
          decoration: InputDecoration(
            labelText: t('E-posta (isteğe bağlı, yalnız yanıt için)'),
            hintText: user?.email ?? 'ornek@eposta.com',
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 6),
          Text(t('Boş bırakırsan hesabının e-postasına ({email}) yanıt veririz.', {'email': user.email}),
              style: oaBody(13, color: OA.muted)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: oaBody(15, color: OA.danger)),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OAButton(_busy ? t('Gönderiliyor…') : t('Gönder'), kind: OAButtonKind.primary, big: true, onPressed: _busy ? null : _send),
        ),
        const SizedBox(height: 10),
        Text(t('Mesajınla birlikte uygulama sürümü ve işletim sistemi bilgisi de gönderilir: {d}', {'d': Contact.device}),
            style: oaBody(13, color: OA.faint)),
      ]),
    );
  }

  Widget _contact() {
    Widget item(IconData icon, String title, String value, VoidCallback onTap, {VoidCallback? onCopy}) => InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: OA.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: OA.border)),
                child: Icon(icon, size: 20, color: OA.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: oaBody(13, color: OA.muted, weight: FontWeight.w600)),
                  Text(value, style: oaBody(16, weight: FontWeight.w600)),
                ]),
              ),
              if (onCopy != null)
                IconButton(tooltip: t('Kopyala'), icon: const Icon(Icons.copy_outlined, size: 20, color: OA.muted), onPressed: onCopy),
            ]),
          ),
        );

    return Column(children: [
      OACard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t('Bize ulaş'), style: oaDisplay(22)),
          const SizedBox(height: 8),
          item(Icons.mail_outline, t('E-posta'), Contact.email, () => openLink(Contact.mailto()), onCopy: () {
            Clipboard.setData(const ClipboardData(text: Contact.email));
            toast(context, t('E-posta adresi kopyalandı.'));
          }),
          item(Icons.forum_outlined, t('İletişim sayfası'), 'oalabs.dev/iletisim', () => openLink(Contact.contactPage)),
          item(Icons.help_outline, t('Sık sorulanlar'), 'oalabs.dev/yardim', () => openLink(Contact.help)),
          item(Icons.lightbulb_outline, t('Fikir panosu ve oylama'), 'oalabs.dev/geri-bildirim', () => openLink(Contact.ideas)),
          item(Icons.map_outlined, t('Yol haritası'), 'oalabs.dev/yol-haritasi', () => openLink(Contact.roadmap)),
          item(Icons.shield_outlined, t('Hesap ve kişisel veriler (KVKK)'), Contact.email,
              () => openLink(Contact.mailto(subject: t('Hesap ve kişisel veriler')))),
        ]),
      ),
      const SizedBox(height: 20),
      OACard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const OAMark(size: 32, ground: OA.surface),
            const SizedBox(width: 10),
            Text('OA Labs', style: oaDisplay(20)),
          ]),
          const SizedBox(height: 8),
          Text(t('OA Labs, Oğuzhan Aydın’ın yazılım atölyesi. Uygulamaların hepsi ücretsiz ve reklamsız.'),
              style: oaBody(15, color: OA.text2)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OAButton('oalabs.dev', onPressed: () => openLink(Contact.site)),
            OAButton(t('Hakkımızda'), onPressed: () => openLink(Contact.about)),
            OAButton('oguzhanaydin.com.tr', onPressed: () => openLink(Contact.developerSite)),
          ]),
        ]),
      ),
    ]);
  }
}
