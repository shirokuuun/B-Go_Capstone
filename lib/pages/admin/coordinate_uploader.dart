import 'package:flutter/material.dart';
import '../../utils/firestore_uploader.dart';

class CoordinateUploaderPage extends StatefulWidget {
  const CoordinateUploaderPage({Key? key}) : super(key: key);

  @override
  State<CoordinateUploaderPage> createState() => _CoordinateUploaderPageState();
}

class _CoordinateUploaderPageState extends State<CoordinateUploaderPage> {
  bool _isUploading = false;
  String _status = 'Ready to upload coordinates';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinate Uploader'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rosario Route Coordinates',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will upload the detailed Rosario route coordinates to Firestore. '
                      'The coordinates include all 16 locations from SM City Lipa to Lipa City Proper.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadRosarioCoordinates,
                      icon: _isUploading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload Rosario Coordinates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Routes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload coordinates for all routes (Batangas, Rosario, Mataas na Kahoy, Tiaong, San Juan).',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadAllCoordinates,
                      icon: _isUploading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload All Routes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify Upload',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check if the Rosario coordinates were uploaded successfully.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _verifyCoordinates,
                      icon: const Icon(Icons.verified),
                      label: const Text('Verify Rosario Coordinates'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadRosarioCoordinates() async {
    setState(() {
      _isUploading = true;
      _status = 'Uploading Rosario coordinates...';
    });

    try {
      await FirestoreUploader.uploadRosarioCoordinates();
      setState(() {
        _status = '✅ Successfully uploaded Rosario coordinates to Firestore!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error uploading coordinates: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadAllCoordinates() async {
    setState(() {
      _isUploading = true;
      _status = 'Uploading all route coordinates...';
    });

    try {
      await FirestoreUploader.uploadAllRouteCoordinates();
      setState(() {
        _status = '✅ Successfully uploaded all route coordinates to Firestore!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error uploading coordinates: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _verifyCoordinates() async {
    setState(() {
      _isUploading = true;
      _status = 'Verifying coordinates...';
    });

    try {
      await FirestoreUploader.verifyRosarioCoordinates();
      setState(() {
        _status = '✅ Coordinates verified successfully! Check console for details.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error verifying coordinates: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
