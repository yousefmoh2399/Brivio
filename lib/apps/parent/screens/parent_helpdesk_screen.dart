import 'package:flutter/material.dart';

import '../../../design_system/tokens/colors.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../features/helpdesk/data/repositories/helpdesk_repository.dart';
import '../tabs/parent_helpdesk_tab.dart';

export '../tabs/parent_helpdesk_tab.dart';

class ParentHelpdeskScreen extends StatelessWidget {
  final Student? child;
  final List<GroupEntity> childGroups;
  final HelpdeskRepository? repository;

  const ParentHelpdeskScreen({
    super.key,
    this.child,
    this.childGroups = const [],
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabWidget = ParentHelpdeskTab(
      child: child,
      childGroups: childGroups,
      repository: repository,
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: const Text(
            'الدعم الفني والشكاوى',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
              .withValues(alpha: 0.95),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'رجوع',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: tabWidget,
        ),
      );
    }

    return tabWidget;
  }
}
