import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/presenter/languages/translation_keys.g.dart';
import 'package:flutter_starter/presenter/navigation/navigation.dart';

@RoutePage()
class PatientShellPage extends StatelessWidget {
  const PatientShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [
        HomeRoute(),
        TrainingRoute(),
        ProgressRoute(),
        DeviceRoute(),
        ProfileRoute(),
      ],
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);

        return Scaffold(
          body: child,
          bottomNavigationBar: _PatientNavigationBar(
            selectedIndex: tabsRouter.activeIndex,
            onSelected: tabsRouter.setActiveIndex,
          ),
        );
      },
    );
  }
}

class _PatientNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PatientNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = [
    _PatientNavigationItem(
      assetPath: 'assets/images/ic_home.png',
      labelKey: LocaleKeys.Patient_Tabs_Today,
    ),
    _PatientNavigationItem(
      assetPath: 'assets/images/ic_calendar.png',
      labelKey: LocaleKeys.Patient_Tabs_Training,
    ),
    _PatientNavigationItem(
      assetPath: 'assets/images/ic_clock.png',
      labelKey: LocaleKeys.Patient_Tabs_Progress,
    ),
    _PatientNavigationItem(
      assetPath: 'assets/images/ic_fill_setting.png',
      labelKey: LocaleKeys.Patient_Tabs_Device,
    ),
    _PatientNavigationItem(
      assetPath: 'assets/images/ic_account.png',
      labelKey: LocaleKeys.Patient_Tabs_Profile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: Colors.white,
          elevation: 12,
          shadowColor: colorScheme.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: 78,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              children: [
                for (final entry in _items.indexed)
                  Expanded(
                    child: _PatientNavigationButton(
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

class _PatientNavigationButton extends StatelessWidget {
  final _PatientNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  const _PatientNavigationButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final label = item.labelKey.tr();

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ImageIcon(
                AssetImage(item.assetPath),
                color: foreground,
                size: selected ? 22 : 21,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
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

class _PatientNavigationItem {
  final String assetPath;
  final String labelKey;

  const _PatientNavigationItem({
    required this.assetPath,
    required this.labelKey,
  });
}
