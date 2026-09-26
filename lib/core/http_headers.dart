/// 自定义 HTTP Header 预设：让拾忆的请求带上其他客户端身份，
/// 供只认特定客户端的网关/中转站（按 User-Agent、originator 等区分配额）识别。
///
/// 取值来源：
/// - Hermes Agent：NousResearch/hermes-agent
///   （agent/codex_headers.py、tests/agent/test_provider_attribution_headers.py）
/// - Codex CLI：openai/codex（codex-rs，originator=codex_cli_rs、version、session_id）
/// - Claude Code：claude-cli/<版本> (external, cli) + x-app: cli 等公开抓包资料
/// - WorkBuddy：腾讯 WorkBuddy（CodeBuddy 系），取自
///   PrasomTR/Workbuddy-codebuddy-openai-proxy 的 internal/upstream/headers.go
///   （UA 三段式 WorkBuddy/<版本> CLI/<版本>、X-CodeBuddy-Request 等）
///
/// 版本号只是示例值，网关若按版本放行，请按需改成真实客户端版本。
library;

/// 单个身份预设。
class HttpHeaderPreset {
  final String id;
  final String name;
  final String subtitle;
  final Map<String, String> headers;

  const HttpHeaderPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.headers,
  });
}

/// 不伪装，只用拾忆默认请求头。
const String kHeaderPresetNone = 'none';

/// 预设表（顺序即设置页展示顺序）。
const List<HttpHeaderPreset> httpHeaderPresets = [
  HttpHeaderPreset(
    id: 'hermes',
    name: 'Hermes Agent',
    subtitle: 'HermesAgent/<版本> + originator: hermes-agent',
    headers: {
      'User-Agent': 'HermesAgent/1.0.0',
      'originator': 'hermes-agent',
      'HTTP-Referer': 'https://hermes-agent.nousresearch.com',
      'X-Title': 'Hermes Agent',
      'X-BILLING-INVOKE-ORIGIN': 'HermesAgent',
    },
  ),
  HttpHeaderPreset(
    id: 'codex',
    name: 'Codex CLI',
    subtitle: 'codex_cli_rs + originator/version/session_id',
    headers: {
      'User-Agent': 'codex_cli_rs/0.50.0 (Linux 6.6.30; x86_64) shiyi-agent',
      'originator': 'codex_cli_rs',
      'version': '0.50.0',
      'session_id': '{{session_id}}',
    },
  ),
  HttpHeaderPreset(
    id: 'claudeCode',
    name: 'Claude Code',
    subtitle: 'claude-cli/<版本> (external, cli) + x-app: cli',
    headers: {
      'user-agent': 'claude-cli/2.0.0 (external, cli)',
      'x-app': 'cli',
      'anthropic-beta':
          'claude-code-20250219,oauth-2025-04-20,'
          'interleaved-thinking-2025-05-14,fine-grained-tool-streaming-2025-05-14',
      'x-stainless-lang': 'js',
      'x-stainless-package-version': '0.68.0',
      'x-stainless-os': 'MacOS',
      'x-stainless-arch': 'arm64',
      'x-stainless-runtime': 'node',
      'x-stainless-runtime-version': 'v22.17.0',
      'x-stainless-retry-count': '0',
      'x-stainless-timeout': '600',
      'X-Claude-Code-Session-Id': '{{uuid}}',
    },
  ),
  HttpHeaderPreset(
    id: 'workbuddy',
    name: 'WorkBuddy',
    subtitle: 'WorkBuddy/<版本> CLI/<版本> + X-CodeBuddy-Request',
    headers: {
      'User-Agent': 'WorkBuddy/1.0.0 CLI/2.137.1',
      'X-CodeBuddy-Request': '1',
      'X-Product': 'SaaS',
      'X-Agent-Purpose': 'conversation',
      'X-IDE-Name': 'WorkBuddy',
      'X-IDE-Type': 'WorkBuddy',
      'X-IDE-Version': '1.0.0',
      'X-Domain': 'www.workbuddy.ai',
      'X-Requested-With': 'XMLHttpRequest',
      'X-Request-ID': '{{uuid}}',
      'X-Conversation-ID': '{{session_id}}',
    },
  ),
];

/// 按 id 取预设；未知 id 返回 null（等同不伪装）。
HttpHeaderPreset? httpHeaderPresetById(String? id) {
  final key = (id ?? '').trim();
  if (key.isEmpty || key == kHeaderPresetNone) return null;
  for (final p in httpHeaderPresets) {
    if (p.id == key) return p;
  }
  return null;
}

/// 预设展示名，用于设置页副标题。
String httpHeaderPresetLabel(String? id) =>
    httpHeaderPresetById(id)?.name ?? '未启用';

/// 合并预设头与用户自定义头：自定义优先，键名忽略大小写；
/// 自定义值为空字符串表示「删除该头」。
Map<String, String> mergeCustomHeaders(
  String? presetId,
  Map<String, String> custom,
) {
  final merged = <String, String>{};
  void put(String name, String value) {
    final key = name.trim();
    if (key.isEmpty) return;
    merged.removeWhere((k, _) => k.toLowerCase() == key.toLowerCase());
    if (value.isEmpty) return;
    merged[key] = value;
  }

  final preset = httpHeaderPresetById(presetId);
  if (preset != null) {
    preset.headers.forEach(put);
  }
  custom.forEach(put);
  return merged;
}
