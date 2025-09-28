import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/pages/passenger/services/pre_book.dart';

class BusPicker extends StatefulWidget {
  const BusPicker({super.key});

  @override
  State<BusPicker> createState() => _BusPickerState();
}

class _BusPickerState extends State<BusPicker> {
  List<Map<String, dynamic>> conductors = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchConductors();
  }

  Future<void> _fetchConductors() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      print('🔍 BusPicker: Fetching conductors from Firebase...');
      
      // First, let's get ALL conductors to debug
      final allSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .get();
      
      print('🔍 BusPicker: Total conductors found: ${allSnapshot.docs.length}');
      
      // Log all conductor data for debugging
      for (final doc in allSnapshot.docs) {
        final data = doc.data();
        final activeTrip = data['activeTrip'];
        print('🔍 Conductor ${doc.id}: isOnline=${data['isOnline']}, route=${data['route']}, name=${data['name']}');
        print('🔍   - isActive: ${data['isActive']}');
        print('🔍   - hasActiveTrip: ${activeTrip != null}');
        if (activeTrip != null) {
          print('🔍   - activeTrip direction: ${activeTrip['direction']}');
          print('🔍   - activeTrip isReturnTrip: ${activeTrip['isReturnTrip']}');
        }
      }

      // Now filter for online conductors
      final conductorList = allSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final isOnline = data['isOnline'] == true;
            final isActive = data['isActive'] == true;
            final hasActiveTrip = data['activeTrip'] != null;
            
            print('🔍 Conductor ${doc.id}: isOnline=$isOnline, isActive=$isActive, hasActiveTrip=$hasActiveTrip');
            
            // Consider conductor as available if they are online AND (active OR have an active trip)
            final isAvailable = isOnline && (isActive || hasActiveTrip);
            print('🔍 Conductor ${doc.id}: isAvailable=$isAvailable');
            
            return isAvailable;
          })
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            print('✅ Available conductor found: ${data['name']} (${data['route']})');
            return data;
          })
          .toList();

      print('🔍 BusPicker: Online conductors found: ${conductorList.length}');

      setState(() {
        conductors = conductorList;
        isLoading = false;
      });
    } catch (e) {
      print('❌ BusPicker: Error fetching conductors: $e');
      setState(() {
        errorMessage = 'Failed to load conductors: $e';
        isLoading = false;
      });
    }
  }

  void _selectConductor(Map<String, dynamic> conductor) {
    // Navigate to pre-book with selected conductor's route
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PreBook(selectedConductor: conductor),
      ),
    );
  }

  Future<void> _showAllConductors() async {
    try {
      print('🔍 BusPicker: Fetching ALL conductors for debugging...');
      
      final allSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .get();
      
      final allConductors = allSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('🔍 BusPicker: All conductors found: ${allConductors.length}');
      
      setState(() {
        conductors = allConductors;
        isLoading = false;
      });
    } catch (e) {
      print('❌ BusPicker: Error fetching all conductors: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Get screen dimensions for better responsive calculations
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing
    final titleFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;

    // Responsive padding
    final horizontalPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF007A8F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Select Bus',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: titleFontSize,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchConductors,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.red[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchConductors,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007A8F),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : conductors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_bus_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No online buses available',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No conductors are currently online',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchConductors,
                      child: ListView.builder(
                        padding: EdgeInsets.all(horizontalPadding),
                        itemCount: _getGroupedConductors().length,
                        itemBuilder: (context, index) {
                          final group = _getGroupedConductors()[index];
                          return _buildRouteGroup(group, isMobile, isTablet, screenWidth, screenHeight);
                        },
                      ),
                    ),
    );
  }

  List<Map<String, dynamic>> _getGroupedConductors() {
    // Group conductors by route
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final conductor in conductors) {
      final route = conductor['route'] ?? 'Unknown';
      if (!grouped.containsKey(route)) {
        grouped[route] = [];
      }
      grouped[route]!.add(conductor);
    }

    // Convert to list format for display
    return grouped.entries.map((entry) => {
      'route': entry.key,
      'conductors': entry.value,
    }).toList();
  }

  Widget _buildRouteGroup(
    Map<String, dynamic> group,
    bool isMobile,
    bool isTablet,
    double screenWidth,
    double screenHeight,
  ) {
    final route = group['route'] as String;
    final conductors = group['conductors'] as List<Map<String, dynamic>>;
    
    // Responsive sizing
    final routeFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final iconSize = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF007A8F),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: iconSize,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route,
                    style: GoogleFonts.outfit(
                      fontSize: routeFontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: isMobile ? 16 : 18,
                ),
              ],
            ),
          ),
          // Conductors list
          ...conductors.map((conductor) => _buildConductorItem(
            conductor,
            isMobile,
            isTablet,
            screenWidth,
            screenHeight,
          )),
        ],
      ),
    );
  }

  Widget _buildConductorItem(
    Map<String, dynamic> conductor,
    bool isMobile,
    bool isTablet,
    double screenWidth,
    double screenHeight,
  ) {
    final isOnline = conductor['isOnline'] == true;
    final name = conductor['name'] ?? 'Unknown Conductor';
    final busNumber = conductor['busNumber']?.toString() ?? 'N/A';
    final passengerCount = conductor['passengerCount'] ?? 0;
    final direction = conductor['activeTrip']?['direction'] ?? 'No active trip';
    final isActive = conductor['isActive'] == true;
    final hasActiveTrip = conductor['activeTrip'] != null;
    
    // Determine if conductor is available (online and either active or has active trip)
    final isAvailable = isOnline && (isActive || hasActiveTrip);
    
    // Debug logging
    print('🔍 Building conductor item: $name, isOnline: $isOnline, isActive: $isActive, hasActiveTrip: $hasActiveTrip, isAvailable: $isAvailable');
    
    // Responsive sizing
    final conductorFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    final statusFontSize = isMobile ? 12.0 : isTablet ? 14.0 : 16.0;
    final iconSize = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 8 : 12,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isAvailable
                ? Colors.green[100]
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.person,
            color: isAvailable
                ? Colors.green[700]
                : Colors.grey[500],
            size: iconSize,
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.outfit(
            fontSize: conductorFontSize,
            fontWeight: FontWeight.w600,
            color: isAvailable
                ? Colors.black87
                : Colors.grey[500],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Bus #$busNumber • $passengerCount passengers',
              style: GoogleFonts.outfit(
                fontSize: statusFontSize,
                color: isAvailable
                    ? Colors.grey[600]
                    : Colors.grey[400],
              ),
            ),
            if (hasActiveTrip && direction.isNotEmpty) ...[
              SizedBox(height: 2),
              Text(
                direction,
                style: GoogleFonts.outfit(
                  fontSize: statusFontSize - 1,
                  color: isAvailable
                      ? Colors.blue[600]
                      : Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.green[100]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAvailable ? 'Online' : 'Offline',
                    style: GoogleFonts.outfit(
                      fontSize: statusFontSize - 2,
                      color: isAvailable
                          ? Colors.green[700]
                          : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isOnline && !isActive && !hasActiveTrip) ...[
                  SizedBox(height: 2),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Inactive',
                      style: GoogleFonts.outfit(
                        fontSize: statusFontSize - 3,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: isAvailable
            ? () => _selectConductor(conductor)
            : null,
        enabled: isAvailable,
      ),
    );
  }
}
