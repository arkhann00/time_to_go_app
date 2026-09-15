enum RegionCheckStatus { success, unavailable }

class RegionCheckResponse {
  final RegionCheckStatus checkStatus;
  final bool shouldWarn;
  final List<String> warningReasons;
  final String? warningMessage;
  final String? countryCode;
  final bool? isInRussia;
  final bool? vpnDetected;
  final bool? proxyDetected;
  final bool? torDetected;

  const RegionCheckResponse({
    required this.checkStatus,
    required this.shouldWarn,
    required this.warningReasons,
    this.warningMessage,
    this.countryCode,
    this.isInRussia,
    this.vpnDetected,
    this.proxyDetected,
    this.torDetected,
  });

  bool get shouldShowWarning =>
      checkStatus == RegionCheckStatus.success && shouldWarn;

  factory RegionCheckResponse.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['warning_reasons'];
    return RegionCheckResponse(
      checkStatus: json['check_status'] == 'success'
          ? RegionCheckStatus.success
          : RegionCheckStatus.unavailable,
      shouldWarn: json['should_warn'] == true,
      warningReasons: rawReasons is List
          ? rawReasons.whereType<String>().toList(growable: false)
          : const [],
      warningMessage: json['warning_message'] as String?,
      countryCode: json['country_code'] as String?,
      isInRussia: json['is_in_russia'] as bool?,
      vpnDetected: json['vpn_detected'] as bool?,
      proxyDetected: json['proxy_detected'] as bool?,
      torDetected: json['tor_detected'] as bool?,
    );
  }
}
