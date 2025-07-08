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
    return Center (
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
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'No. of Passengers:',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 25,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: Colors.white),
                      onPressed: () {
                        if (quantity > 1) setState(() => quantity--);
                      },
                    ),
                    Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        quantity.toString(),
                        style: TextStyle(
                          fontSize: 18, 
                          color: Colors.white,
                          decoration: TextDecoration.none
                          ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: Colors.white),
                      onPressed: () => setState(() => quantity++),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      widget.onConfirm(quantity);
                      Navigator.of(context).pop();
                    },
                    child: Text("Confirm", style: TextStyle(color: Colors.white)),
                  ),
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
  const DiscountSelection({super.key});

  @override
  State<DiscountSelection> createState() => _DiscountSelectionState();
}

class _DiscountSelectionState extends State<DiscountSelection> {
  String selectedLabel = ''; 

  @override
  void initState() {
    super.initState();
    selectedLabel = ''; // No pre-selection
  }

  double getDiscountValue() {
    switch(selectedLabel) {
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
                SizedBox(height: 16),
                Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DiscountOption(
                    label: "Student",
                    value: 0.20,
                    selected: selectedLabel == "Student",
                    onTap: () => setState(() { selectedLabel = "Student"; }),
                  ),
                  DiscountOption(
                    label: "Senior",
                    value: 0.20,
                    selected: selectedLabel == "Senior",
                    onTap: () => setState(() { selectedLabel = "Senior"; }),
                  ),
                  DiscountOption(
                    label: "PWDs",
                    value: 0.20,
                    selected: selectedLabel == "PWDs",
                    onTap: () => setState(() { selectedLabel = "PWDs"; }),
                  ),
                  DiscountOption(
                    label: "Regular",
                    value: 0.0,
                    selected: selectedLabel == "Regular",
                    onTap: () => setState(() { selectedLabel = "Regular"; }),
                  ),
                ],
                              ),

                SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(getDiscountValue());
                    },
                    child: Text("Confirm", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiscountOption extends StatelessWidget {
  final String label;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  const DiscountOption({
    Key? key,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Color(0xFF10B981) : Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}