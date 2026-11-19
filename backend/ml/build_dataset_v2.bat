@echo off
chcp 65001 >nul
rem Build dataset v3: 11 existing menus (high-res Roboflow exports) + khao_pad_moo
python ml/prepare_dataset.py ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Hainanese-Chicken-Rice.v1i.yolov11=khao_man_kai" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\BBQ-Pork-Rice.v2i.yolov11=khao_moo_daeng" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Al food-tong.v1-pork-rice.yolov11=khao_kha_moo" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Chicken-Biryani.v4i.yolov11=khao_mok_gai" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Crispy-Pork-with-Basil.v1i.yolov11=pad_kra_pao_moo_krob" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Rice-with-Stir-fried-Minced-Pork-and-Basil.v1i.yolov11=pad_kra_pao_moo_sub" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Fried-Rice-with-Shrimp-Paste.v1i.yolov11=khao_kluk_kapi" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Fried-Pork-Rice.v1i.yolov11=khao_moo_tod" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Pork-with-Garlic.v1i.yolov11=khao_moo_kratiem" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Roasted-Duck-Rice.v1i.yolov11=khao_na_ped" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Stir-fried-Kale-with-Crispy-Pork.v1i.yolov11=khao_kana_moo_krob" ^
 --source-class "C:\Users\Thirawat Wongthong\Downloads\Pork-Fried-Rice.v1i.yolov11=khao_pad_moo" ^
 --source "C:\Users\Thirawat Wongthong\Downloads\Thai-Food-Classify.v1i.folder" ^
 --output "C:\Users\Thirawat Wongthong\Downloads\thai_food_v3"
