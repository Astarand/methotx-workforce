import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class HolidayListSheet extends StatefulWidget {
  final List<Map<String, dynamic>> holidays;

  const HolidayListSheet({
    super.key,
    required this.holidays,
  });

  static void show(BuildContext context, List<Map<String, dynamic>> holidays) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => HolidayListSheet(holidays: holidays),
    );
  }

  @override
  State<HolidayListSheet> createState() => _HolidayListSheetState();
}

class _HolidayListSheetState extends State<HolidayListSheet> {
  String selectedFilter = 'All';

  List<Map<String, dynamic>> get filteredHolidays {
    if (selectedFilter == 'All') return widget.holidays;
    if (selectedFilter == 'National') {
      return widget.holidays
          .where((h) => (h['type']?.toString().toLowerCase() ?? '')
              .contains('national'))
          .toList();
    }
    if (selectedFilter == 'Festival') {
      return widget.holidays
          .where((h) => (h['type']?.toString().toLowerCase() ?? '')
              .contains('festival'))
          .toList();
    }
    return widget.holidays
        .where((h) =>
            !(h['type']?.toString().toLowerCase() ?? '').contains('national') &&
            !(h['type']?.toString().toLowerCase() ?? '').contains('festival'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // 🔴 ELEGANT EMPTY STATE FOR 0 HOLIDAYS FROM SERVER
    if (widget.holidays.isEmpty) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Title + Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Company Holiday List',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            Expanded(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.beach_access_rounded,
                          size: 36,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No Holidays Configured',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No company holidays have been scheduled for this year yet.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final allCount = widget.holidays.length;
    final nationalCount = widget.holidays
        .where((h) =>
            (h['type']?.toString().toLowerCase() ?? '').contains('national'))
        .length;
    final festivalCount = widget.holidays
        .where((h) =>
            (h['type']?.toString().toLowerCase() ?? '').contains('festival'))
        .length;
    final companyCount = allCount - (nationalCount + festivalCount);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Modal Title + Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Company Holiday List',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 🔴 HORIZONTAL FILTER CHIPS TAB BAR
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All', 'All ($allCount)'),
                _buildFilterChip('National', 'National ($nationalCount)'),
                _buildFilterChip('Festival', 'Festival ($festivalCount)'),
                _buildFilterChip('Company', 'Company ($companyCount)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Holiday Items List
          Expanded(
            child: filteredHolidays.isEmpty
                ? Center(
                    child: Text(
                      'No holidays found in this category',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredHolidays.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final h = filteredHolidays[index];
                      return _buildHolidayItemCard(h);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: GoogleFonts.inter(
            color:
                isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFE0F2FE),
        backgroundColor: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color:
                isSelected ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
          ),
        ),
        onSelected: (_) => setState(() => selectedFilter = key),
      ),
    );
  }

  Widget _buildHolidayItemCard(Map<String, dynamic> h) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.holidayContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.beach_access,
              color: AppColors.holidayBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h['name']?.toString() ??
                      h['holidayName']?.toString() ??
                      h['holiday_name']?.toString() ??
                      '',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${h['date'] ?? h['holidayDate'] ?? h['holiday_date'] ?? ''} • ${h['day'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              h['type']?.toString() ??
                  h['holidayType']?.toString() ??
                  h['holiday_type']?.toString() ??
                  'Holiday',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF0284C7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
