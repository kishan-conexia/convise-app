import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import '../models/app_state.dart';
import '../models/port_details.dart';

class PortSensorPage extends StatefulWidget {
  final String portUrl;

  const PortSensorPage({super.key, required this.portUrl});

  @override
  _PortSensorPageState createState() => _PortSensorPageState();
}

class _PortSensorPageState extends State<PortSensorPage> {
  List<PortDetail> ports = [];
  bool loading = true;
  String errorMessage = '';
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  String deviceLocation = 'Loading Port...';
  bool _isRefreshing = false;
  bool _isInCooldown = false;
  DateTime? _lastRefreshTime;


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_isRefreshing || _isInCooldown) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final credentials = base64Encode(
        utf8.encode('${AppState().ovUsername}:${AppState().ovPassword}'),
      );

      final response = await http.get(
        Uri.parse(widget.portUrl),
        headers: {
          HttpHeaders.authorizationHeader: 'Basic $credentials',
          HttpHeaders.cookieHeader: AppState().cookie,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} - Failed to load port data');
      }

      final document = parse(response.body);

      final locationElement = document.querySelector(
        'tr.ok td[style*="min-width: 250px;"] span.small, tr.error td[style*="min-width: 250px;"] span.small, tr.disabled td[style*="min-width: 250px;"] span.small',
      );

      final location = locationElement?.text.trim() ?? 'Location not available';

      final rows = document.querySelectorAll('table tr');

      final extractedPorts = rows.skip(1).map((row) {
        final cells = row.querySelectorAll('td');

        if (cells.length < 8 || cells[1].text.isEmpty || cells[7].text.isEmpty) {
          return null;
        }

        final graphImg = cells[4].querySelector('img');
        final graphUrl = graphImg?.attributes['src'] ?? '';

        return PortDetail(
          description: cells[1].text.trim(),
          thresholds: cells[3].text.trim(),
          graphUrl: graphUrl,
          event: cells[6].text.trim(),
          value: cells[7].text.trim(),
        );
      }).whereType<PortDetail>().toList();

    // Move Rx and Tx Power items to the top
      extractedPorts.sort((a, b) {
        bool aIsRxTx = a.description.toLowerCase().contains('rx power') ||
            a.description.toLowerCase().contains('tx power');
        bool bIsRxTx = b.description.toLowerCase().contains('rx power') ||
            b.description.toLowerCase().contains('tx power');

        if (aIsRxTx && !bIsRxTx) return -1;
        if (!aIsRxTx && bIsRxTx) return 1;
        return 0; // keep their order relative to each other
      });

      setState(() {
        deviceLocation = location;
        ports = extractedPorts;
        loading = false;
        errorMessage = '';
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Failed to load data';
        // errorMessage = 'Failed to load data: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      setState(() {
        _isRefreshing = false;
        _isInCooldown = true;
        _lastRefreshTime = DateTime.now();
      });

      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _isInCooldown = false);
        }
      });
    }
  }


  Widget _buildAuthImage(String url) {
    if (url.isEmpty) return const SizedBox.shrink();

    final credentials = base64Encode(
      utf8.encode('${AppState().ovUsername}:${AppState().ovPassword}'),
    );

    return Image.network(
      'http://103.44.18.4/$url',
      headers: {
        HttpHeaders.authorizationHeader: 'Basic $credentials',
        HttpHeaders.cookieHeader: AppState().cookie,
      },
      width: 150,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
    );
  }

  Widget _buildPortCard(PortDetail port) {
    final statusColor = _getStatusColor(port.value);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.15),
            child: Icon(Icons.sensors, color: statusColor, size: 20),
          ),
          title: Text(
            port.description,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          subtitle: const Text(
            'Tap to view details',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(1, 2),
                )
              ],
            ),
            child: Text(
              port.value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem('Thresholds', port.thresholds),
                  const SizedBox(height: 10),
                  _buildDetailItem('Event', port.event),
                  if (port.graphUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Performance Graph',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: _buildAuthImage(port.graphUrl),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String value) {
    final cleanValue = value.trim().toLowerCase();

    // Enhanced color logic
    if (cleanValue.contains('dbm')) {
      final numericValue = double.tryParse(
          cleanValue.replaceAll('dbm', '')) ?? 0;
      if (numericValue > -20) return Colors.orange;
      if (numericValue > -25) return Colors.amber;
      return Colors.green.shade700;
    }
    if (cleanValue.contains('ma')) return Colors.blue.shade700;
    if (cleanValue.contains('v')) return Colors.purple.shade700;
    if (cleanValue.contains('°c') || cleanValue.contains('c')) {
      final temp = double.tryParse(
          cleanValue.replaceAll('°c', '').replaceAll('c', '')) ?? 0;
      if (temp > 50) return Colors.red.shade800;
      if (temp > 40) return Colors.orange.shade700;
      return Colors.green.shade700;
    }
    if (cleanValue.contains('ok')) return Colors.green.shade700;
    if (cleanValue.contains('warn')) return Colors.orange.shade700;
    if (cleanValue.contains('crit')) return Colors.red.shade800;
    return Colors.grey.shade600;
  }



  Widget _buildLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Loading port sensors...',
          style: TextStyle(
            color: Colors.blueGrey.shade700,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50, color: Colors.red.shade700),
          const SizedBox(height: 20),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: refreshCookie,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Future<void> refreshCookie() async {
    setState(() {
      loading = true;
    });
    final obsid = await AppState().loginAndGetCookie();
    AppState().cookie = 'OBSID=$obsid';
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: Text(
            deviceLocation,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          // Row(
          //   children: [
          //     const Icon(Icons.settings_ethernet, color: Colors.white, size: 20),
          //     const SizedBox(width: 6),
          //     Expanded(
          //       child: Text(
          //         deviceLocation,
          //         overflow: TextOverflow.ellipsis,
          //         style: const TextStyle(
          //           color: Colors.white,
          //           fontWeight: FontWeight.w600,
          //           fontSize: 18,
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
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

      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: () async {
          if (_isInCooldown && _lastRefreshTime != null) {
            final secondsLeft =
                10 - DateTime.now().difference(_lastRefreshTime!).inSeconds;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please wait ${secondsLeft}s before refreshing again.'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          await _fetchData();
        },
        color: Colors.blueGrey.shade800,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: loading
                  ? _buildLoading()
                  : errorMessage.isNotEmpty
                  ? _buildError()
                  : ListView.builder(
                padding: const EdgeInsets.only(top: 16),
                itemCount: ports.length,
                itemBuilder: (context, index) =>
                    _buildPortCard(ports[index]),
              ),
            ),

            if (_isRefreshing && !loading)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.6),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey),
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),

    );
  }





}