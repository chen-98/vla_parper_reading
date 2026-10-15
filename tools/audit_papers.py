from __future__ import annotations

import json
import re
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
PAPERS = ROOT / "papers"
OUT = PAPERS / "metadata" / "review_audit.json"


def clean(text: str) -> str:
    text = text.replace("\x00", " ").replace("\u00ad", "")
    return re.sub(r"\s+", " ", text).strip()


def snippet(text: str, patterns: list[str], width: int = 1400) -> tuple[str, str]:
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.I)
        if match:
            start = max(0, match.start() - 100)
            return pattern, clean(text[start : start + width])
    return "", ""


def page_for(pages: list[str], patterns: list[str]) -> int | None:
    for index, page in enumerate(pages, start=1):
        if any(re.search(pattern, page, flags=re.I) for pattern in patterns):
            return index
    return None


records = []
for pdf in sorted(PAPERS.rglob("*.pdf")):
    relative = pdf.relative_to(ROOT).as_posix()
    try:
        reader = PdfReader(str(pdf))
        pages = [page.extract_text() or "" for page in reader.pages]
        joined = "\n".join(pages)
        first_pages = clean("\n".join(pages[:2]))[:3000]

        abstract_pattern, abstract = snippet(joined, [r"\babstract\b"])
        intro_pattern, intro = snippet(joined, [r"\b1\.?\s+introduction\b", r"\bintroduction\b"])
        method_pattern, method = snippet(
            joined,
            [
                r"\b3\.?\s+(?:method|approach|methodology|framework|model)\b",
                r"\bmethod(?:ology)?\b",
                r"\boverall (?:architecture|framework)\b",
            ],
        )
        results_pattern, results = snippet(
            joined,
            [r"\b(?:4|5|6)\.?\s+(?:experiments?|results?|evaluation)\b", r"\bexperimental results\b"],
        )
        ablation_pattern, ablation = snippet(joined, [r"\bablation(?: study| studies| analysis)?\b"])
        limitations_pattern, limitations = snippet(
            joined,
            [r"\blimitations?\b", r"\bfuture work\b", r"\bdiscussion\b"],
        )
        figure_pattern, figure = snippet(
            joined,
            [
                r"(?:fig\.?|figure)\s*1\s*[:.]",
                r"(?:fig\.?|figure)\s*2\s*[:.]",
                r"overall (?:architecture|framework|pipeline)",
            ],
            width=1000,
        )

        records.append(
            {
                "id": pdf.stem.split("_")[0] if pdf.stem.startswith("B") else pdf.stem.split("_")[0],
                "local_pdf": relative,
                "bytes": pdf.stat().st_size,
                "pages": len(pages),
                "title_page_text": first_pages,
                "section_pages": {
                    "abstract": page_for(pages, [r"\babstract\b"]),
                    "introduction": page_for(pages, [r"\bintroduction\b"]),
                    "architecture_figure": page_for(
                        pages,
                        [r"(?:fig\.?|figure)\s*[12]\s*[:.]", r"overall (?:architecture|framework|pipeline)"],
                    ),
                    "method": page_for(pages, [r"\bmethod(?:ology)?\b", r"\bframework\b"]),
                    "results": page_for(pages, [r"\bexperiments?\b", r"\bresults?\b", r"\bevaluation\b"]),
                    "ablation": page_for(pages, [r"\bablation\b"]),
                    "limitations": page_for(pages, [r"\blimitations?\b", r"\bfuture work\b", r"\bdiscussion\b"]),
                },
                "snippets": {
                    "abstract": abstract,
                    "introduction": intro,
                    "architecture_figure": figure,
                    "method": method,
                    "results": results,
                    "ablation": ablation,
                    "limitations": limitations,
                },
                "matched_patterns": {
                    "abstract": abstract_pattern,
                    "introduction": intro_pattern,
                    "architecture_figure": figure_pattern,
                    "method": method_pattern,
                    "results": results_pattern,
                    "ablation": ablation_pattern,
                    "limitations": limitations_pattern,
                },
            }
        )
    except Exception as exc:
        records.append({"local_pdf": relative, "error": f"{type(exc).__name__}: {exc}"})

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")

summary = {
    "count": len(records),
    "errors": sum("error" in record for record in records),
    "missing_abstract": sum(not record.get("snippets", {}).get("abstract") for record in records),
    "missing_intro": sum(not record.get("snippets", {}).get("introduction") for record in records),
    "missing_figure": sum(not record.get("snippets", {}).get("architecture_figure") for record in records),
    "missing_method": sum(not record.get("snippets", {}).get("method") for record in records),
    "missing_results": sum(not record.get("snippets", {}).get("results") for record in records),
    "missing_ablation": sum(not record.get("snippets", {}).get("ablation") for record in records),
    "missing_limitations": sum(not record.get("snippets", {}).get("limitations") for record in records),
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
