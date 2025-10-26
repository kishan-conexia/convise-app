import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mnr/pages/attendance_page.dart';
// import 'package:mnr/pages/department_hierarchy_page.dart';
import 'package:mnr/pages/department_page.dart';
import 'package:mnr/pages/detailed_attendance_page.dart';
import 'package:mnr/pages/manager_team_request_page.dart';
import 'package:mnr/pages/monthly_attendance_page.dart';
import 'package:mnr/pages/profile_page.dart';
import 'package:mnr/pages/sensor_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/app_state.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late final PageController _pageController;
  Timer? _carouselTimer;
  DateTime? _lastBackPressed;


  final List<String> _carouselImages = [
    'https://via.placeholder.com/400x200/1976D2/FFFFFF?text=High+Speed+Internet',
    'https://via.placeholder.com/400x200/388E3C/FFFFFF?text=Fiber+Optic+Technology',
    'https://via.placeholder.com/400x200/F57C00/FFFFFF?text=24/7+Support',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _pageController = PageController(viewportFraction: 0.85);

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = _pageController.page!.round() + 1;
        _pageController.animateToPage(
          nextPage % 5, // 6 is the total items in the list
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AppState().initialized) {
        initializeAppState();
      } else {
        setState(() {
          isLoading = false;
        });
        _animationController.forward();
      }
    });
  }

  Future<void> initializeAppState() async {
    setState(() => isLoading = true);
    await AppState().initialize();
    setState(() => isLoading = false);
    _animationController.forward();
  }

  Future<void> _showSignOutDialog() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      _signOut();
    }
  }

  Future<void> _signOut() async {
    try {
      Navigator.of(context).pop();
      await supabase.auth.signOut();
      await Supabase.instance.client.dispose();

      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }

      await AppState().resetState();
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      exit(0);
    } on AuthException catch (error) {
      context.showSnackBar(error.message, isError: true);
    } catch (_) {
      context.showSnackBar('Unexpected error occurred', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Set<int> allowedMonthlyAttendanceDepartments = {1, 30, 301, 302, 303};
    final Set<int> allowedDailyAttendance = {1, 30, 301, 303};

    // Check if any of the managed departments are in the allowed list
    final bool canAccessMonthlyAttendance = AppState().managedDepartmentIds.any(allowedMonthlyAttendanceDepartments.contains);

    final bool canAccessDailyAttendance = AppState().managedDepartmentIds.any(allowedDailyAttendance.contains);

    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppState().appBarGradient,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Loading Conexia Dashboard...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: AppBar(
            title: Hero(
              tag: 'app_logo',
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    const LinearGradient(
                      colors: [Colors.white, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: SvgPicture.asset(
                  'assets/launcher_icon.svg',
                  height: 60,
                  // width: 100,
                ),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white70,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
            ),
            // actions: [
            //   PopupMenuButton<String>(
            //     onSelected: (value) {
            //       switch (value) {
            //         case 'report':
            //           // _selectMonth(context);
            //           break;
            //       // case 'filter':
            //       //   // _exportToCSV();
            //       //   break;
            //       }
            //     },
            //     itemBuilder: (BuildContext context) => [
            //       const PopupMenuItem<String>(
            //         value: 'report',
            //         child: Row(
            //           children: [
            //             Icon(Icons.calendar_month, size: 20, color: Colors.blue),
            //             SizedBox(width: 8),
            //             Text('Attendance Report'),
            //           ],
            //         ),
            //       ),
            //       // const PopupMenuItem<String>(
            //       //   value: 'filter',
            //       //   child: Row(
            //       //     children: [
            //       //       Icon(Icons.filter_alt, size: 20, color: Colors.purple),
            //       //       SizedBox(width: 8),
            //       //       Text('Filter by Status'),
            //       //     ],
            //       //   ),
            //       // ),
            //     ],
            //     icon: const Icon(Icons.more_vert),
            //   ),
            // ],
          ),
        ),
        drawer: Consumer<AppState>(
          builder: (context, appState, child) {
            return Drawer(
              width: MediaQuery.of(context).size.width * 0.75,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildUserInfo(appState),
                        const Divider(color: Colors.white24, height: 32),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildDrawerItem(
                                  icon: Icons.manage_accounts_outlined,
                                  label: 'Profile',
                                  onTap: () {
                                    Navigator.pop(context); // Close the drawer first
                                    Future.microtask(() {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                                    });
                                  },

                                ),
                                _buildDrawerItem(
                                  icon: Icons.fingerprint,
                                  label: 'Attendance',
                                  onTap: () {
                                    Navigator.pop(context); // Close the drawer first
                                    Future.microtask(() {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendancePage()));
                                    });
                                  },
                                ),

                                if (AppState().ovUsername.isNotEmpty && AppState().ovPassword.isNotEmpty) _buildDrawerItem(
                                  icon: Icons.sensors,
                                  label: 'Network Monitor',
                                  onTap: () {
                                    Navigator.pop(context); // Close the drawer first
                                    Future.microtask(() {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SensorPage()));
                                    });
                                  },
                                ),

                                if (AppState().isManager)
                                  _buildDrawerItem(
                                  icon: Icons.bar_chart,
                                  label: 'Department',
                                  onTap: () {
                                    Navigator.pop(context); // Close the drawer first
                                    Future.microtask(() {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DepartmentPage()));
                                      // Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApplicationPage()));
                                    });
                                  },
                                ),

                                if (AppState().isManager)
                                _buildDrawerItem(
                                  icon: Icons.people,
                                  label: 'Team Request',
                                  onTap: () {
                                    Navigator.pop(context); // Close the drawer first
                                    Future.microtask(() {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerTeamRequestsPage(managerId: AppState().userId)));
                                      // Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApplicationPage()));
                                    });
                                  },
                                ),

                                if (canAccessMonthlyAttendance)
                                  _buildDrawerItem(
                                    icon: Icons.calendar_month,
                                    label: 'Monthly Attendance',
                                    onTap: () {
                                      Navigator.pop(context); // Close the drawer first
                                      Future.microtask(() {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyAttendancePage()));
                                      });
                                    },
                                  ),

                                if (canAccessDailyAttendance)
                                _buildDrawerItem(
                                  icon: Icons.calendar_today,
                                  label: 'Daily Attendance',
                                  onTap: () {
                                    Navigator.pop(context); // Close the drawer first
                                    Future.microtask(() {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailedAttendancePage()));
                                    });
                                  },
                                ),

                              ],
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        _buildDrawerItem(
                          icon: Icons.logout_outlined,
                          label: 'Sign Out',
                          onTap: _showSignOutDialog,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        body: Container(
          decoration: BoxDecoration(
              gradient: AppState().bodyGradient
          ),
          child: SafeArea(
            child: SizedBox.expand(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeSection(),
                        const SizedBox(height: 24),
                        _buildSlidingFeatureCardsSection(),
                        const SizedBox(height: 24),
                        _buildQuickActionsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.waving_hand, color: Colors.yellow, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Welcome, ${appState.userName.split(' ').first}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcome to the Conexia World\nEmployee Portal',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.green, size: 12),
                    SizedBox(width: 6),
                    Text(
                      'App Status: Connected',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // for diwali purpose
  // Widget _buildSlidingFeatureCardsSection() {
  //   final highlights = [
  //     // Diwali-themed features celebrating the Festival of Lights
  //     {'icon': Icons.celebration, 'title': 'Festival Spirit', 'desc': 'Join the Diwali celebration with fun activities and contests.'},
  //
  //     {'icon': Icons.emoji_events, 'title': 'Ethnic Wear Contest', 'desc': 'Showcase your traditional attire and win exciting prizes.'},
  //
  //     {'icon': Icons.games, 'title': 'Tambola Game', 'desc': 'Participate in the exciting Tambola game starting at 3 PM.'},
  //
  //     {'icon': Icons.restaurant, 'title': 'Festive Snacks', 'desc': 'Enjoy delicious traditional sweets and snacks together.'},
  //
  //     {'icon': Icons.lightbulb, 'title': 'Light & Joy', 'desc': 'Celebrate the victory of light over darkness this Diwali.'},
  //   ];
  //
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Padding(
  //         padding: EdgeInsets.symmetric(horizontal: 16),
  //         child: Text(
  //           '🪔 Diwali Office Celebration 🪔',
  //           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  //         ),
  //       ),
  //       const SizedBox(height: 12),
  //       SizedBox(
  //         height: 220,
  //         child: PageView.builder(
  //           controller: _pageController,
  //           itemCount: highlights.length,
  //           itemBuilder: (context, index) {
  //             final item = highlights[index];
  //
  //             return Container(
  //               margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //               padding: const EdgeInsets.all(20),
  //               decoration: BoxDecoration(
  //                 gradient: LinearGradient(
  //                   colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
  //                   begin: Alignment.topLeft,
  //                   end: Alignment.bottomRight,
  //                 ),
  //                 borderRadius: BorderRadius.circular(20),
  //                 boxShadow: const [
  //                   BoxShadow(
  //                     color: Colors.black12,
  //                     blurRadius: 8,
  //                     offset: Offset(0, 5),
  //                   ),
  //                 ],
  //               ),
  //               child: Column(
  //                 mainAxisAlignment: MainAxisAlignment.center,
  //                 children: [
  //                   Icon(item['icon'] as IconData, size: 40, color: Colors.white),
  //                   const SizedBox(height: 12),
  //                   Text(item['title'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
  //                   const SizedBox(height: 8),
  //                   Text(item['desc'].toString(), style: const TextStyle(fontSize: 14, color: Colors.white70), textAlign: TextAlign.center),
  //                 ],
  //               ),
  //             );
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildSlidingFeatureCardsSection() {
    final highlights = [
      // Option 2: Replaces 'Secured Access' with data integrity and trust.
      {'icon': Icons.lock_outline, 'title': 'Data Accuracy', 'desc': 'Ensure precise and verifiable attendance records.'},

      // Option 1: Replaces 'Fast Network' with a focus on convenience and ease.
      {'icon': Icons.fingerprint, 'title': 'Easy Punch-in', 'desc': 'Effortless attendance marking with a simple tap.'},

      {'icon': Icons.schedule, 'title': '24/7 Uptime', 'desc': 'Stay connected anytime, anywhere without interruption.'},
      {'icon': Icons.support_agent, 'title': 'IT Support', 'desc': 'Dedicated support for all your technical needs.'},
      {'icon': Icons.group, 'title': 'Team First', 'desc': 'Collaboration and productivity tools for your team.'},
      // {'icon': Icons.location_on, 'title': 'Geo Tracking', 'desc': 'Location-based monitoring for accountability.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Key Features',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: highlights.length,
            itemBuilder: (context, index) {
              final item = highlights[index];

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'] as IconData, size: 40, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(item['title'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(item['desc'].toString(), style: const TextStyle(fontSize: 14, color: Colors.white70), textAlign: TextAlign.center),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }



  Widget _buildGridHighlightsSection() {
    final highlights = [
      {'icon': Icons.speed, 'label': 'Fast Network'},
      {'icon': Icons.verified_user, 'label': 'Secured'},
      {'icon': Icons.schedule, 'label': '24/7 Uptime'},
      {'icon': Icons.group, 'label': 'Team First'},
      {'icon': Icons.location_on, 'label': 'Geo Tracking'},
      {'icon': Icons.support_agent, 'label': 'IT Support'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Features',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: highlights.map((item) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['icon'] as IconData, size: 32, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(item['label'].toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  Widget _buildFeatureHighlightsSection() {
    final highlights = [
      {
        'icon': Icons.wifi,
        'title': '99.9% Uptime',
        'subtitle': 'Reliable fiber network'
      },
      {
        'icon': Icons.shield_outlined,
        'title': 'Secure Access',
        'subtitle': 'Protected employee network'
      },
      {
        'icon': Icons.people_alt_outlined,
        'title': '120+ Employees',
        'subtitle': 'Growing strong'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Highlights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: highlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = highlights[index];
              return Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.blue.shade200],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item['icon'] as IconData, size: 40, color: Colors.blueAccent),
                    const SizedBox(height: 12),
                    Text(
                      item['title'].toString(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['subtitle'].toString(),
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildCarouselSection() {
    return CarouselSlider(
      options: CarouselOptions(
        height: 180,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 4),
        enlargeCenterPage: true,
        viewportFraction: 0.9,
      ),
      items: _carouselImages.map((imageUrl) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'High-Speed Internet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Fiber Optic Technology',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActionsSection() {
    bool showNetwork = AppState().ovUsername.isNotEmpty && AppState().ovPassword.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Attendance Card
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.fingerprint,
                title: 'Attendance',
                subtitle: 'Mark your presence',
                color: Colors.indigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendancePage()),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Network Monitoring Card OR placeholder
            Expanded(
              child: showNetwork
                  ? _buildQuickActionCard(
                icon: Icons.sensors,
                title: 'Network',
                subtitle: 'Monitor device status',
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SensorPage()),
                ),
              ) : const SizedBox.shrink(), // Keeps the width space reserved
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(AppState appState) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade400, Colors.blueAccent.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(50)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: (appState.userAvatar.isNotEmpty)
                  ? NetworkImage(appState.userAvatar)
                  : null,
              backgroundColor: (appState.userAvatar.isEmpty)
                  ? (appState.userName.isNotEmpty)
                  ? _isNumeric(appState.userName)
                  ? Colors.blueGrey // Background for numeric-only names
                  : getColorForLetter(getFirstValidLetter(appState.userName)?.toUpperCase() ?? '')
                  : Colors.grey // For null or empty names
                  : Colors.transparent,
              child: (appState.userAvatar.isEmpty)
                  ? (getFirstValidLetter(appState.userName) != null
                  ? Text(
                getFirstValidLetter(appState.userName)!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ))
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              appState.userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            if (appState.empCode.isNotEmpty) Text(
              "Employee Code: ${appState.empCode}",
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ) else Text(
              appState.userEmail,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            )

          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withOpacity(0.8)),
      title: Text(label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      minLeadingWidth: 24,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.transparent,
      hoverColor: Colors.white.withOpacity(0.1),
      splashColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }


  bool _isNumeric(String input) {
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(input);
  }

  // Function to get background color based on the first letter
  Color getColorForLetter(String letter) {
    if (letter.isEmpty) return Colors.grey; // Default color if letter is empty

    switch (letter.toUpperCase()) {
      case 'A':
      case 'B':
      case 'C':
        return Colors.blue.shade400;
      case 'D':
      case 'E':
      case 'F':
        return Colors.orange.shade400;
      case 'G':
      case 'H':
      case 'I':
        return Colors.green.shade400;
      case 'J':
      case 'K':
      case 'L':
        return Colors.brown.shade300;
      case 'M':
      case 'N':
      case 'O':
        return Colors.teal.shade300;
      case 'P':
      case 'Q':
      case 'R':
        return Colors.red.shade400;
      case 'S':
      case 'T':
      case 'U':
        return Colors.yellow.shade700;
      case 'V':
      case 'W':
      case 'X':
        return Colors.purple.shade300;
      case 'Y':
      case 'Z':
        return Colors.pink.shade300; // 'Rose' color
      default:
        return Colors.blueGrey; // Default color for unexpected input
    }
  }

  // Helper function to get the first valid letter
  String? getFirstValidLetter(String? input) {
    if (input == null || input.isEmpty) return null;

    for (int i = 0; i < input.length; i++) {
      if (RegExp(r'[A-Za-z]').hasMatch(input[i])) {
        return input[i].toUpperCase();
      }
    }
    return null; // Return null if no valid letter is found
  }


  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

}
