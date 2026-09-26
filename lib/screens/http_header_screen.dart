import 'package:flutter/cupertino.dart';

import '../core/app_state.dart';
import '../core/http_headers.dart';
import '../widgets/ios_style.dart';

const _accent = Color(0xFF0A84FF);

/// 自定义 HTTP Header 设置页：选客户端身份预设 + 增删自定义头。
class HttpHeaderScreen extends StatelessWidget {
  final ShiyiState shiyi;
  const HttpHeaderScreen({super.key, required this.shiyi});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: shiyi,
      builder: (context, _) {
        final settings = shiyi.settings;
        final presetId = settings.headerPreset;
        final custom = settings.customHeaders;
        final effective = mergeCustomHeaders(presetId, custom);
        final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

        return CupertinoPageScaffold(
          backgroundColor: dark
              ? const Color(0xFF000000)
              : const Color(0xFFF2F2F7),
          navigationBar: const CupertinoNavigationBar(
            middle: Text('自定义 HTTP Header'),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 36),
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('客户端身份预设'),
                  footer: const Text(
                    '预设只影响请求头，不改动协议与请求体。'
                    '网关若按客户端版本放行，可把版本号改成真实版本。',
                  ),
                  children: [
                    _presetTile(presetId, kHeaderPresetNone, '不伪装'),
                    for (final p in httpHeaderPresets)
                      _presetTile(presetId, p.id, p.name, subtitle: p.subtitle),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('自定义 Header'),
                  footer: const Text(
                    '同名头会覆盖预设与默认头（Content-Type 除外）。'
                    '值支持 {{session_id}} 与 {{uuid}} 占位符，发送时按会话替换。',
                  ),
                  children: [
                    if (custom.isEmpty)
                      const CupertinoListTile(
                        title: Text('暂无自定义头'),
                        subtitle: Text('点下方“添加 Header”新增'),
                      ),
                    for (final entry in custom.entries)
                      CupertinoListTile(
                        title: Text(entry.key),
                        subtitle: Text(
                          entry.value.isEmpty ? '（删除该头）' : entry.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _editHeader(
                          context,
                          originKey: entry.key,
                          originValue: entry.value,
                        ),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Icon(
                            CupertinoIcons.minus_circle_fill,
                            color: Color(0xFFFF3B30),
                            size: 22,
                          ),
                          onPressed: () => _removeHeader(entry.key),
                        ),
                      ),
                    CupertinoListTile(
                      leading: const Icon(
                        CupertinoIcons.add_circled_solid,
                        color: _accent,
                        size: 22,
                      ),
                      title: const Text('添加 Header'),
                      onTap: () => _editHeader(context),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('本次生效的请求头'),
                  footer: Text(
                    '共 ${effective.length} 条，实际发送时再叠加 Authorization / '
                    'anthropic-version 等默认头。',
                  ),
                  children: [
                    if (effective.isEmpty)
                      const CupertinoListTile(title: Text('仅使用默认头')),
                    for (final entry in effective.entries)
                      CupertinoListTile(
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _presetTile(
    String currentId,
    String id,
    String title, {
    String? subtitle,
  }) {
    final selected = currentId == id;
    return CupertinoListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: selected
          ? const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: _accent,
              size: 22,
            )
          : null,
      onTap: () {
        if (selected) return;
        shiyi.updateSettings(shiyi.settings.copyWith(headerPreset: id));
      },
    );
  }

  void _removeHeader(String key) {
    final next = Map<String, String>.from(shiyi.settings.customHeaders)
      ..remove(key);
    shiyi.updateSettings(shiyi.settings.copyWith(customHeaders: next));
  }

  Future<void> _editHeader(
    BuildContext context, {
    String? originKey,
    String? originValue,
  }) async {
    final keyCtrl = TextEditingController(text: originKey ?? '');
    final valueCtrl = TextEditingController(text: originValue ?? '');
    final saved = await showIosFadeDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(originKey == null ? '添加 Header' : '编辑 Header'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: keyCtrl,
                placeholder: '名称，例如 User-Agent',
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: valueCtrl,
                placeholder: '值，留空表示删除该头',
                autocorrect: false,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // 先取出文本再释放控制器，避免读到已 dispose 的 controller。
    final key = keyCtrl.text.trim();
    final value = valueCtrl.text.trim();
    keyCtrl.dispose();
    valueCtrl.dispose();
    if (saved != true || key.isEmpty) return;
    final next = Map<String, String>.from(shiyi.settings.customHeaders);
    if (originKey != null && originKey != key) next.remove(originKey);
    next[key] = value;
    shiyi.updateSettings(shiyi.settings.copyWith(customHeaders: next));
  }
}
