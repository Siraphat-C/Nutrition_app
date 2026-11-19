import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../data/foods.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';
import 'dashboard_screen.dart' show kMealColors;

/// ถ่าย/เลือกรูป → ส่ง /api/analyze → ปรับเมนูและน้ำหนัก → บันทึก /api/logs
class ScanScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const ScanScreen({super.key, required this.onSaved});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  Uint8List? _image;
  bool _analyzing = false;
  bool _saving = false;
  String? _error;

  // ผลวิเคราะห์ (แก้ได้)
  double? _confidence;
  int? _foodId;
  String? _foodName;
  double? _per100g;
  double _grams = kDefaultPlateGrams;
  bool _gramsEdited = false;
  String _meal = mealForNow();

  List<Map<String, dynamic>>? _foods;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _image = bytes;
        _error = null;
        _foodId = null;
        _foodName = null;
        _confidence = null;
        _per100g = null;
        _grams = kDefaultPlateGrams;
        _gramsEdited = false;
        _meal = mealForNow();
      });
      await _analyze(bytes, file.name);
    } catch (e) {
      setState(() => _error = source == ImageSource.camera
          ? 'เปิดกล้องไม่ได้ ลองเลือกรูปจากคลังภาพแทน'
          : 'เลือกรูปไม่ได้: $e');
    }
  }

  Future<void> _analyze(Uint8List bytes, String filename) async {
    setState(() => _analyzing = true);
    try {
      final r = await AppState.instance.api.analyze(bytes, filename.isEmpty ? 'food.jpg' : filename);
      setState(() {
        _foodName = r['food_name'] as String?;
        _confidence = (r['confidence'] as num?)?.toDouble();
        _foodId = (r['food_id'] as num?)?.toInt();
        _per100g = (r['calories_per_100g'] as num?)?.toDouble();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _chooseOtherFood() async {
    try {
      _foods ??= await AppState.instance.api.foods();
    } catch (e) {
      if (mounted) showApiError(context, e);
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('เลือกเมนูที่ถูกต้อง', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final f in _foods!)
              ListTile(
                title: Text(thaiFoodName(f['food_name'] as String?)),
                subtitle: Text(_kcalText((f['calories_per_100g'] as num?)?.toDouble())),
                trailing: f['food_id'] == _foodId ? const Icon(Icons.check, color: kGreenDark) : null,
                onTap: () => Navigator.of(context).pop(f),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _foodId = (picked['food_id'] as num?)?.toInt();
        _foodName = picked['food_name'] as String?;
        _per100g = (picked['calories_per_100g'] as num?)?.toDouble();
        _confidence = null; // ผู้ใช้เลือกเอง
      });
    }
  }

  static String _kcalText(double? per100) =>
      (per100 == null || per100 <= 0) ? 'ยังไม่มีข้อมูลแคลอรี่' : '${fmtInt(per100)} kcal / 100 กรัม';

  double? get _kcal => (_per100g == null || _per100g! <= 0) ? null : _per100g! * _grams / 100;

  Future<void> _save() async {
    final id = _foodId;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await AppState.instance.addMeal(foodId: id, mealType: _meal, grams: _grams, manualWeight: _gramsEdited);
      if (!mounted) return;
      showSnack(context, 'บันทึก${thaiFoodName(_foodName)} ใน${kMealThai[_meal]}แล้ว');
      setState(() {
        _image = null;
        _foodId = null;
        _foodName = null;
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('สแกนอาหาร', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
        const SizedBox(height: 2),
        const Text('ถ่ายให้เห็นทั้งจาน แสงพอ ไม่เบลอ', style: TextStyle(fontSize: 13, color: kMuted)),
        const SizedBox(height: 14),
        _ImageBox(image: _image, analyzing: _analyzing),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _analyzing ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('ถ่ายรูป'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _analyzing ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('เลือกจากคลัง'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AlertCard(level: AlertLevel.danger, title: 'วิเคราะห์ไม่สำเร็จ', detail: _error!),
        ],
        if (_foodName != null && !_analyzing) ...[
          const SizedBox(height: 14),
          _resultCard(),
          const SizedBox(height: 12),
          _portionCard(),
          const SizedBox(height: 12),
          _mealCard(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_foodId == null || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(_kcal == null ? 'บันทึกมื้อนี้' : 'บันทึกมื้อนี้ (${fmtInt(_kcal!)} kcal)'),
          ),
          const SizedBox(height: 8),
          const Text('ผลจาก AI อาจคลาดเคลื่อน ตรวจสอบเมนูและน้ำหนักก่อนบันทึก',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kMuted)),
        ],
      ],
    );
  }

  Widget _resultCard() {
    final conf = _confidence;
    final low = conf != null && conf < 0.6;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(thaiFoodName(_foodName),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
              ),
              if (conf != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: low ? kOrangeBg : kGreenBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('มั่นใจ ${(conf * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: low ? kOrangeText : kGreenText)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_kcalText(_per100g), style: const TextStyle(fontSize: 13, color: kMuted)),
          if (low) ...[
            const SizedBox(height: 10),
            const Text('AI ไม่ค่อยแน่ใจ ตรวจดูว่าเมนูถูกไหม',
                style: TextStyle(fontSize: 13, color: kOrangeText, fontWeight: FontWeight.w600)),
          ],
          if (_foodId == null) ...[
            const SizedBox(height: 10),
            const Text('เมนูนี้ยังไม่มีในฐานข้อมูล เลือกเมนูอื่นก่อนบันทึก',
                style: TextStyle(fontSize: 13, color: kRedText, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _chooseOtherFood,
            icon: const Icon(Icons.edit_outlined, size: 18, color: kGreenText),
            label: const Text('ไม่ใช่เมนูนี้? เลือกเมนูอื่น',
                style: TextStyle(color: kGreenText, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _portionCard() {
    final kcal = _kcal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('ปริมาณอาหาร'),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'ลด 10 กรัม',
                onPressed: _grams > 50 ? () => setState(() {
                  _grams -= 10;
                  _gramsEdited = true;
                }) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('${fmtInt(_grams)} กรัม',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
                    Text(kcal == null ? 'ยังไม่มีข้อมูลแคลอรี่' : '= ${fmtInt(kcal)} kcal',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kcal == null ? kMuted : kGreenText)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'เพิ่ม 10 กรัม',
                onPressed: _grams < 1000 ? () => setState(() {
                  _grams += 10;
                  _gramsEdited = true;
                }) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Slider(
            value: _grams.clamp(50, 1000).toDouble(),
            min: 50,
            max: 1000,
            divisions: 95,
            label: '${fmtInt(_grams)} ก.',
            activeColor: kGreenDark,
            onChanged: (v) => setState(() {
              _grams = v.roundToDouble();
              _gramsEdited = true;
            }),
          ),
          const Text('1 จานทั่วไปประมาณ 250–350 กรัม', style: TextStyle(fontSize: 12, color: kMuted)),
        ],
      ),
    );
  }

  Widget _mealCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('บันทึกเป็นมื้อ'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in kMealThai.entries)
                ChoiceChip(
                  label: Text(m.value),
                  selected: _meal == m.key,
                  onSelected: (_) => setState(() => _meal = m.key),
                  selectedColor: (kMealColors[m.key] ?? kGreen).withValues(alpha: 0.18),
                  labelStyle: TextStyle(fontWeight: _meal == m.key ? FontWeight.w700 : FontWeight.w500, color: kInk),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final Uint8List? image;
  final bool analyzing;
  const _ImageBox({required this.image, required this.analyzing});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.memory(image!, fit: BoxFit.cover)
            else
              Container(
                color: Colors.white,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_rounded, size: 52, color: kGreen),
                    SizedBox(height: 10),
                    Text('ยังไม่มีรูป', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk)),
                    SizedBox(height: 2),
                    Text('รองรับ 12 เมนูอาหารจานเดียว', style: TextStyle(fontSize: 12, color: kMuted)),
                  ],
                ),
              ),
            if (analyzing)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('AI กำลังวิเคราะห์…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
