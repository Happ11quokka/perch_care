"""KB search 로그 파싱 — Hit Rate / similarity 분포 산출.

⚠️ 현재 production 미반영 상태:
   `backend/app/main.py`에 `logging.basicConfig(level=logging.INFO)` 호출이 없어
   `ai_service.py:548`의 `logger.info("KB search: ...")` 가 stdout 미전송.
   본 스크립트는 Phase B (docs/reports/2026-05-rag-metrics.md §9.1) 적용 후 사용 가능.

사용법:
    railway logs --filter '"KB search"' --since 30d --json > /tmp/kb_search.jsonl
    python3 scripts/parse_kb_search_logs.py /tmp/kb_search.jsonl

출력:
    stdout — 통계 (총 retrieval 수, 평균/중앙값 similarity, threshold별 hit rate)
    /tmp/perch_rag_audit/similarity_histogram.csv — 10단계 히스토그램
"""

from __future__ import annotations

import csv
import json
import re
import statistics
import sys
from collections import Counter
from pathlib import Path

PATTERN = re.compile(
    r"KB search(?:\s+\[(?P<scope>[^\]]+)\])?:\s*"
    r".*?top_k=(?P<top_k>\d+)\s+avg_similarity=(?P<sim>[0-9.]+)"
)


def parse(path: Path) -> list[dict]:
    records: list[dict] = []
    for raw in path.open():
        raw = raw.strip()
        if not raw:
            continue
        msg = raw
        try:
            obj = json.loads(raw)
            msg = obj.get("message", "") or raw
        except json.JSONDecodeError:
            pass
        m = PATTERN.search(msg)
        if not m:
            continue
        records.append({
            "scope": m.group("scope") or "encyclopedia",
            "top_k": int(m.group("top_k")),
            "sim": float(m.group("sim")),
        })
    return records


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: parse_kb_search_logs.py <log_file>", file=sys.stderr)
        return 2
    out_dir = Path("/tmp/perch_rag_audit")
    out_dir.mkdir(parents=True, exist_ok=True)

    records = parse(Path(argv[1]))
    n = len(records)
    if n == 0:
        print("No KB search lines found. (Phase B logging not applied? See docs/reports/2026-05-rag-metrics.md §9.1)")
        return 0

    sims = [r["sim"] for r in records]
    top_ks = [r["top_k"] for r in records]
    by_scope: Counter = Counter(r["scope"] for r in records)

    print(f"Total KB retrievals parsed: {n}")
    print(f"By scope: {dict(by_scope)}")
    print(f"Avg similarity: {statistics.mean(sims):.3f}")
    print(f"Median similarity: {statistics.median(sims):.3f}")
    print(f"Avg top_k: {statistics.mean(top_ks):.1f}")

    print("\nHit Rate by threshold:")
    for thr in (0.3, 0.5, 0.6, 0.7):
        hits = sum(1 for s in sims if s >= thr)
        print(f"  >= {thr}: {hits / n:.1%}  ({hits}/{n})")

    bins: Counter = Counter(min(int(s * 10), 9) for s in sims)
    out = out_dir / "similarity_histogram.csv"
    with out.open("w") as f:
        w = csv.writer(f)
        w.writerow(["bin_lower", "bin_upper", "count"])
        for i in range(10):
            w.writerow([i / 10, (i + 1) / 10, bins.get(i, 0)])
    print(f"\nHistogram written: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
