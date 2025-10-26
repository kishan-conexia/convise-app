class Warning {
  final String device;
  final String status;
  final String port;
  final String rx;
  final bool isError;

  Warning({
    required this.device,
    required this.status,
    required this.port,
    required this.rx,
    required this.isError,
  });
}