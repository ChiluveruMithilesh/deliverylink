import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../models/stop_draft.dart';
import '../providers/distributor_provider.dart';

/// Shows a bottom sheet where the distributor enters a shopkeeper's
/// unique code (e.g. "DL-7K2M9X") to add them as a delivery stop.
/// The shop name, address, and exact map coordinates are pulled
/// automatically from that shopkeeper's own registration - the
/// distributor only fills in what's specific to this trip: how much,
/// and any notes for the driver.
Future<StopDraft?> showAddStopSheet(BuildContext context, WidgetRef ref) {
  final codeController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final notesController = TextEditingController();
  String unitType = 'cartons';

  Map<String, dynamic>? resolvedShop;
  String? shopkeeperName;
  List<dynamic> allShopsForCode = [];
  bool isLookingUp = false;
  String? lookupError;

  return showModalBottomSheet<StopDraft>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> lookUpCode() async {
            final code = codeController.text.trim().toUpperCase();
            if (code.isEmpty) return;

            setState(() {
              isLookingUp = true;
              lookupError = null;
              resolvedShop = null;
            });

            try {
              final result = await ref.read(distributorRepositoryProvider).lookupShopByCode(code);
              final shops = result['shops'] as List<dynamic>;
              setState(() {
                shopkeeperName = result['shopkeeperName'] as String?;
                allShopsForCode = shops;
                resolvedShop = shops.length == 1 ? shops.first as Map<String, dynamic> : null;
              });
            } on ApiException catch (e) {
              setState(() => lookupError = e.message);
            } finally {
              setState(() => isLookingUp = false);
            }
          }

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
                  Text('Add Shop by Unique ID', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Ask the shopkeeper for their unique ID (shown on their Profile screen).',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Shopkeeper Code (e.g. DL-7K2M9X)',
                          controller: codeController,
                          prefixIcon: Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: isLookingUp ? null : lookUpCode,
                        icon: isLookingUp
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  if (lookupError != null) ...[
                    const SizedBox(height: 8),
                    Text(lookupError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],

                  if (allShopsForCode.length > 1) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$shopkeeperName has ${allShopsForCode.length} shops - pick one:',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...allShopsForCode.map((s) {
                      final shop = s as Map<String, dynamic>;
                      final isSelected = resolvedShop?['id'] == shop['id'];
                      return Card(
                        color: isSelected ? const Color(0xFFE8F5E9) : null,
                        child: ListTile(
                          leading: Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? const Color(0xFF0F9D58) : Colors.grey,
                          ),
                          title: Text(shop['shop_name'] as String? ?? ''),
                          subtitle: Text(shop['address'] as String? ?? ''),
                          onTap: () => setState(() => resolvedShop = shop),
                        ),
                      );
                    }),
                  ],

                  if (resolvedShop != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFFE8F5E9),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF0F9D58), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    resolvedShop!['shop_name'] as String? ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(resolvedShop!['address'] as String? ?? ''),
                            Text(
                              resolvedShop!['contact_number'] as String? ?? '',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      label: 'Notes for driver (optional)',
                      controller: notesController,
                      prefixIcon: Icons.note,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Add Stop',
                      onPressed: () {
                        final shop = resolvedShop!;
                        Navigator.of(ctx).pop(
                          StopDraft(
                            shopId: shop['id'] as String?,
                            shopName: shop['shop_name'] as String,
                            contactNumber: shop['contact_number'] as String,
                            lat: (shop['lat'] as num).toDouble(),
                            lng: (shop['lng'] as num).toDouble(),
                            quantity: int.tryParse(quantityController.text) ?? 1,
                            unitType: unitType,
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}