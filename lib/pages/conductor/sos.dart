import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

class SOSPage extends StatefulWidget {
  final String route;
  final String placeCollection;

  SOSPage({Key? key, required this.route, required this.placeCollection})
      : super(key: key);

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> {
  final routeService = RouteService();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? selectedEmergencyType;
  Map<String, dynamic>? latestSOS;
  bool isLoading = true;
  List<XFile> selectedImages = [];
  Position? currentPosition;

  List<String> emergencyTypes = [
    'Mechanical Failure',
    'Flat Tire',
    'Brake Failure',
    'Accident',
    'Medical Emergency',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    loadLatestSOS();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showCustomSnackBar('Please enable location services.', 'warning');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showCustomSnackBar('Location permissions are denied.', 'error');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showCustomSnackBar(
            'Location permissions are permanently denied.', 'error');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
      _showCustomSnackBar('Failed to get location.', 'error');
    }
  }

  Future<void> loadLatestSOS() async {
    setState(() => isLoading = true);
    final sosData = await routeService
        .fetchLatestSOS(getRouteLabel(widget.placeCollection));
    setState(() {
      latestSOS = sosData;
      isLoading = false;

      // If there's a pending SOS, populate the fields with existing data
      if (latestSOS != null && latestSOS!['status'] == 'Pending') {
        selectedEmergencyType = latestSOS!['emergencyType'];
        _descriptionController.text = latestSOS!['description'] ?? '';
        // Note: selectedImages is cleared since uploaded images are stored in Firebase
        // We'll display the uploaded images from latestSOS['imageUrls'] instead
        selectedImages.clear();
      }
    });
  }

  String getRouteLabel(String placeCollection) {
    final route = widget.route.trim();
    final map = {
      'Rosario': {
        'Place': 'SM City Lipa - Rosario',
        'Place 2': 'Rosario - SM City Lipa',
      },
      'Tiaong': {
        'Place': 'SM City Lipa - Tiaong',
        'Place 2': 'Tiaong - SM City Lipa',
      },
      'San Juan': {
        'Place': 'SM City Lipa - San Juan',
        'Place 2': 'San Juan - SM City Lipa',
      },
      'Mataas na Kahoy': {
        'Place': 'SM City Lipa - Mataas na Kahoy',
        'Place 2': 'Mataas na Kahoy - SM City Lipa',
      },
      'Mataas Na Kahoy Palengke': {
        'Place': 'Lipa Palengke - Mataas na Kahoy',
        'Place 2': 'Mataas na Kahoy - Lipa Palengke',
      },
    };
    return map[route]?[placeCollection] ?? 'Unknown Route';
  }

  Color getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Color(0xFFFFC107);
      case 'In Progress':
        return Color(0xFF2196F3);
      case 'Resolved':
        return Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  void resetFields() {
    setState(() {
      selectedEmergencyType = null;
      _descriptionController.clear();
      selectedImages.clear();
      latestSOS = null;
    });
  }

  bool get hasPendingSOS {
    return latestSOS != null && latestSOS!['status'] == 'Pending';
  }

  Future<void> _pickImages() async {
    if (hasPendingSOS) {
      _showCustomSnackBar(
          'Cannot modify images while SOS is pending.', 'warning');
      return;
    }

    if (selectedImages.length >= 4) {
      _showCustomSnackBar('Maximum 4 images allowed.', 'warning');
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        int remainingSlots = 4 - selectedImages.length;
        selectedImages.addAll(images.take(remainingSlots));
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    for (var image in selectedImages) {
      try {
        String fileName =
            'sos_${DateTime.now().millisecondsSinceEpoch}_${selectedImages.indexOf(image)}.jpg';
        Reference ref =
            FirebaseStorage.instance.ref().child('sos_images/$fileName');
        await ref.putFile(File(image.path));
        String url = await ref.getDownloadURL();
        imageUrls.add(url);
      } catch (e) {
        print('Error uploading image: $e');
      }
    }
    return imageUrls;
  }

  void _showCustomSnackBar(String message, String type) {
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      case 'warning':
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        break;
      default:
        backgroundColor = Colors.grey;
        icon = Icons.info;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
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
      ),
    );
  }

  Widget detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.normal,
                color: Colors.black87,
                fontSize: 14,
              ),
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

    final appBarFontSize = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final titleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final bodyFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final iconSize = isMobile
        ? 22.0
        : isTablet
            ? 24.0
            : 28.0;

    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 32.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    final primaryTeal = const Color(0xFF0091AD);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !hasPendingSOS) {
          resetFields();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'SOS - Emergency Assistance',
            style: GoogleFonts.outfit(
              fontSize: appBarFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: primaryTeal,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loadLatestSOS,
              tooltip: 'Refresh SOS',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning banner if SOS is pending
                if (hasPendingSOS)
                  Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have an active SOS request. Fields are locked until resolved.',
                            style: GoogleFonts.outfit(
                              fontSize: bodyFontSize,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // SOS Button
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      if (hasPendingSOS) {
                        _showCustomSnackBar(
                          'You already have an active SOS request.',
                          'warning',
                        );
                        return;
                      }

                      if (selectedEmergencyType == null) {
                        _showCustomSnackBar(
                          'Please select an emergency type.',
                          'warning',
                        );
                        return;
                      }

                      if (selectedEmergencyType == 'Other' &&
                          _descriptionController.text.trim().isEmpty) {
                        _showCustomSnackBar(
                          'Please provide details for "Other".',
                          'warning',
                        );
                        return;
                      }

                      if (currentPosition == null) {
                        _showCustomSnackBar(
                          'Getting your location... Please try again.',
                          'warning',
                        );
                        await _getCurrentLocation();
                        return;
                      }

                      try {
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Sending SOS...',
                                      style: GoogleFonts.outfit(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        // Upload images
                        List<String> imageUrls = await _uploadImages();

                        // Send SOS
                        await routeService.sendSOS(
                          emergencyType: selectedEmergencyType!,
                          description: _descriptionController.text,
                          lat: currentPosition!.latitude,
                          lng: currentPosition!.longitude,
                          route: getRouteLabel(widget.placeCollection),
                          isActive: true,
                          imageUrls: imageUrls,
                        );

                        Navigator.pop(context); // Close loading dialog

                        await loadLatestSOS();
                        _showCustomSnackBar(
                          'SOS request sent successfully!',
                          'success',
                        );
                      } catch (e) {
                        Navigator.pop(context); // Close loading dialog
                        _showCustomSnackBar(
                          'Error sending SOS: $e',
                          'error',
                        );
                      }
                    },
                    child: Opacity(
                      opacity: hasPendingSOS ? 0.5 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: hasPendingSOS ? Colors.grey : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.sos,
                              size: isMobile
                                  ? 60
                                  : isTablet
                                      ? 70
                                      : 80,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasPendingSOS ? 'SOS SENT' : 'TAP TO SEND SOS',
                              style: GoogleFonts.outfit(
                                fontSize: isMobile
                                    ? 14
                                    : isTablet
                                        ? 16
                                        : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Emergency Type Selection Card
                Container(
                  decoration: BoxDecoration(
                    color: hasPendingSOS ? Colors.grey.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: hasPendingSOS ? Colors.grey : Colors.red,
                      size: iconSize,
                    ),
                    title: Text(
                      'Emergency Type',
                      style: GoogleFonts.outfit(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: DropdownButtonFormField<String>(
                        value: emergencyTypes.contains(selectedEmergencyType)
                            ? selectedEmergencyType
                            : null,
                        decoration: InputDecoration(
                          hintText: "Select emergency type",
                          hintStyle: GoogleFonts.outfit(
                            color: Colors.grey[600],
                            fontSize: bodyFontSize,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: primaryTeal),
                          ),
                          filled: hasPendingSOS,
                          fillColor: Colors.grey.shade200,
                        ),
                        onChanged: hasPendingSOS
                            ? null
                            : (value) =>
                                setState(() => selectedEmergencyType = value),
                        items: emergencyTypes
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    style: GoogleFonts.outfit(
                                        fontSize: bodyFontSize),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Description Card
                Container(
                  decoration: BoxDecoration(
                    color: hasPendingSOS ? Colors.grey.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    leading: Icon(
                      Icons.description,
                      color: hasPendingSOS ? Colors.grey : primaryTeal,
                      size: iconSize,
                    ),
                    title: Text(
                      'Emergency Details',
                      style: GoogleFonts.outfit(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _descriptionController,
                        enabled: !hasPendingSOS,
                        decoration: InputDecoration(
                          hintText: 'Describe the emergency situation...',
                          hintStyle: GoogleFonts.outfit(
                            color: Colors.grey[600],
                            fontSize: bodyFontSize,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: primaryTeal),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: hasPendingSOS,
                          fillColor: Colors.grey.shade200,
                        ),
                        maxLines: 4,
                        style: GoogleFonts.outfit(fontSize: bodyFontSize),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Image Upload Card
                Container(
                  decoration: BoxDecoration(
                    color: hasPendingSOS ? Colors.grey.shade100 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    leading: Icon(
                      Icons.photo_camera,
                      color: hasPendingSOS ? Colors.grey : primaryTeal,
                      size: iconSize,
                    ),
                    title: Text(
                      'Attach Images (Max 4)',
                      style: GoogleFonts.outfit(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12),
                        // Check if there are any images to display (local or uploaded)
                        if ((hasPendingSOS &&
                                latestSOS != null &&
                                latestSOS!['imageUrls'] != null &&
                                (latestSOS!['imageUrls'] as List).isNotEmpty) ||
                            (!hasPendingSOS && selectedImages.isNotEmpty))
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Show uploaded images if SOS is pending
                              if (hasPendingSOS &&
                                  latestSOS != null &&
                                  latestSOS!['imageUrls'] != null)
                                ...(latestSOS!['imageUrls'] as List)
                                    .map<Widget>((imageUrl) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey.shade200,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey.shade300,
                                          child: Icon(Icons.error,
                                              color: Colors.red),
                                        );
                                      },
                                    ),
                                  );
                                }).toList()
                              // Show local images if not pending
                              else if (!hasPendingSOS)
                                ...selectedImages.map((image) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(image.path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              selectedImages.remove(image);
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                            ],
                          )
                        else
                          Text(
                            hasPendingSOS
                                ? 'No images attached'
                                : 'No images selected',
                            style: GoogleFonts.outfit(
                              fontSize: bodyFontSize,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (!hasPendingSOS) ...[
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: Icon(Icons.add_photo_alternate),
                            label: Text(
                              'Add Images (${selectedImages.length}/4)',
                              style: GoogleFonts.outfit(fontSize: bodyFontSize),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Location Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    leading: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: iconSize,
                    ),
                    title: Text(
                      'Current Location',
                      style: GoogleFonts.outfit(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: currentPosition != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Latitude: ${currentPosition!.latitude.toStringAsFixed(6)}',
                                  style: GoogleFonts.outfit(
                                      fontSize: bodyFontSize),
                                ),
                                Text(
                                  'Longitude: ${currentPosition!.longitude.toStringAsFixed(6)}',
                                  style: GoogleFonts.outfit(
                                      fontSize: bodyFontSize),
                                ),
                              ],
                            )
                          : Text(
                              'Getting location...',
                              style: GoogleFonts.outfit(
                                fontSize: bodyFontSize,
                                color: Colors.grey[600],
                              ),
                            ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.refresh, color: primaryTeal),
                      onPressed: _getCurrentLocation,
                    ),
                  ),
                ),

                if (!isLoading && latestSOS != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      leading: Icon(
                        Icons.info_outline,
                        color: primaryTeal,
                        size: iconSize,
                      ),
                      title: Text(
                        'Current SOS Status',
                        style: GoogleFonts.outfit(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor(latestSOS?['status']),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            latestSOS!['status'],
                            style: GoogleFonts.outfit(
                              fontSize: bodyFontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: primaryTeal,
                      ),
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(
                            'SOS Details',
                            style: GoogleFonts.outfit(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: primaryTeal,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                detailRow('Emergency Type',
                                    latestSOS!['emergencyType']),
                                detailRow('Description',
                                    latestSOS!['description'] ?? 'N/A'),
                                detailRow('Route', latestSOS!['route']),
                                detailRow(
                                  'Time',
                                  latestSOS!['timestamp'] != null
                                      ? (latestSOS!['timestamp'] as Timestamp)
                                          .toDate()
                                          .toLocal()
                                          .toString()
                                      : 'Unknown',
                                ),
                                detailRow('Status', latestSOS!['status']),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Close',
                                style: GoogleFonts.outfit(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            if (latestSOS!['status'] == 'Pending')
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await RouteService()
                                        .cancelSOS(latestSOS!['id']);
                                    if (mounted) {
                                      Navigator.of(context).pop();
                                      _showCustomSnackBar(
                                        'SOS cancelled successfully.',
                                        'success',
                                      );
                                      resetFields();
                                      await loadLatestSOS();
                                    }
                                  } catch (e) {
                                    Navigator.of(context).pop();
                                    _showCustomSnackBar(
                                      'Failed to cancel SOS: $e',
                                      'error',
                                    );
                                  }
                                },
                                child: Text(
                                  'Cancel SOS',
                                  style: GoogleFonts.outfit(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
