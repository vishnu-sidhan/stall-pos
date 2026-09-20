/// Dedicated StallPOS module entrypoint.
///
/// Use this library when embedding Point of Sale, Catalog Management,
/// and Order History features into an existing host Flutter application.
library;

// Domain Models
export 'src/models/stall_models.dart';

// Storage Interfaces & Services
export 'src/storage/stall_storage.dart' show StallStorage;
export 'src/storage/in_memory_storage.dart'
    show InMemoryStorage, InMemoryStallStorage;
export 'src/storage/stall_storage_service.dart' show StallStorageService;

// Controllers
export 'src/controllers/order_controller.dart' show OrderController;
export 'src/controllers/theme_controller.dart' show ThemeController;

// Embeddable Views & Full-Screen Wrappers
export 'src/views/stall_pos_view.dart' show StallPosView, StallPosScreen;
export 'src/views/store_management_view.dart'
    show StoreManagementView, StoreManagementScreen;
export 'src/views/order_history_view.dart'
    show OrderHistoryView, OrderHistoryScreen;

// POS Reusable Widgets (TakeOrderPanel, MenuItemCard, CartBottomSheet, etc.)
export 'src/widgets/stall_pos/stall_pos_widgets.dart';

// Services
export 'src/services/csv_export_service.dart' show CsvExportService;
export 'src/services/csv_import_service.dart'
    show CsvImportService, MenuCatalogParseResult, CsvParseResult;

// Theme & Styling
export 'src/theme/app_theme.dart' show AppTheme;
