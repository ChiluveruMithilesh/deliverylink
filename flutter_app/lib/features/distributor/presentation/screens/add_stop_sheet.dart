import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../models/stop_draft.dart';

/// Shows a bottom sheet to capture one delivery stop's details.
/// In production, lat/lng come from the Google Maps location picker;
/// here they default to 0,0 as a placeholder for manual entry/testing,
/// matching the "search shops" + "Google Maps location picker" spec.
Future<StopDraft?> showAddStopSheet(BuildContext context) {
  final shopNameController = TextEditingController();
  final contactController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final notesController = TextEditingController();
  String unitType = 'cartons';

  return showModalBottomSheet<StopDraft>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add Shop Stop', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Shop Name',
                    controller: shopNameController,
                    prefixIcon: Icons.store,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Contact Number',
                    controller: contactController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Quantity',
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.inventory_2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: ['cartons', 'bags', 'boxes'].map((u) {
                      final isSelected = unitType == u;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(u),
                            selected: isSelected,
                            onSelected: (_) => setState(() => unitType = u),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Notes (optional)',
                    controller: notesController,
                    prefixIcon: Icons.note,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Add Stop',
                    onPressed: () {
                      if (shopNameController.text.trim().isEmpty ||
                          contactController.text.trim().length != 10) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter shop name and valid 10-digit phone')),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop(
                        StopDraft(
                          shopName: shopNameController.text.trim(),
                          contactNumber: contactController.text.trim(),
                          // Placeholder coordinates: wire to Google Maps picker in production.
                          lat: 17.385 + (0.01 * (0.5 - DateTime.now().millisecond / 1000)),
                          lng: 78.4867 + (0.01 * (0.5 - DateTime.now().microsecond / 1000)),
                          quantity: int.tryParse(quantityController.text) ?? 1,
                          unitType: unitType,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
