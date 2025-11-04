import 'package:b_go/pages/passenger/services/confirm_payment.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GCash-like payment wallet page
/// Shows available balance and navigates to confirmation page
class PaymentPage extends StatefulWidget {
  final String bookingId;
  final String route;
  final String directionLabel;
  final Map<String, dynamic> fromPlace;
  final Map<String, dynamic> toPlace;
  final int quantity;
  final List<String> fareTypes;
  final double baseFare;
  final double totalAmount;
  final List<String> discountBreakdown;
  final List<double> passengerFares;

  const PaymentPage({
    Key? key,
    required this.bookingId,
    required this.route,
    required this.directionLabel,
    required this.fromPlace,
    required this.toPlace,
    required this.quantity,
    required this.fareTypes,
    required this.baseFare,
    required this.totalAmount,
    required this.discountBreakdown,
    required this.passengerFares,
  }) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final double _availableBalance = 2000.00; // Placeholder balance up to 2000 pesos
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5EED),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'G',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5EED),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Hello!',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () {},
              child: Text(
                'HELP',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Top Blue Section with Balance and Tabs
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(0xFF2C5EED),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Birthday Promo Banner
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cake, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Surprise Birthday',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SHAKE AWAY',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Tabs
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildTab('Wallet', true),
                              _buildTab('Save', false),
                              _buildTab('Borrow', false),
                              _buildTab('Grow', false),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        
                        // Balance Card - Made more compact
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF4169F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'AVAILABLE BALANCE',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _balanceVisible = !_balanceVisible;
                                          });
                                        },
                                        child: Icon(
                                          _balanceVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '+ Cash In',
                                      style: GoogleFonts.outfit(
                                        color: Color(0xFF2C5EED),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '₱',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    _balanceVisible
                                        ? _availableBalance.toStringAsFixed(2)
                                        : '****.**',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                  
                  // Action Buttons Grid - Made more compact
                  Container(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(
                              icon: Icons.send,
                              label: 'Send',
                              color: Color(0xFF2C5EED),
                            ),
                            _buildActionButton(
                              icon: Icons.phone_android,
                              label: 'Load',
                              color: Color(0xFF2C5EED),
                            ),
                            _buildActionButton(
                              icon: Icons.account_balance,
                              label: 'Transfer',
                              color: Color(0xFF2C5EED),
                            ),
                            _buildActionButton(
                              icon: Icons.receipt,
                              label: 'Bills',
                              color: Color(0xFF2C5EED),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(
                              icon: Icons.savings,
                              label: 'GInvest',
                              color: Color(0xFF2C5EED),
                            ),
                            _buildActionButton(
                              icon: Icons.credit_card,
                              label: 'Cards',
                              color: Color(0xFF2C5EED),
                            ),
                            _buildActionButton(
                              icon: Icons.star,
                              label: 'A+ Rewards',
                              color: Color(0xFF2C5EED),
                            ),
                            _buildActionButton(
                              icon: Icons.directions_bus,
                              label: 'Commute',
                              color: Colors.red,
                              highlighted: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Add some bottom padding to ensure content doesn't get cut off
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),
          
          // Pay Now Button - Fixed at bottom
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                // Check if balance is sufficient
                if (_availableBalance >= widget.totalAmount) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConfirmationPayment(
                        bookingId: widget.bookingId,
                        route: widget.route,
                        directionLabel: widget.directionLabel,
                        fromPlace: widget.fromPlace,
                        toPlace: widget.toPlace,
                        quantity: widget.quantity,
                        fareTypes: widget.fareTypes,
                        baseFare: widget.baseFare,
                        totalAmount: widget.totalAmount,
                        discountBreakdown: widget.discountBreakdown,
                        passengerFares: widget.passengerFares,
                        availableBalance: _availableBalance,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Insufficient balance. Please cash in first.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0091AD),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Pay Now',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF2C5EED),
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 22),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail, size: 22),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner, size: 22),
            label: 'QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long, size: 22),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 22),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Color(0xFF2C5EED) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    bool highlighted = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: highlighted ? Colors.red.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: highlighted
                ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
                : null,
          ),
          child: Icon(
            icon,
            color: color,
            size: 26,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}