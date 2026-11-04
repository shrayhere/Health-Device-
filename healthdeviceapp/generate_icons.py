import os, shutil
from PIL import Image

src_icon = r'D:\Health_Device_Windows_x64\data\flutter_assets\assets\icon\app_icon.png'
dest_asset = r'd:\SG\main files\healthdeviceapp\assets\icon\app_icon.png'
shutil.copyfile(src_icon, dest_asset)
print('Copied original 556KB app_icon.png to assets/icon/app_icon.png')

img = Image.open(src_icon).convert('RGBA')

standard_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

base_res = r'd:\SG\main files\healthdeviceapp\android\app\src\main\res'

for folder, sz in standard_sizes.items():
    d = os.path.join(base_res, folder)
    os.makedirs(d, exist_ok=True)
    out_p = os.path.join(d, 'ic_launcher.png')
    resized = img.resize((sz, sz), Image.Resampling.LANCZOS)
    resized.save(out_p, format='PNG')
    print('Saved', out_p, (sz, sz))

fg_sizes = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
}

for folder, sz in fg_sizes.items():
    d = os.path.join(base_res, folder)
    os.makedirs(d, exist_ok=True)
    out_fg = os.path.join(d, 'ic_launcher_foreground.png')
    icon_inner_sz = int(sz * 0.72)
    inner_resized = img.resize((icon_inner_sz, icon_inner_sz), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (sz, sz), (0, 0, 0, 0))
    offset = (sz - icon_inner_sz) // 2
    canvas.paste(inner_resized, (offset, offset), inner_resized)
    canvas.save(out_fg, format='PNG')
    print('Saved foreground', out_fg, (sz, sz))

# Write colors.xml for adaptive icon background
val_dir = os.path.join(base_res, 'values')
os.makedirs(val_dir, exist_ok=True)
colors_xml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0F172A</color>
</resources>
'''
with open(os.path.join(val_dir, 'colors.xml'), 'w', encoding='utf-8') as f:
    f.write(colors_xml)

v26_dir = os.path.join(base_res, 'mipmap-anydpi-v26')
os.makedirs(v26_dir, exist_ok=True)
adaptive_xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
with open(os.path.join(v26_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
    f.write(adaptive_xml)
print('Saved adaptive icon xml to mipmap-anydpi-v26/ic_launcher.xml')

strings_xml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Health Device</string>
</resources>
'''
with open(os.path.join(val_dir, 'strings.xml'), 'w', encoding='utf-8') as f:
    f.write(strings_xml)
print('Saved values/strings.xml with Health Device')
