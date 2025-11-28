import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:b_go/pages/bus_reserve/bus_reserve_pages/bus_listing.dart';

class BusCalendarPage extends StatefulWidget {
  const BusCalendarPage({Key? key}) : super(key: key);

  @override
  State<BusCalendarPage> createState() => _BusCalendarPageState();
}

class _BusCalendarPageState extends State<BusCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, int> _busCountByDay = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusAvailability();
  }

  Future<void> _loadBusAvailability() async {
    setState(() => _isLoading = true);
    
    try {
      final buses = await ReservationService.getAllConductorsAsBuses();
      final Map<String, int> countByDay = {
        'Monday': 0,
        'Tuesday': 0,
        'Wednesday': 0,
        'Thursday': 0,
        'Friday': 0,
        'Saturday': 0,
        'Sunday': 0,
      };

      // Count buses that are available (not reserved) for each day
      for (var bus in buses) {
        final conductor = bus['conductorData'] as Map<String, dynamic>?;
        
        // Only count buses that are available (not already reserved/pending/unavailable)
        if (conductor != null) {
          final busStatus = ReservationService.getBusAvailabilityStatus(conductor);
          // Skip buses that are already reserved, pending, or unavailable
          if (busStatus != 'available') {
            continue;
          }
        }
        
        final codingDays = List<String>.from(bus['codingDays'] ?? []);
        for (var day in codingDays) {
          if (countByDay.containsKey(day)) {
            countByDay[day] = countByDay[day]! + 1;
          }
        }
      }

      setState(() {
        _busCountByDay = countByDay;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bus availability: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getWeekdayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  int _getBusCountForDate(DateTime date) {
    final weekday = _getWeekdayName(date);
    return _busCountByDay[weekday] ?? 0;
  }

  bool _isDaySelectable(DateTime date) {
    // Only allow future dates and today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    
    if (checkDate.isBefore(today)) {
      return false;
    }

    return _getBusCountForDate(date) > 0;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!_isDaySelectable(selectedDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No buses available on this day',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _confirmSelection() {
    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a date',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    final weekday = _getWeekdayName(_selectedDay!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusListingByDay(
          selectedDate: _selectedDay!,
          selectedWeekday: weekday,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    final titleFontSize = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    final subtitleFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    final buttonHeight = isMobile ? 50.0 : isTablet ? 55.0 : 60.0;
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select Reservation Date',
          style: GoogleFonts.outfit(
            fontSize: titleFontSize,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0091AD),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16),
                          
                          // Info card
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFF0091AD).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFF0091AD).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF0091AD),
                                  size: isMobile ? 24 : 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Select a date to view available buses for that day',
                                    style: GoogleFonts.outfit(
                                      fontSize: subtitleFontSize,
                                      color: Color(0xFF0091AD),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 24),
                          
                          // Calendar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TableCalendar(
                              firstDay: DateTime.now(),
                              lastDay: DateTime.now().add(Duration(days: 365)),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                              onDaySelected: _onDaySelected,
                              calendarFormat: CalendarFormat.month,
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              calendarStyle: CalendarStyle(
                                selectedDecoration: BoxDecoration(
                                  color: Color(0xFF0091AD),
                                  shape: BoxShape.circle,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: Color(0xFF0091AD).withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                disabledDecoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                outsideDecoration: BoxDecoration(
                                  color: Colors.transparent,
                                ),
                                defaultTextStyle: GoogleFonts.outfit(
                                  color: Colors.black87,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                                weekendTextStyle: GoogleFonts.outfit(
                                  color: Colors.black87,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                                disabledTextStyle: GoogleFonts.outfit(
                                  color: Colors.grey.shade400,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                                selectedTextStyle: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                todayTextStyle: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              headerStyle: HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: GoogleFonts.outfit(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0091AD),
                                ),
                                leftChevronIcon: Icon(
                                  Icons.chevron_left,
                                  color: Color(0xFF0091AD),
                                ),
                                rightChevronIcon: Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF0091AD),
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: GoogleFonts.outfit(
                                  fontSize: isMobile ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                weekendStyle: GoogleFonts.outfit(
                                  fontSize: isMobile ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              enabledDayPredicate: _isDaySelectable,
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  final busCount = _getBusCountForDate(day);
                                  final isSelectable = _isDaySelectable(day);
                                  
                                  return Container(
                                    margin: EdgeInsets.all(4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelectable
                                          ? Colors.white
                                          : Colors.grey.shade100,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${day.day}',
                                          style: GoogleFonts.outfit(
                                            color: isSelectable
                                                ? Colors.black87
                                                : Colors.grey.shade400,
                                            fontSize: isMobile ? 14 : 16,
                                          ),
                                        ),
                                        if (isSelectable && busCount > 0)
                                          Container(
                                            margin: EdgeInsets.only(top: 2),
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Color(0xFF0091AD),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 24),
                          
                          // Legend
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Buses by Day',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 12),
                                ..._busCountByDay.entries.map((entry) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile ? 14 : 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: entry.value > 0
                                                ? Color(0xFF0091AD).withOpacity(0.2)
                                                : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${entry.value} ${entry.value == 1 ? 'bus' : 'buses'}',
                                            style: GoogleFonts.outfit(
                                              fontSize: isMobile ? 12 : 14,
                                              fontWeight: FontWeight.w600,
                                              color: entry.value > 0
                                                  ? Color(0xFF0091AD)
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Continue button
                SafeArea(
                  child: Container(
                    padding: EdgeInsets.all(horizontalPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedDay != null
                              ? Color(0xFF0091AD)
                              : Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _selectedDay != null ? _confirmSelection : null,
                        child: Text(
                          _selectedDay != null
                              ? 'Continue - ${DateFormat('EEE, MMM d, yyyy').format(_selectedDay!)}'
                              : 'Select a Date to Continue',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}