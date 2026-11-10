import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account.dart';
import 'catalog.dart';
import 'oa_theme.dart';

/// Android tek giriş: başka bir OA uygulaması "OA Labs Center ile giriş yap" dediğinde
/// Center bu ekranla açılır. İsteyen uygulamanın paket adını Android verir.
class LinkRequests {
  LinkRequests._();
  static const _ch = MethodChannel('oa/center');

  /// Bekleyen isteğin paket adı (yoksa null).
  static Future<String?> pending() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _ch.invokeMethod<String>('bekleyenGiris');
    } catch (_) {
      return null;
    }
  }

  /// İsteğe cevap ver ([code] null: vazgeçildi). Ekran kapanır, kullanıcı öbür uygulamaya döner.
  static Future<void> answer(String? code) async {
    try {
      await _ch.invokeMethod('girisSonuc', {'kod': code});
    } catch (_) {}
  }

  /// Paket adından katalogdaki OA uygulaması (OA uygulaması değilse null).
  static OAApp? appFor(String package, List<OAApp> apps) {
    for (final a in [...apps, ...builtinCatalog]) {
      if (a.android?.package == package) return a;
    }
    return null;
  }
}

/// Giriş isteği: "Pusula Browser, OA Labs hesabınla giriş yapmak istiyor".
class LinkPrompt extends StatefulWidget {
  const LinkPrompt({super.key, required this.app, required this.account, required this.onSignIn});
  final OAApp app;
  final OAAccount account;

  /// Center'da henüz giriş yapılmamışsa Hesabım'a git.
  final VoidCallback onSignIn;

  @override
  State<LinkPrompt> createState() => _LinkPromptState();
}

class _LinkPromptState extends State<LinkPrompt> {
  bool _busy = false;
  String? _error;

  Future<void> _allow() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final code = await widget.account.handoffFor(widget.app.id);
    if (!mounted) return;
    if (code == null) {
      setState(() {
        _busy = false;
        _error = 'Giriş izni verilemedi. İnternet bağlantını kontrol edip yeniden dene.';
      });
      return;
    }
    await LinkRequests.answer(code);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.account.user;
    return ColoredBox(
      color: const Color(0xCC07080C),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                color: Colors.transparent,
                child: OACard(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const OAMark(size: 40, ground: OA.surface),
                      const SizedBox(width: 12),
                      Expanded(child: Text('OA hesabınla giriş', style: oaDisplay(22))),
                    ]),
                    const SizedBox(height: 14),
                    Text(
                      user == null
                          ? '${widget.app.name}, OA Labs hesabınla giriş yapmak istiyor. Önce OA Labs Center’da giriş yap.'
                          : '${widget.app.name}, OA Labs hesabınla giriş yapmak istiyor.',
                      style: oaBody(17),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: OA.surface2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: OA.border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(user.name, style: oaBody(17, weight: FontWeight.w600)),
                          Text(user.email, style: oaBody(15, color: OA.text2)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Text('${widget.app.name} kendi oturumunu açar; Hesabım’daki cihaz listesinde ayrı görünür.',
                          style: oaBody(13, color: OA.muted)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: oaBody(15, color: OA.danger)),
                    ],
                    const SizedBox(height: 20),
                    if (user == null)
                      OAButton('Giriş yap', kind: OAButtonKind.primary, big: true, onPressed: widget.onSignIn)
                    else
                      OAButton(_busy ? 'Bekle…' : 'İzin ver',
                          kind: OAButtonKind.primary, big: true, onPressed: _busy ? null : _allow),
                    const SizedBox(height: 10),
                    OAButton('Vazgeç', onPressed: _busy ? null : () => LinkRequests.answer(null)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
