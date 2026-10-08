import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_starter/data/sources/network/network.dart';
import 'package:flutter_starter/di.dart';
import 'package:flutter_starter/services/ble/exo_ble_protocol.dart';
import 'package:flutter_starter/services/ble/exo_ble_service.dart';

class MotionRoutineLibraryPage extends StatefulWidget {
  final String patientId;

  const MotionRoutineLibraryPage({super.key, required this.patientId});

  @override
  State<MotionRoutineLibraryPage> createState() =>
      _MotionRoutineLibraryPageState();
}

class _MotionRoutineLibraryPageState extends State<MotionRoutineLibraryPage> {
  final _ble = ExoBleService.shared;
  late Future<List<Map<String, dynamic>>> _routines;
  StreamSubscription<ExerciseDeviceStatus>? _statusSubscription;
  String? _activeSession;
  String? _activeRoutineId;
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _statusSubscription = _ble.status.listen((event) {
      if (!mounted || event.sessionId != _activeSession) return;
      setState(() {
        _status = switch (event.state) {
          'preparing' || 'home_ready' => 'Đang đưa chân về HOME',
          'running' => 'Đang chạy quy trình',
          'flexing' => 'Đang co / nâng',
          'extending' => 'Đang duỗi / hạ',
          'stopping' => 'Đang dừng và về HOME',
          'completed' => 'Đã hoàn thành và về HOME',
          'stopped' => 'Đã dừng và về HOME',
          'rejected' || 'not_ready' => event.reason ?? 'Thiết bị từ chối',
          _ => event.state,
        };
        if (event.state == 'completed' ||
            event.state == 'stopped' ||
            event.state == 'rejected' ||
            event.state == 'not_ready') {
          _activeSession = null;
          _activeRoutineId = null;
          _busy = false;
        }
      });
    });
  }

  void _reload() {
    _routines =
        provider.get<NetworkDataSource>().getMotionRoutines(widget.patientId);
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MotionBuilderPage(patientId: widget.patientId),
      ),
    );
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _start(Map<String, dynamic> routine) async {
    if (_busy) return;
    final routineId = '${routine['id']}';
    final sessionId =
        'routine-${DateTime.now().millisecondsSinceEpoch}-$routineId';
    setState(() {
      _busy = true;
      _activeSession = sessionId;
      _activeRoutineId = routineId;
      _status = 'Đang tải quy trình an toàn';
    });
    try {
      final payload =
          await provider.get<NetworkDataSource>().dispatchMotionRoutine(
                patientId: widget.patientId,
                routineId: routineId,
              );
      await _ble.sendRoutine(
        payload.map((key, value) => MapEntry(key, value as Object?)),
        sessionId: sessionId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _activeSession = null;
        _activeRoutineId = null;
        _status = 'Không chạy được: $error';
      });
    }
  }

  Future<void> _stop() async {
    final session = _activeSession;
    if (session == null) return;
    setState(() {
      _busy = true;
      _status = 'Đang dừng và đưa chân về HOME';
    });
    try {
      await _ble.stopRoutine(sessionId: session);
    } catch (error) {
      if (mounted) setState(() => _status = 'Không dừng được: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bài tập cá nhân')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo bài mới'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _routines,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? FilledButton(
                      onPressed: () => setState(_reload),
                      child: const Text('Thử lại'),
                    )
                  : const CircularProgressIndicator(),
            );
          }
          final routines = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_status),
                ),
              if (routines.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('Chưa có bài tập cá nhân.')),
                ),
              for (final routine in routines) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.account_tree_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${routine['name']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text('${routine['repetitions']} lần',
                                style:
                                    TextStyle(color: colors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (_activeRoutineId == '${routine['id']}')
                        FilledButton.tonalIcon(
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Dừng'),
                        )
                      else
                        IconButton.filled(
                          onPressed: _busy ? null : () => _start(routine),
                          tooltip: 'Bắt đầu',
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Motion builder UI. The server remains the source of truth for allowed
/// movements; this page only presents safe, theme-aligned choices.
class MotionBuilderPage extends StatefulWidget {
  final String patientId;

  const MotionBuilderPage({super.key, required this.patientId});

  @override
  State<MotionBuilderPage> createState() => _MotionBuilderPageState();
}

class _MotionBuilderPageState extends State<MotionBuilderPage> {
  late Future<List<Map<String, dynamic>>> _library;
  final _name = TextEditingController(text: 'Bài tập cá nhân');
  final _repetitions = TextEditingController(text: '1');
  final _steps = <Map<String, dynamic>>[];
  String _executionMode = 'ONE_LEG';
  String _startingSide = 'RIGHT';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _library = provider.get<NetworkDataSource>().getMotionLibrary();
  }

  @override
  void dispose() {
    _name.dispose();
    _repetitions.dispose();
    super.dispose();
  }

  bool _allowed(Map<String, dynamic> item) {
    final state = <String, String>{
      'C1': 'IN',
      'C2': 'IN',
      'C3': 'IN',
      'C4': 'IN'
    };
    for (final step in _steps) {
      if (step['direction'] != 'STOP') {
        state[step['motor'] as String] = step['direction'] as String;
      }
    }
    final motor = item['motor'] as String;
    final itemSide = motor == 'C1' || motor == 'C2' ? 'RIGHT' : 'LEFT';
    // For both modes the user designs one complete leg flow. In two-leg mode
    // the server mirrors C1→C3 and C2→C4 after this flow returns HOME.
    if (itemSide != _startingSide) return false;
    return state[motor] != item['direction'];
  }

  List<Map<String, dynamic>> _available(List<Map<String, dynamic>> library) =>
      library.where(_allowed).toList(growable: false);

  String _sideLabel(String side) => side == 'RIGHT' ? 'Chân phải' : 'Chân trái';

  String _durationLabel(Object? value) {
    final seconds = ((value as num?)?.toDouble() ?? 0) / 1000;
    return seconds == seconds.roundToDouble()
        ? '${seconds.round()} giây'
        : '${seconds.toStringAsFixed(1)} giây';
  }

  int get _totalDurationMs => _steps.fold<int>(
        0,
        (total, step) =>
            total +
            ((step['duration_ms'] as num?)?.toInt() ?? 0) +
            ((step['rest_after_ms'] as num?)?.toInt() ?? 0),
      );

  String get _totalDurationLabel {
    final seconds = (_totalDurationMs / 1000).ceil();
    if (seconds < 60) return '$seconds giây';
    return '${seconds ~/ 60} phút ${seconds % 60} giây';
  }

  IconData _stepIcon(Map<String, dynamic> step) =>
      '${step['label']}'.toLowerCase().contains('gối')
          ? Icons.directions_walk_rounded
          : Icons.accessibility_new_rounded;

  void _resetFlow() => setState(() => _steps.clear());

  Future<void> _pickMovement(List<Map<String, dynamic>> library) async {
    final choices = _available(library);
    if (choices.isEmpty) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MovementPicker(
        choices: choices,
        sideLabel: _sideLabel,
        durationLabel: _durationLabel,
        stepIcon: _stepIcon,
        onSelected: (item) => Navigator.of(context).pop(item),
      ),
    );
    if (selected == null) return;
    setState(() {
      _steps.add({
        'label': selected['label'],
        'motor': selected['motor'],
        'direction': selected['direction'],
        'duration_ms': selected['duration_ms'],
        'rest_after_ms': selected['default_rest_after_ms'],
        'repeat_count': 1
      });
    });
  }

  Future<void> _save() async {
    if (_steps.isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await provider.get<NetworkDataSource>().createMotionRoutine(
            patientId: widget.patientId,
            name: _name.text.trim(),
            repetitions: int.tryParse(_repetitions.text) ?? 1,
            executionMode: _executionMode,
            startingSide: _startingSide,
            steps: _steps,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể lưu quy trình: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Tạo bài tập riêng'),
        actions: [
          if (_steps.isNotEmpty)
            IconButton(
                tooltip: 'Làm lại',
                onPressed: _resetFlow,
                icon: const Icon(Icons.restart_alt_rounded))
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _library,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Không tải được danh sách động tác.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final library = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _BuilderIntro(
                mode: _executionMode == 'ONE_LEG'
                    ? 'Một chân'
                    : 'Hai chân xen kẽ',
                side: _sideLabel(_startingSide),
                stepCount: _steps.length,
                duration: _totalDurationLabel,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                number: '1',
                title: 'Đặt tên bài tập',
                helper: 'Để người tập dễ nhận biết khi bắt đầu.',
                icon: Icons.edit_note_rounded,
                child: Column(children: [
                  _BuilderTextField(
                    controller: _name,
                    label: 'Tên bài tập',
                    hint: 'Ví dụ: Bài tập buổi sáng',
                    icon: Icons.title_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _BuilderTextField(
                    controller: _repetitions,
                    label: 'Số vòng lặp',
                    hint: 'Nhập số lần thực hiện',
                    icon: Icons.repeat_rounded,
                    suffix: 'vòng',
                    keyboardType: TextInputType.number,
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                number: '2',
                title: 'Chọn phạm vi vận động',
                helper: 'Hệ thống sẽ tự khóa các lựa chọn không an toàn.',
                icon: Icons.tune_rounded,
                child: _ChoiceRow(
                  selected: _executionMode,
                  choices: const [
                    _ChoiceItem(
                        value: 'ONE_LEG',
                        title: '1 chân',
                        subtitle: 'Tập một bên',
                        icon: Icons.directions_walk_rounded),
                    _ChoiceItem(
                        value: 'TWO_LEG_ALTERNATING',
                        title: '2 chân',
                        subtitle: 'Xen kẽ hai bên',
                        icon: Icons.compare_arrows_rounded),
                  ],
                  onChanged: (value) => setState(() {
                    _executionMode = value;
                    _resetFlow();
                  }),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                number: '3',
                title: _executionMode == 'TWO_LEG_ALTERNATING'
                    ? 'Chân bắt đầu'
                    : 'Chân thực hiện',
                helper: _executionMode == 'TWO_LEG_ALTERNATING'
                    ? 'Các bước sẽ được luân phiên trái – phải.'
                    : 'Chỉ hiển thị động tác của chân đã chọn.',
                icon: Icons.accessibility_new_rounded,
                child: _ChoiceRow(
                  selected: _startingSide,
                  choices: const [
                    _ChoiceItem(
                        value: 'RIGHT',
                        title: 'Chân phải',
                        subtitle: 'C1 • C2',
                        icon: Icons.chevron_right_rounded),
                    _ChoiceItem(
                        value: 'LEFT',
                        title: 'Chân trái',
                        subtitle: 'C3 • C4',
                        icon: Icons.chevron_left_rounded),
                  ],
                  onChanged: (value) => setState(() {
                    _startingSide = value;
                    _resetFlow();
                  }),
                ),
              ),
              const SizedBox(height: 12),
              _RuleBanner(mode: _executionMode, side: _startingSide),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('4. Xây dựng trình tự',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Text('${_steps.length} bước',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Chạm vào từng ô để tạo chuỗi vận động theo mong muốn.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 10),
              if (_steps.isEmpty)
                _EmptyFlowCard(onAdd: () => _pickMovement(library))
              else ...[
                for (var i = 0; i < _steps.length; i++)
                  _StepCard(
                      index: i,
                      step: _steps[i],
                      durationLabel: _durationLabel(_steps[i]['duration_ms']),
                      onDelete: () => setState(() => _steps.removeAt(i))),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: () => _pickMovement(library),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm bước tiếp theo')),
              ],
              const SizedBox(height: 16),
              _HomeNotice(colors: colors),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                  onPressed: _saving || _steps.isEmpty ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu bài tập')))),
    );
  }
}

class _BuilderIntro extends StatelessWidget {
  final String mode;
  final String side;
  final int stepCount;
  final String duration;
  const _BuilderIntro(
      {required this.mode,
      required this.side,
      required this.stepCount,
      required this.duration});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primaryContainer, colors.secondaryContainer]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 25,
              backgroundColor: colors.primary,
              child: Icon(Icons.auto_awesome_rounded, color: colors.onPrimary)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Tạo bài tập riêng',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer)),
                const SizedBox(height: 3),
                Text('Thiết kế theo khả năng của từng người tập',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colors.onPrimaryContainer)),
              ])),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _HeroBadge(icon: Icons.accessibility_new_rounded, label: mode),
          _HeroBadge(icon: Icons.swap_horiz_rounded, label: side),
          _HeroBadge(
              icon: Icons.format_list_numbered_rounded,
              label: '$stepCount bước'),
          if (stepCount > 0)
            _HeroBadge(icon: Icons.schedule_rounded, label: duration),
        ]),
      ]),
    );
  }
}

class _BuilderTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  const _BuilderTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = Color.alphaBlend(
        colors.primary.withValues(alpha: .035), colors.surface);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixText: suffix,
          filled: true,
          fillColor: fill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          border: border(Colors.transparent),
          enabledBorder: border(Colors.transparent),
          focusedBorder: border(colors.primary.withValues(alpha: .35), 1.5),
        ),
      ),
    ]);
  }
}

class _ChoiceItem {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  const _ChoiceItem(
      {required this.value,
      required this.title,
      required this.subtitle,
      required this.icon});
}

class _ChoiceRow extends StatelessWidget {
  final String selected;
  final List<_ChoiceItem> choices;
  final ValueChanged<String> onChanged;
  const _ChoiceRow(
      {required this.selected, required this.choices, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < choices.length; i++) ...[
            Expanded(
              child: _ChoiceTile(
                item: choices[i],
                selected: choices[i].value == selected,
                onTap: () => onChanged(choices[i].value),
              ),
            ),
            if (i != choices.length - 1) const SizedBox(width: 10),
          ],
        ],
      );
}

class _ChoiceTile extends StatelessWidget {
  final _ChoiceItem item;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceTile(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = selected ? colors.primaryContainer : colors.surface;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.5 : 1),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(item.icon,
                  color: selected ? colors.primary : colors.onSurfaceVariant),
              const Spacer(),
              Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: selected ? colors.primary : colors.outline),
            ]),
            const SizedBox(height: 8),
            Text(item.title,
                style:
                    TextStyle(color: foreground, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(item.subtitle,
                style: TextStyle(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: colors.primary),
        const SizedBox(width: 6),
        Text(label,
            style:
                TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface))
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? number;
  final String title;
  final String? helper;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {this.number,
      required this.title,
      this.helper,
      required this.icon,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (number != null) ...[
                  CircleAvatar(
                      radius: 15,
                      backgroundColor: colors.primaryContainer,
                      child: Text(number!,
                          style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w800))),
                  const SizedBox(width: 10),
                ] else ...[
                  Icon(icon, color: colors.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                    child: Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
              ]),
              if (helper != null)
                Padding(
                    padding: const EdgeInsets.only(left: 40, top: 4),
                    child: Text(helper!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant))),
              const SizedBox(height: 14),
              child,
            ])));
  }
}

class _RuleBanner extends StatelessWidget {
  final String mode;
  final String side;
  const _RuleBanner({required this.mode, required this.side});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = mode == 'TWO_LEG_ALTERNATING'
        ? 'Hãy tạo trọn flow cho chân $side. Hệ thống sẽ tự chạy flow đối xứng cho chân còn lại.'
        : 'Chỉ được chọn các động tác của ${side == 'RIGHT' ? 'chân phải' : 'chân trái'}. Khớp đã nâng sẽ không thể nâng tiếp.';
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: colors.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: colors.onTertiaryContainer)))
        ]));
  }
}

class _MovementPicker extends StatelessWidget {
  final List<Map<String, dynamic>> choices;
  final String Function(String) sideLabel;
  final String Function(Object?) durationLabel;
  final IconData Function(Map<String, dynamic>) stepIcon;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _MovementPicker({
    required this.choices,
    required this.sideLabel,
    required this.durationLabel,
    required this.stepIcon,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chọn một động tác',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                  'Các lựa chọn đang hiển thị đã phù hợp với khớp và chân bạn chọn.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .58),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: choices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = choices[index];
                    final direction =
                        item['direction'] == 'OUT' ? 'Nâng / co' : 'Hạ / duỗi';
                    final accent = item['direction'] == 'OUT'
                        ? colors.primary
                        : colors.tertiary;
                    return Material(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onSelected(item),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: accent.withValues(alpha: .13),
                                    borderRadius: BorderRadius.circular(15)),
                                child: Icon(stepIcon(item), color: accent)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${item['label']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(
                                      '$direction  •  ${durationLabel(item['duration_ms'])}  •  ${sideLabel('${item['side']}'.toUpperCase())}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: colors.onSurfaceVariant)),
                                ])),
                            Icon(Icons.add_circle_rounded, color: accent),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
      ),
    );
  }
}

class _EmptyFlowCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFlowCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant)),
        child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              Icon(Icons.account_tree_rounded,
                  size: 42, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text('Chưa có động tác nào',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Thêm từng bước để tạo trình tự riêng cho bạn.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Thêm động tác'))
            ])));
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> step;
  final String durationLabel;
  final VoidCallback onDelete;
  const _StepCard(
      {required this.index,
      required this.step,
      required this.durationLabel,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOut = step['direction'] == 'OUT';
    final accent = isOut ? colors.primary : colors.tertiary;
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant)),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 5, color: accent),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 6, 12),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 18,
                        backgroundColor: accent.withValues(alpha: .13),
                        child: Text('${index + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: accent))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('${step['label']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            _StepChip(
                                icon: isOut
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                label: isOut ? 'Nâng / co' : 'Hạ / duỗi',
                                color: accent),
                            _StepChip(
                                icon: Icons.schedule_rounded,
                                label: durationLabel,
                                color: colors.onSurfaceVariant),
                          ]),
                        ])),
                    IconButton(
                        onPressed: onDelete,
                        tooltip: 'Xóa bước',
                        icon: Icon(Icons.delete_outline_rounded,
                            color: colors.error)),
                  ]))),
        ]),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StepChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700))
        ]),
      );
}

class _HomeNotice extends StatelessWidget {
  final ColorScheme colors;
  const _HomeNotice({required this.colors});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.flag_rounded, color: colors.primary),
        const SizedBox(width: 10),
        const Expanded(
            child: Text(
                'Khi lưu, hệ thống sẽ tự thêm bước đưa các khớp đã dùng về vị trí ban đầu.'))
      ]));
}
