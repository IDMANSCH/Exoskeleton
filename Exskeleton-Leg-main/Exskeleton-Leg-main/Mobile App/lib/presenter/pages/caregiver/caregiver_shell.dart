import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_bloc.dart';
import 'package:flutter_starter/data/states/auth/auth_event.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/presenter/pages/patient/patient_placeholders.dart';

@RoutePage()
class CaregiverShellPage extends StatefulWidget {
  const CaregiverShellPage({super.key});

  @override
  State<CaregiverShellPage> createState() => _CaregiverShellPageState();
}

class _CaregiverShellPageState extends State<CaregiverShellPage> {
  late Future<List<Map<String, dynamic>>> _relationships;
  int _selectedIndex = 0;
  int _notificationsVersion = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _relationships = provider.get<NetworkDataSource>().getRelationships();
  }

  Future<void> _openNetwork() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CareNetworkPage()),
    );
    if (mounted) setState(_reload);
  }

  void _openPatient(Map<String, dynamic> link) {
    final patientId = link['patient_id']?.toString();
    if (patientId == null || patientId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CaregiverPatientOverviewPage(
          patientId: patientId,
          patientName: link['patient_name']?.toString() ?? 'Người tập',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthBloc>().state.account;
    final pages = <Widget>[
      _CaregiverDashboard(
        accountName: account?.displayName ?? '',
        relationships: _relationships,
        onManage: _openNetwork,
        onOpenPatient: _openPatient,
      ),
      _CaregiverPatients(
        relationships: _relationships,
        onManage: _openNetwork,
        onOpenPatient: _openPatient,
      ),
      PatientNotificationsPage(key: ValueKey(_notificationsVersion)),
      _CaregiverSettings(
          accountName: account?.displayName ?? '',
          onManage: _openNetwork,
          onNotifications: () => setState(() {
            _selectedIndex = 2;
            _notificationsVersion++;
          })),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _CaregiverNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() {
          _selectedIndex = index;
          if (index == 2) _notificationsVersion++;
        }),
      ),
    );
  }
}

class _CaregiverDashboard extends StatelessWidget {
  final String accountName;
  final Future<List<Map<String, dynamic>>> relationships;
  final Future<void> Function() onManage;
  final ValueChanged<Map<String, dynamic>> onOpenPatient;

  const _CaregiverDashboard(
      {required this.accountName,
      required this.relationships,
      required this.onManage,
      required this.onOpenPatient});

  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text('Xin chào, $accountName',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Theo dõi an toàn và tiến độ của người thân tại một nơi.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          const _CaregiverHero(),
          const SizedBox(height: 22),
          FutureBuilder<List<Map<String, dynamic>>>(
              future: relationships,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _OverviewLoading();
                }
                final all = snapshot.data ?? const <Map<String, dynamic>>[];
                final active =
                    all.where((item) => item['status'] == 'active').toList();
                final pending =
                    all.where((item) => item['status'] == 'pending').length;
                if (active.isEmpty) {
                  return _CareEmptyState(
                      pendingCount: pending, onManage: onManage);
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CareSummary(
                          activeCount: active.length, pendingCount: pending),
                      const SizedBox(height: 22),
                      Text('Người tập của bạn',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      for (final link in active) ...[
                        _PatientLinkCard(
                            link: link, onTap: () => onOpenPatient(link)),
                        const SizedBox(height: 10),
                      ],
                    ]);
              }),
        ],
      ));
}

class _CaregiverPatients extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> relationships;
  final Future<void> Function() onManage;
  final ValueChanged<Map<String, dynamic>> onOpenPatient;
  const _CaregiverPatients(
      {required this.relationships,
      required this.onManage,
      required this.onOpenPatient});

  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Row(children: [
            Expanded(
                child: Text('Người tập',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900))),
            FilledButton.tonalIcon(
                onPressed: onManage,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Thêm')),
          ]),
          const SizedBox(height: 6),
          Text('Chỉ hiển thị dữ liệu khi lời mời đã được chấp nhận.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
              future: relationships,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _OverviewLoading();
                }
                final links = snapshot.data ?? const <Map<String, dynamic>>[];
                if (links.isEmpty) {
                  return _CareEmptyState(pendingCount: 0, onManage: onManage);
                }
                return Column(children: [
                  for (final link in links) ...[
                    _PatientLinkCard(
                        link: link,
                        onTap: link['status'] == 'active'
                            ? () => onOpenPatient(link)
                            : onManage),
                    const SizedBox(height: 10),
                  ]
                ]);
              }),
        ],
      ));
}

class _CaregiverSettings extends StatelessWidget {
  final String accountName;
  final Future<void> Function() onManage;
  final VoidCallback onNotifications;
  const _CaregiverSettings({
    required this.accountName,
    required this.onManage,
    required this.onNotifications,
  });

  Future<void> _logout(BuildContext context) async {
    await provider.get<NetworkDataSource>().logout();
    if (context.mounted) context.read<AuthBloc>().add(const AuthLoggedOut());
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text('Cài đặt',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Cá nhân hóa tài khoản và cách bạn đồng hành.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          _CaregiverSettingsHero(accountName: accountName),
          const SizedBox(height: 20),
          const _CareSettingsLabel('Tài khoản & đồng hành'),
          const SizedBox(height: 9),
          _CaregiverSettingTile(
            assetPath:
                'assets/images/gen_assets/asset_patient_profile_card.png',
            title: 'Quản lý người tập',
            subtitle: 'Thêm, chấp nhận hoặc hủy liên kết',
            accent: const Color(0xFF6A5AE0),
            onTap: onManage,
          ),
          const SizedBox(height: 10),
          _CaregiverSettingTile(
            assetPath: 'assets/images/gen_assets/asset_notifications.png',
            title: 'Thông báo an toàn',
            subtitle: 'Theo dõi lời mời và cảnh báo mới nhất',
            accent: Color(0xFF18A6A8),
            onTap: onNotifications,
          ),
          const SizedBox(height: 20),
          const _CareSettingsLabel('Ứng dụng'),
          const SizedBox(height: 9),
          const _CaregiverSettingTile(
            assetPath: 'assets/images/gen_assets/asset_help.png',
            title: 'Trợ giúp & hướng dẫn',
            subtitle: 'Tìm hiểu cách theo dõi người tập an toàn',
            accent: Color(0xFFEC8B3A),
          ),
          const SizedBox(height: 10),
          _CaregiverSettingTile(
            assetPath: 'assets/images/gen_assets/asset_privacy.png',
            title: 'Đăng xuất',
            subtitle: 'Thoát khỏi tài khoản hiện tại',
            accent: Theme.of(context).colorScheme.error,
            onTap: () => _logout(context),
          ),
        ],
      ));
}

class _CaregiverSettingsHero extends StatelessWidget {
  final String accountName;
  const _CaregiverSettingsHero({required this.accountName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, const Color(0xFF6A5AE0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(children: [
        Container(
          width: 74,
          height: 74,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .20),
              borderRadius: BorderRadius.circular(22)),
          child: Image.asset('assets/images/gen_assets/asset_profile.png'),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Xin chào,',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .80),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(accountName.isEmpty ? 'Người giám sát' : accountName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('Đang đồng hành cùng người tập',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ),
        Image.asset('assets/images/gen_assets/asset_progress.png',
            width: 48, height: 48),
      ]),
    );
  }
}

class _CareSettingsLabel extends StatelessWidget {
  final String text;
  const _CareSettingsLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
      );
}

class _CaregiverSettingTile extends StatelessWidget {
  final String assetPath;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  const _CaregiverSettingTile({
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: accent.withValues(alpha: .20), width: 1.1)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 15, 13),
            child: Row(children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(17)),
                child: Image.asset(assetPath, fit: BoxFit.contain),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12)),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ]),
          ),
        ),
      );
}

class _CareSummary extends StatelessWidget {
  final int activeCount;
  final int pendingCount;
  const _CareSummary({required this.activeCount, required this.pendingCount});

  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(
              child: _Metric(label: 'Đang theo dõi', value: '$activeCount')),
          Expanded(
              child: _Metric(label: 'Chờ xác nhận', value: '$pendingCount')),
          Image.asset('assets/images/ic_heart_circle.png',
              width: 44, height: 44),
        ]),
      ));
}

class _CareEmptyState extends StatelessWidget {
  final int pendingCount;
  final Future<void> Function() onManage;
  const _CareEmptyState({required this.pendingCount, required this.onManage});

  @override
  Widget build(BuildContext context) => _CareSurface(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Image.asset('assets/images/gen_assets/asset_patient_profile_card.png',
              width: 96, height: 96, fit: BoxFit.contain),
          const SizedBox(height: 14),
          Text(
              pendingCount > 0
                  ? 'Lời mời đang chờ xác nhận'
                  : 'Chưa có người tập',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              pendingCount > 0
                  ? 'Bạn vẫn có thể dùng các mục khác trong khi chờ người tập chấp nhận.'
                  : 'Thêm người tập bằng email để bắt đầu theo dõi.',
              textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(pendingCount > 0 ? 'Xem lời mời' : 'Thêm người tập')),
        ]),
      ));
}

class _PatientLinkCard extends StatelessWidget {
  final Map<String, dynamic> link;
  final VoidCallback onTap;
  const _PatientLinkCard({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = link['status'] == 'active';
    return _CareSurface(
        child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: CircleAvatar(
          child: Icon(active
              ? Icons.accessibility_new_rounded
              : Icons.schedule_rounded)),
      title: Text(link['patient_name']?.toString() ?? 'Người tập',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(active
          ? 'Đã liên kết · Xem tiến độ và lịch sử'
          : 'Đang chờ xác nhận'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ));
  }
}

class _CaregiverHero extends StatelessWidget {
  const _CaregiverHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/gen_assets/asset_progress.png',
            width: 76,
            height: 76,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đồng hành mỗi ngày',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('Tiến độ, lịch sử và cảnh báo luôn được cập nhật.',
                  style: TextStyle(color: scheme.onPrimaryContainer)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _CaregiverNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _CaregiverNavigationBar(
      {required this.selectedIndex, required this.onSelected});

  static const _items = [
    _CaregiverNavigationItem(
        assetPath: 'assets/images/ic_home.png', label: 'Tổng quan'),
    _CaregiverNavigationItem(
        assetPath: 'assets/images/ic_account.png', label: 'Người tập'),
    _CaregiverNavigationItem(
        assetPath: 'assets/images/ic_bell.png', label: 'Thông báo'),
    _CaregiverNavigationItem(
        assetPath: 'assets/images/ic_fill_setting.png', label: 'Cài đặt'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: Colors.white,
          elevation: 12,
          shadowColor: scheme.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: 78,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55)),
            ),
            child: Row(
              children: [
                for (final entry in _items.indexed)
                  Expanded(
                    child: _CaregiverNavigationButton(
                      item: entry.$2,
                      selected: selectedIndex == entry.$1,
                      onTap: () => onSelected(entry.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaregiverNavigationButton extends StatelessWidget {
  final _CaregiverNavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  const _CaregiverNavigationButton(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ImageIcon(AssetImage(item.assetPath),
                  color: foreground, size: selected ? 22 : 21),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontSize: 10.5,
                        height: 1.1,
                        letterSpacing: 0,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaregiverNavigationItem {
  final String assetPath;
  final String label;
  const _CaregiverNavigationItem(
      {required this.assetPath, required this.label});
}

class CaregiverPatientOverviewPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const CaregiverPatientOverviewPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<CaregiverPatientOverviewPage> createState() =>
      _CaregiverPatientOverviewPageState();
}

class _CaregiverPatientOverviewPageState
    extends State<CaregiverPatientOverviewPage> {
  late Future<Map<String, dynamic>> _progress;
  late Future<List<Map<String, dynamic>>> _alerts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = provider.get<NetworkDataSource>();
    _progress = api.getProgressOverview(widget.patientId);
    _alerts = api.getPatientAlerts(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.patientName)),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('Tổng quan luyện tập',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Theo dõi tiến độ và cảnh báo an toàn theo thời gian thực.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: _progress,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const _OverviewLoading();
                final data = snapshot.data!;
                final completion =
                    ((data['completion_rate'] as num?)?.toDouble() ?? 0)
                        .clamp(0, 1);
                final minutes =
                    ((data['active_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
                return Column(children: [
                  _PatientOverviewHero(
                    name: widget.patientName,
                    completion: completion.toDouble(),
                    sessionCount: '${data['session_count'] ?? 0}',
                  ),
                  const SizedBox(height: 14),
                  _ProgressOverviewCard(
                    completion: completion.toDouble(),
                    sessions: '${data['session_count'] ?? 0}',
                    repetitions: '${data['total_repetitions'] ?? 0}',
                    minutes: '${minutes}p',
                  ),
                ]);
              },
            ),
            const SizedBox(height: 16),
            Text('Lịch sử luyện tập',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: _progress,
              builder: (context, snapshot) {
                final sessions =
                    (snapshot.data?['recent_sessions'] as List<dynamic>? ??
                            const [])
                        .whereType<Map<String, dynamic>>()
                        .toList();
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _OverviewLoading();
                }
                if (sessions.isEmpty) {
                  return const _OverviewSurface(
                    child: Text('Chưa có buổi tập nào được ghi nhận.'),
                  );
                }
                return Column(
                  children: sessions.map((session) {
                    final seconds =
                        (session['active_seconds'] as num?)?.toInt() ?? 0;
                    final repetitions =
                        (session['completed_repetitions'] as num?)?.toInt() ??
                            0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SessionHistoryCard(
                        exerciseCode: session['exercise_code']?.toString(),
                        repetitions: repetitions,
                        duration: _durationLabel(seconds),
                        date: _dateLabel(session['started_at']),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Cảnh báo gần đây',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _alerts,
              builder: (context, snapshot) {
                final alerts = snapshot.data ?? const <Map<String, dynamic>>[];
                if (alerts.isEmpty) {
                  return const _AlertEmptyCard();
                }
                return Column(
                    children: alerts
                        .map((alert) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AlertCard(
                                title: alert['title']?.toString() ?? 'Cảnh báo',
                                message: alert['message']?.toString() ?? '',
                              ),
                            ))
                        .toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientOverviewHero extends StatelessWidget {
  final String name;
  final double completion;
  final String sessionCount;

  const _PatientOverviewHero({
    required this.name,
    required this.completion,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, const Color(0xFF18A6A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(children: [
        Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .20),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Image.asset(
            'assets/images/gen_assets/asset_patient_profile_card.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đang đồng hành cùng',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .82),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(children: [
                _HeroBadge(
                    icon: Icons.check_circle_outline_rounded,
                    text: '$sessionCount phiên'),
                const SizedBox(width: 7),
                _HeroBadge(
                    icon: Icons.trending_up_rounded,
                    text: '${(completion * 100).round()}% tuần này'),
              ]),
            ],
          ),
        ),
        Image.asset('assets/images/gen_assets/asset_progress.png',
            width: 55, height: 55, fit: BoxFit.contain),
      ]),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

class _ProgressOverviewCard extends StatelessWidget {
  final double completion;
  final String sessions;
  final String repetitions;
  final String minutes;

  const _ProgressOverviewCard({
    required this.completion,
    required this.sessions,
    required this.repetitions,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OverviewSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tiến độ tuần này',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Duy trì đều đặn để phục hồi tốt hơn',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
          SizedBox(
            width: 66,
            height: 66,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: completion,
                strokeWidth: 7,
                backgroundColor: scheme.primaryContainer,
                color: scheme.primary,
              ),
              Text('${(completion * 100).round()}%',
                  style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          _ColorMetric(
              icon: Icons.calendar_today_rounded,
              label: 'Phiên tập',
              value: sessions,
              color: const Color(0xFF6A5AE0)),
          _ColorMetric(
              icon: Icons.repeat_rounded,
              label: 'Số lần',
              value: repetitions,
              color: const Color(0xFFEC8B3A)),
          _ColorMetric(
              icon: Icons.timer_outlined,
              label: 'Thời gian',
              value: minutes,
              color: const Color(0xFF18A6A8)),
        ]),
      ]),
    );
  }
}

class _ColorMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ColorMetric(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 7),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 7),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 17, fontWeight: FontWeight.w900)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}

class _SessionHistoryCard extends StatelessWidget {
  final String? exerciseCode;
  final int repetitions;
  final String duration;
  final String date;
  const _SessionHistoryCard({
    required this.exerciseCode,
    required this.repetitions,
    required this.duration,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OverviewSurface(
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(17)),
          child: Image.asset(_exerciseAsset(exerciseCode), fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_exerciseLabel(exerciseCode),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('$repetitions lần · $duration',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 2),
            Text(date,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
          ]),
        ),
        const Icon(Icons.check_circle_rounded, color: Color(0xFF35B979)),
      ]),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String message;
  const _AlertCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return _OverviewSurface(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.warning_amber_rounded, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(message),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _AlertEmptyCard extends StatelessWidget {
  const _AlertEmptyCard();

  @override
  Widget build(BuildContext context) => _OverviewSurface(
        child: Row(children: [
          Image.asset('assets/images/ic_heart_circle.png',
              width: 48, height: 48),
          const SizedBox(width: 12),
          const Expanded(
              child: Text('Chưa có cảnh báo nào. Mọi thứ đang ổn định.')),
        ]),
      );
}

String _exerciseAsset(String? code) {
  const base = 'assets/images/gen_assets/';
  return switch (code) {
    'walk' => '${base}exercise_walk.png',
    'raise_left_leg' => '${base}exercise_raise_left_leg.png',
    'raise_right_leg' => '${base}exercise_raise_right_leg.png',
    'kick_left_leg' => '${base}exercise_kick_left_leg.png',
    'kick_right_leg' => '${base}exercise_kick_right_leg.png',
    'kick_left_knee' => '${base}exercise_kick_left_knee.png',
    'kick_right_knee' => '${base}exercise_kick_right_knee.png',
    'sit_to_stand' => '${base}exercise_sit_to_stand.png',
    _ => '${base}asset_exercises.png',
  };
}

String _durationLabel(int seconds) {
  if (seconds < 60) return '${seconds}s';
  return '${seconds ~/ 60} phút ${seconds % 60}s';
}

String _dateLabel(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (parsed == null) return 'Không rõ thời gian';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.hour)}:${two(parsed.minute)} · ${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
}

String _exerciseLabel(String? code) {
  return switch (code) {
    'walk' => 'Bước chân luân phiên',
    'raise_left_leg' => 'Nâng đùi trái',
    'raise_right_leg' => 'Nâng đùi phải',
    'kick_left_leg' => 'Đá chân trái',
    'kick_right_leg' => 'Đá chân phải',
    'kick_left_knee' => 'Đá gối trái',
    'kick_right_knee' => 'Đá gối phải',
    'sit_to_stand' => 'Đứng lên – ngồi xuống',
    _ => code?.isNotEmpty == true ? code! : 'Bài tập',
  };
}

class _OverviewSurface extends StatelessWidget {
  final Widget child;
  const _OverviewSurface({required this.child});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ]));
}

class _OverviewLoading extends StatelessWidget {
  const _OverviewLoading();

  @override
  Widget build(BuildContext context) => const _OverviewSurface(
      child: SizedBox(
          height: 150, child: Center(child: CircularProgressIndicator())));
}

class _CareSurface extends StatelessWidget {
  final Widget child;
  const _CareSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
