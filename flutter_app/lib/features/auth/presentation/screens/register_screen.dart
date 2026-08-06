import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

enum SignupRole { distributor, driver, shopkeeper }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  SignupRole _role = SignupRole.distributor;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Role-specific controllers
  final _businessNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _licenceNumberController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _vehicleNumberController.dispose();
    _licenceNumberController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    super.dispose();
  }

  String get _roleValue => switch (_role) {
        SignupRole.distributor => 'distributor',
        SignupRole.driver => 'driver',
        SignupRole.shopkeeper => 'shopkeeper',
      };

  void _submit() {
    final payload = <String, dynamic>{
      'role': _roleValue,
      'fullName': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'password': _passwordController.text,
    };

    switch (_role) {
      case SignupRole.distributor:
        payload['businessName'] = _businessNameController.text.trim();
        break;
      case SignupRole.driver:
        payload['vehicleType'] = 'auto';
        payload['vehicleNumber'] = _vehicleNumberController.text.trim();
        payload['drivingLicenceNumber'] = _licenceNumberController.text.trim();
        payload['vehicleCapacityKg'] = 200;
        break;
      case SignupRole.shopkeeper:
        payload['shopName'] = _shopNameController.text.trim();
        payload['shopAddress'] = _shopAddressController.text.trim();
        // In production these come from the Google Maps location picker.
        payload['shopLat'] = 0.0;
        payload['shopLng'] = 0.0;
        break;
    }

    ref.read(authControllerProvider.notifier).register(payload);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.message)));
      }
    });

    final isLoading = ref.watch(authControllerProvider) is AuthLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('I am a', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _RoleSelector(selected: _role, onChanged: (r) => setState(() => _role = r)),
              const SizedBox(height: 24),
              AppTextField(label: 'Full Name', controller: _fullNameController, prefixIcon: Icons.person),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: Icons.lock,
              ),
              const SizedBox(height: 16),
              ..._roleSpecificFields(),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Register', onPressed: _submit, isLoading: isLoading),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _roleSpecificFields() {
    switch (_role) {
      case SignupRole.distributor:
        return [
          AppTextField(
            label: 'Business Name',
            controller: _businessNameController,
            prefixIcon: Icons.storefront,
          ),
          const SizedBox(height: 16),
        ];
      case SignupRole.driver:
        return [
          AppTextField(
            label: 'Vehicle Number',
            controller: _vehicleNumberController,
            prefixIcon: Icons.local_shipping,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Driving Licence Number',
            controller: _licenceNumberController,
            prefixIcon: Icons.badge,
          ),
          const SizedBox(height: 16),
        ];
      case SignupRole.shopkeeper:
        return [
          AppTextField(label: 'Shop Name', controller: _shopNameController, prefixIcon: Icons.store),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Shop Address',
            controller: _shopAddressController,
            prefixIcon: Icons.location_on,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
        ];
    }
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selected, required this.onChanged});

  final SignupRole selected;
  final ValueChanged<SignupRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: SignupRole.values.map((role) {
        final isSelected = role == selected;
        final label = switch (role) {
          SignupRole.distributor => 'Distributor',
          SignupRole.driver => 'Auto Driver',
          SignupRole.shopkeeper => 'Shopkeeper',
        };
        final icon = switch (role) {
          SignupRole.distributor => Icons.storefront,
          SignupRole.driver => Icons.local_shipping,
          SignupRole.shopkeeper => Icons.store,
        };
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(role),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F9D58) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0F9D58) : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade700),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
