import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/certification.dart';

/// 식품·영양 관련 자격증/면허 정보 섹션.
class CertificationsScreen extends StatelessWidget {
  const CertificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final licenses =
        kCertifications.where((c) => c.kind == CertKind.license).toList();
    final tech = kCertifications
        .where((c) =>
            c.kind == CertKind.engineer || c.kind == CertKind.craftsman)
        .toList();
    final private =
        kCertifications.where((c) => c.kind == CertKind.private).toList();
    final international = kCertifications
        .where((c) => c.kind == CertKind.international)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'certs_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(context, 'certs_section_license'),
          ...licenses.map((c) => _CertCard(cert: c)),
          const SizedBox(height: 20),
          _sectionHeader(context, 'certs_section_tech'),
          ...tech.map((c) => _CertCard(cert: c)),
          if (private.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader(context, 'certs_section_private'),
            ...private.map((c) => _CertCard(cert: c)),
          ],
          if (international.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader(context, 'certs_section_international'),
            ...international.map((c) => _CertCard(cert: c)),
          ],
          const SizedBox(height: 16),
          _sourceNote(context),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String key) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(tr(context, key),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _sourceNote(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr(context, 'certs_source_note'),
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: Colors.grey.shade600)),
            ),
          ],
        ),
      );
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.cert});
  final Certification cert;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _CertDetailScreen(cert: cert))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cert.icon, color: Colors.grey.shade600, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cert.name,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(cert.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

}

class _CertDetailScreen extends StatelessWidget {
  const _CertDetailScreen({required this.cert});
  final Certification cert;

  Future<void> _openOfficial(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(cert.url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'cannot_open_link'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cert.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(cert.icon, color: Colors.grey.shade600, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cert.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(cert.tagline,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _field(context, 'cert_issuer', cert.issuer),
          _field(context, 'cert_eligibility', cert.eligibility),
          _subjectsField(context),
          _field(context, 'cert_method', cert.method),
          _field(context, 'cert_pass', cert.passCriteria),
          _field(context, 'cert_schedule', cert.schedule),
          if (cert.fee != null) _field(context, 'cert_fee', cert.fee!),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openOfficial(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brand500,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(tr(context, 'cert_official'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String key) => Text(
        tr(context, key),
        style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.brand600),
      );

  Widget _field(BuildContext context, String labelKey, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, labelKey),
            const SizedBox(height: 5),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, height: 1.55, color: Color(0xFF27272A))),
          ],
        ),
      );

  Widget _subjectsField(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, 'cert_subjects'),
            const SizedBox(height: 8),
            ...cert.subjects.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: AppTheme.brand500,
                            shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Color(0xFF27272A))),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
}
