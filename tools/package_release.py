"""Package the verified executable and clean Godot source without local save data."""
from pathlib import Path
import hashlib
import shutil
import zipfile
import json

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'dist'
RELEASE = DIST / 'GreycitySurvivors-v3-Windows'
assert (RELEASE / 'GreycitySurvivors.exe').is_file()
for name in ('README.md', '动画预览.html'):
    shutil.copy2(ROOT / name, RELEASE / name)
for name in ('FONT-LICENSE.txt', 'GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt', 'LICENSES.md'):
    target = RELEASE / 'assets' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / 'assets' / name, target)
for path in (ROOT / 'assets' / 'vfx').glob('*.png'):
    target = RELEASE / 'assets' / 'vfx' / path.name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
for name in ('VERIFICATION.md', 'BUILD-GUIDE.md', 'V3-DESIGN.md', 'ART-GENERATION.md', 'VFX-PROMPTS.md'):
    target = RELEASE / 'docs' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / 'docs' / name, target)
(RELEASE / '操作说明.txt').write_text('灰城余生 · 第三版\n\n双击 GreycitySurvivors.exe 开始游戏。无需安装或联网。\nWASD / 方向键移动；自动攻击和拾取；按住 E 救人、搜刮或操作机关。\nTab 查看队伍；B 查看构筑；Esc 暂停。整备界面手动开始下一波。\n设置中可以关闭震动和闪烁、减少血迹。\n每次整备自动保存；战斗中退出回到最近一次整备。\n打开 动画预览.html 可慢放、暂停并逐帧查看特效素材。\n完整规则见 README.md，实测方法与限制见 docs/VERIFICATION.md。\n', encoding='utf-8-sig')
release_zip = DIST / 'GreycitySurvivors-v3-Windows.zip'
with zipfile.ZipFile(release_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(RELEASE.rglob('*')):
        if path.is_file(): archive.write(path, Path(RELEASE.name) / path.relative_to(RELEASE))

source_zip = DIST / 'GreycitySurvivors-v3-Source.zip'
allowed_roots = {'scripts', 'assets', 'data', 'docs'}
allowed_files = {'project.godot', 'main.tscn', 'export_presets.cfg', 'README.md', '动画预览.html', '开始游戏.bat'}
visual_images={path.split('/')[-1] for path in json.loads((ROOT/'tests/visual-v3-result.json').read_text(encoding='utf-8'))['screenshots']}
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(ROOT.rglob('*')):
        if not path.is_file(): continue
        relative = path.relative_to(ROOT)
        included = relative.parts[0] in allowed_roots or str(relative) in allowed_files
        if relative.parts[0] == 'tests':
            active_tests={'v3.gd','safety_v3.gd','mechanisms_v3.gd','builds_v3.gd','campaign_v3.gd','visual_v3.gd','performance_v3.gd','feedback.gd','tactics_compare.gd'}
            included = len(relative.parts)==2 and (path.name in active_tests or path.name.endswith('v3-result.json') or path.name.startswith('campaign-v3-') and path.suffix=='.json' or path.name in {'feedback-result.json','tactics-result.json','v3-result.json','05-upgrade.png','14-equipment.png','16-build.png','17-build-codex.png'} or path.name.startswith('stress-v3-') and path.suffix=='.png')
            included |= relative.as_posix() == 'tests/release-v3/release-result.json'
            included |= len(relative.parts)==2 and (path.name in visual_images or path.name=='runtime-v3-hashes.json')
        included |= relative.as_posix() in {'tools/package_release.py','tools/run_v3_matrix.py','tools/write_v3_guide.py','tools/write_v3_report.py'}
        if included: archive.write(path, Path('greycity-survivors') / relative)
    archive.writestr('greycity-survivors/源码使用说明.txt', '用 Godot 4.7.2 打开 project.godot；F6/F5 运行。开始游戏.bat 供与 Windows 发布目录合用，源码压缩包不重复包含可执行程序。导出前请在 Godot 中设置本机 Windows 模板位置。\n')
for path in (release_zip, source_zip):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
    print(path.name, path.stat().st_size, 'bytes')
manifest = '\n'.join(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.name for path in (RELEASE/'GreycitySurvivors.exe', release_zip, source_zip))+'\n'
(DIST/'SHA256SUMS-v3.txt').write_text(manifest, encoding='ascii')
shutil.copy2(RELEASE/'GreycitySurvivors.exe', ROOT/'build'/'GreycitySurvivors.exe')
