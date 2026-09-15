/// The StallPOS & Multi-Counter modular package.
///
/// Can be imported and used as a module in any Flutter host application.
library;

// Data Models
export 'src/models/counter_model.dart';
export 'src/models/counter_log_entry.dart';
export 'src/models/stall_models.dart';

// Centralized Storage Contracts & Implementations
export 'src/storage/app_storage.dart';
export 'src/storage/stall_storage.dart';
export 'src/storage/counter_storage.dart';
export 'src/storage/in_memory_storage.dart';
export 'src/storage/stall_storage_service.dart';
export 'src/storage/counter_storage_service.dart';

// Controllers
export 'src/controllers/counter_controller.dart';
export 'src/controllers/order_controller.dart';
export 'src/controllers/theme_controller.dart';

// Screens & Views
export 'src/views/stall_pos_view.dart';
export 'src/views/stall_pos_screen.dart';
export 'src/views/store_management_view.dart';
export 'src/views/store_management_screen.dart';
export 'src/views/order_history_view.dart';
export 'src/views/order_history_screen.dart';
export 'src/views/home_screen.dart';
export 'src/views/history_screen.dart';
export 'src/views/main_navigation_screen.dart';

// Reusable Widgets
export 'src/widgets/stall_pos/stall_pos_widgets.dart';
export 'src/widgets/counter_card.dart';
export 'src/widgets/add_edit_counter_sheet.dart';
export 'src/widgets/payment_confirmation_dialog.dart';
export 'src/widgets/csv_import_dialog.dart';
export 'src/widgets/search_sort_bar.dart';
export 'src/widgets/empty_state.dart';

// Theme & Styling
export 'src/theme/app_theme.dart';

// Services
export 'src/services/csv_export_service.dart';
export 'src/services/csv_import_service.dart';

// Standalone Application Widget
export 'main.dart' show StallPosApp;
