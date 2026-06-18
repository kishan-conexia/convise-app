import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';

import 'package:ntp/ntp.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

import '../main.dart';
import 'device.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // --- Access Control Sets ---
  final Set<int> allowedMonthlyAttendanceDepartments = {1, 30, 301, 302, 303};
  final Set<int> allowedDailyAttendance = {1, 30, 301, 303};

  final Set<int> allowedSpanco = {1, 20, 201, 202, 2011, 2012, 2013, 2014, 105};

  // final Set<int> allowedFeasibility = {1, 20, 30, 103, 105, 201, 202, 303, 2011, 2012, 2013, 2014};
  final Set<int> managerOfFeasibility = {103, 105};

  final Set<int> hr_admin = {30, 301, 303, 105};

  // --- Calculated Access Booleans (Getters) ---

  bool get canAccessMonthlyAttendance {
    return managedDepartmentIds.any(allowedMonthlyAttendanceDepartments.contains);
  }

  bool get canAccessDailyAttendance {
    return managedDepartmentIds.any(allowedDailyAttendance.contains);
  }

  // bool get canAccessFeasibility {
  //   // Check if the departmentId is not null AND if it is contained in the allowedFeasibility set.
  //   return departmentId != null && allowedFeasibility.contains(departmentId);
  // }

  bool get canManageFeasibility {
    return managedDepartmentIds.any(managerOfFeasibility.contains);
  }

  bool get canAccessProfileRequest {
    return managedDepartmentIds.any(hr_admin.contains);
  }

  bool get canAccessSpanco {
    // Check if the departmentId is not null AND if it is contained in the allowedFeasibility set.
    return departmentId != null && allowedSpanco.contains(departmentId);
  }

  final Gradient appBarGradient = LinearGradient(
    colors: [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final Gradient bodyGradient = LinearGradient(
    colors: [Colors.blue.shade50, Colors.blue.shade100],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Add anywhere in AppState class
  bool get isTestAccount => empCode == 'app_test';

  final user = supabase.auth.currentUser;

  Map<String, dynamic> employeeProfile = {};
  Map<String, dynamic>? workSchedule;

  String userId = '';
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String empCode = '';
  String userAvatar = '';
  String ovUsername = '';
  String ovPassword = '';
  int? departmentId;
  bool isManager = false;

  bool? appAccess;

  String imageLinks = '';
  String updateType = '';
  int currentVersion = 0;
  int minVersion = 0;
  int maxVersion = 0;

  String deviceId = '';
  Map<String, dynamic> deviceData = {};
  bool deviceChanged = false;

  bool? geofencing;


  String cookie = '';
  List<Device> devices = [];


  List<dynamic> plans = [];
  List<dynamic> faqs = [];
  List<int> managedDepartmentIds = [];

  bool initialized = false;

  Future<void> initialize() async {

    await Future.delayed(const Duration(seconds: 2));

    await _checkAppVersion();
    if (updateType.isNotEmpty){
      appAccess = false;
      return;
    }

    await _getCurrentDeviceId();
    await fetchUserProfileId();

    if (deviceChanged){
      return;
    }

    initialized = true;
    notifyListeners();
  }

  Future<void> _checkAppVersion() async {
    try {
      // Fetch the app's build number (version code)
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion = int.parse(packageInfo.buildNumber); // e.g., 10

      // Fetch the configuration for the app version from Supabase
      final response = await supabase
          .from('user_app_config')
          .select('min_version, max_version, force_update, image_links')
          .eq('id', 1) // Adjust this for iOS if needed
          .maybeSingle();

      if (response != null) {
        minVersion = response['min_version'] ?? 0;
        maxVersion = response['max_version'] ?? 0;
        imageLinks = response['image_links'] ?? '';
        final maxForceUpdate = response['force_update'] ?? false;

        if (currentVersion < minVersion) {
          // Handle version lower than min_version
          updateType = 'min_version';
          // _showUpdateDialog("App version is too old. Please update the app.");
        } else if (maxForceUpdate && currentVersion < maxVersion) {
          // Handle version higher than max_version (optional check)
          updateType = 'force_update';
          // _showUpdateDialog("Your app version is not supported anymore. Please update.");
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print("Error checking app version: $error");
      }
    }
  }

  Future<DateTime> getCurrentTime() async {
    DateTime now = await getOnlineDateTime();
    // DateTime currentTime = now.add(const Duration(minutes: 330));
    return now;
  }


  Future<DateTime> getOnlineDateTime() async {
    try {
      DateTime currentTime = await NTP.now();

      return currentTime;
    } catch (e) {
      // print('Error fetching time: $e');
      return fetchSupabaseDateTime(); // Fallback to device time in case of an error
    }
  }

  Future<DateTime> fetchSupabaseDateTime() async {
    try {
      // Use Supabase to fetch current time
      final response = await supabase.rpc('get_supabase_time');

      if (response != null) {
        return DateTime.parse(response as String);
      } else {
        throw Exception('Failed to fetch time');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching time');
      }
      throw Exception('All time-fetching methods failed');
    }
  }

  // Method to fetch the current device ID
  // Future<void> _getCurrentDeviceId() async {
  //   final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //
  //   if (Platform.isAndroid) {
  //     AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  //     deviceId = androidInfo.id ?? ''; // Unique Android ID
  //   } else if (Platform.isIOS) {
  //     IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
  //     deviceId = iosInfo.identifierForVendor ?? ''; // Unique iOS ID
  //   } else {
  //     throw UnsupportedError('Unsupported platform');
  //   }
  // }

  Future<void> _getCurrentDeviceId() async {
    final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

    final packageInfo = await PackageInfo.fromPlatform();
    String? _appVersion = packageInfo.version;

    try {

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          deviceData = {
            'platform': 'Android',
            'model': androidInfo.model,
            'manufacturer': androidInfo.manufacturer,
            // 'version': androidInfo.version.release,
            // 'sdk_int': androidInfo.version.sdkInt,
          };
          deviceId = androidInfo.id ?? '';
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceData = {
            'platform': 'iOS',
            'model': iosInfo.model,
            'name': iosInfo.name,
            // 'system_version': iosInfo.systemVersion,
          };
          deviceId = iosInfo.identifierForVendor ?? '';
        }
      } else {
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceData = {
          'platform': 'Web',
          'browser': webInfo.browserName.toString(),
          'user_agent': webInfo.userAgent,
        };
      }
    } catch (e) {
      debugPrint('Failed to initialize ErrorLogger: $e');
      // Set a default device data in case of initialization failure
      deviceData = {
        'platform': kIsWeb ? 'Web (Init Failed)' : 'Mobile/IOS (Init Failed)',
        'error': e.toString(),
        'app_version': _appVersion, // Still try to get app version
      };
    }
  }


  Future<void> fetchUserProfileId() async {
    if (user != null) {
      final userResponse = await supabase
          .from('profiles')
          .select()
          .eq('id', user!.id)
          .maybeSingle();

      if (userResponse!.isEmpty) {
        // Insert a new profile if both responses are empty
        await supabase.from('profiles').insert({
          'id': user!.id,
          'email': user!.email!,
          'full_name': user!.userMetadata?['full_name'],
          'avatar_url': user!.userMetadata?['avatar_url'],
          'device_info': deviceData,
        });
        // Set default values after insertion
        userId = user!.id;
        userEmail = user!.email!;
        userName = user!.userMetadata?['full_name'] ?? '';
        userAvatar = user!.userMetadata?['avatar_url'] ?? '';

      } else {
        userId = user!.id;
        userEmail = user!.email!;
        userName = userResponse['full_name'] ?? '';
        userPhone = userResponse['phone'] ?? '';
        empCode = userResponse['employee_code'] ?? '';
        userAvatar = userResponse['avatar_url'] ?? '';
        appAccess = userResponse['app_access'];
        ovUsername = userResponse['ov_username'] ?? '';
        ovPassword = userResponse['ov_password'] ?? '';
        geofencing = userResponse['geofencing'];
        departmentId = userResponse['department'];

        final storedInfo = Map<String, dynamic>.from(userResponse['device_info'] ?? {});
        final currentInfo = deviceData ?? {};

        // ── Skip device check for test account ──────────────────
        final isTestAccount = (userResponse['employee_code'] ?? '') == 'app_test';

        if (!isTestAccount) {
          if (userResponse['device_info'] == null || userResponse['device_info'] == '') {
            await _updateDeviceId();
          } else if (!mapEquals(storedInfo, currentInfo)) {
            deviceChanged = true;
            await _newDeviceId();
          }
        }

        employeeProfile = userResponse;

        // Check if user is a manager of any department
        final managerDepartments = await supabase
            .from('departments')
            .select('id')
            .eq('manager_id', user!.id)
            .eq('is_active', true);

        if (managerDepartments.isNotEmpty) {
          isManager = true;
          // Store managed department IDs
          managedDepartmentIds = managerDepartments.map((d) => d['id'] as int).toList();
        }

      }
    }
  }

  Future<void> _updateDeviceId() async {
    try {
      // Update the device_info column in the 'khaiwals' table
      final response = await supabase.from('profiles').update({
        'device_info': deviceData,
      }).eq('id', userId);

      if (response != null) {
        throw Exception('Failed to update device ID: $response');
      }

      notifyListeners(); // Notify listeners about the change
    } catch (error) {
      throw Exception('Error updating device ID');
    }
  }

  Future<void> _newDeviceId() async {
    try {
      // Update the device_info column in the 'khaiwals' table
      final response = await supabase.from('profiles').update({
        'new_device_info': deviceData, // Set the current device ID
      }).eq('id', userId);

      if (response != null) {
        throw Exception('Failed to update device ID: $response');
      }

      notifyListeners(); // Notify listeners about the change
    } catch (error) {
      throw Exception('Error updating device ID');
    }
  }

  Future<String?> loginAndGetCookie() async {
    final loginUri = Uri.parse('http://103.44.18.4');

    final response = await http.post(
      loginUri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': ovUsername,
        'password': ovPassword,
      },
    );

    if (response.statusCode == 302 || response.statusCode == 200) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.contains('OBSID=')) {
        final match = RegExp(r'OBSID=([^;]+);').firstMatch(setCookie);
        return match?.group(1);
      }
    }

    return null;
  }


  Future<String> fetchObserviumHtml() async {
    final obsid = await loginAndGetCookie();

    if (obsid == null) {
      throw Exception('Login failed or OBSID not found.');
    }

    cookie = 'OBSID=$obsid';


    final uri = Uri.parse('http://103.44.18.4/devices/format=detail/pagesize=1000');

    final credentials = base64Encode(utf8.encode('$ovUsername:$ovPassword'));

    final response = await http.get(
      uri,
      headers: {
        HttpHeaders.authorizationHeader: 'Basic $credentials',
        HttpHeaders.cookieHeader: cookie,
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Request failed (HTTP ${response.statusCode})');
    }
  }


  Future<List<Device>> loadObserviumDevices() async {
    final htmlString = await fetchObserviumHtml();
    final document = parse(htmlString);

    // Select each <tr> that represents a device row:
    final rows = document.querySelectorAll('table.table-hover.table-striped tr.up, table.table-hover.table-striped tr.error');

    return rows.map((row) {
      // All <td> cells for this row
      final tds = row.querySelectorAll('td');

      // 1. Extract the openLink path: "device/device=149/"
      final onclick = row.attributes['onclick'] ?? '';
      final match = RegExp(r"openLink\('([^']+)'\)").firstMatch(onclick);
      final detailsPath = match?.group(1) ?? '';                // RegExp pull :contentReference[oaicite:6]{index=6}

      // 2. Extract device ID (digits after "device=")
      final idMatch = RegExp(r"device=(\d+)").firstMatch(detailsPath);
      final id = idMatch?.group(1) ?? '';

      // 3. Hostname: <a> text in the 3rd <td>
      final hostname = tds[2].querySelector('a')?.text.trim() ?? '';

      // 4. Location: text after the first <br> in 3rd <td>
      final locParts = tds[2].innerHtml.split('<br>');
      final location = locParts.length > 1
          ? parse(locParts[1]).documentElement!.text.trim()
          : '';

      // 5. Interfaces: first <span class="label"> in 4th <td>
      final ifaceText = tds[3].querySelector('span.label')?.text ?? '0';
      final interfaces = int.tryParse(ifaceText) ?? 0;

      // 6. OS: entire text of the 5th <td>
      final os = tds[4].text.trim();

      // 7. Uptime: first line of the 6th <td>
      final uptime = tds[5].text.split('\n').first.trim();

      return Device(
        id: id,
        hostname: hostname,
        location: location,
        interfaces: interfaces,
        os: os,
        uptime: uptime,
        detailsPath: detailsPath,
      );
    }).toList();
  }




  Future<void> resetState() async {

    userId = '';
    userName = '';
    userEmail = '';
    userPhone = '';
    userAvatar = '';

    appAccess = null;

    updateType = '';
    currentVersion = 0;
    minVersion = 0;
    maxVersion = 0;

    notifyListeners();
  }


}
