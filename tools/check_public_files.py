"""Check the staged publication boundary; prints paths, never secret values."""
from pathlib import Path
import re, subprocess, sys
root=Path(__file__).resolve().parents[1]
paths=subprocess.check_output(["git","diff","--cached","--name-only","-z"],cwd=root).decode().split("\0")
problems=[]
patterns=[rb"gh[pousr]_[A-Za-z0-9]{20,}",rb"github_pat_[A-Za-z0-9_]{30,}",rb"AKIA[0-9A-Z]{16}",rb"sk-(?:proj-)?[A-Za-z0-9_-]{24,}",rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",rb"https?://[^\s/:]+:[^\s/@]+@"]
for rel in filter(None,paths):
 p=root/rel
 if not p.is_file(): continue
 if rel.startswith((".godot/","backups/","addons/")) or (rel.startswith("assets/") and p.suffix!=".json") or p.name.startswith(".env") or p.suffix in (".pem",".key",".blend",".blend1"):
  problems.append((rel,"excluded file type"))
 raw=subprocess.check_output(["git","show",":"+rel],cwd=root)
 if len(raw)>50*1024*1024: problems.append((rel,"unexpected large file"))
 if any(re.search(pattern,raw) for pattern in patterns): problems.append((rel,"possible credential"))
for path,reason in problems: print(path+": "+reason)
print("PUBLIC_BOUNDARY_PASS" if not problems else "PUBLIC_BOUNDARY_FAIL")
sys.exit(bool(problems))
