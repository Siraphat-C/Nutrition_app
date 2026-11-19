/// ชื่อภาษาไทยของ 12 เมนูที่โมเดลรู้จัก (คีย์ตรงกับ food_name ในฐานข้อมูล)
const Map<String, String> kFoodThaiNames = {
  'khao_kha_moo': 'ข้าวขาหมู',
  'khao_man_kai': 'ข้าวมันไก่',
  'khao_na_ped': 'ข้าวหน้าเป็ด',
  'khao_mok_gai': 'ข้าวหมกไก่',
  'khao_moo_daeng': 'ข้าวหมูแดง',
  'khao_moo_tod': 'ข้าวหมูทอด',
  'khao_moo_kratiem': 'ข้าวหมูกระเทียม',
  'khao_pad_moo': 'ข้าวผัดหมู',
  'khao_kana_moo_krob': 'ข้าวคะน้าหมูกรอบ',
  'khao_kluk_kapi': 'ข้าวคลุกกะปิ',
  'pad_kra_pao_moo_sub': 'ข้าวกะเพราหมูสับ',
  'pad_kra_pao_moo_krob': 'ข้าวกะเพราหมูกรอบ',
};

String thaiFoodName(String? key) {
  if (key == null) return 'ไม่ทราบเมนู';
  return kFoodThaiNames[key] ?? key;
}

/// น้ำหนักอาหารเริ่มต้นต่อ 1 จาน (กรัม) ใช้ตอนผู้ใช้ยังไม่ได้แก้
const double kDefaultPlateGrams = 300;

const Map<String, String> kMealThai = {
  'breakfast': 'มื้อเช้า',
  'lunch': 'มื้อกลางวัน',
  'dinner': 'มื้อเย็น',
  'snack': 'ของว่าง',
};

/// เดามื้อจากเวลาตอนนี้
String mealForNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 11) return 'breakfast';
  if (h >= 11 && h < 15) return 'lunch';
  if (h >= 17 && h < 21) return 'dinner';
  return 'snack';
}
