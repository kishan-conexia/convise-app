import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mnr/pages/access_denied.dart';
import 'package:mnr/pages/device_info_page.dart';
import 'package:mnr/pages/info_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../main.dart';
import '../models/app_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  final _employeeCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _employeeCodeError;
  String? _passwordError;
  bool _showPassword = false;

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _bubbleController;
  late AnimationController _logoController;
  late AnimationController _buttonController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bubbleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    // Fade Controller for overall entrance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Slide Controller for form sliding up
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Scale Controller for interactive elements
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Bubble Controller for floating animation
    _bubbleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Logo Controller for logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Button Controller for button interactions
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));

    _bubbleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.linear,
    ));

    _logoRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    _fadeController.forward();
    _bubbleController.repeat();

    Future.delayed(const Duration(milliseconds: 300), () {
      _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      _slideController.forward();
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _bubbleController.dispose();
    _logoController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      await AppState().initialize();

      if (AppState().updateType.isNotEmpty) {
        _navigateToPage(InfoPage(currentVersion: AppState().currentVersion,
            minVersion: AppState().minVersion,
            maxVersion: AppState().maxVersion,
            updateType: AppState().updateType));
        return;
      }

      if (AppState().deviceChanged) {
        _navigateToPage(DeviceInfoPage(deviceId: AppState().deviceId,
            deviceChanged: AppState().deviceChanged));
        return;
      }

      // Check for app access
      if (AppState().appAccess == false) {
        _navigateToPage(AccessDeniedPage());
        return; // Terminate further navigation
      }

      _navigateToPage(const MyHomePage(title: 'Home Page'));
    } else {
      // User not logged in, stop the loading state
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handle Sign In / Sign Out
  Future<void> _onSignInOrOut() async {
    if (supabase.auth.currentUser == null) {
      // User is not signed in, sign them in
      await _signInWithGoogle();
    } else {
      _showSignOutDialog();
    }
  }

  // Method for signing in with Google
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      //  Replace with your actual client IDs
      const webClientId = '569444382878-maffbe6qjodcmt77li2ingrfocj026k5.apps.googleusercontent.com';
      const iosClientId = '569444382878-l155k7n049uep4430rp7ec0p71ujv7jt.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      // Check if a user is already signed in and disconnect if needed
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }

      // Trigger Google Sign-In
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // User canceled sign-in
      }

      // Retrieve authentication tokens
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Authentication failed: Missing access or ID token.';
      }

      // Sign in with Supabase
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Validate session
      if (response.session == null || response.user == null) {
        throw Exception('Authentication failed: No session created.');
      }

      // Check if the user is authenticated
      if (response.session != null && response.user != null) {
        await AppState().initialize();

        if (AppState().updateType.isNotEmpty) {
          _navigateToPage(InfoPage(currentVersion: AppState().currentVersion,
              minVersion: AppState().minVersion,
              maxVersion: AppState().maxVersion,
              updateType: AppState().updateType));
          return;
        }

        if (AppState().deviceChanged) {
          _navigateToPage(DeviceInfoPage(deviceId: AppState().deviceId,
              deviceChanged: AppState().deviceChanged));
          return;
        }

        // Check for app access
        if (AppState().appAccess == false) {
          _navigateToPage(AccessDeniedPage());
          return; // Terminate further navigation
        }

        _navigateToPage(const MyHomePage(title: 'Home Page'));
      } else {
        throw 'Authentication failed: No session created.';
      }
    } catch (error) {
      String errorMessage = 'Close the app completely, restart it, and try again.';

      if (error.toString().contains('Network')) {
        errorMessage =
        'It seems there\'s a network issue. Please check your connection and try again.';
      } else if (error.toString().contains('Authentication failed')) {
        errorMessage =
        'Authentication failed. Close the app, restart it, and try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showSignOutDialog() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
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

  Future<void> _onLoginPressed() async {
    // Button press animation
    _buttonController.forward().then((_) {
      _buttonController.reverse();
    });

    // Add haptic feedback
    HapticFeedback.lightImpact();

    // Validate fields manually
    setState(() {
      _employeeCodeError = _employeeCodeController.text.trim().isEmpty
          ? 'Employee code is required'
          : (_employeeCodeController.text.trim().length > 10
          ? 'Max 10 characters allowed'
          : null);

      _passwordError = _passwordController.text.trim().isEmpty
          ? 'Password is required'
          : (_passwordController.text.trim().length < 6
          ? 'Minimum 6 characters'
          : (_passwordController.text.trim().length > 20
          ? 'Maximum 20 characters'
          : null));
    });

    // Stop login if there are any errors
    if (_employeeCodeError != null || _passwordError != null) return;

    setState(() => _isLoading = true);

    String identifier = _employeeCodeController.text.trim();
    String password = _passwordController.text.trim();

    String? emailToUse;

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (emailRegex.hasMatch(identifier)) {
      // Input is email
      emailToUse = identifier;
    } else {
      // Input is assumed to be employee_code, look it up
      final response = await supabase
          .from('profiles')
          .select('email')
          .eq('employee_code', identifier)
          .maybeSingle();

      if (response == null || response['email'] == null ||
          response['email'] == '') {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid employee code.')),
        );
        return;
      }

      emailToUse = response['email'] as String;
    }

    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: emailToUse,
        password: password,
      );

      if (authResponse.session != null && authResponse.user != null) {
        await AppState().initialize();

        if (AppState().updateType.isNotEmpty) {
          _navigateToPage(InfoPage(
            currentVersion: AppState().currentVersion,
            minVersion: AppState().minVersion,
            maxVersion: AppState().maxVersion,
            updateType: AppState().updateType,
          ));
          return;
        }

        if (AppState().deviceChanged) {
          _navigateToPage(DeviceInfoPage(deviceId: AppState().deviceId,
              deviceChanged: AppState().deviceChanged));
          return;
        }

        // Check for app access
        if (AppState().appAccess == false) {
          _navigateToPage(const AccessDeniedPage());
          return; // Terminate further navigation
        }

        _navigateToPage(const MyHomePage(title: 'Home Page'));
      } else {
        throw Exception('Login failed. Invalid session.');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${error.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToPage(Widget page) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _signOut() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await supabase.auth.signOut();
      await Supabase.instance.client.dispose();

      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        // await googleSignIn.signOut();
        await googleSignIn.disconnect();
      }

      await AppState().resetState();

      setState(() {
        _isLoading = false;
      }); // Update UI
      // Close the app after successful sign out
      // SystemNavigator.pop();
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      exit(0); // Forcefully terminate the app

    } on AuthException {
      // context.showSnackBar(error.message, isError: true);
    } catch (error) {
      // context.showSnackBar('Unexpected error occurred', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        onTap: FocusScope.of(context).unfocus,
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Stack(
                children: [
                  // Animated gradient background
                  AnimatedContainer(
                    duration: const Duration(seconds: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.indigo.shade900,
                          Colors.blueAccent.shade700,
                          Colors.blue.shade300,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Animated bubbles
                  AnimatedBuilder(
                    animation: _bubbleAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: size,
                        painter: AnimatedBubblePainter(
                          animationValue: _bubbleAnimation.value,
                          size: size,
                        ),
                      );
                    },
                  ),
                  // Main content
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated logo
                            AnimatedBuilder(
                              animation: _logoController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _logoScaleAnimation.value,
                                  child: Transform.rotate(
                                    angle: _logoRotationAnimation.value,
                                    child: Hero(
                                      tag: 'app_logo',
                                      child: ShaderMask(
                                        shaderCallback: (bounds) =>
                                            LinearGradient(
                                              colors: [Colors.white, Colors.blueAccent],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ).createShader(bounds),
                                        blendMode: BlendMode.srcIn,
                                        child: SvgPicture.asset(
                                          'assets/launcher_icon.svg',
                                          height: 100,
                                          width: 100,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            // Animated title
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _slideController,
                                curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
                              )),
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: const Text(
                                  'The Conexia World',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 1.3,
                                    height: 1.3,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                        color: Colors.black26,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Animated form container
                            SlideTransition(
                              position: _slideAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      width: size.width * 0.9,
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                            color: Colors.white.withOpacity(0.25)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: _isLoading
                                          ? const SpinKitFadingCircle(
                                        color: Colors.white,
                                        size: 50.0,
                                      )
                                          : Column(
                                        children: [
                                          // Animated Employee Code Field
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            duration: const Duration(milliseconds: 800),
                                            builder: (context, value, child) {
                                              return Transform.translate(
                                                offset: Offset(0, 20 * (1 - value)),
                                                child: Opacity(
                                                  opacity: value,
                                                  child: TextField(
                                                    controller: _employeeCodeController,
                                                    maxLength: 10,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: InputDecoration(
                                                      labelText: 'Employee Code',
                                                      labelStyle: const TextStyle(color: Colors.white70),
                                                      prefixIcon: const Icon(Icons.badge, color: Colors.white70),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(15),
                                                        borderSide: const BorderSide(color: Colors.white54),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(15),
                                                        borderSide: const BorderSide(color: Colors.white, width: 2),
                                                      ),
                                                      counterText: '',
                                                    ),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        if (value.isEmpty) {
                                                          _employeeCodeError = null;
                                                        } else if (value.length > 10) {
                                                          _employeeCodeError = 'Max 10 characters allowed';
                                                        } else {
                                                          _employeeCodeError = null;
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 20),
                                          // Animated Password Field
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            duration: const Duration(milliseconds: 1000),
                                            builder: (context, value, child) {
                                              return Transform.translate(
                                                offset: Offset(0, 20 * (1 - value)),
                                                child: Opacity(
                                                  opacity: value,
                                                  child: TextField(
                                                    controller: _passwordController,
                                                    obscureText: !_showPassword,
                                                    maxLength: 20,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: InputDecoration(
                                                      labelText: 'Password',
                                                      labelStyle: const TextStyle(color: Colors.white70),
                                                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                                                      suffixIcon: IconButton(
                                                        icon: Icon(
                                                          _showPassword ? Icons.visibility_off : Icons.visibility,
                                                          color: Colors.white70,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
                                                            _showPassword = !_showPassword;
                                                          });
                                                        },
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(15),
                                                        borderSide: const BorderSide(color: Colors.white54),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(15),
                                                        borderSide: const BorderSide(color: Colors.white, width: 2),
                                                      ),
                                                      counterText: '',
                                                    ),
                                                    onChanged: (value) {
                                                      setState(() {
                                                        if (value.isEmpty) {
                                                          _passwordError = null;
                                                        } else if (value.length < 6) {
                                                          _passwordError = 'Minimum 6 characters';
                                                        } else if (value.length > 20) {
                                                          _passwordError = 'Maximum 20 characters';
                                                        } else {
                                                          _passwordError = null;
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          // Error messages with animation
                                          if (_employeeCodeError != null)
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              duration: const Duration(milliseconds: 300),
                                              builder: (context, value, child) {
                                                return Transform.scale(
                                                  scale: value,
                                                  child: Opacity(
                                                    opacity: value,
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(bottom: 10),
                                                      child: Text(
                                                        _employeeCodeError!,
                                                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          const SizedBox(height: 5),
                                          if (_passwordError != null)
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              duration: const Duration(milliseconds: 300),
                                              builder: (context, value, child) {
                                                return Transform.scale(
                                                  scale: value,
                                                  child: Opacity(
                                                    opacity: value,
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(bottom: 10),
                                                      child: Text(
                                                        _passwordError!,
                                                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          const SizedBox(height: 30),
                                          // Animated Login Button
                                          ScaleTransition(
                                            scale: _buttonScaleAnimation,
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: _isLoading ? null : _onLoginPressed,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue.shade300,
                                                  foregroundColor: Colors.indigo.shade800,
                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  elevation: 6,
                                                  shadowColor: Colors.black45,
                                                ),
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(milliseconds: 300),
                                                  child: _isLoading
                                                      ? const SizedBox(
                                                    height: 22,
                                                    width: 22,
                                                    child: SpinKitFadingCircle(color: Colors.white, size: 35.0),
                                                  )
                                                      : const Row(
                                                    key: ValueKey("login_button"),
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.login),
                                                      SizedBox(width: 8),
                                                      Text("Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
        ),
      ),
    );
  }
}

class AnimatedBubblePainter extends CustomPainter {
  final double animationValue;
  final Size size;
  final Paint bubblePaint;
  final List<BubbleData> bubbles;

  AnimatedBubblePainter({
    required this.animationValue,
    required this.size,
  }) : bubblePaint = Paint()
    ..color = Colors.white.withOpacity(0.05)
    ..style = PaintingStyle.fill,
        bubbles = List.generate(25, (index) {
          return BubbleData(
            center: Offset(
              Random(index).nextDouble() * size.width,
              Random(index + 100).nextDouble() * size.height,
            ),
            radius: Random(index + 200).nextDouble() * 40 + 10,
            speed: Random(index + 300).nextDouble() * 0.5 + 0.2,
            phase: Random(index + 400).nextDouble() * 2 * pi,
          );
        });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < bubbles.length; i++) {
      final bubble = bubbles[i];

      // Calculate animated position
      final animatedY = bubble.center.dy +
          sin(animationValue * 2 * pi * bubble.speed + bubble.phase) * 20;
      final animatedX = bubble.center.dx +
          cos(animationValue * 2 * pi * bubble.speed * 0.5 + bubble.phase) * 10;

      // Keep bubbles within bounds
      final clampedX = animatedX.clamp(0.0, size.width);
      final clampedY = animatedY.clamp(0.0, size.height);

      // Apply pulsing effect to opacity
      final pulseOpacity = 0.03 + (sin(animationValue * 2 * pi * bubble.speed + bubble.phase) * 0.02);
      bubblePaint.color = Colors.white.withOpacity(pulseOpacity);

      // Draw the animated bubble
      canvas.drawCircle(
        Offset(clampedX, clampedY),
        bubble.radius,
        bubblePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BubbleData {
  final Offset center;
  final double radius;
  final double speed;
  final double phase;

  BubbleData({
    required this.center,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}