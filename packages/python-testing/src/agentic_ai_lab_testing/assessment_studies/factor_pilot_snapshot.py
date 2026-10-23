# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Freeze source bytes exclusively into a new isolated pilot directory."""
from pathlib import Path
import hashlib,json,subprocess,shutil


def main():
    root=Path.cwd(); dest=root/'.cache/ascent/factor-pilot/snapshot';dest.mkdir(exist_ok=False)
    paths=subprocess.check_output(['rg','--files','--hidden','-g','!.git','-g','!.cache','-g','!.data','-g','!.gerbil','-g','!.env*','-g','!.aws','-g','!.codex','-g','!.agents','-g','!.venv','-g','!node_modules'],text=True).splitlines()
    files={}
    for p in paths:
     if p.endswith(('.ss','.scm','.py','.qnt','.lean','.json','.awk')) or p in ('gerbil.pkg','justfile'):
      b=(root/p).read_bytes();files[p]=hashlib.sha256(b).hexdigest(); q=dest/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b)
    for p,h in files.items():
     if hashlib.sha256((root/p).read_bytes()).hexdigest()!=h: raise RuntimeError('source changed while freezing '+p)
    lib=dest/'.gerbil/lib';lib.mkdir(parents=True)
    for name in ('asp-gerbil-scheme','clan','core'):
     shutil.copytree(root/'.gerbil/lib'/name,lib/name,symlinks=False)
    (lib/'static').mkdir()
    for p in (root/'.gerbil/lib/static').iterdir():
     if not p.name.startswith('gerbil-ascent'):
      shutil.copy2(p,lib/'static'/p.name)
    manifest={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'branch':subprocess.check_output(['git','branch','--show-current'],text=True).strip(),'dirtyStatus':subprocess.check_output(['git','status','--porcelain'],text=True),'sourceHashes':files,'snapshotDigest':hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()}
    (root/'.cache/ascent/factor-pilot/source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('SNAPSHOT',len(files),manifest['snapshotDigest'])


if __name__ == "__main__":
    main()
