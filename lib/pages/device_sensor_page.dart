import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:mnr/pages/port_sensor_page.dart';
import '../models/app_state.dart';

class DeviceSensorPage extends StatefulWidget {
  final String deviceId;

  const DeviceSensorPage({super.key, required this.deviceId});

  @override
  _DeviceSensorPageState createState() => _DeviceSensorPageState();
}

class _DeviceSensorPageState extends State<DeviceSensorPage> {
  bool loading = true;
  List<Map<String, dynamic>> ports = [];
  List<Map<String, dynamic>> temperatureSensors = [];
  String errorMessage = '';
  int _requestCounter = 0;
  String switchLocation = 'Loading Switch...';
  final Map<String, String> _portLocationsCache = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isTemperatureRefreshing = false;
  DateTime? _lastTemperatureRefreshTime;
  bool _portLocationsLoading = true;



  @override
  void initState() {
    super.initState();
    fetchDeviceDetails();
  }

  Future<void> refreshCookie() async {
    setState(() {
      loading = true;
    });

    final obsid = await AppState().loginAndGetCookie();
    AppState().cookie = 'OBSID=$obsid';

    await fetchDeviceDetails();
  }

  Future<void> fetchDeviceDetails() async {
    try {

      final url = Uri.parse('http://103.44.18.4/${widget.deviceId}');
      final credentials = base64Encode(
        utf8.encode('${AppState().ovUsername}:${AppState().ovPassword}'),
      );

      final response = await http.get(
        url,
        headers: {
          HttpHeaders.authorizationHeader: 'Basic $credentials',
          HttpHeaders.cookieHeader: AppState().cookie,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} - Failed to load device data');
      }

      final document = parser.parse(response.body);

      // Extract location
      final locationAnchor = document.querySelector('tr.up td a[href*="devices/location="], tr.error td a[href*="devices/location="]');
      switchLocation = locationAnchor?.text.trim() ?? 'Location not available';

      final portSections = document.querySelectorAll('.box.box-solid');

      List<Map<String, dynamic>> parsedPorts = [];
      List<Map<String, dynamic>> parsedTemperatureSensors = [];

      Map<String, dynamic>? currentPort;

      for (var section in portSections) {
        final header = section.querySelector('.box-header h3');
        final headerTitle = header?.text.trim().toLowerCase() ?? '';
        final isTemperature = headerTitle.contains('temperature');
        final rows = section.querySelectorAll('tbody tr');

        currentPort = null;

        for (var row in rows) {
          // Header row (either for ports or temperature sections)
          if (row.querySelector('td[colspan="6"].entity') != null) {
            final link = row.querySelector('a.entity-popup');
            final href = link?.attributes['href'] ?? '';
            final portName = link?.text.trim() ?? 'Unknown Port';
            final labels = row.querySelectorAll('span.label')
                .map((e) => e.text.trim()).toList();

            currentPort = {
              'name': portName,
              'href': href,
              'labels': labels,
              'sensors': <Map<String, dynamic>>[],
              'isTemperature': isTemperature,
            };

            if (!isTemperature) {
              parsedPorts.add(currentPort);
            }
          }

          // Sensor row
          else if (row.classes.contains('up') || row.classes.contains('error')) {
            final cells = row.querySelectorAll('td');
            if (cells.length >= 4) {
              final sensor = {
                'name': cells[1].querySelector('a')?.text.trim() ?? 'Unknown',
                'value': cells[3].querySelector('.label')?.text.trim() ?? 'N/A',
                'graphUrl': cells[2].querySelector('img')?.attributes['src'] ?? '',
              };

              if (isTemperature) {
                parsedTemperatureSensors.add(sensor);
              } else if (currentPort != null) {
                (currentPort['sensors'] as List<Map<String, dynamic>>).add(sensor);
              }
            }
          }
        }
      }

      setState(() {
        ports = parsedPorts;
        temperatureSensors = parsedTemperatureSensors;
        loading = false;
        errorMessage = '';
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Failed to load device data';
        // errorMessage = '''Failed to load device data:${e is FormatException ? 'Invalid server response' : e.toString()}''';
      });
      if (kDebugMode) print('Error details: $e');
    }
  }



  Widget _buildContent() => GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _buildSearchBar(),
        ),
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            children: [
              if (temperatureSensors.isNotEmpty)
                _buildTemperatureCard(),
              ..._filteredPorts(ports).map((port) => _buildPortCard(port)),
            ],
          ),
        ),
      ],
    ),
  );



  bool get _isInCooldown {
    if (_lastTemperatureRefreshTime == null) return false;
    return DateTime.now().difference(_lastTemperatureRefreshTime!) <
        const Duration(seconds: 10);
  }

// Update the temperature card widget
  Widget _buildTemperatureCard() {
    const iconColor = Colors.blue;
    final iconBgColor = iconColor.withOpacity(0.1);
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _isTemperatureRefreshing
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.thermostat, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Switch Temperature Sensor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  color: Colors.red,
                  onPressed: () {
                    if (_isTemperatureRefreshing) return;

                    if (_isInCooldown) {
                      final secondsLeft = 10 -
                          DateTime.now().difference(_lastTemperatureRefreshTime!).inSeconds;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please wait ${secondsLeft}s before refreshing again.'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      _refreshTemperatureSensors();
                    }
                  },

                ),
              ],
            ),
            if (_isTemperatureRefreshing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(color: Colors.red),
              ),
            const SizedBox(height: 8),
            if (temperatureSensors.isEmpty)
              const Text('No temperature sensors available.'),
            ...temperatureSensors.map((sensor) => _buildSensorTile(sensor)),
          ],
        ),
      ),
    );
  }




  Widget _buildPortCard(Map<String, dynamic> port) {
    final portUrl = 'http://103.44.18.4/${port['href']}view=sensors/';

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.shade100),
      ),
      child: ListTile(
        // leading: Icon(
        //   port['isTemperature'] ? Icons.thermostat : Icons.settings_ethernet,
        //   color: port['isTemperature'] ? Colors.red : Colors.purple,
        // ),
        title: Text(
          port['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: port['isTemperature'] ? Colors.red.shade800 : Colors.purple.shade800,
          ),
        ),
        subtitle: _fetchPortLocation(portUrl),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PortSensorPage(portUrl: portUrl),
            ),
          );
        },
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Widget _fetchPortLocation(String portUrl) {
    if (_portLocationsCache.containsKey(portUrl)) {
      return Text(
        _portLocationsCache[portUrl] ?? 'Location not specified',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return FutureBuilder<String>(
      future: _getPortLocationFromUrl(portUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading location...',
              style: TextStyle(fontSize: 12, color: Colors.grey));
        }
        if (snapshot.hasError) {
          return Text('Location unavailable',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700));
        }

        final location = snapshot.data ?? 'Location not specified';
        _portLocationsCache[portUrl] = location;

        // If all ports are cached now, update the loading flag
        if (_portLocationsCache.length >= ports.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _portLocationsLoading = false;
              });
            }
          });
        }

        return Text(
          location,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }


  Future<String> _getPortLocationFromUrl(String url) async {
    // Create sequential delay
    final delayDuration = Duration(milliseconds: _requestCounter * 500);
    _requestCounter++;

    await Future.delayed(delayDuration);

    try {
      final credentials = base64Encode(
        utf8.encode('${AppState().ovUsername}:${AppState().ovPassword}'),
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {
          HttpHeaders.authorizationHeader: 'Basic $credentials',
          HttpHeaders.cookieHeader: AppState().cookie,
        },
      );

      // Keep existing parsing logic
      if (response.statusCode != 200) {
        return 'HTTP Error ${response.statusCode}';
      }

      final document = parse(response.body);
      // final portRow = document.querySelector('tr.ok, tr.error, tr.disabled');

      final locationElement = document.querySelector(
        'tr.ok td[style*="min-width: 250px;"] span.small, tr.error td[style*="min-width: 250px;"] span.small, tr.disabled td[style*="min-width: 250px;"] span.small',
      );

      final location = locationElement?.text.trim();

      if (location != null) {
        // final mainTd = portRow.querySelector('td[style*="min-width: 250px;"]');
        // final locationSpan = mainTd?.querySelector('span.small');
        //
        // final location = locationSpan?.text
        //     .replaceAll(RegExp(r'\s+'), ' ')
        //     .trim() ?? '';

        return location.isNotEmpty ? location : 'No location available';
      }

      return 'Location data not found';
    } catch (e) {
      if (kDebugMode) print('Location fetch error: $e');
      return 'Error loading location';
    }
  }


  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
      child: TextField(
        controller: _searchController,
        enabled: !_portLocationsLoading,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          // hintText: 'Search Ports by Name',
          hintText: ports.isNotEmpty ? _portLocationsLoading ? 'Loading locations...' : 'Search Ports by Name' : 'Ports Unavailable',

          prefixIcon: const Icon(Icons.search, color: Colors.purple),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.purple.shade100),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthImage(String url) {
    final credentials = base64Encode(
      utf8.encode('${AppState().ovUsername}:${AppState().ovPassword}'),
    );

    return Image.network(
      'http://103.44.18.4/$url',
      headers: {
        HttpHeaders.authorizationHeader: 'Basic $credentials',
        HttpHeaders.cookieHeader: AppState().cookie,
      },
      width: 100,
      height: 30,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
    );
  }


// Keep _fetchPortLocation and _getPortLocationFromUrl methods as they are

  Color _getLabelColor(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('syrotech')) return Colors.blue.shade800;
    if (lowerLabel.contains('goxs')) return Colors.orange.shade800;
    if (lowerLabel.contains('sn:')) return Colors.green.shade800;
    return Colors.grey.shade600;
  }

  Widget _buildSensorTile(Map<String, dynamic> sensor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(
        sensor['name'],
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: sensor['graphUrl'].toString().isNotEmpty
          ? _buildAuthImage(sensor['graphUrl'])
          : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(sensor['value']),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          sensor['value'],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _getStatusColor(String value) {
    // Trim whitespace and normalize case
    final cleanValue = value.trim().toLowerCase();

    if (cleanValue.contains('dbm')) {
      final numericString = cleanValue.replaceAll('dbm', '');
      final numericValue = double.tryParse(numericString) ?? 0;
      return numericValue > -20 ? Colors.orange : Colors.green;
    }
    if (cleanValue.contains('ma')) return Colors.blue.shade700;
    if (cleanValue.contains('v')) return Colors.purple.shade700;
    if (cleanValue.contains('°c') || cleanValue.contains('c')) return Colors.red.shade700;
    return Colors.grey.shade600;
  }

  // Widget _buildLoadingState() => Column(
  //   mainAxisAlignment: MainAxisAlignment.center,
  //   children: [
  //     const CircularProgressIndicator(),
  //     const SizedBox(height: 20),
  //     Text('Loading sensor data...',
  //         style: TextStyle(color: Colors.purple.shade600)),
  //   ],
  // );

  Widget _buildLoadingState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Loading sensor data...',
          style: TextStyle(
            color: Colors.blueGrey.shade700,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 20),
          Text(errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: refreshCookie,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Future<void> _refreshTemperatureSensors() async {
    if (_isInCooldown) return; // Prevent refresh if in cooldown

    setState(() {
      _isTemperatureRefreshing = true;
      _lastTemperatureRefreshTime = DateTime.now();
    });

    try {
      final url = Uri.parse('http://103.44.18.4/${widget.deviceId}');
      final credentials = base64Encode(
        utf8.encode('${AppState().ovUsername}:${AppState().ovPassword}'),
      );

      final response = await http.get(
        url,
        headers: {
          HttpHeaders.authorizationHeader: 'Basic $credentials',
          HttpHeaders.cookieHeader: AppState().cookie,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to refresh temperature data');
      }

      final document = parser.parse(response.body);
      final portSections = document.querySelectorAll('.box.box-solid');
      List<Map<String, dynamic>> newTemperatureSensors = [];

      for (var section in portSections) {
        final header = section.querySelector('.box-header h3');
        final headerTitle = header?.text.trim().toLowerCase() ?? '';
        if (!headerTitle.contains('temperature')) continue;

        final rows = section.querySelectorAll('tbody tr');

        for (var row in rows) {
          if (row.classes.contains('up') || row.classes.contains('error')) {
            final cells = row.querySelectorAll('td');
            if (cells.length >= 4) {
              newTemperatureSensors.add({
                'name': cells[1].querySelector('a')?.text.trim() ?? 'Unknown',
                'value': cells[3].querySelector('.label')?.text.trim() ?? 'N/A',
                'graphUrl': cells[2].querySelector('img')?.attributes['src'] ?? '',
              });
            }
          }
        }
      }

      setState(() {
        temperatureSensors = newTemperatureSensors;
      });
    } catch (e) {
      if (kDebugMode) print('Temperature refresh error: $e');
    } finally {
      setState(() => _isTemperatureRefreshing = false);
    }
  }


  List<Map<String, dynamic>> _filteredPorts(List<Map<String, dynamic>> list) {
    if (_searchQuery.isEmpty) return list;

    return list.where((port) {
      final name = port['name'].toString().toLowerCase();
      final portUrl = 'http://103.44.18.4/${port['href']}view=sensors/';
      final location = _portLocationsCache[portUrl]?.toLowerCase() ?? '';

      return name.contains(_searchQuery) || location.contains(_searchQuery);
    }).toList();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     switchLocation,
      //     overflow: TextOverflow.ellipsis,
      //     maxLines: 1,
      //     // style: const TextStyle(fontSize: 18),
      //     style: TextStyle(
      //       color: Colors.white,
      //       // fontWeight: FontWeight.bold,
      //       fontSize: 18,
      //     ),
      //   ),
      //   // centerTitle: true,
      //   backgroundColor: Colors.transparent,
      //   flexibleSpace: Container(
      //     decoration: BoxDecoration(
      //       gradient: LinearGradient(
      //         colors: [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
      //         begin: Alignment.topLeft,
      //         end: Alignment.bottomRight,
      //       ),
      //     ),
      //   ),
      // ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: Text(
            switchLocation,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),

          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: loading
            ? _buildLoadingState()
            : errorMessage.isNotEmpty
            ? _buildErrorState()
            : _buildContent(),
      ),
    );
  }


  @override
  void dispose() {
    _requestCounter = 0; // Reset counter when widget disposes
    _searchController.dispose();
    super.dispose();
  }
}