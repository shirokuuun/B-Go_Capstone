import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';

class SOSPage extends StatefulWidget {
  String route;

  SOSPage({Key? key, required this.route}) : super(key: key);

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> {

  
  final routeService = RouteService();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String? selectedEmergencyType;
  List<String> emergencyTypes = [
    'Mechanical Failure',
    'Flat Tire',
    'Brake Failure',
    'Accident',
    'Medical Emergency',
    'Other'
  ];

  String getRouteLabel(String placeCollection) {
    final route = widget.route.trim();

    if (route == 'Rosario') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Rosario';
        case 'Place 2':
          return 'Rosario - SM City Lipa';
      }
    } else if (route == 'Batangas') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Batangas City';
        case 'Place 2':
          return 'Batangas City - SM City Lipa';
      }
    } else if (route == 'Mataas na Kahoy') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - SM City Lipa';
      }
    } else if (route == 'Tiaong') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Tiaong';
        case 'Place 2':
          return 'Tiaong - SM City Lipa';
      }
    }

    return 'Unknown Route';
  }
  
  Map<String, dynamic>? latestSOS;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLatestSOS();
  }

  Future<void> loadLatestSOS() async {
    final routeLabel = getRouteLabel('Place');
    latestSOS = await routeService.fetchLatestSOS(routeLabel); 
    setState(() {
      isLoading = false;
    });
  }

  Color getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Received':
        return Colors.blue;
      case 'In Progress':
        return Colors.purple;
      case 'Resolved':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(65.0),
        child: AppBar(
          title: Text(
            'SOS - Emergency Assistance',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: Color(0xFF1D2B53),
          centerTitle: true,
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                loadLatestSOS(); 
              },
              tooltip: 'Refresh SOS',
            ),
          ],
        ),
      ),

     body: SafeArea(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
              child: GestureDetector(
                onTap: () async {
                if (selectedEmergencyType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select an emergency type.')),
                  );
                  return;
                }

                if (selectedEmergencyType == 'Other' && _descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please provide details for "Other" emergency.')),
                  );
                  return;
                }

                try {

                  final route = getRouteLabel('Place');

                  await routeService.cleanUpOldSOS(route);

                  await routeService.sendSOS(
                    emergencyType: selectedEmergencyType!,
                    description: _descriptionController.text,
                    lat: 0.0,
                    lng: 0.0,
                    route: getRouteLabel('Place'),
                    isActive: true,
                  );

                  await loadLatestSOS();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('SOS request sent successfully!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending SOS: $e')),
                  );
                }
              },


                child: Container(
                  padding: EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sos,
                        size: MediaQuery.of(context).size.width * 0.2,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to send SOS',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

              SizedBox(height: 30),

              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start, 
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                        Icons.warning,
                        color: Colors.red,
                        size: 30,
                      ),
                      SizedBox(width: 10),
                    Text(
                      'Select Emergency Type',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                    ),
                    SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedEmergencyType != null && emergencyTypes.contains(selectedEmergencyType)
                          ? selectedEmergencyType
                          : null,
                      decoration: InputDecoration(
                        hintText: "Choose an emergency type",
                        hintStyle: TextStyle(fontSize: 14),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder( 
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                      ),
                      dropdownColor: Colors.white,
                      iconEnabledColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          selectedEmergencyType = value!;
                        });
                      },
                      items: emergencyTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                        );
                      }).toList(),
                    ),

                    
                    SizedBox(height: 20),

                    Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color: Colors.red,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Enter Emergency Details',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Enter emergency details',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey, 
                              width: 1,       
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                        ),
                        minLines: 1, // minimum lines to show
                        maxLines: 3, // limit max height
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.black,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Current Location',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'GPS',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                      )
                    ],
                  ),
                  
                  SizedBox(height: 20),

                  Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row( 
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          color: Colors.black,
                          size: 30,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Status:',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: getStatusColor(latestSOS?['status']),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isLoading
                              ? 'Loading...'
                              : (latestSOS == null || latestSOS!.isEmpty)
                                ? ''
                                : latestSOS!['status'] ?? 'Unknown',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),

                        ),
                      ],
                    ),
                  ],
                ),

                  ],
                ),
              ),
              SizedBox(height: 30),

              /*SizedBox(
                width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Handle cancel SOS logic here, e.g. delete from Firestore or update status
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('SOS request cancelled.')),
                  );
                },
                label: Text(
                  'Cancel SOS',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 18), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),*/
            ],
          ),
        ),
        
      ),
    ),

    );
  }
}