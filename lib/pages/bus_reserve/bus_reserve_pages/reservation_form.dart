import 'package:b_go/pages/bus_reserve/bus_reserve_pages/bus_home.dart';
import 'package:b_go/pages/bus_reserve/bus_reserve_pages/payment_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReservationForm extends StatefulWidget {
  final List<String> selectedBusIds;
  final DateTime selectedDate; // Added selectedDate parameter

  ReservationForm({
    Key? key, 
    required this.selectedBusIds,
    required this.selectedDate, // Made it required
  }) : super(key: key);

  @override
  State<ReservationForm> createState() => _ReservationFormState();
}

class _ReservationFormState extends State<ReservationForm> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _departureTimeController = TextEditingController();
  final TextEditingController _passengerCountController = TextEditingController();

  bool _isRoundTrip = false;
  Map<String, dynamic>? _selectedBus;

  @override
  void initState() {
    super.initState();
    _loadSelectedBus();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _departureTimeController.dispose();
    _passengerCountController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, String type) {
    Color backgroundColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        iconColor = Colors.white;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        iconColor = Colors.white;
        break;
      case 'warning':
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        iconColor = Colors.white;
        break;
      default:
        backgroundColor = Colors.grey;
        icon = Icons.info;
        iconColor = Colors.white;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 12,
                color: backgroundColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _fullNameController.clear();
      _contactNumberController.clear();
      _departureTimeController.clear();
      _passengerCountController.clear();
      _isRoundTrip = false;
    });
  }

  Future<void> _loadSelectedBus() async {
    final allBuses = await ReservationService.getAllConductorsAsBuses();
    final selectedBus = allBuses.firstWhere(
      (bus) => widget.selectedBusIds.contains(bus['id']),
      orElse: () => {},
    );

    setState(() {
      _selectedBus = selectedBus.isNotEmpty ? selectedBus : null;
    });
  }

  Future<void> _submitReservation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showCustomSnackBar('Please log in to make a reservation', 'error');
      return;
    }

    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = user.email!;
    final contactNumber = _contactNumberController.text.trim();
    final departureTime = _departureTimeController.text.trim();
    final passengerCount = _passengerCountController.text.trim();

    if (from.isEmpty ||
        to.isEmpty ||
        fullName.isEmpty ||
        contactNumber.isEmpty ||
        departureTime.isEmpty ||
        passengerCount.isEmpty) {
      _showCustomSnackBar('Please fill out all fields', 'warning');
      return;
    }

    if (!_isValidPhoneNumber(contactNumber)) {
      _showCustomSnackBar(
          'Please enter a valid contact number (10-11 digits)', 'warning');
      return;
    }

    if (!_isValidPassengerCount(passengerCount)) {
      _showCustomSnackBar(
          'Please enter a valid number of passengers (1-22)', 'warning');
      return;
    }

    try {
      final reservationId = await ReservationService.saveReservation(
        selectedBusIds: widget.selectedBusIds,
        from: from,
        to: to,
        isRoundTrip: _isRoundTrip,
        fullName: fullName,
        email: email,
        departureDate: widget.selectedDate, // Use the passed selectedDate
        departureTime: departureTime,
        passengerCount: passengerCount,
      );

      // Get conductor data from _selectedBus
      final conductorData = _selectedBus?['conductorData'] as Map<String, dynamic>?;

      final reservationDetails = {
        'from': from,
        'to': to,
        'isRoundTrip': _isRoundTrip,
        'fullName': fullName,
        'email': email,
        'departureDate': DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate),
        'departureTime': departureTime,
        'passengerCount': passengerCount,
        'contactNumber': contactNumber,
        // Add bus information
        'driverName': conductorData?['driverName'] ?? 'N/A',
        'plateNumber': conductorData?['plateNumber'] ?? _selectedBus?['plateNumber'] ?? 'N/A',
        'busNumber': conductorData?['busNumber']?.toString() ?? _selectedBus?['busNumber']?.toString() ?? 'N/A',
      };

      _clearForm();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(
            reservationId: reservationId,
            selectedBusIds: widget.selectedBusIds,
            reservationDetails: reservationDetails,
          ),
        ),
      );
    } catch (e) {
      _showCustomSnackBar('Error: $e', 'error');
    }
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return Container(
      margin: EdgeInsets.symmetric(
          vertical: isMobile
              ? 8
              : isTablet
                  ? 10
                  : 12),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile
              ? 12
              : isTablet
                  ? 16
                  : 20,
          vertical: isMobile
              ? 4
              : isTablet
                  ? 6
                  : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (val) => setState(() {}),
        onTap: onTap,
        readOnly: readOnly,
        inputFormatters: inputFormatters,
        style: GoogleFonts.outfit(
          fontSize: isMobile
              ? 14
              : isTablet
                  ? 16
                  : 18,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: GoogleFonts.outfit(
            fontSize: isMobile
                ? 14
                : isTablet
                    ? 16
                    : 18,
          ),
        ),
      ),
    );
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(' ', '');
    if (cleanNumber.isEmpty) return false;

    final numberRegex = RegExp(r'^[0-9]+$');
    if (!numberRegex.hasMatch(cleanNumber)) return false;

    return cleanNumber.length == 10 || cleanNumber.length == 11;
  }

  bool _isValidPassengerCount(String count) {
    if (count.isEmpty) return false;
    final number = int.tryParse(count);
    return number != null && number > 0 && number <= 22;
  }

  Future<void> _selectDepartureTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _departureTimeController.text = picked.format(context);
      });
    }
  }

  Widget _buildSelectedBusInfo() {
    if (_selectedBus == null) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading selected bus information...',
                style: GoogleFonts.outfit(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(isMobile
          ? 12
          : isTablet
              ? 16
              : 20),
      decoration: BoxDecoration(
        color: Color(0xFF0091AD).withOpacity(0.1),
        border: Border.all(color: Color(0xFF0091AD).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus,
                  color: Color(0xFF0091AD), size: isMobile ? 20 : 24),
              SizedBox(width: 8),
              Text(
                'Selected Bus & Date',
                style: GoogleFonts.outfit(
                  fontSize: isMobile
                      ? 16
                      : isTablet
                          ? 18
                          : 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0091AD),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedBus!['name'] ?? 'Unknown Bus',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile
                        ? 14
                        : isTablet
                            ? 16
                            : 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0091AD),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Text(
                      'Departure Date: ${DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate)}',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 12
                            : isTablet
                                ? 14
                                : 16,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Available Days: ${List<String>.from(_selectedBus!['codingDays'] ?? []).join(', ')}',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile
                        ? 12
                        : isTablet
                            ? 14
                            : 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Price: ₱${_selectedBus!['Price']}',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile
                        ? 12
                        : isTablet
                            ? 14
                            : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final subtitleFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final expandedHeight = isMobile
        ? 60.0
        : isTablet
            ? 70.0
            : 80.0;
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF0091AD),
            leading: Padding(
              padding: EdgeInsets.only(top: 18.0, left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            title: Padding(
              padding: EdgeInsets.only(top: 22.0),
              child: Text(
                'Reservation Form',
                style: GoogleFonts.outfit(
                  fontSize: titleFontSize,
                  color: Colors.white,
                ),
              ),
            ),
            centerTitle: true,
          ),
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
            pinned: true,
            expandedHeight: expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007A8F),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Fill out the form below',
                        style: GoogleFonts.outfit(
                          fontSize: subtitleFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectedBusInfo(),
                  Text(
                    'Trip Information',
                    style: GoogleFonts.outfit(
                      fontSize: sectionFontSize,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0091AD),
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  _buildFormField('From', _fromController),
                  _buildFormField('To', _toController),
                  Text(
                    'Departure Time',
                    style: GoogleFonts.outfit(
                      fontSize: sectionFontSize,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0091AD),
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  _buildFormField(
                    'Departure Time',
                    _departureTimeController,
                    onTap: _selectDepartureTime,
                    readOnly: true,
                  ),
                  _buildFormField(
                    'Number of Passengers (1-22)',
                    _passengerCountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _isRoundTrip,
                        onChanged: (val) {
                          setState(() {
                            _isRoundTrip = val ?? false;
                          });
                        },
                        activeColor: Color(0xFF0091AD),
                      ),
                      Text(
                        'Roundtrip',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile
                              ? 14
                              : isTablet
                                  ? 16
                                  : 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  Text(
                    'Passenger Information',
                    style: GoogleFonts.outfit(
                      fontSize: sectionFontSize,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0091AD),
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  _buildFormField('Full Name', _fullNameController),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email,
                            color: Colors.grey.shade600, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Address',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 12 : 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                FirebaseAuth.instance.currentUser?.email ??
                                    'Not logged in',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildFormField(
                    'Contact Number (10-11 digits)',
                    _contactNumberController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      ContactNumberFormatter(),
                    ],
                  ),
                  SizedBox(height: isMobile ? 20 : 30),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        left: false,
        right: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _fromController.text.isNotEmpty &&
                      _toController.text.isNotEmpty &&
                      _fullNameController.text.isNotEmpty &&
                      _contactNumberController.text.isNotEmpty &&
                      _departureTimeController.text.isNotEmpty &&
                      _passengerCountController.text.isNotEmpty
                  ? const Color(0xFF0091AD)
                  : Colors.grey.shade400,
              minimumSize: Size(
                  double.infinity,
                  isMobile
                      ? 45
                      : isTablet
                          ? 50
                          : 55),
            ),
            onPressed: _fromController.text.isNotEmpty &&
                    _toController.text.isNotEmpty &&
                    _fullNameController.text.isNotEmpty &&
                    _contactNumberController.text.isNotEmpty &&
                    _departureTimeController.text.isNotEmpty &&
                    _passengerCountController.text.isNotEmpty
                ? () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Confirm Reservation',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0091AD),
                            )),
                        content: Text(
                          'You are about to reserve an entire bus for ${DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate)}. Please note that this booking is non-refundable once confirmed.\n\nDo you wish to proceed?',
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0091AD),
                            ),
                            child: Text(
                              'Proceed',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await _submitReservation();
                    }
                  }
                : null,
            child: Text(
              'Submit Reservation',
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
      ),
    );
  }
}

class ContactNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final limited =
        digitsOnly.length > 11 ? digitsOnly.substring(0, 11) : digitsOnly;

    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
  }
}