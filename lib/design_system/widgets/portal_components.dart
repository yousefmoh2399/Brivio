import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

class PortalDestination {
  final IconData icon;
  final String label;

  const PortalDestination({required this.icon, required this.label});
}

class PortalScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final int selectedIndex;
  final List<PortalDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onRefresh;
  final VoidCallback? onSignOut;

  const PortalScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.body,
    this.onRefresh,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final drawer = _PortalNavigation(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor,
      selectedIndex: selectedIndex,
      destinations: destinations,
      onDestinationSelected: (index) {
        onDestinationSelected(index);
        if (!isWide) Navigator.of(context).maybePop();
      },
      onSignOut: onSignOut,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Scaffold(
      drawer: isWide
          ? null
          : Drawer(
              width: 280,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: drawer,
            ),
      appBar: isWide
          ? null
          : AppBar(
              centerTitle: true,
              backgroundColor:
                  (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                      .withValues(alpha: 0.9),
              elevation: 0,
              scrolledUnderElevation: 0.5,
              title: Text(
                context.l10n.t(destinations[selectedIndex].label),
                style: AppTypography.titleMedium(
                  textPrimary,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
              actions: [
                if (onRefresh != null)
                  IconButton(
                    tooltip: context.tr('refresh'),
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
              ],
            ),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 270, child: drawer),
          if (isWide)
            VerticalDivider(
              width: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalNavigation extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final int selectedIndex;
  final List<PortalDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onSignOut;

  const _PortalNavigation({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SafeArea(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.t(title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium(
                            textPrimary,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          context.l10n.t(subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final item = destinations[index];
                  final selected = selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: selected
                          ? accentColor.withValues(alpha: .14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        selected: selected,
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(
                          item.icon,
                          size: 20,
                          color: selected ? accentColor : textSecondary,
                        ),
                        title: Text(
                          context.l10n.t(item.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.bodyMedium(
                                selected ? accentColor : textPrimary,
                              ).copyWith(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (onSignOut != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: onSignOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      context.tr('sign_out'),
                      style: AppTypography.labelLarge(
                        textPrimary,
                      ).copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PortalHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget? trailing;
  final Widget? leading;

  const PortalHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.trailing,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: isMobile ? 11 : 16,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          final headerInfo = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading ??
                  Container(
                    width: isMobile ? 36 : 44,
                    height: isMobile ? 36 : 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor.withValues(alpha: .25),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(icon, color: accentColor, size: isMobile ? 19 : 22),
                  ),
              SizedBox(width: isMobile ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.t(eyebrow).toUpperCase(),
                      style: TextStyle(
                        fontSize: isMobile ? 9.5 : 11,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.t(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 15.5 : 18.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      context.l10n.t(subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isMobile ? 10.5 : 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerInfo,
                if (trailing != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: trailing!,
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerInfo),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: trailing!,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class PortalMetricCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const PortalMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<PortalMetricCard> createState() => _PortalMetricCardState();
}

class _PortalMetricCardState extends State<PortalMetricCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _ctrl.reverse() : null,
      onTapUp: widget.onTap != null ? (_) => _ctrl.forward() : null,
      onTapCancel: widget.onTap != null ? () => _ctrl.forward() : null,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 17,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onTap != null)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 11,
                        color: widget.accentColor,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Value
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Label
              Text(
                context.l10n.t(widget.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PortalMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const PortalMetricGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final columns = width >= 1180
            ? 4
            : width >= 760
            ? 3
            : 2; // always 2 on mobile for cleaner look
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: isMobile ? 8 : 10,
          mainAxisSpacing: isMobile ? 8 : 10,
          mainAxisExtent: isMobile ? 98 : 120,
          children: children,
        );
      },
    );
  }
}

class PortalSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PortalSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.t(title),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            context.l10n.t(subtitle!),
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class PortalErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const PortalErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.errorSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.errorSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PortalAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const PortalAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
}

class PortalPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<PortalAction> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? eyebrow;
  final bool showBackButton;
  final List<Widget>? headerWidgets;
  final PreferredSizeWidget? pinnedBottom;
  final bool scrollableHeader;

  const PortalPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.actions = const [],
    this.padding = const EdgeInsets.all(20),
    this.eyebrow,
    this.showBackButton = true,
    this.headerWidgets,
    this.pinnedBottom,
    this.scrollableHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final canPop = showBackButton && Navigator.of(context).canPop();
    final primaryActions = actions.where((a) => a.primary).toList();
    final secondaryActions = actions.where((a) => !a.primary).toList();

    Widget buildAction(PortalAction action) {
      if (action.primary) {
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: isMobile ? 6 : 8,
            ),
            minimumSize: isMobile ? const Size(36, 32) : const Size(48, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: action.onPressed,
          icon: Icon(action.icon, size: isMobile ? 15 : 18),
          label: Text(
            context.l10n.t(action.label),
            style: TextStyle(
              fontSize: isMobile ? 11.5 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 9 : 12,
            vertical: isMobile ? 6 : 8,
          ),
          minimumSize: isMobile ? const Size(36, 32) : const Size(48, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: isMobile ? 15 : 18),
        label: Text(
          context.l10n.t(action.label),
          style: TextStyle(fontSize: isMobile ? 11.5 : 13),
        ),
      );
    }

    final effectiveEyebrow = eyebrow ?? 'منظومة بريفيو التعليمية';
    final effectivePadding = isMobile
        ? const EdgeInsets.fromLTRB(12, 10, 12, 14)
        : padding;

    final headerWidget = PortalHeader(
      eyebrow: effectiveEyebrow,
      title: title,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor,
      trailing: (canPop || actions.isNotEmpty)
          ? Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canPop)
                  IconButton.filledTonal(
                    tooltip: 'رجوع',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ...secondaryActions.map(buildAction),
                ...primaryActions.map(buildAction),
              ],
            )
          : null,
    );

    if (scrollableHeader) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SafeArea(
        child: Padding(
          padding: effectivePadding,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerWidget,
                    SizedBox(height: isMobile ? 10 : 16),
                    if (headerWidgets != null) ...[
                      ...headerWidgets!,
                      SizedBox(height: isMobile ? 10 : 16),
                    ],
                  ],
                ),
              ),
              if (pinnedBottom != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PortalPinnedBottomDelegate(
                    pinnedBottom!,
                    isDark: isDark,
                  ),
                ),
            ],
            body: child,
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: effectivePadding,
        child: Column(
          children: [
            headerWidget,
            SizedBox(height: isMobile ? 10 : 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _PortalPinnedBottomDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSizeWidget child;
  final bool isDark;

  _PortalPinnedBottomDelegate(this.child, {required this.isDark});

  @override
  double get minExtent => child.preferredSize.height;

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PortalPinnedBottomDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.isDark != isDark;
  }
}

class PortalSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  const PortalSearchField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return TextField(
      controller: controller,
      style: TextStyle(fontSize: isMobile ? 12.5 : 14),
      decoration: InputDecoration(
        isDense: isMobile,
        contentPadding: isMobile
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : null,
        labelText: context.l10n.t(label),
        labelStyle: TextStyle(fontSize: isMobile ? 12 : 13.5),
        prefixIcon: Icon(Icons.search_rounded, size: isMobile ? 20 : 24),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.t('Clear search'),
                icon: Icon(Icons.close_rounded, size: isMobile ? 18 : 20),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
              ),
      ),
      onChanged: onChanged,
    );
  }
}

class PortalStateView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final VoidCallback onRetry;
  final Widget child;

  const PortalStateView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }
    if (errorMessage != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: PortalErrorBanner(message: errorMessage!, onRetry: onRetry),
        ),
      );
    }
    if (isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textPrimary = isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary;
      final textSecondary = isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;

      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(emptyIcon, size: 26, color: AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.t(emptyTitle),
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium(
                      textPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.t(emptySubtitle),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall(textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return child;
  }
}

class PortalListCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final List<Widget> trailing;
  final VoidCallback? onTap;

  const PortalListCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.trailing = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final leading = Container(
                width: isMobile ? 36 : 44,
                height: isMobile ? 36 : 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                ),
                child: Icon(icon, color: accentColor, size: isMobile ? 18 : 22),
              );
              final textBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.t(title),
                    maxLines: constraints.maxWidth < 460 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 12.5 : 14.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.t(subtitle),
                    maxLines: constraints.maxWidth < 460 ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 10.5 : 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 520 && trailing.isNotEmpty) {
                return Padding(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading,
                      SizedBox(width: isMobile ? 10 : 14),
                      Expanded(child: textBlock),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: context.tr('Actions'),
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (sheetContext) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: trailing,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final actions = Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: trailing,
              );

              return Padding(
                padding: EdgeInsets.all(isMobile ? 10 : 14),
                child: Row(
                  children: [
                    leading,
                    SizedBox(width: isMobile ? 10 : 14),
                    Expanded(child: textBlock),
                    if (trailing.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      actions,
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class PortalStatusChip extends StatelessWidget {
  final String status;

  const PortalStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (Color color, IconData icon) = switch (normalized) {
      'active' => (AppColors.success, Icons.check_circle_rounded),
      'paid' => (AppColors.success, Icons.check_circle_rounded),
      'published' => (AppColors.success, Icons.check_circle_rounded),
      'submitted' => (AppColors.success, Icons.upload_rounded),
      'graded' => (AppColors.primary, Icons.grade_rounded),
      'pending' => (AppColors.warning, Icons.schedule_rounded),
      'archived' => (AppColors.darkTextSecondary, Icons.archive_rounded),
      'suspended' => (AppColors.error, Icons.block_rounded),
      'rejected' => (AppColors.error, Icons.cancel_rounded),
      'failed' => (AppColors.error, Icons.close_rounded),
      _ => (AppColors.primary, Icons.info_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            context.l10n.t(status).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
