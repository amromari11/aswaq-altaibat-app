import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/delivery_location.dart';
import '../../domain/entities/saved_address.dart';
import '../providers/location_providers.dart';

/// Add or edit a saved address. Pass an existing [SavedAddress] via router
/// `extra` to edit it.
class AddressFormPage extends ConsumerStatefulWidget {
  const AddressFormPage({super.key, this.existing});

  final SavedAddress? existing;

  @override
  ConsumerState<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<AddressFormPage> {
  static const _presetLabels = ['المنزل', 'العمل', 'أخرى'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _detailsController;
  String? _zoneId;
  double? _lat;
  double? _lng;
  bool _makeDefault = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelController = TextEditingController(text: existing?.label ?? _presetLabels.first);
    _detailsController = TextEditingController(text: existing?.details ?? '');
    _zoneId = existing?.zoneId;
    _lat = existing?.latitude;
    _lng = existing?.longitude;
    _makeDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pinOnMap() async {
    final result = await context.push<DeliveryLocation>('/location-picker-osm');
    if (result == null) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
      if (_detailsController.text.trim().isEmpty) _detailsController.text = result.address;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(savedAddressesProvider.notifier).upsert(
          SavedAddress(
            id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
            label: _labelController.text.trim(),
            zoneId: _zoneId!,
            details: _detailsController.text.trim(),
            latitude: _lat,
            longitude: _lng,
            isDefault: _makeDefault,
          ),
        );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final zones = ref.watch(zonesProvider);
    final zone = ref.watch(zonesRepositoryProvider).byId(_zoneId);
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'تعديل العنوان' : 'عنوان جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('اسم العنوان', style: AppTextStyles.h3),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in _presetLabels)
                  ChoiceChip(
                    label: Text(preset),
                    selected: _labelController.text == preset,
                    onSelected: (_) => setState(() => _labelController.text = preset),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _labelController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'مثال: بيت العائلة'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال اسم للعنوان.' : null,
            ),
            const SizedBox(height: 20),
            Text('منطقة التوصيل', style: AppTextStyles.h3),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _zoneId,
              hint: const Text('اختر المنطقة'),
              items: [
                for (final z in zones) DropdownMenuItem(value: z.id, child: Text(z.nameAr)),
              ],
              onChanged: (value) => setState(() => _zoneId = value),
              validator: (v) => v == null ? 'الرجاء اختيار منطقة التوصيل.' : null,
            ),
            if (zone != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'رسوم التوصيل ${CurrencyFormatter.jod(zone.deliveryFeeJod)} • الحد الأدنى للطلب ${CurrencyFormatter.jod(zone.minOrderJod)} • الوقت المتوقع ~${zone.etaMinutes} دقيقة',
                  style: AppTextStyles.body.copyWith(color: AppColors.primary),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('تفاصيل العنوان', style: AppTextStyles.h3),
            const SizedBox(height: 10),
            TextFormField(
              controller: _detailsController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'الحي، الشارع، رقم المبنى، أقرب معلم...'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال تفاصيل العنوان.' : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pinOnMap,
              icon: Icon(
                _lat == null ? Icons.map_outlined : Icons.check_circle,
                color: _lat == null ? AppColors.primary : AppColors.success,
              ),
              label: Text(_lat == null ? 'تحديد الموقع على الخريطة' : 'تم تحديد الموقع — تعديل'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _makeDefault,
              onChanged: (v) => setState(() => _makeDefault = v),
              title: const Text('تعيين كعنوان افتراضي'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('حفظ العنوان')),
          ],
        ),
      ),
    );
  }
}
