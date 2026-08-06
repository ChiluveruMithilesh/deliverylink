import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../models/stop_draft.dart';
import '../providers/distributor_provider.dart';
import 'add_stop_sheet.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _pickupAddressController = TextEditingController();
  final _goodsDescriptionController = TextEditingController();
  final _totalQuantityController = TextEditingController();
  final _goodsValueController = TextEditingController();
  final _paymentOfferedController = TextEditingController();

  final List<StopDraft> _stops = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _goodsDescriptionController.dispose();
    _totalQuantityController.dispose();
    _goodsValueController.dispose();
    _paymentOfferedController.dispose();
    super.dispose();
  }

  Future<void> _addStop() async {
    final stop = await showAddStopSheet(context);
    if (stop != null) {
      if (_stops.length >= 40) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Maximum 40 stops per trip')));
        }
        return;
      }
      setState(() => _stops.add(stop));
    }
  }

  Future<void> _publish() async {
    if (_pickupAddressController.text.trim().isEmpty ||
        _goodsDescriptionController.text.trim().isEmpty ||
        _totalQuantityController.text.trim().isEmpty ||
        _goodsValueController.text.trim().isEmpty ||
        _paymentOfferedController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all trip details')),
      );
      return;
    }
    if (_stops.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one shop stop')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(distributorRepositoryProvider);
      final trip = await repo.createTrip({
        'pickupAddress': _pickupAddressController.text.trim(),
        // Placeholder pickup coordinates: wire to Google Maps picker in production.
        'pickupLat': 17.385,
        'pickupLng': 78.4867,
        'goodsDescription': _goodsDescriptionController.text.trim(),
        'totalQuantity': int.tryParse(_totalQuantityController.text) ?? _stops.length,
        'goodsValue': double.tryParse(_goodsValueController.text) ?? 0,
        'paymentOffered': double.tryParse(_paymentOfferedController.text) ?? 0,
        'stops': _stops.map((s) => s.toJson()).toList(),
      });

      await repo.publishTrip(trip['id'] as String);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Trip published! Nearby drivers notified.')));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Delivery Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pickup', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Pickup Address',
              controller: _pickupAddressController,
              prefixIcon: Icons.location_on,
            ),
            const SizedBox(height: 24),
            Text('Goods', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Goods Description',
              controller: _goodsDescriptionController,
              prefixIcon: Icons.inventory,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Total Quantity',
              controller: _totalQuantityController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.numbers,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Approx. Goods Value (₹)',
              controller: _goodsValueController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.currency_rupee,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Payment Offered to Driver (₹)',
              controller: _paymentOfferedController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivery Stops (${_stops.length}/40)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filled(
                  onPressed: _addStop,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Shop',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_stops.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No stops added yet. Tap + to add a shop.', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._stops.asMap().entries.map((entry) {
                final index = entry.key;
                final stop = entry.value;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(stop.shopName),
                    subtitle: Text('${stop.quantity} ${stop.unitType} • ${stop.contactNumber}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _stops.removeAt(index)),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Publish Trip',
              onPressed: _publish,
              isLoading: _isSubmitting,
              icon: Icons.send,
            ),
          ],
        ),
      ),
    );
  }
}
