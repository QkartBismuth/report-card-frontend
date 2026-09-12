# Рапортичка — Android-приложение

Flutter-клиент для учёта посещаемости занятий учебной группы. Работает в паре с backend ([report-card-backend](https://github.com/QkartBismuth/report-card-backend)).

## Возможности

- Авторизация с сохранением сессии; выбор темы оформления (светлая / тёмная / системная / OLED) на экране входа.
- Роли:
  - **Староста** — создаёт сессии на текущий день (до 4 пар), выбирая предмет из общего каталога для каждой пары; отмечает посещаемость студентов; загружает `.docx` со списком группы.
  - **Преподаватель-куратор** — видит группу целиком; подтверждает/снимает подтверждение сессий.
  - **Преподаватель-предметник** — видит только пары своих предметов.
- Для преподавателя сессии группируются **по дням**: одна запись на день → подтверждение и выгрузка всего дня одной кнопкой.
- Каталог предметов загружается автоматически (у преподавателя — «Мои предметы»).
- Выгрузка рапортички в PDF / DOCX / XLSX (одна сессия, один день, период).

## Стек

- Flutter 3.x · Dart SDK `^3.13.2`
- `provider` (состояние), `http` (API), `shared_preferences` (сессия и тема)
- `intl` (даты), `file_picker`, `open_filex`, `path_provider` (загрузка/открытие файлов)

## Требования

- Flutter SDK 3.27+ (stable)
- Android SDK (для сборки под Android)
- Работающий backend (см. `report-card-backend`)

## Запуск

```bash
flutter pub get

# адрес backend указывается при запуске/сборке:
flutter run --dart-define=API_URL=http://<IP_машины>:8010

# Android-эмулятор (localhost хост-машины):
flutter run --dart-define=API_URL=http://10.0.2.2:8010
```

Без `--dart-define` используется значение по умолчанию из `lib/config.dart` — `http://10.0.2.2:8010`.

## Сборка APK

```bash
flutter build apk --debug --dart-define=API_URL=http://<IP_машины>:8010
```

Готовый файл: `build/app/outputs/flutter-apk/app-debug.apk`. Иконка приложения — адаптивная (Android 8+) на основе `ico.svg`.

## Тесты

```bash
flutter analyze
flutter test
```

## Структура

```
lib/
├── main.dart               # вход, темы, provider
├── config.dart             # адрес backend (API_URL)
├── marks.dart              # отметки посещаемости
├── models/                 # user, group, session, student, subject
├── services/               # api_service, auth_service, theme_controller
├── state/app_state.dart    # глобальное состояние
├── screens/                # login, home, create_session, attendance,
│                           # sessions_list, day_sessions, session_detail,
│                           # disciplines (предметы), students, export, upload_raport
├── utils/day_groups.dart   # группировка сессий по дням
└── widgets/                # student_mark_tile
```

## Пользователи по умолчанию

| Логин     | Пароль       | Роль         |
|-----------|--------------|--------------|
| `starosta` | `starosta123` | староста     |
| `teacher`  | `teacher123`  | преподаватель |