# Shopper - Flutter Shopping List App

## Project Overview
Shopping list app with dictionary, multiple lists (places), place links, and sharing functionality.

## Project Structure
```
lib/
  main.dart              - App entry point, theme setup
  globals.dart           - Constants, colors, localization (lw()), dialogs, ItemDialog
  database.dart          - SQLite database helper
  routes.dart            - App routes
  home_screen.dart       - Lists screen (places)
  list_screen.dart       - Single list screen with items
  items_dictionary_screen.dart - Dictionary of items
  settings_screen.dart   - App settings
  move_items_screen.dart - Move/copy items between lists
  welcome_screen.dart    - First launch screen
  place.dart             - Place model
  list.dart              - ListItem model
  items.dart             - Item model (dictionary)
  ToDo.txt               - Task list
  Done.txt               - Completed tasks log

assets/
  locales.json           - Translations (en, ru, ua)
  colors.json            - Color themes
```

## ToDo.txt Rules
Location: `lib/ToDo.txt`

**Task markers:**
- `+` = completed
- `o` = next task
- `>` = next task (same priority as `o`)
- `?` = under question, skip for now
- (no marker) = pending

**Rules:**
1. Russian text → translate to English, keep in same position
2. When task (>, o) is done → mark as `+`
3. Never reorder existing lines
4. **New tasks → add immediately after section header** (`===TODO:`, `===TOFIX:`, `===ERRORS:`)
5. Sections: `===TODO:`, `===TOFIX:`, `===ERRORS:`

## Done.txt Rules
Location: `lib/Done.txt`

**After completing a task, add entry to Done.txt:**
- Date header: `--- YYYY-MM-DD ---` (add new date header if different from last)
- Task line: `+ task description` (translated to English)
- Summary: brief description of changes made (files, what was done)
- **New entries go at the top** (after `=== DONE ===` header)

## Localization
- File: `assets/locales.json`
- Function: `lw('English text')` returns translated text
- Languages: en (default), ru, ua
- **Always add translations when changing UI strings**

## Font Constants (globals.dart)
```dart
fsSmall = 14, fsNormal = 16, fsMedium = 18, fsLarge = 20, fsTitle = 24
fwNormal, fwMedium, fwBold
```

## Color Variables (globals.dart)
```dart
clText, clBgrnd, clUpBar, clFill, clSel, clMenu
```

## Key Patterns

### Place Links
Items can link to other lists using:
- `quantity = "-1"` (marker)
- `unit = "-{placeId}"` (target list ID)

### Async Context Safety
Always check `mounted` after every `await` before using `context`:
```dart
final result = await someAsyncOperation();
if (mounted) {
  Navigator.pushNamed(context, '/route');
}
```

### Message Types
```dart
showMessage(context, 'text', type: MessageType.success/warning/error/info);
```

## Scripts

### 00-Make.sh
Build script - creates APK and sets git tag with new build number.

### 01-PushTag.sh
Push to GitHub with version tracking:
1. Checks working tree is clean
2. Pushes commits to origin
3. Gets latest tag (e.g. `v0.7.260115+26`)
4. Adds version marker to ToDo.txt after each section header: `# v0.7.260115+26 (2025-01-15 12:42:00)`
5. Commits ToDo.txt changes
6. Pushes the tag

Has `DRY=""` variable for dry-run testing.

## Build Commands
```bash
./00-Make.sh          # Build APK + create tag
./01-PushTag.sh       # Push to GitHub + update ToDo.txt
flutter run           # Run in debug mode
```

## Version Info
Located in `globals.dart`:
```dart
const String progVersion = 'x.x.xxxxxx';
const int buildNumber = xx;
```

## Workflow
- **User builds and tests APK** — do not run `flutter build apk` or `./00-Make.sh`
- Claude writes code, user handles building and testing
