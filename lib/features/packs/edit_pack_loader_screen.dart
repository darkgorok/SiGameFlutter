import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import 'local_pack.dart';
import 'pack_editor_screen.dart';
import 'pack_file.dart';

class EditPackLoaderScreen extends StatefulWidget {
  const EditPackLoaderScreen({super.key});

  @override
  State<EditPackLoaderScreen> createState() => _EditPackLoaderScreenState();
}

class _EditPackLoaderScreenState extends State<EditPackLoaderScreen> {
  bool _loading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickAndOpenPack();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.packEditorEdit)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.packSelectFilePrompt,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    _errorText ?? context.l10n.packSelectFilePrompt,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _pickAndOpenPack,
                    child: Text(context.l10n.packSelectFile),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndOpenPack() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final jsonText = await pickPackJsonText();
      if (jsonText == null || jsonText.trim().isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final raw = jsonDecode(jsonText);
      final pack = LocalPackDocument.fromJson(raw);
      if (!_isPackValid(pack)) {
        throw const FormatException('invalid pack format');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PackEditorScreen(initialPack: pack)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = context.l10n.packInvalidFile;
      });
    }
  }

  bool _isPackValid(LocalPackDocument pack) {
    if (pack.questions.isEmpty) {
      return false;
    }
    for (final q in pack.questions) {
      if (q.theme.trim().isEmpty) {
        return false;
      }
      if (q.cost <= 0 || q.round <= 0) {
        return false;
      }
    }
    return true;
  }
}
