import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Site-wide credit line, shown in the footer of every screen.
///
/// Required by the task: "Built for Digital Heroes Training Task", linked to
/// digitalheroesco.com.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static final Uri _url = Uri.parse('https://digitalheroesco.com');

  Future<void> _open() async {
    await launchUrl(_url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                'Built for ',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              InkWell(
                onTap: _open,
                child: Text(
                  'Digital Heroes Training Task',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
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
