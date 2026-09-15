# Проверка региона подключения — контракт для Flutter

## Назначение

Публичная ручка определяет страну и известные признаки VPN, proxy или Tor по
внешнему IP запроса. Авторизация не нужна. Результат предназначен только для
предупреждения: доступ к приложению блокировать нельзя, потому что GeoIP и
определение VPN могут ошибаться.

```http
GET /settings/region-check
Accept: application/json
```

IP, координаты или другие данные отправлять в query/body не нужно: backend берёт
IP из самого HTTP-запроса. Не передавайте `X-Forwarded-For` из Flutter.

## Успешный ответ из России без VPN

```json
{
  "check_status": "success",
  "country_code": "RU",
  "country_name": "Russia",
  "region": "Moscow",
  "city": "Moscow",
  "is_in_russia": true,
  "vpn_detected": false,
  "proxy_detected": false,
  "tor_detected": false,
  "should_warn": false,
  "warning_reasons": [],
  "warning_message": null
}
```

## Ответ вне России и с обнаруженным VPN

```json
{
  "check_status": "success",
  "country_code": "DE",
  "country_name": "Germany",
  "region": "Hesse",
  "city": "Frankfurt am Main",
  "is_in_russia": false,
  "vpn_detected": true,
  "proxy_detected": false,
  "tor_detected": false,
  "should_warn": true,
  "warning_reasons": ["outside_russia", "anonymizer_detected"],
  "warning_message": "Похоже, вы находитесь за пределами России и используете VPN или прокси. Приложение может работать с перебоями."
}
```

`anonymizer_detected` добавляется, если обнаружен хотя бы один из признаков:
`vpn_detected`, `proxy_detected`, `tor_detected`.

Если GeoIP-провайдер недоступен или IP локальный, backend всё равно отвечает
HTTP 200:

```json
{
  "check_status": "unavailable",
  "country_code": null,
  "country_name": null,
  "region": null,
  "city": null,
  "is_in_russia": null,
  "vpn_detected": null,
  "proxy_detected": null,
  "tor_detected": null,
  "should_warn": false,
  "warning_reasons": [],
  "warning_message": null
}
```

## Логика Flutter

Ручку достаточно вызвать после запуска приложения или возвращения из долгого
background. Показывайте неблокирующий dialog/banner только когда одновременно:

```dart
response.checkStatus == RegionCheckStatus.success && response.shouldWarn
```

Текст берите из `warning_message`. При `check_status == unavailable` ничего не
показывайте и продолжайте обычную работу приложения. Не вычисляйте предупреждение
по `country_name`: для логики используйте только `should_warn`, а причины — только
для аналитики. Не считайте `vpn_detected: false` гарантией отсутствия VPN.

Минимальная модель:

```dart
enum RegionCheckStatus { success, unavailable }

class RegionCheckResponse {
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

  final RegionCheckStatus checkStatus;
  final bool shouldWarn;
  final List<String> warningReasons;
  final String? warningMessage;
  final String? countryCode;
  final bool? isInRussia;
  final bool? vpnDetected;
  final bool? proxyDetected;
  final bool? torDetected;

  factory RegionCheckResponse.fromJson(Map<String, dynamic> json) {
    return RegionCheckResponse(
      checkStatus: json['check_status'] == 'success'
          ? RegionCheckStatus.success
          : RegionCheckStatus.unavailable,
      shouldWarn: json['should_warn'] == true,
      warningReasons: List<String>.from(json['warning_reasons'] ?? const []),
      warningMessage: json['warning_message'] as String?,
      countryCode: json['country_code'] as String?,
      isInRussia: json['is_in_russia'] as bool?,
      vpnDetected: json['vpn_detected'] as bool?,
      proxyDetected: json['proxy_detected'] as bool?,
      torDetected: json['tor_detected'] as bool?,
    );
  }
}
```

## Настройка backend

Используется HTTPS API `api.ipapi.is`; ответы кешируются в памяти процесса на 6
часов. Без ключа действует лимит бесплатного тарифа провайдера. Для production
рекомендуется задать ключ только на backend:

```bash
IPAPI_API_KEY=...
```

Ключ нельзя добавлять в Flutter или коммитить в репозиторий.
