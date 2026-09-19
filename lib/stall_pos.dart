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
        OrderItem,
        StallOrder,
        ItemPreparationStatus,
        ItemDietaryType;

// Storage Interfaces
export 'src/storage/stall_storage.dart' show StallStorage;
export 'src/storage/in_memory_storage.dart'
    show InMemoryStorage, InMemoryStallStorage;

// Controllers
export 'src/controllers/order_controller.dart' show OrderController;

// Embeddable Views & Full-Screen Wrappers
export 'src/views/stall_pos_view.dart' show StallPosView, StallPosScreen;
export 'src/views/store_management_view.dart' show StoreManagementView, StoreManagementScreen;
export 'src/views/order_history_view.dart' show OrderHistoryView, OrderHistoryScreen;

// Services
export 'src/services/csv_export_service.dart' show CsvExportService;
export 'src/services/csv_import_service.dart'
    show CsvImportService, MenuCatalogParseResult, CsvParseResult;
