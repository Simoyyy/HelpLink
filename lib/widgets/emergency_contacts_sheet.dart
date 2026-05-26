import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:helplink/utils/app_theme.dart';

// ── Malaysian state emergency contacts ────────────────────────────────────────

class _EmergencyContact {
  final String service;
  final String number;
  final IconData icon;
  final Color color;

  const _EmergencyContact({
    required this.service,
    required this.number,
    required this.icon,
    required this.color,
  });
}

class _StateContacts {
  final String state;
  final List<_EmergencyContact> contacts;
  const _StateContacts(this.state, this.contacts);
}

// National hotline fallback — always shown
const _national = [
  _EmergencyContact(
    service: 'Police (Emergency)',
    number: '999',
    icon: Icons.local_police_rounded,
    color: Color(0xFF1565C0),
  ),
  _EmergencyContact(
    service: 'Fire & Rescue (Bomba)',
    number: '994',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFD32F2F),
  ),
  _EmergencyContact(
    service: 'Ambulance / Medical',
    number: '999',
    icon: Icons.medical_services_rounded,
    color: Color(0xFF2E7D32),
  ),
  _EmergencyContact(
    service: 'Civil Defence (APM)',
    number: '991',
    icon: Icons.shield_rounded,
    color: Color(0xFF6A1B9A),
  ),
];

// State-level direct numbers (police HQ, bomba HQ, hospital emergency)
final _stateContacts = <String, _StateContacts>{
  'kuala lumpur': _StateContacts('Kuala Lumpur', [
    _EmergencyContact(service: 'KL Police Contingent HQ', number: '03-22662222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba KL', number: '03-22723333', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital KL Emergency', number: '03-26155555', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM KL', number: '03-22738122', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'putrajaya': _StateContacts('Putrajaya', [
    _EmergencyContact(service: 'Putrajaya Police', number: '03-88871222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Putrajaya', number: '03-88884444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Putrajaya Emergency', number: '03-88826000', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM', number: '991', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'selangor': _StateContacts('Selangor', [
    _EmergencyContact(service: 'Selangor Police Contingent', number: '03-55225522', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Selangor', number: '03-55104444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'HTAR Emergency', number: '03-33624333', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Selangor', number: '03-55102388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'johor': _StateContacts('Johor', [
    _EmergencyContact(service: 'Johor Police Contingent', number: '07-2202222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Johor Bahru', number: '07-2233333', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Sultanah Aminah Emergency', number: '07-2253000', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Johor', number: '07-2244333', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'penang': _StateContacts('Penang', [
    _EmergencyContact(service: 'Penang Police Contingent', number: '04-2222222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Penang', number: '04-2810444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Pulau Pinang Emergency', number: '04-2225333', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Penang', number: '04-2613388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'perak': _StateContacts('Perak', [
    _EmergencyContact(service: 'Perak Police Contingent', number: '05-2533333', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Ipoh', number: '05-5454444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Raja Permaisuri Bainun Emergency', number: '05-2082333', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Perak', number: '05-2413188', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'negeri sembilan': _StateContacts('Negeri Sembilan', [
    _EmergencyContact(service: 'N. Sembilan Police Contingent', number: '06-7622222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Seremban', number: '06-7623333', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Tuanku Ja\'afar Emergency', number: '06-7688000', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM N. Sembilan', number: '06-7624388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'melaka': _StateContacts('Melaka', [
    _EmergencyContact(service: 'Melaka Police Contingent', number: '06-2822222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Melaka', number: '06-2823444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Melaka Emergency', number: '06-2892344', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Melaka', number: '06-2842388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'pahang': _StateContacts('Pahang', [
    _EmergencyContact(service: 'Pahang Police Contingent', number: '09-5512222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Kuantan', number: '09-5133444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Tengku Ampuan Afzan Emergency', number: '09-5572222', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Pahang', number: '09-5156388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'terengganu': _StateContacts('Terengganu', [
    _EmergencyContact(service: 'Terengganu Police Contingent', number: '09-6222222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Kuala Terengganu', number: '09-6234444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Sultanah Nur Zahirah Emergency', number: '09-6212222', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Terengganu', number: '09-6237388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'kelantan': _StateContacts('Kelantan', [
    _EmergencyContact(service: 'Kelantan Police Contingent', number: '09-7482222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Kota Bharu', number: '09-7433444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Raja Perempuan Zainab II Emergency', number: '09-7452000', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Kelantan', number: '09-7488388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'kedah': _StateContacts('Kedah', [
    _EmergencyContact(service: 'Kedah Police Contingent', number: '04-7332222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Alor Setar', number: '04-7314444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Sultan Abdul Halim Emergency', number: '04-7402000', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Kedah', number: '04-7744988', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'perlis': _StateContacts('Perlis', [
    _EmergencyContact(service: 'Perlis Police Contingent', number: '04-9762222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Kangar', number: '04-9763444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Tuanku Fauziah Emergency', number: '04-9762333', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Perlis', number: '04-9768388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'sabah': _StateContacts('Sabah', [
    _EmergencyContact(service: 'Sabah Police Contingent', number: '088-217222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Kota Kinabalu', number: '088-218444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Queen Elizabeth Emergency', number: '088-518000', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Sabah', number: '088-233388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'sarawak': _StateContacts('Sarawak', [
    _EmergencyContact(service: 'Sarawak Police Contingent', number: '082-245522', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Kuching', number: '082-246444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Umum Sarawak Emergency', number: '082-276666', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Sarawak', number: '082-441388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
  'labuan': _StateContacts('Labuan', [
    _EmergencyContact(service: 'Labuan Police', number: '087-408222', icon: Icons.local_police_rounded, color: Color(0xFF1565C0)),
    _EmergencyContact(service: 'Bomba Labuan', number: '087-408444', icon: Icons.local_fire_department_rounded, color: Color(0xFFD32F2F)),
    _EmergencyContact(service: 'Hospital Labuan Emergency', number: '087-422322', icon: Icons.medical_services_rounded, color: Color(0xFF2E7D32)),
    _EmergencyContact(service: 'Civil Defence APM Labuan', number: '087-416388', icon: Icons.shield_rounded, color: Color(0xFF6A1B9A)),
  ]),
};

// ── State detector ────────────────────────────────────────────────────────────

_StateContacts? _detectState(String? location) {
  if (location == null || location.isEmpty) return null;
  final lower = location.toLowerCase();
  for (final key in _stateContacts.keys) {
    if (lower.contains(key)) return _stateContacts[key];
  }
  return null;
}

// ── Public entry point ────────────────────────────────────────────────────────

Future<void> showEmergencyContactsSheet(
  BuildContext context, {
  String? userLocation,
  VoidCallback? onGetHelp,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _EmergencySheet(userLocation: userLocation, onGetHelp: onGetHelp),
  );
}

// ── Sheet widget ─────────────────────────────────────────────────────────────

class _EmergencySheet extends StatelessWidget {
  final String? userLocation;
  final VoidCallback? onGetHelp;
  const _EmergencySheet({this.userLocation, this.onGetHelp});

  Future<void> _call(BuildContext context, String number) async {
    final clean = number.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch dialler for $number'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detected = _detectState(userLocation);
    final contacts = detected?.contacts ?? _national;
    final stateName = detected?.state ?? 'Malaysia';
    final isNational = detected == null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Red header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.crisis_alert_rounded,
                        color: AppTheme.errorRed, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Emergency Contacts',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark)),
                        Text(
                          isNational
                              ? 'National hotlines — enable location for local numbers'
                              : 'Local numbers for $stateName',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Disaster relief description ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppTheme.errorRed),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Use this only for urgent situations such as natural disaster relief, '
                        'medical emergencies, or immediate safety threats.',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // ── Contact cards ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: contacts
                    .map((c) => _ContactTile(
                          contact: c,
                          onCall: () => _call(context, c.number),
                        ))
                    .toList(),
              ),
            ),

            // ── National hotline note (shown only when state-specific) ──
            if (!isNational)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                            children: [
                              TextSpan(text: 'Universal emergency: '),
                              TextSpan(
                                  text: '999',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.errorRed)),
                              TextSpan(text: '  •  Fire & Rescue: '),
                              TextSpan(
                                  text: '994',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD32F2F))),
                              TextSpan(text: '  •  Civil Defence: '),
                              TextSpan(
                                  text: '991',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6A1B9A))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ── Get Help Now button (disaster relief request) ──
            if (onGetHelp != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onGetHelp!();
                    },
                    icon: const Icon(Icons.volunteer_activism_rounded),
                    label: const Text('Get Help Now',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),

            // ── Close button ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: const Text('Close',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contact tile ──────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final _EmergencyContact contact;
  final VoidCallback onCall;
  const _ContactTile({required this.contact, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: contact.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: contact.color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(contact.icon, color: contact.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.service,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark)),
                  Text(contact.number,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: contact.color,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onCall,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: contact.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    const Text('Call',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
