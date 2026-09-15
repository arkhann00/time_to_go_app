# Архитектура приложения

## Слои

```text
lib/
├── main.dart                  # точка входа и временный composition root
├── core/                      # независимые общие типы и утилиты
│   └── models/app_enums.dart
├── data/                      # инфраструктура и внешнее хранение
│   ├── local/user_profile_cache.dart
│   └── remote/backend_api.dart
├── domain/                    # чистые модели предметной области
│   └── models/
│       ├── believer.dart
│       ├── outreach_statistics.dart
│       ├── user.dart
│       └── models.dart
└── presentation/              # экраны и виджеты (следующий этап выноса)
```

Правило зависимостей: `presentation → domain ← data`; `core` ни от чего не
зависит. `data` может зависеть от `domain`, но UI не должен обращаться к HTTP
или SharedPreferences напрямую — это задача репозиториев.

## Текущее состояние миграции

Доменная модель, API-клиент и локальный кэш уже вынесены из монолитного
`main.dart`. Файлы `lib/backend_api.dart` и `lib/user_profile_cache.dart`
сохранены только как совместимые export-точки для внешнего кода. Новые импорты
должны использовать пути из `data/`.

`main.dart` пока остаётся presentation/composition root: в нём находятся
экраны, Cupertino/Material виджеты, локализация и координация состояния. Это
сделано намеренно: перенос экранов следует выполнять небольшими проверяемыми
шагами, чтобы не сломать навигацию и UX.

## Следующий безопасный этап

1. Вынести `S` в `presentation/localization/`.
2. Перенести общие UI-компоненты в `presentation/widgets/`.
3. Разделить экраны по feature-папкам: `auth`, `dashboard`, `believers`,
   `map`, `profile`, `settings`, `methods`.
4. Ввести `AuthRepository`, `BelieversRepository`, `StatisticsRepository` и
   `ProfileRepository`, чтобы убрать вызовы `BackendApi` из state виджетов.
5. Переместить состояние `HomeScreen` в controller/view-model выбранного
   подхода (например, `ChangeNotifier` без новых зависимостей).

Новые функции следует добавлять уже в соответствующий слой, а не в
`main.dart`.
