"""Byte-exact draft snapshots for paper-orchestra. Standard library only. Each command prints one compact JSON object; exit 0 only when ``ok``.
Commands: snap, begin, verify, audit, restore, digest, inventory, check-input, resolve-paths,
verify-build, check-report, selftest. A scope is JSON
``{"include","exclude","owned","orch"}``; an absent include is an error unless the empty-baseline flag is given or a later snapshot of this run recorded its removal. Snapshots live under
``<paper>/orchestra/snapshots/<tag>/``. ``ok:false`` is an error; expected findings are
``ok:true`` with a ``findings`` list. The scope always excludes the snapshot root and the
actual orch; the inventory skips only the snapshot root, this run's records and owned paths.
"""
from __future__ import annotations
import hashlib
import json
import os
import re
import shutil
import sys
import time
import tempfile
from pathlib import Path, PurePosixPath
ORCH = "orchestra"
TMP_DIR = ".po-store-tmp"
REPORT_BEGIN = "BLOCKERS BEGIN"
REPORT_END = "BLOCKERS END"
def _tmpdir(paper: Path) -> Path:
    return paper / ORCH / TMP_DIR
def _long(path: Path) -> str:
    """Windows extended path for APIs that do not opt into long paths."""
    s = str(path)
    if os.name == "nt" and not s.startswith("\\\\?\\"): return "\\\\?\\" + os.path.abspath(s)
    return s
def _sha(p: Path) -> str:
    h = hashlib.sha256()
    with open(_long(p), "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""): h.update(chunk)
    return h.hexdigest()
def _norm(rel: object) -> str:
    if not isinstance(rel, str): raise TypeError(f"scope path must be a string: {rel!r}")
    if any(c in rel for c in "*?["): raise ValueError(f"scope path must be literal: {rel}")
    raw = rel.replace("\\", "/")
    if re.match(r"^[A-Za-z]:", raw) or raw.startswith("/"): raise ValueError(f"path must be relative inside the paper: {rel}")
    r = PurePosixPath(raw)
    if ".." in r.parts: raise ValueError(f"path must be relative inside the paper: {rel}")
    return str(r)
def _orch_rel(paper: Path, orch: Path) -> str:
    """Paper-relative path of the actual orchestra directory, with forward slashes."""
    try: return orch.resolve().relative_to(paper.resolve()).as_posix()
    except ValueError: return ORCH
def _snapshot_has(paper: Path, rel: str) -> bool:
    base = _long(paper / ORCH / "snapshots")
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if not d.startswith(".tmp-")]
        if "MANIFEST.json" not in files: continue
        try: m = json.loads((Path(root) / "MANIFEST.json").read_text(encoding="utf-8"))
        except (OSError, ValueError): continue
        if isinstance(m.get("files"), dict) and any(_norm(rel) == _norm(name) or _norm(name).startswith(_norm(rel).rstrip('/') + '/') or (rel in (".", "") and m["files"]) for name in m["files"]): return True
    return False
def _load_scope(scope: dict, paper: Path, require_includes: bool = True, orch: str = ORCH, allow_empty: bool = False) -> tuple[list[str], list[str]]:
    if not isinstance(scope, dict): raise TypeError("scope must be a JSON object")
    for key in ("include", "exclude", "owned"):
        val = scope.get(key)
        if val is not None and not isinstance(val, list):
            raise ValueError(f"scope {key} must be a list")
    inc = [_norm(x) for x in scope.get("include", [])]
    if not inc: raise ValueError("scope include list is empty")
    inactive = [i for i in inc if not (Path(_long(paper / i)).is_file() or Path(_long(paper / i)).is_dir())]
    declared = [i for i in inactive if _snapshot_has(paper, i)]
    first_scope = len(declared) < len(inactive)
    if require_includes:
        for i in inactive:
            if i not in declared and not allow_empty: raise ValueError(f"include is absent: {i}")
    if scope.get("exclude") is None: scope = {**scope, "exclude": []}
    if not isinstance(scope["exclude"], list) or not isinstance(scope.get("owned"), list):
        raise ValueError("scope must state owned paths (an empty list if none)")
    exc = [_norm(x) for x in scope["exclude"] + scope["owned"]] + [orch, ORCH + "/snapshots", ORCH + "/" + TMP_DIR, ".git"]
    for e in exc:
        excluded = _excluded_key(paper, e)
        if e == "." or _under(_key(paper), excluded): raise ValueError(f"excluded or owned path covers the paper: {e}")
        if any(_under(_excluded_key(paper, i), excluded) for i in inc):
            raise ValueError(f"excluded or owned path covers an include: {e}")
    if first_scope and not allow_empty and all(any(_under(_excluded_key(paper, i), _excluded_key(paper, e)) for e in exc) for i in inc):
        raise ValueError("scope file set is empty: every include is excluded")
    return inc, exc
def _key(path: Path) -> str:
    return os.path.normcase(str(path)) if os.name == 'nt' else os.path.realpath(path)
def _under(key: str, root: str) -> bool: return key == root or key.startswith(root.rstrip(os.sep) + os.sep)
def _excluded_key(paper: Path, rel: str) -> str:
    return os.path.normcase(os.path.abspath(paper / rel))
def _same_path(paper: Path, p: Path, rel: str) -> bool:
    target = paper / rel
    if p.is_symlink() or target.is_symlink():
        return os.path.normcase(os.path.abspath(p)) == _excluded_key(paper, rel)
    try: return os.path.samefile(_long(p), _long(target))
    except OSError: return os.path.normcase(os.path.abspath(p)) == _excluded_key(paper, rel)
def _excluded(paper: Path, p: Path, exc: list[str]) -> bool:
    k = _key(p)
    for e in exc:
        root = paper / e
        if _under(k, _excluded_key(paper, e)) or _same_path(paper, p, e): return True
        if Path(_long(root)).is_dir() and not root.is_symlink():
            try:
                if Path(_long(p)).resolve().is_relative_to(root.resolve()): return True
            except OSError:
                pass
def _allowed(paper: Path, p: Path, exc: list[str]) -> bool:
    k = _key(p)
    return _under(k, _key(paper)) and not _excluded(paper, p, exc)
def _reparse(p: Path) -> bool:
    if p.is_symlink(): return True
    is_junction = getattr(p, "is_junction", None)
    if callable(is_junction) and is_junction(): return True
    if os.name == "nt":
        try: return bool(p.lstat().st_file_attributes & 0x400)
        except (OSError, AttributeError):
            return False
def _check_reparse(paper: Path, p: Path) -> None:
    if _reparse(p):
        raise ValueError( f"reparse point in scope: {p.relative_to(paper).as_posix()}")
def _ancestors(paper: Path, p: Path) -> list[Path]:
    rel = p.relative_to(paper)
    return [paper.joinpath(*rel.parts[:i]) for i in range(1, len(rel.parts) + 1)]
def scoped_files(paper: Path, scope: dict, require_includes: bool = True, allow_empty: bool = False) -> dict[str, Path]:
    inc, exc = _load_scope(scope, paper, require_includes=require_includes, orch=str(scope.get("orch") or ORCH), allow_empty=allow_empty); real = paper.resolve()
    out: dict[str, Path] = {}
    for i in inc:
        root = paper / i
        for p in _ancestors(paper, root): _check_reparse(paper, p)
        if Path(_long(root)).exists() and not root.resolve().is_relative_to(real):
            raise ValueError(f"include resolves outside the paper: {i}")
        if Path(_long(root)).is_file(): cands = [root]
        elif Path(_long(root)).is_dir():
            cands = []
            for base, dirs, fs in os.walk(root, followlinks=False):
                here = Path(base); kept = []
                for name in dirs:
                    child = here / name
                    lex_excluded = any( _under(_excluded_key(paper, child.relative_to(paper).as_posix()), _excluded_key(paper, e)) for e in exc)
                    if lex_excluded: continue
                    _check_reparse(paper, child)
                    if _allowed(paper, child, exc): kept.append(name)
                dirs[:] = kept
                for name in fs:
                    child = here / name
                    lex_excluded = any( _under(_excluded_key(paper, child.relative_to(paper).as_posix()), _excluded_key(paper, e)) for e in exc)
                    if lex_excluded: continue
                    _check_reparse(paper, child)
                    if _allowed(paper, child, exc): cands.append(child)
        else: cands = []
        for p in cands:
            rel = p.relative_to(paper).as_posix()
            if Path(_long(p)).is_file() and _allowed(paper, p, exc): out[rel] = p
    return out
def _manifest(paper: Path, scope: dict, require_includes: bool = True, allow_empty: bool = False) -> dict[str, str]:
    return {r: _sha(f) for r, f in sorted(scoped_files(paper, scope, require_includes, allow_empty).items())}
def _digest(files: dict[str, str]) -> str:
    return hashlib.sha256(json.dumps(sorted(files.items())).encode()).hexdigest()
def _snapdir(paper: Path, tag: str) -> Path: return paper / ORCH / "snapshots" / _norm(tag)
def _exists(paper: Path, tag: str) -> bool:
    return Path(_long(_snapdir(paper, tag) / "MANIFEST.json")).is_file()
def _read_snap(paper: Path, tag: str) -> tuple[dict, list[str]]:
    d = _snapdir(paper, tag); m = json.loads(Path(_long(d / "MANIFEST.json")).read_text(encoding="utf-8"))
    bad = []
    for r, h in m["files"].items():
        f = d / "files" / r
        if not Path(_long(f)).is_file() or _sha(f) != h: bad.append(r)
    if _digest(m["files"]) != m.get("digest"): bad.append("MANIFEST.json digest")
    return m, bad
def cmd_audit(paper: Path, tag: str) -> dict:
    m, bad = _read_snap(paper, tag)
    if bad: return {"ok": False, "tag": tag, "damaged": bad, "digest": m.get("digest"), "n_files": len(m["files"])}
    return {"ok": True, "tag": tag, "damaged": [], "digest": m["digest"], "n_files": len(m["files"]), "findings": []}
def _manifest_checked(paper: Path, scope: dict) -> dict[str, str]:
    _load_scope(scope, paper, orch=str(scope.get("orch") or ORCH), allow_empty=True)
    return _manifest(paper, scope, require_includes=False, allow_empty=True)
def cmd_snap(paper: Path, scope: dict, tag: str, allow_empty: bool = False, files_override: dict[str, Path] | None = None) -> dict:
    _load_scope(scope, paper, require_includes=not allow_empty, orch=str(scope.get("orch") or ORCH), allow_empty=allow_empty)
    d = _snapdir(paper, tag)
    if _exists(paper, tag):
        m, bad = _read_snap(paper, tag); live = _manifest(paper, m["scope"], require_includes=False)
        same = not bad and m["scope"] == scope and live == m["files"]
        return {"ok": same, "reused": True, "tag": tag, "damaged": bad, "digest": m["digest"], "n_files": len(m["files"]), "error": None if same else "existing tag differs from the live draft or scope"}
    files = {r: _sha(f) for r, f in files_override.items()} if files_override is not None else _manifest(paper, scope, require_includes=False)
    if not files and not allow_empty and not any(_snapshot_has(paper, i) for i in scope.get("include", [])):
        return {"ok": False, "tag": tag, "error": "scope file set is empty: use --now empty", "n_files": 0}
    Path(_long(d.parent)).mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix=".tmp-", dir=_long(d.parent)))
    sources = files_override if files_override is not None else {r: paper / r for r in files}
    for r in files:
        dst = tmp / "files" / r; Path(_long(dst.parent)).mkdir(parents=True, exist_ok=True)
        shutil.copyfile(_long(sources[r]), _long(dst)); shutil.copymode(_long(sources[r]), _long(dst))
    m = {"tag": tag, "scope": scope, "files": files, "digest": _digest(files)}
    (tmp / "MANIFEST.json").write_text(json.dumps(m, indent=1, ensure_ascii=False), encoding="utf-8")
    for _ in range(100):
        try: os.replace(tmp, d); break
        except PermissionError: time.sleep(.05)
    else: os.replace(tmp, d)
    _, bad = _read_snap(paper, tag)
    return {"ok": not bad, "reused": False, "tag": tag, "damaged": bad, "digest": m["digest"], "n_files": len(files)}
def _same(paper: Path, a: str, b: str) -> bool:
    """One target by the volume's identity: normcase plus samefile where both exist."""
    if a == b or (os.name == 'nt' and os.path.normcase(a) == os.path.normcase(b)): return True
    try: return os.path.samefile(_long(paper / a), _long(paper / b))
    except OSError: return False
def _diff(paper: Path, target: dict[str, str], live: dict[str, str]) -> list[str]:
    """Differing paths by the target volume's identity, named with the snapshot spelling."""
    rest, out = dict(live), []
    for r, h in target.items():
        match = next((x for x in rest if _same(paper, r, x)), None)
        if match is None or rest.pop(match) != h: out.append(r)
    return sorted(out + list(rest))
def cmd_verify(paper: Path, tag: str) -> dict:
    m, bad = _read_snap(paper, tag)
    if bad: return {"ok": False, "tag": tag, "no_change": False, "differs": [], "damaged": bad, "digest": m.get("digest")}
    live = _manifest(paper, m["scope"], require_includes=False)
    diff = _diff(paper, m["files"], live)
    return {"ok": not diff and not bad, "tag": tag, "no_change": not diff, "differs": diff, "damaged": bad, "digest": m["digest"], "live_digest": _digest(live)}
def cmd_begin(paper: Path, scope: dict, tag: str, allow_empty: bool = False) -> dict:
    """Snapshot an absent tag; otherwise compare the live draft with it. Never restores."""
    if not _exists(paper, tag):
        snap = cmd_snap(paper, scope, tag, allow_empty=allow_empty)
        return {**snap, "action": "snapshot", "findings": ["tag_created"] if snap["ok"] else []}
    m, bad = _read_snap(paper, tag)
    if bad: return {"ok": False, "tag": tag, "action": "compare", "damaged": bad, "error": "snapshot_damaged"}
    try: live = _manifest(paper, m["scope"], require_includes=False)
    except (OSError, ValueError, TypeError) as e:
        return {"ok": False, "tag": tag, "action": "compare", "error": f"{type(e).__name__}: {e}"}
    if live == m["files"]:
        return {"ok": True, "tag": tag, "action": "current", "digest": m["digest"], "findings": []}
    digest = _digest(live)
    return {"ok": True, "tag": tag, "action": "compare", "digest": digest, "tag_digest": m["digest"],
            "findings": ["draft_changed_since_tag"], "live_digest": digest}
def cmd_inventory(paper: Path, scope: dict, run: str = "") -> dict:
    """Inventory every readable non-owned file: the draft scope does not bound it.
    Skipped: the fixed snapshot root, this run's records and owned paths."""
    orch = str(scope.get("orch") or ORCH)
    _load_scope(scope, paper, require_includes=False, orch=orch)
    unreadable = [_norm(x) for x in scope.get("owned", [])]; files = []
    for base, dirs, names in os.walk(paper, followlinks=False):
        here = Path(base); kept = []
        for name in dirs:
            child = here / name; rel = child.relative_to(paper).as_posix()
            if _store_only(rel, run, orch) or _excluded(paper, child, unreadable): continue
            if _reparse(child): return {"ok": False, "error": "reparse point in scope: " + rel}
            kept.append(name)
        dirs[:] = kept
        for name in names:
            child = here / name; rel = child.relative_to(paper).as_posix()
            if _store_only(rel, run, orch) or _excluded(paper, child, unreadable): continue
            if _reparse(child): return {"ok": False, "error": "reparse point in scope: " + rel}
            if not Path(_long(child)).is_file(): continue
            try: st = Path(_long(child)).stat(); digest = _sha(child)
            except OSError: continue
            files.append({"path": rel, "size": st.st_size, "sha256": digest, "mtime_ns": st.st_mtime_ns})
    files.sort(key=lambda x: x["path"]); return {"ok": True, "files": files, "count": len(files)}
def _identity(paper: Path, rel: str) -> str:
    """Path identity on the target volume: case identity on Windows, real identity on POSIX."""
    p = paper / _norm(rel)
    base = p if p.exists() else p.parent
    while not base.exists() and base != paper: base = base.parent
    resolved = base.resolve()
    result = (Path(os.path.relpath(resolved, paper.resolve())) / p.relative_to(base)).as_posix()
    return result.replace('\\', '/')
def cmd_resolve_paths(paper: Path, paths: list[str]) -> dict:
    paper = Path(str(paper.resolve()).replace(chr(92)*2+'?'+chr(92), '')); out = []; errors = []
    for raw in paths:
        try: _norm(raw)
        except (ValueError, TypeError) as e:
            errors.append(f"{raw}: {type(e).__name__}: {e}"); continue
        try: identity = _identity(paper, raw)
        except ValueError: errors.append(f"{raw}: not under the paper"); continue
        out.append({"input": raw, "path": identity})
    return {"ok": not errors, "paths": out, "errors": errors}
def _writable(p: Path) -> None:
    mode = p.stat().st_mode
    if not mode & 0o200: p.chmod(mode | 0o200)
def _clear_target(dst: Path) -> None:
    if dst.is_symlink() or (dst.exists() and not dst.is_dir()): _writable(dst); dst.unlink()
    elif dst.is_dir():
        for child in list(dst.iterdir()): _clear_target(child)
        dst.rmdir()
def _clear_reparse_ancestors(paper: Path, dst: Path) -> None:
    for part in _ancestors(paper, dst)[:-1]:
        if _reparse(part): part.unlink()
def _stage(paper: Path, tag: str, files: dict[str, str]) -> tuple[Path | None, list[str]]:
    src = _snapdir(paper, tag) / "files"
    try:
        Path(_long(_tmpdir(paper))).mkdir(parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix="stage-", dir=_long(_tmpdir(paper))))
    except OSError as e: return None, [f"staging: {type(e).__name__}: {e}"]
    errors = []
    for r, h in files.items():
        try:
            dst = stage / r; Path(_long(dst.parent)).mkdir(parents=True, exist_ok=True)
            shutil.copyfile(_long(src / r), _long(dst)); shutil.copymode(_long(src / r), _long(dst))
            if _sha(dst) != h: errors.append(f"{r}: staged copy differs from the snapshot")
        except OSError as e: errors.append(f"{r}: {type(e).__name__}: {e}")
    return stage, errors
def _restore_record(paper: Path, tag: str) -> Path:
    return _snapdir(paper, tag).parent / (tag.replace("/", "_") + ".restore.json")
def _pending_restore(paper: Path, tag: str) -> dict | None:
    p = _restore_record(paper, tag)
    try: r = json.loads(Path(_long(p)).read_text(encoding="utf-8"))
    except (OSError, ValueError): return None
    return r if r.get("tag") == tag and r.get("files") else None
def _apply(paper: Path, scope: dict, stage: Path, files: dict[str, str], tag: str, record: Path | None = None,
           done: set[str] | None = None) -> tuple[list[str], list[str]]:
    """Replace each file atomically; a persistent record names an interrupted restore."""
    removed, errors = [], []
    try: targets = {r: _key(paper / r) for r, f in scoped_files(paper, scope, require_includes=False).items()}
    except (OSError, ValueError) as e:
        return removed, [f"scope: {type(e).__name__}: {e}"]
    _, exc = _load_scope(scope, paper, require_includes=False, orch=str(scope.get("orch") or ORCH))
    def store_record(data: dict) -> None:
        tmp = record.with_name(record.name + ".tmp")
        tmp.write_text(json.dumps(data), encoding="utf-8"); os.replace(_long(tmp), _long(record))
    def finish(r: str) -> None:
        if not record or r in (done or set()): return
        data = json.loads(record.read_text(encoding="utf-8")); data["done"].append(r)
        store_record(data)
    if record and done is None:
        try: store_record({"tag": tag, "files": sorted(set(files) | (set(targets) - set(files))), "done": []})
        except OSError as e: return removed, [f"restore record: {type(e).__name__}: {e}"]
    ordered = sorted(files)
    for r in ordered:
        dst = paper / r
        try:
            if not _allowed(paper, dst, exc):
                errors.append(f"{r}: target resolves outside the scope; not written"); continue
            _clear_reparse_ancestors(paper, dst)
            if dst.is_dir(): _clear_target(dst)
            Path(_long(dst.parent)).mkdir(parents=True, exist_ok=True)
            # A POSIX case-only rename is distinct; replace it so snapshot spelling returns.
            case_twin = os.name != 'nt' and any(x != r and x.casefold() == r.casefold() for x in files)
            alien = any(x != r and _same(paper, r, x) for x in targets)
            if not case_twin and not alien and not dst.is_symlink() and dst.is_file() and _sha(dst) == files[r] \
                    and dst.stat().st_mode & 0o777 == (stage / r).stat().st_mode & 0o777:
                finish(r); continue
            if dst.is_file() or dst.is_symlink(): _writable(dst)
            os.replace(_long(stage / r), _long(dst))
            finish(r)
        except OSError as e: errors.append(f"{r}: {type(e).__name__}: {e}")
    kept = {_key(paper / r) for r in files}
    for r, key in sorted(targets.items()):
        if key in kept: continue
        p = paper / r
        try:
            # A case-only rename and its target may share an inode on a case-insensitive volume.
            if p.exists() and any(x != r and p.exists() and os.path.samefile(_long(p), _long(paper / x)) for x in files): continue
            if p.is_file() or p.is_symlink(): _writable(p); p.unlink(); removed.append(r)
        except OSError as e: errors.append(f"{r}: {type(e).__name__}: {e}")
    return removed, errors
def _restore_files(paper: Path, tag: str, record: Path | None = None, done: set[str] | None = None) -> tuple[list[str], list[str]]:
    m, _ = _read_snap(paper, tag); stage, errors = _stage(paper, tag, m["files"]); removed: list[str] = []
    if stage is not None:
        if not errors:
            removed, aerrors = _apply(paper, m["scope"], stage, m["files"], tag, record, done); errors.extend(aerrors)
        shutil.rmtree(_long(stage), ignore_errors=True)
    return removed, errors
def _conflicts(paper: Path, scope: dict, target_files: set[str], live_files: set[str]) -> list[str]:
    """Refuse every file/directory type clash in either direction before a change."""
    _, exc = _load_scope(scope, paper, require_includes=False, orch=str(scope.get("orch") or ORCH))
    orch = str(scope.get("orch") or ORCH)
    protected = [_excluded_key(paper, e) for e in exc + [orch]]; conflicts = []
    for path in target_files:
        if Path(_long(paper / path)).is_dir():
            conflicts.append(path + ': target_is_directory')
            for p in (paper / path).rglob("*"):
                rel = p.relative_to(paper).as_posix(); key = os.path.normcase(os.path.abspath(p))
                if any(_under(key, root) for root in protected) or _excluded(paper, p, exc + [orch]):
                    conflicts.append(rel)
    for path in live_files - target_files:
        for ancestor in PurePosixPath(path).parents:
            if ancestor.as_posix() in target_files:
                conflicts.append(ancestor.as_posix() + ': target_is_directory'); break
    for path in target_files:
        for ancestor in PurePosixPath(path).parents:
            if ancestor.as_posix() in live_files:
                conflicts.append(ancestor.as_posix() + ': parent_is_file'); break
    return sorted(set(conflicts))
def _backup_live(paper: Path, tag: str, scope: dict) -> str:
    n = 1
    while _exists(paper, f"{tag}.before-restore-{n}"): n += 1
    backup = f"{tag}.before-restore-{n}"
    try: present = scoped_files(paper, scope, require_includes=False)
    except (OSError, ValueError, TypeError) as e: raise RuntimeError("backup scan: " + type(e).__name__) from e
    b = cmd_snap(paper, scope, backup, allow_empty=True, files_override=present)
    if not b["ok"]: raise RuntimeError("backup failed")
    return backup
def cmd_restore(paper: Path, tag: str, allow_type_clash: bool = False, expect: str = '') -> dict:
    m, bad = _read_snap(paper, tag)
    if bad: return {"ok": False, "tag": tag, "damaged": bad, "touched": False}
    live = _manifest(paper, m["scope"], require_includes=False)
    live_digest = _digest(live)
    pending = _pending_restore(paper, tag)
    if live_digest == m["digest"]:
        if pending: _restore_record(paper, tag).unlink(missing_ok=True)
        return {"ok": True, "tag": tag, "touched": False, "no_change": True, "findings": [],
                "digest": m["digest"], "restore_tag": tag, "live_digest": live_digest, "tag_digest": m["digest"]}
    if expect and not pending and live_digest != expect:
        return {"ok": True, "tag": tag, "touched": False, "findings": ["draft_changed_since_tag"],
                "live_digest": live_digest, "tag_digest": expect}
    conflicts = [] if allow_type_clash else _conflicts(paper, m["scope"], set(m["files"]), set(live))
    if conflicts: return {"ok": True, "tag": tag, "conflicts": conflicts, "touched": False, "findings": ["type_clash"]}
    # A pending record is completed from its own done list, never discarded.
    if pending:
        record = _restore_record(paper, tag)
        try: backup = _backup_live(paper, tag, m["scope"])
        except RuntimeError as e: return {"ok": False, "tag": tag, "error": str(e), "touched": False, "record": record.relative_to(paper).as_posix()}
        done = set(pending.get("done") or [])
        stage, errors = _stage(paper, tag, m["files"])
        if stage is not None and not errors:
            _, aerrors = _apply(paper, m["scope"], stage, m["files"], tag, record, done)
            errors.extend(aerrors)
            shutil.rmtree(_long(stage), ignore_errors=True)
        rel = record.relative_to(paper).as_posix()
        v = cmd_verify(paper, tag)
        ok = v["ok"] and not errors
        if ok: record.unlink(missing_ok=True)
        return {"ok": ok, "tag": tag, "differs": v["differs"], "errors": errors, "backup": backup, "findings": ["completed_record: " + rel] if ok else [],
                "digest": m["digest"], "touched": True, "restore_tag": tag, "completed_record": True, "record": rel}
    try: backup = _backup_live(paper, tag, m["scope"])
    except RuntimeError as e: return {"ok": False, "tag": tag, "error": str(e), "touched": False}
    was_clean = cmd_verify(paper, tag)["no_change"]
    record = _restore_record(paper, tag)
    removed, errors = _restore_files(paper, tag, record=record)
    v = cmd_verify(paper, tag)
    ok = v["ok"] and not errors
    if ok: record.unlink(missing_ok=True)
    if not ok:
        _, back = _restore_files(paper, backup); errors.extend(back); rb = cmd_verify(paper, backup)
        if not rb["ok"]:
            errors.append("rollback_verify_failed: "
                          + ", ".join(rb["differs"] or rb["damaged"] or ["?"]))
    return {"ok": ok, "tag": tag, "removed": removed, "differs": v["differs"], "errors": errors, "backup": backup, "rolled_back": not ok, "digest": m["digest"], "no_change": was_clean, "touched": True, "restore_tag": tag}
def _digest_result(paper: Path, scope: dict) -> dict:
    return {"ok": True, "digest": _digest(_manifest_checked(paper, scope))}
def _committed_tags(base: Path) -> list[tuple[str, float]]:
    if not Path(_long(base)).is_dir(): return []
    rows = []
    for d in os.scandir(_long(base)):
        mf = Path(d.path) / "MANIFEST.json"
        if d.name.startswith(".tmp-") or not d.is_dir() or not Path(_long(mf)).is_file(): continue
        try: rows.append((d.name, os.stat(_long(mf)).st_mtime))
        except OSError: continue
    return rows
def _recoverable_tag(paper: Path, run: str, digest: str = '') -> tuple[str | None, bool]:
    base = paper / ORCH / "snapshots" / run
    if digest:
        for name, _ in sorted(_committed_tags(base)):
            m, bad = _read_snap(paper, f"{run}/{name}")
            if not bad and m.get("digest") == digest: return f"{run}/{name}", False
    return None, False
def cmd_check_input(paper: Path, orch: Path, run: str, build: str, digest: str) -> dict:
    """Bind a build id to its input digest before running any build command."""
    name = "input-" + re.sub(r"[^A-Za-z0-9_-]", "-", build) + ".json"
    path = orch / "refine" / run / name
    if Path(_long(path)).is_file():
        saved = json.loads(Path(_long(path)).read_text(encoding="utf-8"))
        if saved.get("digest") != digest:
            tag, nearest = _recoverable_tag(paper, run, str(saved.get("digest") or ""))
            return {"ok": False, "run": run, "build": build, "error": "input_digest_drift", "expected": saved.get("digest"), "actual": digest, "recoverable_snapshot": tag, "restorable": tag is not None, "nearest": nearest, "recoverable_record": path.as_posix(), **({} if tag else {"error_detail": "no snapshot matches the bound build input"})}
        return {"ok": True, "run": run, "build": build, "recorded": False, "digest": digest, "findings": []}
    Path(_long(path.parent)).mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"build": build, "digest": digest}), encoding="utf-8")
    return {"ok": True, "run": run, "build": build, "recorded": True, "digest": digest, "findings": []}
def _store_only(rel: str, run: str = "", orch: str = ORCH) -> bool:
    r = _norm(rel)
    if r == ".git" or r.startswith(".git/"): return True
    if r == ORCH + "/snapshots" or r.startswith(ORCH + "/snapshots/"): return True
    if r == ORCH + "/" + TMP_DIR: return True
    prefix = str(orch).replace("\\", "/").strip("/") + "/refine" + ("/" + run if run else "")
    return r == prefix or r.startswith(prefix + "/")
def cmd_verify_build(paper: Path, build: Path, outputs: list[str], sources: list[str], scope: dict | None,
                     dirs: list[str] | None = None, run: str = "", intermediates: list[str] | None = None, pre_inventory: Path | None = None) -> dict:
    """Verify declared deliveries against the build record and the live draft."""
    paper = Path(_long(paper.resolve()))
    try: rec = json.loads(Path(_long(build)).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return {"ok": True, "findings": ["build_record_unreadable: " + type(e).__name__], "files": [], "unlisted": [], "deliverables": [], "sources_verified": []}
    written = {_identity(paper, x) for x in rec.get("written", [])}
    entries = {_identity(paper, f["path"]): f for f in rec.get("files", []) if isinstance(f, dict) and isinstance(f.get("path"), str)}
    raw_skip = [_identity(paper, x) for x in (intermediates or [])]
    skip = []
    for s in raw_skip:
        q = paper / s
        if (Path(str(q) + "/").is_dir() or (q.is_dir() if q.exists() else False)):
            skip.append(s.rstrip("/"))
        else: skip.append(s)
    skip_files = set(raw_skip)
    is_skipped = lambda p: p in skip_files or any(p.startswith(s + "/") for s in skip)
    stated = {_identity(paper, x) for x in rec.get("deliverables", [])}
    src = {_identity(paper, x) for x in sources}
    roots = [_identity(paper, d) for d in dirs or []]
    under = lambda p: any(p == r or p.startswith(r + "/") for r in roots)
    display = {}
    for x in [*outputs, *sources, *(dirs or []), *(f.get("path", "") for f in rec.get("files", []) if isinstance(f, dict)), *rec.get("deliverables", []), *rec.get("written", [])]:
        if not x: continue
        try: display.setdefault(_identity(paper, x), x)
        except (OSError, ValueError, TypeError): pass
    inv = cmd_inventory(paper, scope or {"include": ["."], "owned": []}, run)
    if not inv.get("ok"):
        return {"ok": True, "findings": ["build_inventory_failed: " + str(inv.get("error") or "")], "files": [], "unlisted": [], "deliverables": [], "sources_verified": []}
    owned = [_norm(x) for x in (scope or {}).get("owned", [])]
    owned_roots = [_identity(paper, x) for x in owned]
    is_owned = lambda p: any(p == o or p.startswith(o + "/") for o in owned_roots)
    inventoried = {f["path"]: f for f in inv["files"]}
    for root in dirs or []:
        try: base = paper / _norm(root)
        except (ValueError, TypeError) as e:
            return {"ok": True, "findings": ["build_output_unreadable: " + root + ": " + type(e).__name__], "files": [], "unlisted": [], "deliverables": [], "sources_verified": []}
        if not Path(_long(base)).is_dir(): continue
        stack = [base]
        while stack:
            node = stack.pop()
            try: children = list(os.scandir(_long(node)))
            except OSError as e:
                rel = node.relative_to(paper).as_posix()
                return {"ok": True, "findings": ["build_output_unreadable: " + rel + ": " + type(e).__name__], "files": [], "unlisted": [], "deliverables": [], "sources_verified": []}
            for child in children:
                p = Path(child.path); rel = p.relative_to(paper).as_posix()
                ident = _identity(paper, rel)
                if is_skipped(ident) or is_owned(ident): continue
                if _reparse(p):
                    return {"ok": True, "findings": ["build_output_unreadable: " + rel + ": reparse point"], "files": [], "unlisted": [], "deliverables": [], "sources_verified": []}
                if child.is_dir(follow_symlinks=False): stack.append(p)
                elif child.is_file(follow_symlinks=False):
                    ident = _identity(paper, rel)
                    display[ident] = display.get(ident, rel)
                    try: st, digest = p.stat(), _sha(p)
                    except OSError as e: return {"ok": True, "findings": ["build_output_unreadable: " + display[ident] + ": " + type(e).__name__], "files": [], "unlisted": [], "deliverables": [], "sources_verified": []}
                    inventoried[ident] = {'path': rel, 'size': st.st_size, 'sha256': digest, 'mtime_ns': st.st_mtime_ns}
    delivery = {_identity(paper, x) for x in outputs} | src
    overlap = sorted(q for q in delivery if is_skipped(q))
    for root in roots:
        for ident, info in inventoried.items():
            if under(ident) and not is_skipped(ident) and not is_owned(ident) and not _reparse(paper / ident):
                delivery.add(ident)
    newest = 0
    if scope:
        try: newest = max((int((paper / r).stat().st_mtime_ns) for r in _manifest(paper, scope, require_includes=False) if (paper / r).is_file()), default=0)
        except (OSError, ValueError, TypeError): newest = 0
    if rec.get('input_digest') and isinstance(rec.get('input_digest'), str):
        newest = max(newest, int(entry.get('mtime', 0)) + 1 if (entry := next((e for e in rec.get('files', []) if isinstance(e, dict) and e.get('path') in stated), {})) else 0)
    if pre_inventory is not None and not Path(_long(pre_inventory)).is_file():
        return {"ok": True, "findings": ["build_inventory_missing"], "files": [], "unlisted": [], "deliverables": [], "sources_verified": []}
    before_all = {}
    if pre_inventory is not None:
        raw = json.loads(Path(_long(pre_inventory)).read_text(encoding="utf-8"))
        before_all = {_identity(paper, x["path"]): x for x in raw["files"]}
    findings, files, actual = [], [], set()
    started = rec.get("started")
    for ident in sorted(delivery):
        p = paper / ident
        if not Path(_long(p)).is_file() or _reparse(p):
            findings.append("build_output_missing: " + ident); files.append({"path": display.get(ident, ident), "exists": False}); continue
        try: digest, st = _sha(p), Path(_long(p)).stat()
        except OSError as e:
            findings.append("build_output_unreadable: " + ident + ": " + type(e).__name__)
            files.append({"path": display.get(ident, ident), "exists": True, "error": type(e).__name__}); continue
        actual.add(ident); files.append({"path": display.get(ident, ident), "exists": True, "sha256": digest, "source": ident in src})
        entry = entries.get(ident)
        if ident in src:
            if not entry or entry.get("sha256") != digest: findings.append("build_digest_drift: " + ident)
            continue
        if ident not in stated: findings.append("build_deliverable_undeclared: " + ident)
        if not entry: findings.append("build_deliverable_missing: " + ident)
        elif entry.get("sha256") != digest: findings.append("build_output_not_current: " + ident)
        elif str(entry.get("mtime", "")) != str(st.st_mtime_ns): findings.append("build_output_mtime_drift: " + ident)
        if st.st_mtime_ns < newest and ident not in src: findings.append("build_output_not_current: " + ident)
        stale = (ident in before_all and all(before_all[ident].get(k) == v for k, v in (("size", st.st_size), ("sha256", digest), ("mtime_ns", st.st_mtime_ns)))) if pre_inventory is not None else (isinstance(started, int) and st.st_mtime_ns < started)
        if stale:
            findings.append("build_output_not_rewritten: " + ident)
    unlisted = sorted(p for p in written if p not in delivery and not is_skipped(p) and not is_owned(p))
    for q in stated - delivery: findings.append("build_deliverable_extra: " + display.get(q, q))
    pre_path = Path(_long(pre_inventory)).resolve() if pre_inventory is not None else None
    pre_ident = _identity(paper, pre_path.relative_to(Path(_long(paper))).as_posix()) if pre_path is not None and pre_path.is_relative_to(Path(_long(paper))) else ""
    if before_all:
        post_all = {x["path"]: x for x in inv["files"]}
        changed = sorted(q for q in set(before_all) | set(post_all)
                         if (q not in before_all and not is_skipped(q))
                         or (q not in post_all and not is_skipped(q))
                         or (q in before_all and q in post_all and any(before_all[q].get(k) != post_all[q].get(k) for k in ("size", "sha256", "mtime_ns"))))
        for q in changed:
            if q not in delivery and not is_skipped(q) and not is_owned(q) and not _store_only(q, run, str(scope.get('orch') or ORCH) if scope else ORCH) and q != pre_ident and q not in unlisted: unlisted.append(q)
    if unlisted: findings.append("unlisted_output")
    findings += ["contract_output_intermediate_overlap: " + display.get(q, q) for q in overlap]
    if rec.get("returncode") != 0: findings.append("build_failed: returncode")
    return {"ok": True, "findings": findings, "files": files, "unlisted": [display.get(p, p) for p in unlisted],
            "deliverables": sorted(display.get(p, p) for p in actual), "sources_verified": sorted(src)}
def cmd_restore_pending(paper: Path, tag: str) -> dict:
    record = _restore_record(paper, tag)
    pending = _pending_restore(paper, tag)
    return {"ok": True, "pending": pending, "record": record.relative_to(paper).as_posix() if pending else "", "findings": ["restore_pending"] if pending else []}
def cmd_check_inventory(paper: Path, build: str, path: Path, scope: dict | None = None, run: str = "") -> dict:
    target = Path(_long(path))
    if Path(_long(target)).is_file():
        saved = json.loads(target.read_text(encoding="utf-8"))
        return {"ok": True, "build": build, "files": saved["files"], "started": saved["started"], "reused": True}
    orch = paper / _norm(str((scope or {}).get("orch") or ORCH))
    recs = [q for q in (orch / "refine").glob(f"*/build-{build}.json*")] if (orch / "refine").is_dir() else []
    here = Path(_long(path)).parent
    if here.is_dir() and any(os.path.samefile(q.parent, here) for q in recs): return {"ok": False, "error": "build_inventory_missing", "build": build}
    files = cmd_inventory(paper, scope or {"include": ["."], "owned": []}, run)["files"]
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(target.name + ".tmp")
    tmp.write_text(json.dumps({"build": build, "started": time.time_ns(), "files": files}), encoding="utf-8")
    os.replace(_long(tmp), _long(target))
    return {"ok": True, "build": build, "files": files, "started": json.loads(target.read_text(encoding="utf-8"))["started"], "reused": False}
def cmd_record_digest(build: Path) -> dict:
    rec = json.loads(Path(_long(build)).read_text(encoding="utf-8"))
    if not isinstance(rec, dict) or not isinstance(rec.get("deliverables"), list): return {"ok": False, "error": "build_record_incomplete"}
    return {"ok": True, "digest": _sha(build), "deliverables": sorted(map(str, rec["deliverables"]))}
def cmd_check_report(paper: Path, report: Path, tag: str, kind: str, run: str = '', verdict_arg: str = '', count_arg: str = '') -> dict:
    try: lines = Path(_long(report)).read_text(encoding="utf-8").splitlines()
    except OSError: return {"ok": True, "findings": ["report_missing"], "exists": False}
    first, verdict, blockers = (lines + ["", "", ""])[:3]
    findings = []
    if first != f"run {run or tag.split('/')[0]} | check {kind} | {tag}": findings.append("report_header_mismatch")
    if verdict not in ("Verdict: ACCEPT", "Verdict: REJECT", "Verdict: NOT_RUN"): findings.append("report_verdict_mismatch")
    if verdict_arg and verdict != "Verdict: " + verdict_arg: findings.append("report_verdict_mismatch")
    m = re.fullmatch(r"Blockers: (\d+)", blockers)
    if not m: findings.append("report_blockers_line")
    start = next((i for i, x in enumerate(lines) if x.strip() == REPORT_BEGIN), -1)
    end = next((i for i, x in enumerate(lines) if x.strip() == REPORT_END), -1)
    if start < 0 or end <= start:
        findings.append("report_blocker_block")
    elif m:
        body = [x for x in lines[start + 1:end] if x.strip() and x.strip() != "none"]
        if len(body) != int(m.group(1)):
            findings.append("report_blocker_count")
        if count_arg and count_arg.isdigit() and int(count_arg) != int(m.group(1)): findings.append("report_count_mismatch")
        declared = verdict.split(": ", 1)[1]
        if declared == "ACCEPT" and int(m.group(1)) != 0:
            findings.append("report_verdict_count_mismatch")
    return {"ok": True, "findings": findings, "exists": True, "report": str(report).replace("\\", "/"),
            "kind": kind, "tag": tag, "run": run or tag.split("/")[0], "check_report": True}
def selftest() -> dict:
    fails: list[str] = []
    def expect(exc: type, fn) -> None:
        try: fn()
        except exc: pass
        else: fails.append(f"accepted an invalid call: {fn}")
    with tempfile.TemporaryDirectory() as t:
        p = Path(t) / "paper dir ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©'x"
        (p / "sections").mkdir(parents=True); (p / ORCH).mkdir()
        (p / "sections" / "body.md").write_bytes(b"line\r\n$Id: x $\r\n")
        (p / "sections" / "cafÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©.md").write_bytes("u".encode("utf-16"))
        (p / "notes.md").write_bytes(b"author notes"); (p / "sections" / "new.md").write_bytes(b"new")
        (p / "sections" / "literal.md").write_bytes(b"literal"); (p / ORCH / "process.md").write_bytes(b"contract")
        wide = {"include": ["."], "exclude": ["out"], "owned": ["sections/owned.md"]}; narrow = {"include": ["sections/body.md", "sections/new.md"], "owned": []}
        (p / "sections" / "owned.md").write_bytes(b"owner v1"); e = cmd_begin(p, wide, "r/pre")
        if not e["ok"] or e["action"] != "snapshot" or e["n_files"] != 5: fails.append(f"begin snapshot {e}")
        if e.get("digest") != _digest(_manifest(p, wide)): fails.append("begin snapshot has no digest")
        body0 = (p / "sections" / "body.md").read_bytes(); (p / "sections" / "body.md").write_bytes(b"half")
        (p / "sections" / "owned.md").write_bytes(b"owner v2"); e2 = cmd_begin(p, wide, "r/pre")
        if not e2["ok"] or "draft_changed_since_tag" not in e2.get("findings", []): fails.append(f"begin resume {e2}")
        if e2.get("tag_digest") != e.get("digest") or e2.get("digest") == e2.get("tag_digest"): fails.append("begin does not report both digests")
        mismatch = cmd_restore(p, "r/pre", expect="0" * 64)
        if not mismatch["ok"] or "draft_changed_since_tag" not in mismatch.get("findings", []) or mismatch.get("touched") or (p / "sections" / "body.md").read_bytes() != b"half": fails.append(f"restore ignored a changed live draft {mismatch}")
        rr = cmd_restore(p, "r/pre")
        if not rr["ok"]: fails.append(f"explicit restore {rr}")
        if (p / "sections" / "body.md").read_bytes() != body0: fails.append("explicit restore left the half edit")
        if (p / "sections" / "new.md").read_bytes() != b"new": fails.append("restore changed a file already in the tag")
        bk = cmd_verify(p, rr["backup"]) if rr.get("backup") else rr
        if not bk["ok"] and "sections/new.md" not in _read_snap(p, rr["backup"])[0]["files"]: fails.append("backup missing the live state")
        if (p / "sections" / "owned.md").read_bytes() != b"owner v2": fails.append("restore rolled back an owned file")
        if not (p / ORCH / "process.md").exists(): fails.append("restore touched excluded files")
        n = cmd_snap(p, narrow, "r/narrow"); (p / "notes.md").write_bytes(b"newer notes")
        (p / "sections" / "body.md").unlink(); rn = cmd_restore(p, "r/narrow")
        if not rn["ok"] or (p / "notes.md").read_bytes() != b"newer notes": fails.append(f"narrow restore {rn}")
        if not (p / "sections" / "cafÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©.md").exists() or n["n_files"] != 2 or not (p / "sections" / "body.md").exists(): fails.append("narrow restore touched the wrong files")
        (p / "sections" / "body.md").unlink(); (p / "sections" / "body.md").mkdir()
        (p / "sections" / "body.md" / "part.md").write_bytes(b"split"); rc = cmd_restore(p, "r/narrow")
        if not rc["ok"] or "type_clash" not in rc.get("findings", []) or not rc.get("conflicts") or rc.get("touched") or not (p / "sections" / "body.md" / "part.md").exists():
            fails.append(f"file/dir type clash was not reported before any change {rc}")
        shutil.rmtree(p / "sections" / "body.md")
        if not cmd_restore(p, "r/narrow", allow_type_clash=True)["ok"]: fails.append("explicit reconcile did not restore the snapshot")
        if (p / "sections" / "body.md").read_bytes() != body0: fails.append("file/dir restore lost the snapshot bytes")
        mode_path = p / "sections" / "body.md"
        mode_path.chmod(0o444); cmd_restore(p, "r/narrow")
        if mode_path.read_bytes() != body0: fails.append("read-only file blocked restore")
        mode_path.chmod(mode_path.stat().st_mode | 0o200); snapfile = _snapdir(p, "r/narrow") / "files" / "sections" / "body.md"
        snapfile.write_bytes(b"corrupt"); bad = cmd_restore(p, "r/narrow")
        if bad["ok"] or bad["touched"]: fails.append(f"damaged snapshot touched live {bad}")
        fresh = Path(tempfile.mkdtemp(dir=t, prefix="absent-"))
        expect(ValueError, lambda: cmd_snap(fresh, {"include": ["sections/missing.md"], "owned": []}, "r/absent-include"))
        if not cmd_snap(p, {"include": ["sections/missing.md"], "owned": []}, "r/absent-include", allow_empty=True)["ok"]:
            fails.append("empty-baseline snap refused a declared absent file")
        if not _digest_result(p, {"include": ["sections/missing.md"], "owned": []})["ok"]:
            fails.append("digest rejected an empty baseline")
        expect(ValueError, lambda: _norm("C:x.md")); expect(ValueError, lambda: _norm("c:/x.md"))
        outside = Path(t) / "outside"; outside.mkdir(); (p / "linkdir").symlink_to(outside, target_is_directory=True)
        expect(ValueError, lambda: scoped_files(p, {"include": ["linkdir"], "owned": []}))
        (p / "linkdir").unlink(); (p / "sections" / "link.md").symlink_to(p / "notes.md")
        expect(ValueError, lambda: scoped_files(p, {"include": ["sections"], "owned": []}))
        (p / "sections" / "link.md").unlink()
        for bad_scope in ({"include": ["sections/*.md"], "owned": []}, {"include": ["sections"], "exclude": ["sections/*.md"], "owned": []}, {"include": ["sections"], "owned": ["annotations/*.md"]}, {"include": ["sections/literal.md"], "exclude": ["sections"], "owned": []}):
            expect(ValueError, lambda s=bad_scope: scoped_files(p, s))
        (p / "linked").symlink_to(p / "sections", target_is_directory=True)
        expect(ValueError, lambda: scoped_files(p, {"include": ["."], "exclude": ["out"], "owned": []}))
        (p / "linked").unlink(); (p / "draft").mkdir(exist_ok=True); (p / "draft" / "body.md").write_bytes(b"draft v1")
        anchored = {"include": ["draft/body.md"], "owned": ["owned"]}; cmd_snap(p, anchored, "t/x")
        shutil.rmtree(p / "draft"); (p / "draft").symlink_to(p / "owned", target_is_directory=True)
        try: scoped_files(p, anchored); fails.append("symlinked ancestor in scope accepted")
        except ValueError as e:
            if "draft" not in str(e): fails.append(f"ancestor error names the wrong path: {e}")
        (p / "draft").unlink()
        rw = {"include": ["."], "exclude": ["out"], "owned": []}; cmd_snap(p, rw, "r/write-once")
        (p / "notes.md").write_bytes(b"drift"); retry = cmd_snap(p, rw, "r/write-once")
        if retry["ok"] or not retry.get("error"): fails.append(f"snap reused a tag after drift {retry}")
        cmd_restore(p, "r/write-once")
        a = {"include": ["notes.md"], "owned": []}; cmd_snap(p, a, "r/audit"); (p / ORCH / "snapshots" / "r/audit" / "files" / "notes.md").write_bytes(b"bad")
        if cmd_audit(p, "r/audit")["ok"]: fails.append("audit accepted a damaged snapshot file")
        (p / ORCH / "snapshots" / "r/audit" / "files" / "notes.md").write_bytes(b"newer notes")
        mpath = p / ORCH / "snapshots" / "r/audit" / "MANIFEST.json"
        m = json.loads(mpath.read_text(encoding="utf-8")); m["digest"] = "0" * 64
        mpath.write_text(json.dumps(m), encoding="utf-8")
        if cmd_audit(p, "r/audit")["ok"]: fails.append("audit accepted a forged manifest digest")
        owned_dir = {"include": ["notes.md"], "owned": ["notes.md/owner.txt"]}; (p / "notes.md").unlink()
        (p / "notes.md").mkdir(); (p / "notes.md" / "owner.txt").write_bytes(b"owner")
        blocked = cmd_restore(p, "r/audit")
        if blocked["ok"] or blocked.get("touched") or (p / "notes.md" / "owner.txt").read_bytes() != b"owner": fails.append(f"restore crossed a protected file {blocked}")
        (p / "notes.md" / "owner.txt").unlink(); (p / "notes.md").rmdir(); (p / "notes.md").write_bytes(b"newer notes")
        cmd_snap(p, {"include": ["sections/body.md"], "owned": []}, "r/empty-live")
        (p / "sections" / "body.md").unlink(); empty_backup = cmd_restore(p, "r/empty-live")
        if not empty_backup["ok"] or not (p / "sections" / "body.md").is_file(): fails.append(f"empty-live restore failed {empty_backup}")
        owned_scope = {"include": ["notes.md"], "owned": ["notes.md/owner.md", "notes.md/reserved"]}
        (p / "notes.md").unlink(); (p / "notes.md").write_bytes(b"newer notes")
        cmd_snap(p, owned_scope, "r/empty-dir"); (p / "notes.md").unlink(); (p / "notes.md").mkdir()
        (p / "notes.md" / "reserved").mkdir(); (p / "notes.md" / "owner.md").write_bytes(b"owned")
        blocked = cmd_restore(p, "r/empty-dir")
        if not blocked["ok"] or "type_clash" not in blocked.get("findings", []) or blocked.get("touched") or not (p / "notes.md" / "reserved").exists(): fails.append(f"directory at a snapshot target was not reported {blocked}")
        shutil.rmtree(p / "notes.md"); (p / "notes.md").write_bytes(b"newer notes")
        for bad_scope in ({"include": ["."], "exclude": ["."], "owned": []}, {"include": ["notes.md"], "exclude": ["notes.md"], "owned": []}, {"include": ["notes.md"], "exclude": ["notes.md", "sections"], "owned": []}, {"include": ["notes.md"], "exclude": ["."], "owned": ["orchestra/refine"]}):
            expect(ValueError, lambda s=bad_scope: scoped_files(p, s))
        expect(TypeError, lambda: scoped_files(p, {"include": [None], "owned": []}))
        cmd_snap(p, {"include": ["notes.md"], "owned": []}, "fresh-run/pre-format")
        ci = cmd_check_input(p, p / ORCH, "fresh-run", "format", "abc"); again = cmd_check_input(p, p / ORCH, "fresh-run", "format", "abc")
        drift = cmd_check_input(p, p / ORCH, "fresh-run", "format", "def")
        if not ci["ok"] or again["recorded"] or drift["ok"] or drift.get("recoverable_snapshot") is not None or not drift.get("nearest") is False:
            fails.append(f"input digest binding failed {ci} {again} {drift}")
        snap_input = cmd_snap(p, {"include": ["sections/body.md"], "owned": []}, "new-run/pre-format")
        cmd_check_input(p, p / ORCH, "new-run", "format", snap_input["digest"])
        drift2 = cmd_check_input(p, p / ORCH, "new-run", "format", "def")
        if drift2.get("recoverable_snapshot") != "new-run/pre-format" or drift2.get("nearest"):
            fails.append(f"build input recovery did not match the bound digest {drift2}")
        stored = {"include": [".po-restore-chapter.md"], "owned": []}
        (p / ".po-restore-chapter.md").write_bytes(b"draft with a store-like name")
        if not cmd_snap(p, stored, "r/tmp-name")["ok"]: fails.append("store-named draft file was not snapshotted")
        (p / ".po-restore-chapter.md").write_bytes(b"changed")
        if not cmd_restore(p, "r/tmp-name")["ok"]: fails.append("store-named draft file was not restored")
        (p / "out").mkdir(exist_ok=True); (p / "out" / "paper.html").write_bytes(b"paper")
        (p / "sections" / "body.md").write_bytes(b"body")
        inv = cmd_inventory(p, {"include": ["sections/body.md"], "owned": ["owned"]})
        paths = {f["path"] for f in inv["files"]}
        if not inv["ok"] or "out/paper.html" not in paths or "sections/body.md" not in paths or any(x.startswith("orchestra/snapshots/") or x.startswith("orchestra/refine/") for x in paths):
            fails.append(f"inventory scope wrong {sorted(paths)[:8]}")
        if not all(isinstance(f.get("size"), int) and f.get("sha256") and f.get("mtime_ns") for f in inv["files"]):
            fails.append("inventory lacks size or digest")
        (p / ".po-store-tmp").write_bytes(b"draft"); wide2 = {"include": ["."], "owned": []}
        if not cmd_begin(p, wide2, "r/store-name")["ok"]:
            fails.append("store-named draft file blocked begin")
        (p / ".po-store-tmp").write_bytes(b"edited"); (p / "added-chapter.md").write_bytes(b"added")
        rr = cmd_restore(p, "r/store-name")
        if not rr["ok"] or (p / ".po-store-tmp").read_bytes() != b"draft" or (p / "added-chapter.md").exists():
            fails.append(f"store-named draft file blocked restore {rr}")
        if (p / TMP_DIR).is_dir(): fails.append("temp files live beside the draft")
        if not (p / ORCH / TMP_DIR).is_dir(): fails.append("store temp dir is not under orchestra")
        (p / "out" / "link.html").symlink_to(p / "sections" / "body.md")
        if cmd_inventory(p, {"include": ["sections/body.md"], "owned": ["owned"]})["ok"]:
            fails.append("inventory accepted a live reparse point")
        (p / "out" / "link.html").unlink()
        rp = cmd_resolve_paths(p, ["OUT/PAPER.HTML", "sections/body.md"])
        want0 = "out/paper.html" if os.name == "nt" else "OUT/PAPER.HTML"
        if not (rp["ok"] and rp["paths"][0]["path"] == want0 and rp["paths"][1]["path"] == "sections/body.md"): fails.append(f"contract path resolution failed {rp}")
        (p / "notes.md").write_bytes(b"original notes"); miss = {"include": ["notes.md", "chapters2"], "owned": []}
        (p / "chapters2").mkdir(); assert cmd_snap(p, miss, "r/missing")["ok"]
        (p / "notes.md").unlink(); (p / "chapters2").rmdir()
        assert not cmd_verify(p, "r/missing")["ok"]; assert cmd_restore(p, "r/missing")["ok"]; assert (p / "notes.md").is_file()
        (p / "owned").mkdir(exist_ok=True); (p / "owned" / "secret.md").write_bytes(b"secret")
        inv2 = cmd_inventory(p, {"include": ["notes.md"], "owned": ["owned"]})
        if not inv2["ok"]: fails.append(f"inventory after owned setup failed {inv2}")
        (p / "chapters").mkdir(exist_ok=True)
        (p / "chapters" / "proof.md").write_bytes(b"proof")
        narrow2 = {"include": ["notes.md", "chapters"], "owned": []}
        if not cmd_begin(p, narrow2, "r/keep-dir")["ok"]: fails.append("dir begin failed")
        (p / "chapters" / "new.md").write_bytes(b"new chapter"); kd = cmd_restore(p, "r/keep-dir")
        if not kd["ok"] or (p / "chapters" / "new.md").exists():
            fails.append(f"restore left an extra file {kd}")
        shutil.rmtree(p / "chapters"); (p / "notes.md").write_bytes((p / "notes.md").read_bytes() + b" merged")
        if not cmd_snap(p, narrow2, "r/keep-dir-2")["ok"]:
            fails.append("a removed directory include was refused after a prior snapshot recorded it")
        front = {"include": ["notes.md"], "owned": []}
        if not cmd_snap(p, front, "r/after-merge")["ok"]:
            fails.append("a later snapshot was refused after merging an included directory")
        fp = Path(tempfile.mkdtemp(dir=t, prefix="merged-"))
        (fp / "once.md").write_bytes(b"history")
        fresh_scope = {"include": ["once.md"], "owned": []}
        cmd_snap(fp, fresh_scope, "r/history")
        (fp / "once.md").unlink()
        cmd_snap(fp, fresh_scope, "r/pre")
        if not cmd_snap(fp, fresh_scope, "r/next")["ok"]:
            fails.append("a removed directory include was refused after a prior snapshot recorded it")
        if not _digest_result(p, front)["ok"]:
            fails.append("scope is invalid after restore")
        q = Path(t) / "custom paper"; (q / "sections").mkdir(parents=True); (q / "meta").mkdir()
        (q / "sections" / "body.md").write_bytes(b"v1"); (q / "meta" / "process.md").write_bytes(b"contract")
        cp = {"include": ["."], "exclude": ["meta/refine"], "owned": [], "orch": "meta"}
        cmd_snap(q, cp, "r/pre"); w = cmd_snap(q, cp, "r/write"); b = cmd_begin(q, cp, "r/write")
        rec = cmd_restore(q, "r/pre")
        if not (w.get("ok") and b.get("action") == "current" and rec["ok"] and cmd_audit(q, "r/pre")["ok"]
                and cmd_audit(q, "r/write")["ok"] and (q / "meta" / "process.md").read_bytes() == b"contract"):
            fails.append(f"custom orch scope saw its snapshot root {w} {b} {rec}")
        (q / "orchestra" / "press-copy.html").write_bytes(b"press")
        iq = {f["path"] for f in cmd_inventory(q, {"include": ["sections"], "owned": [], "orch": "meta"}, "r")["files"]}
        if "orchestra/press-copy.html" not in iq or any(x.startswith("orchestra/snapshots/") or x.startswith("meta/refine/") for x in iq):
            fails.append(f"inventory scope wrong for a custom orch {sorted(iq)}")
        rp = q / "rej.md"; hdr = "run r | check k | t"
        rp.write_text("\n".join([hdr, "Verdict: REJECT", "Blockers: 2", REPORT_BEGIN, "a", "b", REPORT_END]), encoding="utf-8")
        if cmd_check_report(q, rp, "t", "k", "r", "REJECT", "2")["findings"]: fails.append("a two-blocker REJECT was refused")
        rp.write_text("\n".join([hdr, "Verdict: ACCEPT", "Blockers: 2", REPORT_BEGIN, "a", "b", REPORT_END]), encoding="utf-8")
        if "report_verdict_count_mismatch" not in cmd_check_report(q, rp, "t", "k", "r", "ACCEPT", "2")["findings"]: fails.append("an ACCEPT with blockers passed")
        (p / "notes.md").write_bytes(b"live before")
        if not cmd_snap(p, {"include": ["notes.md"], "owned": []}, "r/rollback")["ok"]:
            fails.append("rollback case snapshot failed")
        real_apply, calls = _apply, [0]
        def broken(paper: Path, scope: dict, stage: Path, files: dict, tag: str, record: Path | None = None, done: set[str] | None = None) -> tuple:
            removed, errors = real_apply(paper, scope, stage, files, tag, record, done); calls[0] += 1
            return removed, errors + (["injected failure"] if calls[0] == 1 else [])
        globals()["_apply"] = broken
        try:
            rb = cmd_restore(p, "r/rollback")
        finally:
            globals()["_apply"] = real_apply
        if rb["ok"] is False or (p / "notes.md").read_bytes() != b"live before":
            fails.append(f"failed restore did not roll back byte for byte {rb}")
    return {"ok": not fails, "failures": fails}
def _unprefix(x: str) -> str:
    return x[2:] if x.startswith("./") else x
def main(argv: list[str]) -> int:
    import argparse
    ap = argparse.ArgumentParser(); ap.add_argument("--paper"); ap.add_argument("cmd", nargs="?")
    for flag in ("--scope","--tag","--orch","--run","--build","--digest","--report","--kind","--now","--build-file","--verdict","--count","--path","--pre-inventory"): ap.add_argument(flag)
    ap.add_argument("--paths", nargs="*", default=[]); ap.add_argument("--declared", nargs="*", default=[]); ap.add_argument("--sources", nargs="*", default=[]); ap.add_argument("--intermediates", nargs="*", default=[]); ap.add_argument("--expect")
    opts = ap.parse_args(argv)
    a = opts if opts.cmd else argparse.Namespace(**{**vars(opts), "cmd": argv[-1]})
    try:
        paper = Path(_long(Path(os.path.expanduser(a.paper)).resolve())) if a.paper else Path(".")
        scope = (json.loads(Path(os.path.expanduser(a.scope)).read_text( encoding="utf-8")) if a.scope else None)
        orch = Path(os.path.expanduser(a.orch)).resolve() if a.orch else paper / ORCH
        res = { "snap": lambda: cmd_snap(paper, scope, a.tag, allow_empty=(a.now == "empty")),
          "begin": lambda: cmd_begin(paper, scope, a.tag, allow_empty=(a.now == "empty")), "verify": lambda: cmd_verify(paper, a.tag),
          "audit": lambda: cmd_audit(paper, a.tag), "restore": lambda: cmd_restore(paper, a.tag, expect=a.expect or ""),
          "digest": lambda: _digest_result(paper, scope), "inventory": lambda: cmd_inventory(paper, scope, a.run or ""),
          "resolve-paths": lambda: cmd_resolve_paths(paper, [_unprefix(x) for x in a.paths]),
          "verify-build": lambda: cmd_verify_build(paper, Path(a.build_file), [_unprefix(x) for x in a.paths], [_unprefix(x) for x in a.sources or []], scope, [_unprefix(x) for x in a.declared or []], a.run or "", intermediates=[_unprefix(x) for x in getattr(a, "intermediates", None) or []], pre_inventory=Path(a.pre_inventory) if a.pre_inventory else None),
          "check-report": lambda: cmd_check_report(paper, Path(a.report), a.tag, a.kind, a.run or "", a.verdict or "", a.count or ""),
          "record-digest": lambda: cmd_record_digest(Path(a.build_file)),
          "restore-pending": lambda: cmd_restore_pending(paper, a.tag),
          "check-input": lambda: cmd_check_input(paper, orch, a.run, a.build, a.digest),
          "check-inventory": lambda: cmd_check_inventory(paper, a.build, Path(a.path), scope, a.run or ""), "selftest": selftest, }[a.cmd]()
    except (OSError, ValueError, KeyError, TypeError, AttributeError, json.JSONDecodeError) as e:
        res = {"ok": False, "error": f"{type(e).__name__}: {e}"}
    sys.stdout.buffer.write( json.dumps(res, ensure_ascii=False, separators=(",", ":")).encode() + b"\n")
    return 0 if res.get("ok") is True else 1
if __name__ == "__main__": sys.exit(main(sys.argv[1:]))
