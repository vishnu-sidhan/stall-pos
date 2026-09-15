/// Dedicated StallPOS module entrypoint.
///
/// Use this library when embedding Point of Sale, Catalog Management,
/// and Order History features into an existing host Flutter application.
library;

// Domain Models
export 'src/models/stall_models.dart'
    show
        MenuItem,
        ItemCategory,
        CategoryVariant,
        Order,
        OrderItem,
        DietaryType,
        StallOrder,
        OrderLineItem,
        ItemDietaryType;

// Storage Interfaces
export 'src/storage/stall_storage.dart' show StallStorage;
export 'src/storage/in_memory_storage.dart'
    show InMemoryStorage, InMemoryStallStorage;

// Controllers
export 'src/controllers/order_controller.dart' show OrderController;

// Embeddable Views & Full-Screen Wrappers
export 'src/views/stall_pos_view.dart' show StallPosView;
export 'src/views/stall_pos_screen.dart' show StallPosScreen;
export 'src/views/store_management_view.dart' show StoreManagementView;
export 'src/views/store_management_screen.dart' show StoreManagementScreen;
export 'src/views/order_history_view.dart' show OrderHistoryView;
export 'src/views/order_history_screen.dart' show OrderHistoryScreen;

// Services
export 'src/services/csv_export_service.dart' show CsvExportService;
export 'src/services/csv_import_service.dart'
    show CsvImportService, MenuCatalogParseResult, CsvParseResult;
