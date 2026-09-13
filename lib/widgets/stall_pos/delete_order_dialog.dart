import 'dart:async';
import 'package:flutter/material.dart';

/// Standard confirmation dialog for deleting an active or historical order ticket.
class DeleteOrderDialog {
  DeleteOrderDialog._();

  /// Shows the delete confirmation dialog. If confirmed, executes [onConfirm]
  /// and shows a success SnackBar.
  static Future<bool> show(
    BuildContext context, {
    int? token,
    int? orderToken,
    required FutureOr<void> Function() onConfirm,
  }) async {
    final effectiveToken = token ?? orderToken ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Order #$effectiveToken?'),
        content: Text('Delete Order #$effectiveToken? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onConfirm();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$effectiveToken deleted.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    }
    return false;
  }
}
