import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:b_go/pages/bus_reserve/bus_reserve_pages/reservation_form.dart';

class BusListingByDay extends StatefulWidget {
  final DateTime selectedDate;
  final String selectedWeekday;

  const BusListingByDay({
    Key? key,
    required this.selectedDate,
    required this.selectedWeekday,
  }) : super(key: key);

  @override
  State<BusListingByDay> createState() => _BusListingByDayState();
}

class _BusListingByDayState extends State<BusListingByDay> {
  List<Map<String, dynamic>> _availableBuses = [];
  bool _isLoading = true;
  String _availabilityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAvailableBuses();
  }

  Future<void> _loadAvailableBuses() async {
    setState(() => _isLoading = true);

    try {
      final allBuses = await ReservationService.getAllConductorsAsBuses();

      print('Total buses fetched: ${allBuses.length}');
      print('Looking for weekday: ${widget.selectedWeekday}');

      // Filter buses by selected weekday
      final filteredBuses = allBuses.where((bus) {
        // Check for both singular and plural field names
        final codingDay = bus['codingDay'] as String?;
        final codingDays = bus['codingDays'];

        print(
            'Bus ${bus['busNumber']}: codingDay=$codingDay, codingDays=$codingDays');

        // Check if codingDay (singular) matches
        if (codingDay != null && codingDay == widget.selectedWeekday) {
          print('Match found for bus ${bus['busNumber']} with codingDay');
          return true;
        }

        // Check if codingDays (plural) contains the weekday
        if (codingDays != null) {
          final daysList = codingDays is List
              ? List<String>.from(codingDays)
              : [codingDays.toString()];

          if (daysList.contains(widget.selectedWeekday)) {
            print('Match found for bus ${bus['busNumber']} with codingDays');
            return true;
          }
        }

        return false;
      }).toList();

      print('Filtered buses count: ${filteredBuses.length}');

      setState(() {
        _availableBuses = filteredBuses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading buses: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredBuses() {
    if (_availabilityFilter == 'all') {
      return _availableBuses;
    }

    return _availableBuses.where((bus) {
      final conductor = bus['conductorData'] as Map<String, dynamic>?;

      if (conductor == null) {
        return _availabilityFilter == 'available';
      }

      final busAvailabilityStatus =
          ReservationService.getBusAvailabilityStatus(conductor);

      if (_availabilityFilter == 'available') {
        return busAvailabilityStatus == 'available';
      } else if (_availabilityFilter == 'unavailable') {
        return busAvailabilityStatus == 'unavailable' ||
            busAvailabilityStatus == 'pending';
      } else if (_availabilityFilter == 'reserved') {
        return busAvailabilityStatus == 'reserved';
      }

      return true;
    }).toList();
  }

  void _showBusDetails(Map<String, dynamic> bus) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final conductor = bus['conductorData'] as Map<String, dynamic>?;
    final busAvailabilityStatus = conductor != null
        ? ReservationService.getBusAvailabilityStatus(conductor)
        : 'available';

    bool isAvailable = busAvailabilityStatus == 'available';

    Color statusColor;
    String statusText;

    if (busAvailabilityStatus == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending Payment';
    } else if (busAvailabilityStatus == 'reserved') {
      statusColor = Colors.blue;
      statusText = 'Reserved (Verified)';
    } else if (busAvailabilityStatus == 'unavailable') {
      statusColor = Colors.red;
      statusText = 'Unavailable';
    } else {
      statusColor = Colors.green;
      statusText = 'Available';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      color: Color(0xFF0091AD),
                      size: isMobile ? 24 : 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Bus Details',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 20
                            : isTablet
                                ? 22
                                : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: isMobile ? 24 : 28),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (conductor?['busImageUrl'] != null)
                          Container(
                            margin: EdgeInsets.only(bottom: 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                conductor!['busImageUrl'],
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: Icon(
                                        Icons.directions_bus,
                                        size: 80,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF0091AD).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                'Bus Number',
                                'Bus #${conductor?['busNumber']?.toString() ?? bus['busNumber']?.toString() ?? 'N/A'}',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Plate Number',
                                conductor?['plateNumber'] ??
                                    bus['plateNumber'] ??
                                    'N/A',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Route',
                                conductor?['route'] ?? bus['route'] ?? 'N/A',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Driver',
                                conductor?['driverName'] ?? 'Unknown',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Conductor',
                                conductor?['name'] ?? 'Unknown',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Available Day',
                                bus['codingDay']?.toString() ??
                                    (bus['codingDays'] != null
                                        ? List<String>.from(bus['codingDays'])
                                            .join(', ')
                                        : 'N/A'),
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Price',
                                '₱${bus['Price'] ?? 'N/A'}',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Status',
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile
                                          ? 14
                                          : isTablet
                                              ? 16
                                              : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: statusColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: GoogleFonts.outfit(
                                        fontSize: isMobile
                                            ? 12
                                            : isTablet
                                                ? 14
                                                : 16,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: isMobile
                              ? 50
                              : isTablet
                                  ? 55
                                  : 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAvailable
                                  ? Color(0xFF0091AD)
                                  : Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isAvailable
                                ? () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReservationForm(
                                          selectedBusIds: [bus['id']],
                                          selectedDate: widget.selectedDate,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(
                              isAvailable
                                  ? 'Continue with Selected Bus'
                                  : 'Bus Not Available',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: isMobile
                                    ? 16
                                    : isTablet
                                        ? 18
                                        : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
      },
    );
  }

  Widget _buildDetailRow(
      String label, String value, bool isMobile, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: isMobile
                  ? 14
                  : isTablet
                      ? 16
                      : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: isMobile
                  ? 14
                  : isTablet
                      ? 16
                      : 18,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _availabilityFilter == value;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return GestureDetector(
      onTap: () {
        setState(() {
          _availabilityFilter = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12, vertical: isMobile ? 5 : 6),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: isMobile
                ? 12
                : isTablet
                    ? 14
                    : 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildConductorInfo(Map<String, dynamic> bus) {
    final conductor = bus['conductorData'] as Map<String, dynamic>?;

    if (conductor == null || conductor.isEmpty) {
      return Text(
        'No conductor data',
        style: GoogleFonts.outfit(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final busAvailabilityStatus =
        ReservationService.getBusAvailabilityStatus(conductor);

    Color statusColor;
    String statusText;

    if (busAvailabilityStatus == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending Payment';
    } else if (busAvailabilityStatus == 'reserved') {
      statusColor = Colors.blue;
      statusText = 'Reserved (Verified)';
    } else if (busAvailabilityStatus == 'unavailable') {
      statusColor = Colors.red;
      statusText = 'Unavailable';
    } else {
      statusColor = Colors.green;
      statusText = 'Available';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Driver: ',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: conductor['driverName'] ?? 'Unknown',
                style: GoogleFonts.outfit(
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Route: ',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: conductor['route'] ?? bus['route'] ?? 'N/A',
                style: GoogleFonts.outfit(
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Status: ',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: statusText,
                style: GoogleFonts.outfit(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final titleFontSize = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final containerPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final marginSpacing = isMobile
        ? 6.0
        : isTablet
            ? 8.0
            : 10.0;
    final horizontalMargin = isMobile
        ? 10.0
        : isTablet
            ? 12.0
            : 16.0;
    final busNameFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'Buses for ${widget.selectedWeekday}',
              style: GoogleFonts.outfit(
                fontSize: titleFontSize,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy').format(widget.selectedDate),
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 12 : 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0091AD),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(containerPadding),
                    child: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Filter:',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile
                                      ? 14
                                      : isTablet
                                          ? 16
                                          : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildFilterChip('All', 'all'),
                                      SizedBox(width: 8),
                                      _buildFilterChip(
                                          'Available', 'available'),
                                      SizedBox(width: 8),
                                      _buildFilterChip(
                                          'Unavailable', 'unavailable'),
                                      SizedBox(width: 8),
                                      _buildFilterChip('Reserved', 'reserved'),
                                      SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _getFilteredBuses().isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No buses available for ${widget.selectedWeekday}",
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 16 : 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final bus = _getFilteredBuses()[index];
                            final conductor =
                                bus['conductorData'] as Map<String, dynamic>?;
                            final busAvailabilityStatus = conductor != null
                                ? ReservationService.getBusAvailabilityStatus(
                                    conductor)
                                : 'available';

                            bool isGrayedOut =
                                busAvailabilityStatus != 'available';

                            return GestureDetector(
                              onTap: () => _showBusDetails(bus),
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                    vertical: marginSpacing,
                                    horizontal: horizontalMargin),
                                padding: EdgeInsets.all(containerPadding),
                                decoration: BoxDecoration(
                                  color: isGrayedOut
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isGrayedOut
                                        ? Colors.grey.shade400
                                        : const Color(0xFF0091AD)
                                            .withOpacity(0.7),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Bus #${conductor?['busNumber']?.toString() ?? bus['busNumber']?.toString() ?? 'N/A'}',
                                            style: GoogleFonts.outfit(
                                              fontSize: busNameFontSize,
                                              fontWeight: FontWeight.bold,
                                              color: isGrayedOut
                                                  ? Colors.grey.shade600
                                                  : Color(0xFF0091AD),
                                            ),
                                            overflow: TextOverflow.visible,
                                            maxLines: 2,
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: isGrayedOut
                                              ? Colors.grey.shade500
                                              : Color(0xFF0091AD),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    Padding(
                                      padding: EdgeInsets.only(
                                          left: isMobile ? 0 : 8),
                                      child: _buildConductorInfo(bus),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _getFilteredBuses().length,
                        ),
                      ),
              ],
            ),
    );
  }
}
