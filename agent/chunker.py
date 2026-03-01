"""
마크다운 문서를 의미 단위 청크로 분할하는 모듈.

청킹 전략 — 섹션 기반:
1. H2 헤더 기준 섹션 분리
2. H3 서브섹션은 각각 별도 청크
3. 문서 제목(H1) + 섹션 헤더를 각 청크 앞에 붙임
4. References 섹션 제외
5. 1500자 초과 시 문단 경계로 서브 분할
6. 100자 미만 청크 스킵
"""

import re
from pathlib import Path

SKIP_FILES = {"_index.md", "README.md"}
SKIP_SECTIONS = {"references", "参考来源", "参考资料", "主要参考来源"}
MAX_CHUNK_CHARS = 1500
MIN_CHUNK_CHARS = 100


def parse_markdown_into_chunks(
    content: str,
    source: str,
    category: str,
    language: str,
) -> list[dict]:
    """마크다운 문서를 섹션 기반으로 청킹하여 딕셔너리 리스트로 반환."""
    lines = content.split("\n")

    # H1 제목 추출
    doc_title = ""
    for line in lines:
        if line.startswith("# ") and not line.startswith("## "):
            doc_title = line.lstrip("# ").strip()
            break

    # H2 섹션으로 분리
    sections = _split_by_h2(lines)

    chunks = []
    for section_title, section_lines in sections:
        # References 섹션 스킵
        if section_title.lower().strip() in SKIP_SECTIONS:
            continue

        # H3 서브섹션이 있으면 각각 분리
        subsections = _split_by_h3(section_lines)

        if len(subsections) > 1:
            # H3 서브섹션 각각을 청크로
            for sub_title, sub_lines in subsections:
                full_title = f"{section_title} > {sub_title}" if sub_title else section_title
                text = _build_chunk_text(doc_title, full_title, sub_lines)
                _add_chunks(chunks, text, source, category, language, full_title)
        else:
            # H3 없으면 H2 섹션 전체를 청크로
            text = _build_chunk_text(doc_title, section_title, section_lines)
            _add_chunks(chunks, text, source, category, language, section_title)

    return chunks


def _split_by_h2(lines: list[str]) -> list[tuple[str, list[str]]]:
    """라인들을 H2 헤더 기준으로 분리."""
    sections = []
    current_title = ""
    current_lines = []

    for line in lines:
        if line.startswith("## "):
            if current_title or current_lines:
                sections.append((current_title, current_lines))
            current_title = line.lstrip("# ").strip()
            current_lines = []
        elif line.startswith("# ") and not line.startswith("## "):
            # H1 제목 건너뛰기 (이미 추출함)
            continue
        else:
            current_lines.append(line)

    if current_title or current_lines:
        sections.append((current_title, current_lines))

    return sections


def _split_by_h3(lines: list[str]) -> list[tuple[str, list[str]]]:
    """라인들을 H3 헤더 기준으로 분리."""
    subsections = []
    current_title = ""
    current_lines = []

    for line in lines:
        if line.startswith("### "):
            if current_title or current_lines:
                subsections.append((current_title, current_lines))
            current_title = line.lstrip("# ").strip()
            current_lines = []
        else:
            current_lines.append(line)

    if current_title or current_lines:
        subsections.append((current_title, current_lines))

    return subsections


def _build_chunk_text(doc_title: str, section_title: str, lines: list[str]) -> str:
    """문서 제목 + 섹션 헤더 + 본문으로 청크 텍스트 구성."""
    body = "\n".join(lines).strip()
    if doc_title and section_title:
        return f"# {doc_title}\n## {section_title}\n{body}"
    elif doc_title:
        return f"# {doc_title}\n{body}"
    elif section_title:
        return f"## {section_title}\n{body}"
    return body


def _add_chunks(
    chunks: list[dict],
    text: str,
    source: str,
    category: str,
    language: str,
    section_title: str,
):
    """텍스트를 청크 리스트에 추가. 너무 길면 문단 경계로 분할."""
    if len(text) < MIN_CHUNK_CHARS:
        return

    if len(text) <= MAX_CHUNK_CHARS:
        chunks.append({
            "content": text,
            "source": source,
            "category": category,
            "language": language,
            "section_title": section_title,
        })
    else:
        # 문단 경계(\n\n)로 서브 분할
        sub_chunks = _split_by_paragraphs(text)
        for i, sub in enumerate(sub_chunks):
            if len(sub) < MIN_CHUNK_CHARS:
                continue
            sub_title = f"{section_title} (part {i + 1})" if len(sub_chunks) > 1 else section_title
            chunks.append({
                "content": sub,
                "source": source,
                "category": category,
                "language": language,
                "section_title": sub_title,
            })


def _split_by_paragraphs(text: str) -> list[str]:
    """긴 텍스트를 문단 경계로 분할하여 MAX_CHUNK_CHARS 이하로 만듦."""
    paragraphs = re.split(r"\n\n+", text)
    result = []
    current = ""

    for para in paragraphs:
        if current and len(current) + len(para) + 2 > MAX_CHUNK_CHARS:
            result.append(current.strip())
            current = para
        else:
            current = current + "\n\n" + para if current else para

    if current.strip():
        result.append(current.strip())

    return result


def discover_knowledge_files(knowledge_dir: Path) -> list[dict]:
    """knowledge 디렉토리에서 처리할 마크다운 파일 목록을 반환."""
    files = []
    for md_file in sorted(knowledge_dir.rglob("*.md")):
        if md_file.name in SKIP_FILES:
            continue
        # 카테고리: knowledge_dir 바로 아래 첫 번째 디렉토리
        rel_path = md_file.relative_to(knowledge_dir)
        parts = rel_path.parts
        category = parts[0] if len(parts) > 1 else "general"
        source = str(rel_path)
        files.append({
            "path": md_file,
            "source": source,
            "category": category,
        })
    return files
