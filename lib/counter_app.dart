/// The Counter App modular package.
///
/// Exports counter-specific models, controller, storage, and UI widgets.
library;

// Data Models
export 'src/models/counter_model.dart';
export 'src/models/counter_log_entry.dart';

// Centralized Storage Contracts & Implementations
export 'src/storage/counter_storage.dart';
export 'src/storage/in_memory_storage.dart' show InMemoryCounterStorage;
export 'src/storage/counter_storage_service.dart';

// Controllers
export 'src/controllers/counter_controller.dart';
export 'src/controllers/theme_controller.dart';

// Screens & Views
export 'src/views/home_screen.dart';
export 'src/views/history_screen.dart';

// Reusable Widgets
export 'src/widgets/counter_card.dart';
export 'src/widgets/add_edit_counter_sheet.dart';
export 'src/widgets/csv_import_dialog.dart';
export 'src/widgets/search_sort_bar.dart';
export 'src/widgets/empty_state.dart';

// Theme & Styling
export 'src/theme/app_theme.dart';

// Services
export 'src/services/csv_export_service.dart';
export 'src/services/csv_import_service.dart';
