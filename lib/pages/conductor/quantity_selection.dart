import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class QuantitySelection extends StatefulWidget {
  final Function(int quantity) onConfirm;

  const QuantitySelection({Key? key, required this.onConfirm}) : super(key: key);

  @override
  _QuantitySelectionState createState() => _QuantitySelectionState();
}

class _QuantitySelectionState extends State<QuantitySelection> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 270,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1D2B53).withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Quantity',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 16),

                // Quantity Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: Colors.white),
                      onPressed: quantity > 1
                          ? () => setState(() => quantity--)
                          : null,
                    ),
                    Text(
                      '$quantity',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.white),
                      onPressed: () => setState(() => quantity++),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        widget.onConfirm(quantity);
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Confirm',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiscountSelection extends StatefulWidget {
  final int quantity;
  const DiscountSelection({super.key, required this.quantity});

  @override
  State<DiscountSelection> createState() => _DiscountSelectionState();
}

class _DiscountSelectionState extends State<DiscountSelection> {
  final List<String> fareTypes = ['Regular', 'Student', 'PWDs', 'Senior'];
  late List<String> selectedLabels;

  @override
  void initState() {
    super.initState();
    selectedLabels = List.generate(widget.quantity, (index) => 'Regular');
  }

  double getDiscountValue(String type) {
    switch (type) {
      case "Student":
      case "Senior":
      case "PWDs":
        return 0.20;
      case "Regular":
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
             color: Colors.transparent,
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1D2B53).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Discount',
                    style: GoogleFonts.bebasNeue(fontSize: 25, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < widget.quantity; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Text(
                            'Passenger ${i + 1}:',
                            style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            dropdownColor: const Color(0xFF1D2B53),
                            value: selectedLabels[i],
                            iconEnabledColor: Colors.white,
                            style: GoogleFonts.outfit(color: Colors.white),
                            underline: Container(),
                            items: fareTypes.map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedLabels[i] = val!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          List<double> discounts = selectedLabels.map(getDiscountValue).toList();
                          Navigator.of(context).pop(discounts);
                        },
                        child: const Text("Confirm", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


