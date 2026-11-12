import pathlib,json,hashlib
baseline=json.loads(pathlib.Path('tests/hotfix/baseline_hashes.json').read_text())
changed=[]
for name,expected in baseline.items():
 p=pathlib.Path(name)
 if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected: changed.append(name)
print(json.dumps(changed,ensure_ascii=False,indent=2))
print('Preview6B intact:',not any(x.startswith('soulgameexported') for x in changed))
pathlib.Path('tests/hotfix/changed_game_files.json').write_text(json.dumps(changed,indent=2),encoding='utf-8')
