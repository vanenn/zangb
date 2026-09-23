"""Run real combat at 30 Hz, isolated storage, no invulnerability or damage cheats."""
import concurrent.futures, json, subprocess, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT.parent / 'system-supplier/tools/Godot_v4.7.2-stable_win64_console.exe'
SEEDS = (4471, 8197, 13003)
jobs = [(c, d, s, p) for s in SEEDS for d, p in [('challenge','build'), ('challenge','random'), ('easy','build')] for c in ('teacher','mechanic','guard')]

def run(job):
    c,d,s,p=job
    stem=f'campaign-v3-{c}-{d}-{s}-{p}'
    path=ROOT/'tests'/f'{stem}.json'
    start=time.time()
    with (ROOT/'tests'/f'{stem}.log').open('w', encoding='utf-8') as log:
        result=subprocess.run([str(ENGINE),'--headless','--path',str(ROOT),'--script','tests/campaign_v3.gd','--',c,d,str(s),p],stdout=log,stderr=subprocess.STDOUT,timeout=1800)
    if result.returncode or not path.exists() or path.stat().st_mtime<start:
        raise RuntimeError(f'{stem} failed; see log')
    data=json.loads(path.read_text(encoding='utf-8'))
    print(stem, 'completed=',data['completed'],'waves=',len(data['waves']), flush=True)
    return data

if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results=list(pool.map(run,jobs))
    (ROOT/'tests/matrix-v3-result.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print('MATRIX FINISHED', len(results), flush=True)
