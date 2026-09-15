# Firebase push-напоминания

Клиент регистрирует FCM device token только на Android/iOS после входа через
`PUT /auth/me/push-device` с `token`, `platform` (`ios`/`android`) и IANA
timezone устройства. При refresh token выполняется повторный PUT; при logout —
`DELETE /auth/me/push-device` с token. Ответ DELETE — `204`, а `404` для уже
удалённого token безопасно игнорируется.

Настройки получаются через `GET /auth/me/notification-settings`; PATCH является
частичным и принимает `believers_friday_reminder_enabled` и/или
`believers_friday_reminder_time` в формате `HH:MM`. Для ручной проверки в
авторизованной среде доступен `POST /auth/me/test-push-notification`.

Напоминание с `data.screen=believers` открывает существующую вкладку Believers.
Публичные `/auth/test-push-notification` и `/auth/admin/push-device-tokens`
намеренно не вызываются мобильным клиентом.

Перед релизом владелец проекта должен:

1. Загрузить APNs key `.p8` в Firebase Console (Project settings → Cloud
   Messaging).
2. В Xcode для Runner включить Signing & Capabilities → Push Notifications
   (и Background Modes → Remote notifications).
3. Проверить разрешения, foreground, background и terminated открытие на
   реальном Android и iPhone: симулятор iOS FCM не заменяет реальное устройство.
