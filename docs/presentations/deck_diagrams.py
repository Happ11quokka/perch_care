"""Native-shape diagrams for the AWS deck. `augment(sec)` swaps or inserts diagram blocks
into a parsed markdown section; each diagram is drawn with template colors/fonts.

Part 1 diagrams describe the Perch Care service (from the repo/원고).
Part 2 diagrams follow the AWS Bedrock user guide structure; the source page is cited under
each figure (docs.aws.amazon.com/bedrock/latest/userguide/...).
"""
from deck_style import *  # noqa: F401,F403
from deck_style import (ACCENTS, BLUE, BODY_FONT, CARD_BG, CODE_BG, GAP, GREEN, MUTED, NAVY,
                        ORANGE, PINK, PURPLE, TBL_LINE, TITLE_FONT, WHITE, add_runs, em_len,
                        parse_inline, rect, rgb, textbox)
from lxml import etree
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

LANE_BG = "1A2430"
DOCS = "docs.aws.amazon.com/bedrock/latest/userguide/"


# ── primitives ───────────────────────────────────────────────────────────────
def label(slide, x, y, w, h, text, size=9, color=MUTED, font=BODY_FONT, align=PP_ALIGN.LEFT,
          anchor=MSO_ANCHOR.TOP, bold=False, bold_color=None):
    _, tf = textbox(slide, x, y, w, h, anchor)
    p = tf.paragraphs[0]
    p.alignment = align
    add_runs(p, parse_inline(text), size, color=color, font=font, base_bold=bold,
             bold_color=bold_color or color)
    return tf


def node(slide, x, y, w, h, title, sub=None, accent=ORANGE, fill=CARD_BG, tsize=10, ssize=8.5,
         border=True, mono=False, dashed=False, tcolor=WHITE):
    s = rect(slide, x, y, w, h, fill, line=accent if border else None,
             shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.12)
    if border:
        s.line.width = Pt(1.25)
        if dashed:
            s.line.dash_style = 4  # MSO_LINE.DASH
    tf = s.text_frame
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.margin_left = tf.margin_right = Inches(0.06)
    tf.margin_top = tf.margin_bottom = Inches(0.03)
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    add_runs(p, parse_inline(title), tsize, base_bold=True, color=tcolor,
             font=TITLE_FONT if mono else BODY_FONT, bold_color=tcolor)
    if sub:
        p2 = tf.add_paragraph()
        p2.alignment = PP_ALIGN.CENTER
        add_runs(p2, parse_inline(sub), ssize, color=MUTED, bold_color=accent)
    return s


def arrow(slide, x1, y1, x2, y2, color=MUTED, width=1.25, dashed=False, label_text=None,
          lsize=8, lcolor=None, head=True):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    c.line.color.rgb = rgb(color)
    c.line.width = Pt(width)
    ln = c.line._get_or_add_ln()
    if dashed:
        etree.SubElement(ln, qn("a:prstDash")).set("val", "dash")
    if head:
        te = etree.SubElement(ln, qn("a:tailEnd"))
        te.set("type", "triangle")
        te.set("w", "med")
        te.set("len", "med")
    if label_text:
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        lw = max(0.6, em_len(label_text) * lsize / 72 + 0.15)
        _, tf = textbox(slide, mx - lw / 2, my - 0.22 if abs(y1 - y2) < 0.05 else my - 0.09,
                        lw, 0.2, MSO_ANCHOR.MIDDLE)
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        add_runs(p, [(label_text, {})], lsize, color=lcolor or color)
    return c


def lane(slide, x, y, w, h, title, accent, tsize=9.5):
    rect(slide, x, y, w, h, LANE_BG, line=TBL_LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.03)
    rect(slide, x, y, 0.07, h, accent)
    label(slide, x + 0.18, y + 0.06, w - 0.3, 0.26, title, tsize, accent, TITLE_FONT)


def hchain(slide, x, y, w, h, items, accent=ORANGE, gap=0.32, tsize=10, ssize=8.5, mono=False):
    """items: list of (title, sub) or (title, sub, accent). Returns list of (cx, cy, x, w)."""
    n = len(items)
    nw = (w - gap * (n - 1)) / n
    out = []
    for k, it in enumerate(items):
        title, sub = it[0], it[1]
        acc = it[2] if len(it) > 2 else accent
        nx = x + k * (nw + gap)
        node(slide, nx, y, nw, h, title, sub, acc, tsize=tsize, ssize=ssize, mono=mono)
        out.append((nx + nw / 2, y + h / 2, nx, nw))
        if k > 0:
            arrow(slide, nx - gap + 0.02, y + h / 2, nx - 0.02, y + h / 2)
    return out


def chips(slide, x, y, maxw, texts, accent, size=9, lh=0.27, gapx=0.08):
    """Pill chips flowing left-to-right, wrapping. '*text' → accent-colored emphasis. Returns height."""
    cx, cy = x, y
    for t in texts:
        emph = t.startswith("*")
        t = t.lstrip("*")
        cw = em_len(t) * size / 72 + 0.22
        if cx + cw > x + maxw and cx > x:
            cx, cy = x, cy + lh + 0.05
        s = rect(slide, cx, cy, cw, lh, CODE_BG if not emph else CARD_BG,
                 line=accent if emph else TBL_LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.5)
        tf = s.text_frame
        tf.margin_left = tf.margin_right = Inches(0.05)
        tf.margin_top = tf.margin_bottom = 0
        tf.vertical_anchor = MSO_ANCHOR.MIDDLE
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        add_runs(p, [(t, {})], size, color=accent if emph else WHITE, base_bold=emph)
        cx += cw + gapx
    return cy + lh - y


def stat_tile(slide, x, y, w, h, value, caption, accent, vsize=22):
    rect(slide, x, y, w, h, CARD_BG)
    rect(slide, x, y, w, 0.06, accent)
    label(slide, x + 0.15, y + 0.18, w - 0.3, 0.5, value, vsize, accent, TITLE_FONT, bold=True)
    label(slide, x + 0.15, y + h - 0.42, w - 0.3, 0.36, caption, 9.5, MUTED)


def hbar(slide, x, y, w, h, segments, total=None, lsize=8.5):
    """segments: (text, value, color). Draw a stacked bar; labels inside when wide enough."""
    total = total or sum(v for _, v, _ in segments)
    cx = x
    for text, val, color in segments:
        sw = w * val / total
        s = rect(slide, cx, y, sw, h, color)
        tf = s.text_frame
        tf.margin_left = tf.margin_right = Inches(0.04)
        tf.vertical_anchor = MSO_ANCHOR.MIDDLE
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        if em_len(text) * lsize / 72 + 0.1 < sw:
            add_runs(p, [(text, {})], lsize, color=NAVY, base_bold=True, bold_color=NAVY)
        cx += sw


def source(slide, x, y, w, text):
    label(slide, x, y, w, 0.2, "출처: " + text, 8, "7C8791")
    return 0.2


def diagram(fn, h):
    return dict(type="diagram", fn=fn, h=h)


# ═════════════════════════════════════════════════════════════════════════════
# Part 1 — Perch Care
# ═════════════════════════════════════════════════════════════════════════════
LAYERS_03 = [
    ("클라이언트", ["Flutter iOS / Android", "Riverpod MVVM", "*오프라인 SyncService 큐 (실패 → 로컬 저장 → 재시작 시 재전송)"],
     "lib/src/services/sync/sync_service.dart"),
    ("앱", ["FastAPI + uvicorn", "*단일 프로세스", "Docker", "*replica 1"],
     "backend/Dockerfile — CMD alembic upgrade head && uvicorn"),
    ("앱 내부 상태", ["*slowapi 인메모리 레이트리밋", "*인사이트 중복방지 전역 set", "*/uploads StaticFiles 직접 서빙"],
     "app/limiter.py · app/routers/pets.py:162 · app/main.py:86"),
    ("데이터", ["PostgreSQL 17", "*pgvector 3,072차원 HNSW", "*청크 2,843건", "업로드 = 컨테이너 로컬 디스크"],
     "app/models/knowledge_chunk.py:19"),
    ("배치·백그라운드", ["APScheduler (앱 프로세스 안, 03:00 UTC)", "asyncio.create_task 주간 인사이트",
                  "Railway Cron 일간 알림", "*FCM v1 HTTP 동기 루프"],
     "app/scheduler.py · app/services/push_service.py:39"),
    ("외부", ["OpenAI", "DeepSeek (api.deepseek.com)", "LangSmith", "FCM", "Vercel 랜딩", "Apple / Google / Kakao OAuth"],
     ".env.example — 환경변수 34개"),
    ("배포", ["GitHub main push → Railway 자동 배포", "*IaC 0개", "*.github/workflows 없음"], "—"),
]


def d03_layers(slide, x, y, w):
    lw, rw = 1.45, 3.0
    rh, gap = 0.64, 0.07
    for i, (name, comps, ref) in enumerate(LAYERS_03):
        acc = ACCENTS[i % 5]
        ry = y + i * (rh + gap)
        rect(slide, x, ry, w, rh, LANE_BG)
        rect(slide, x, ry, lw, rh, CARD_BG)
        rect(slide, x, ry, 0.07, rh, acc)
        label(slide, x + 0.17, ry, lw - 0.2, rh, name, 10, acc, TITLE_FONT, anchor=MSO_ANCHOR.MIDDLE, bold=True)
        chips(slide, x + lw + 0.12, ry + 0.06, w - lw - rw - 0.3, comps, ORANGE, size=9.5, lh=0.25)
        label(slide, x + w - rw, ry, rw - 0.1, rh, ref, 8, BLUE, TITLE_FONT, anchor=MSO_ANCHOR.MIDDLE)
    label(slide, x, y + 7 * (rh + gap), w, 0.22,
          "주황 테두리 = replica가 2가 되는 순간 깨지는 항목 · 파란 글씨 = 저장소 코드 근거", 8.5, MUTED)
    return 7 * (rh + gap) + 0.22


def d04_pipeline(slide, x, y, w):
    lh = 1.62
    # lane 1 — encyclopedia
    lane(slide, x, y, w, lh, "Encyclopedia (텍스트) — POST /ai/encyclopedia/stream", GREEN)
    row = y + 0.38
    pts = hchain(slide, x + 0.2, row, w - 0.4, 0.55, [
        ("사용자 질문", "SSE 요청"),
        ("언어 감지", "Counter 빈도"),
        ("RAG", "HyDE → text-embedding-3-large → pgvector HNSW → 리랭킹"),
        ("_select_model(category)", "카테고리별 라우팅"),
        ("gpt-4o-mini / gpt-4.1-nano", "disease = 정확도 · 그 외 = 속도·비용"),
        ("SSE 토큰 스트림", "DB 세션 0 구간"),
    ], GREEN, gap=0.26, tsize=9, ssize=7.5)
    by = y + 1.05
    node(slide, x + 0.2, by, w * 0.6, 0.42,
         "중국어 dominant → DeepSeek 병렬 호출 (중국 조류 문화·법규 보충) → system prompt 합류",
         "실패 시 None으로 조용히 빠짐 → 22번 실사례", PINK, dashed=True, tsize=9, ssize=7.5)
    arrow(slide, x + 0.2 + w * 0.6, by + 0.21, pts[3][0], row + 0.55 + 0.02, PINK, dashed=True)
    # lane 2 — vision
    y2 = y + lh + GAP
    lane(slide, x, y2, w, lh, "Vision Health Check (이미지) — mode: 배변 · 사료 · 외상 · 중독 …", BLUE)
    row2 = y2 + 0.38
    pts2 = hchain(slide, x + 0.2, row2, w - 0.4, 0.55, [
        ("이미지 + mode", "펫 선택"),
        ("언어 감지", "_resolve_language"),
        ("RAG", "search_knowledge(mode, 부위) + 펫 건강 이력 + 과거 분석"),
        ("gpt-4o Vision", "RAG 근거 + 이미지"),
        ("후처리", "not_visible 강제 · confidence 보정"),
        ("SSE 결과", "쿼터 10회/월"),
    ], BLUE, gap=0.26, tsize=9, ssize=7.5)
    by2 = y2 + 1.05
    node(slide, x + 0.2, by2, w * 0.6, 0.42,
         "중국어 → DeepSeek 병렬 호출 (mode별 프롬프트: 중국 특유 맥락 보충) → system prompt 합류",
         "최종 판단은 항상 GPT", PINK, dashed=True, tsize=9, ssize=7.5)
    arrow(slide, x + 0.2 + w * 0.6, by2 + 0.21, pts2[3][0], row2 + 0.55 + 0.02, PINK, dashed=True)
    return 2 * lh + GAP


def d06_stats(slide, x, y, w):
    tiles = [("$20 / 월", "월 인프라 비용 — Railway · Docker · replica 1", ORANGE),
             ("23 req / 시간", "요청량 (2026-09-16 Railway CLI 측정)", GREEN),
             ("32 ms", "응답 p99 · CPU ≈ 0% · 272 MB", BLUE),
             ("us-west2", "리전 — 미국 서부 · 한·중·일 리전 없음", PURPLE)]
    tw = (w - 3 * GAP) / 4
    for k, (v, c, a) in enumerate(tiles):
        stat_tile(slide, x + k * (tw + GAP), y, tw, 1.25, v, c, a)
    return 1.25


def d07_costbar(slide, x, y, w):
    label(slide, x, y, w, 0.24, "**AWS 최소구성 ≈ $105 / 월** — 항목별 비중 (트래픽이 작을수록 NAT 고정비가 지배)", 9.5, WHITE, bold_color=ORANGE)
    hbar(slide, x, y + 0.28, w, 0.36, [
        ("NAT GW $45 · 43%", 45, ORANGE), ("RDS t4g.micro $22 · 21%", 22, PURPLE),
        ("ALB $18 · 17%", 18, BLUE), ("Fargate $10", 10, GREEN), ("기타 $10", 10, PINK)])
    label(slide, x, y + 0.7, 1.6, 0.24, "Railway 현재 $20", 9, GREEN, bold=True)
    hbar(slide, x + 1.6, y + 0.72, w - 1.6, 0.2, [("$20", 20, GREEN)], total=105)
    return 0.95


def d08_funnel(slide, x, y, w):
    items = [("1,000,000", "누적 다운로드", "한·중·미·일·브라질 SOM 합산", PINK),
             ("300,000", "MAU", "다운로드 대비 30% 잔존", GREEN),
             ("50,000", "DAU", "일일 기록 앱 통상 17%", PURPLE),
             ("30,000 / 일", "AI 호출", "DAU의 60%가 하루 1회", BLUE),
             ("500", "피크 동시 SSE 스트림", "DAU의 1%가 동시에 AI 대화", ORANGE)]
    n = len(items)
    gap = 0.34
    nw = (w - gap * (n - 1)) / n
    for k, (v, t, why, acc) in enumerate(items):
        nx = x + k * (nw + gap)
        rect(slide, nx, y, nw, 1.45, CARD_BG)
        rect(slide, nx, y, nw, 0.06, acc)
        label(slide, nx + 0.12, y + 0.14, nw - 0.24, 0.5, v, 20, acc, TITLE_FONT, bold=True)
        label(slide, nx + 0.12, y + 0.62, nw - 0.24, 0.3, t, 10.5, WHITE, bold=True)
        label(slide, nx + 0.12, y + 0.92, nw - 0.24, 0.5, why, 8.5, MUTED)
        if k > 0:
            arrow(slide, nx - gap + 0.03, y + 0.72, nx - 0.03, y + 0.72)
    ny = y + 1.45 + 0.1
    node(slide, x, ny, w, 0.4, "이미지 업로드 20,000 / 일 · 평균 500KB → 일 10GB",
         "S3 + CloudFront · Lambda 썸네일 · 수명주기 30일의 근거 (24번)", MUTED, tsize=9.5, ssize=8, border=False, fill=LANE_BG)
    return 1.45 + 0.1 + 0.4


def d16_decision(slide, x, y, w):
    qh, nh = 0.55, 0.55
    qs = ["요청-응답 1회인가?", "30초 이내에 끝나는가?", "무상태인가? (커넥션 풀 불필요)"]
    qw = 2.3
    gap = 0.5
    node(slide, x, y, 1.4, qh, "AI 작업 하나", "썸네일 · 인사이트 · 푸시 · 챗 …", MUTED, tsize=9.5, ssize=7.5)
    cx = x + 1.4
    for k, q in enumerate(qs):
        arrow(slide, cx + 0.02, y + qh / 2, cx + gap - 0.02, y + qh / 2, label_text="예" if k else None, lcolor=GREEN)
        nx = cx + gap
        node(slide, nx, y, qw, qh, q, None, BLUE, tsize=9.5)
        arrow(slide, nx + qw / 2, y + qh + 0.02, nx + qw / 2, y + qh + 0.42, PINK, label_text="아니오", lcolor=PINK)
        cx = nx + qw
    arrow(slide, cx + 0.02, y + qh / 2, cx + gap - 0.02, y + qh / 2, label_text="예", lcolor=GREEN)
    node(slide, cx + gap, y, w - (cx + gap - x), qh, "Lambda", "1회 · 무상태 · 30초 이내 — 이벤트 · 배치", GREEN, tsize=11, ssize=8)
    fy = y + qh + 0.45
    node(slide, x + 1.9, fy, w - 1.9, nh, "ECS Fargate", "스트림 · 장기 연결 · 커넥션 풀 — 백과사전 챗 SSE · 비전 건강체크 스트림", PINK, tsize=11, ssize=8)
    return qh + 0.45 + nh


def d17_two_paths(slide, x, y, w):
    lh1 = 2.05
    lane(slide, x, y, w, lh1, "사용자가 기다리는 경로 — 동기 · 스트림 (ECS Fargate)", GREEN)
    row = y + 0.62
    pts = hchain(slide, x + 0.2, row, w * 0.5, 0.6, [
        ("앱", "Flutter"), ("CloudFront / WAF", "엣지 레이트리밋"), ("ALB", "SSE 패스스루 · 300s"),
        ("ECS Fargate API", "태스크 2–12 · 오토스케일")], GREEN, gap=0.28, tsize=9.5, ssize=7.5)
    fx, fy = pts[-1][0], pts[-1][1]
    tx = x + w * 0.5 + 0.75
    tw = w - (tx - x) - 0.2
    targets = [("Bedrock — 챗 주 추론", "VPC 엔드포인트 · IAM · Guardrails", ORANGE),
               ("OpenAI — Vision · 임베딩", "NAT 경유 · 외부 API 유지", BLUE),
               ("Aurora + pgvector — RAG · 쿼터", "RDS Proxy · writer 1 + reader 1", PURPLE),
               ("ElastiCache — 레이트리밋 · dedup", "태스크 2개부터 필수", PINK)]
    th = 0.36
    for k, (t, s, a) in enumerate(targets):
        ty = y + 0.36 + k * (th + 0.06)
        node(slide, tx, ty, tw, th, t, None, a, tsize=8.5)
        label(slide, tx + tw + 0.05, ty, 0.01, th, "", 8)
        arrow(slide, pts[-1][2] + pts[-1][3] + 0.02, fy, tx - 0.02, ty + th / 2, a, width=1)
        label(slide, tx + 0.1, ty + th - 0.02, tw, 0.1, "", 6)
    label(slide, x + 0.2, y + lh1 - 0.36, w * 0.5, 0.3, "← SSE 토큰 스트림 → 앱   ·   Fargate에서 사라지는 것: APScheduler · create_task · 동기 푸시 루프 · StaticFiles", 8.5, GREEN)
    # lane 2
    y2 = y + lh1 + GAP
    lh2 = 2.2
    lane(slide, x, y2, w, lh2, "사용자가 기다리지 않는 경로 — 이벤트 · 배치 (Lambda)", PURPLE)
    rows = [
        [("S3 업로드 이벤트", None), ("Lambda", "썸네일 생성"), ("S3", "썸네일 · 수명주기 30일")],
        [("API → SQS enqueue", "주간 인사이트 요청"), ("Lambda", "인사이트 워커"), ("Bedrock", "Flex / 배치 티어"), ("Aurora", "결과 저장")],
        [("EventBridge Scheduler", "일간 알림 크론"), ("Lambda", "팬아웃"), ("SQS", "토큰 배치"), ("Lambda", "FCM 배치 전송")],
    ]
    ry = y2 + 0.36
    for r in rows:
        hchain(slide, x + 0.2, ry, w * 0.72, 0.42, r, PURPLE, gap=0.3, tsize=9, ssize=7.5)
        ry += 0.42 + 0.1
    dx = x + w * 0.72 + 0.55
    node(slide, dx, y2 + 0.36, w - (dx - x) - 0.2, 1.46, "실패 → DLQ → CloudWatch 알람",
         "사라지는 작업 0 · 중복 실행 0 · 끝나지 않는 루프 0", PINK, tsize=9.5, ssize=8, dashed=True)
    return lh1 + GAP + lh2


def d18_paths(slide, x, y, w):
    gw = w * 0.62
    lane(slide, x, y, gw, 1.55, "글로벌 파티션 — 서울 메인 (arn:aws:)", GREEN)
    node(slide, x + 0.2, y + 0.5, 1.5, 0.75, "ECS Fargate", "API 태스크 역할 (IAM)", GREEN, tsize=9.5, ssize=7.5)
    node(slide, x + 2.2, y + 0.38, 1.55, 0.42, "VPC 엔드포인트", "PrivateLink · NAT 안 탐", ORANGE, tsize=9, ssize=7.5)
    node(slide, x + 4.25, y + 0.38, gw - 4.45, 0.42, "Bedrock — Claude (APAC Geo / Global 프로필) · DeepSeek v3.2 (도쿄 in-region)", "OpenAI 호환 엔드포인트 → base_url 한 줄", ORANGE, tsize=8.5, ssize=7.5)
    node(slide, x + 2.2, y + 0.95, 1.55, 0.42, "NAT Gateway", "아웃바운드 · 비용 43%", BLUE, tsize=9, ssize=7.5)
    node(slide, x + 4.25, y + 0.95, gw - 4.45, 0.42, "OpenAI — gpt-4o Vision · text-embedding-3-large", "유지 (재색인 비용 · 임베딩은 Bedrock에 없음)", BLUE, tsize=8.5, ssize=7.5)
    arrow(slide, x + 1.72, y + 0.75, x + 2.18, y + 0.59, ORANGE)
    arrow(slide, x + 1.72, y + 0.95, x + 2.18, y + 1.16, BLUE)
    arrow(slide, x + 3.77, y + 0.59, x + 4.23, y + 0.59, ORANGE)
    arrow(slide, x + 3.77, y + 1.16, x + 4.23, y + 1.16, BLUE)
    cx = x + gw + GAP
    cw = w - gw - GAP
    lane(slide, cx, y, cw, 1.55, "중국 파티션 (arn:aws-cn:) — Bedrock 없음", PINK)
    node(slide, cx + 0.2, y + 0.5, 1.4, 0.75, "ECS Fargate", "베이징 / 닝샤", PINK, tsize=9.5, ssize=7.5)
    node(slide, cx + 2.0, y + 0.5, cw - 2.2, 0.75, "DeepSeek 직접 API", "api.deepseek.com · 데이터가 중국 안에 머묾 (PIPL) · V4-Flash 3~4배 저렴", PINK, tsize=9.5, ssize=7.5)
    arrow(slide, cx + 1.62, y + 0.87, cx + 1.98, y + 0.87, PINK)
    return 1.55


def d23_bars(slide, x, y, w):
    bars = [("LLM 호출 — 월 90만 건 × $0.002~0.003", 1800, "≈ $1,800+", ORANGE),
            ("AWS 인프라 — MAU 30만 · Savings Plan", 1250, "≈ $1,250", BLUE),
            ("Railway — 현재 규모", 20, "$20", GREEN)]
    lw = 3.3
    bh = 0.3
    for k, (t, v, txt, c) in enumerate(bars):
        by = y + k * (bh + 0.1)
        label(slide, x, by, lw, bh, t, 9, WHITE, anchor=MSO_ANCHOR.MIDDLE)
        bw = max((w - lw - 1.0) * v / 1800, 0.06)
        rect(slide, x + lw, by, bw, bh, c)
        label(slide, x + lw + bw + 0.08, by, 1.0, bh, txt, 9.5, c, TITLE_FONT, anchor=MSO_ANCHOR.MIDDLE, bold=True)
    return 3 * (bh + 0.1)


# ═════════════════════════════════════════════════════════════════════════════
# Part 2 — Bedrock (AWS user guide structure)
# ═════════════════════════════════════════════════════════════════════════════
def db05_id(slide, x, y, w):
    parts = [("apac.", "접두어 = 라우팅 범위", "us. / eu. / apac. = Geo 크로스리전 · global. = 전 세계 · 없음 = in-region", PURPLE),
             ("anthropic.", "제공사", "amazon · openai · deepseek · meta …", BLUE),
             ("claude-sonnet-5", "모델 (+ 버전)", "애플리케이션 프로필이면 arn:…:application-inference-profile/… 로 대체", GREEN)]
    ws = [2.3, 2.3, w - 4.6 - 0.4]
    cx = x
    for (t, s, d, a), pw in zip(parts, ws):
        node(slide, cx, y, pw, 0.42, t, None, a, tsize=12, mono=True)
        label(slide, cx + 0.05, y + 0.47, pw - 0.1, 0.22, s, 9, a, bold=True)
        label(slide, cx + 0.05, y + 0.68, pw - 0.1, 0.4, d, 8, MUTED)
        cx += pw + 0.2
    return 1.05 + source(slide, x, y + 1.05, w, DOCS + "inference-profiles-support.html · model-ids.html")


def db06_choose(slide, x, y, w):
    rows = [("OpenAI SDK 코드가 이미 있다", "Chat Completions / Responses", "runtime 엔드포인트 · base_url + 키만 교체", ORANGE),
            ("여러 모델을 한 코드로 부른다", "Converse", "모든 모델 공통 스키마 · Guardrails · 크로스리전", BLUE),
            ("모델 고유 파라미터를 직접 쓴다", "Invoke", "모델별 요청 본문 그대로", PURPLE)]
    rh = 0.36
    for k, (q, api, why, a) in enumerate(rows):
        ry = y + k * (rh + 0.08)
        node(slide, x, ry, 3.4, rh, q, None, MUTED, tsize=9, border=False, fill=LANE_BG)
        arrow(slide, x + 3.42, ry + rh / 2, x + 3.9, ry + rh / 2, a)
        node(slide, x + 3.92, ry, 2.8, rh, api, None, a, tsize=9.5, mono=True)
        label(slide, x + 6.85, ry, w - 6.9, rh, why, 8.5, MUTED, anchor=MSO_ANCHOR.MIDDLE)
    h = 3 * (rh + 0.08)
    return h + source(slide, x, y + h, w, DOCS + "endpoints.html · inference-api.html")


def db07_tiers(slide, x, y, w):
    items = [("Flex", "≈ 50% ↓ · 처리 지연 허용 — 요약 · 평가 · 백그라운드", GREEN),
             ("Standard", "정가 · 기본 (service_tier 생략)", BLUE),
             ("Priority", "≈ 1.75× · 요청 단위 우선 · 최저 지연 — 채팅 첫 토큰", ORANGE),
             ("Reserved", "TPM 예약 · 월 고정 · 99.5% 목표 · 초과분은 Standard", PURPLE)]
    n = 4
    gap = 0.25
    nw = (w - 2.2 - gap * (n - 1)) / n
    for k, (t, s, a) in enumerate(items):
        nx = x + k * (nw + gap)
        node(slide, nx, y, nw, 0.62, t, s, a, tsize=11, ssize=8, mono=True)
    arrow(slide, x, y + 0.72, x + w - 2.2, y + 0.72, MUTED, label_text="지연 ↓ · 확실성 ↑ · 단가 ↑", lsize=8.5)
    node(slide, x + w - 2.0, y, 2.0, 0.62, "배치 추론", "S3 JSONL → 잡 → S3 · 50% ↓ · 툴/캐싱 ✗", PINK, tsize=10, ssize=7.5, dashed=True, mono=True)
    return 0.95 + source(slide, x, y + 0.95, w, DOCS + "service-tiers-inference.html · batch-inference.html")


def db08_regions(slide, x, y, w):
    node(slide, x, y + 0.55, 2.0, 0.9, "서울 ap-northeast-2", "호출 리전 = 가격 기준 · CloudTrail inferenceRegion에 실제 처리 리전 기록", ORANGE, tsize=10, ssize=7.5)
    bx = x + 2.7
    bw = (w - 2.7 - GAP) / 2
    lane(slide, bx, y, bw, 1.0, "Geo 크로스리전 — apac.  (데이터 잔류: 지리권 안 · 정가)", PURPLE)
    chips(slide, bx + 0.2, y + 0.4, bw - 0.4, ["서울", "도쿄", "싱가포르", "시드니", "뭄바이", "*Claude Fable 5 ✅"], PURPLE, size=8.5)
    lane(slide, bx + bw + GAP, y, bw, 1.0, "Global 크로스리전 — global.  (전 세계 상용 리전 · ≈10% 저렴)", BLUE)
    chips(slide, bx + bw + GAP + 0.2, y + 0.4, bw - 0.4, ["us-east-1", "us-west-2", "eu-west-1", "ap-*", "…", "*Opus 5 · Sonnet 5 · GPT-5.6"], BLUE, size=8.5)
    lane(slide, bx, y + 1.1, w - 2.7, 0.55, "in-region 직접 호출 — 접두어 없음 (예: DeepSeek V3.2는 도쿄 in-region · 서울 없음 · 크로스리전 미지원 → 서울→도쿄 ≈ 30ms)", GREEN, tsize=8.5)
    arrow(slide, x + 2.02, y + 0.85, bx - 0.02, y + 0.5, PURPLE)
    arrow(slide, x + 2.02, y + 1.0, bx + bw + GAP - 0.02, y + 0.5, BLUE)
    arrow(slide, x + 2.02, y + 1.2, bx - 0.02, y + 1.37, GREEN)
    label(slide, x, y + 1.75, w, 0.22, "공통: 추가 라우팅 비용 없음 · AWS 백본만 사용 · 목적지 리전 활성화 불필요 · Geo는 SCP에서 모든 목적지 리전 허용 필요", 8.5, MUTED)
    return 1.97 + source(slide, x, y + 1.97, w, DOCS + "cross-region-inference.html")


def db09_cache(slide, x, y, w):
    segs = [("tools", 1.3, ORANGE), ("system 프롬프트", 2.0, ORANGE), ("RAG 컨텍스트", 2.2, ORANGE),
            ("최근 10턴 히스토리", 2.4, BLUE), ("새 질문", 1.5, BLUE)]
    total = sum(s[1] for s in segs)
    cx = x
    cp = None
    for k, (t, ww, c) in enumerate(segs):
        sw = (w - 0.6) * ww / total
        node(slide, cx, y + 0.3, sw, 0.5, t, None, c, tsize=9.5, fill=CARD_BG)
        cx += sw + 0.1
        if k == 2:
            cp = cx - 0.05
            cx += 0.2
    rect(slide, cp - 0.02, y + 0.15, 0.05, 0.8, GREEN)
    label(slide, cp - 1.0, y - 0.02, 2.0, 0.22, "cachePoint (체크포인트)", 9, GREEN, TITLE_FONT, align=PP_ALIGN.CENTER, bold=True)
    label(slide, x, y + 0.88, cp - x, 0.3, "캐시 구간 (prefix) — 쓰기 1.25× · 읽기 −90% · 레이트리밋 미포함 · TTL 5분(히트마다 연장)", 8.5, ORANGE)
    label(slide, cp + 0.15, y + 0.88, x + w - cp - 0.15, 0.3, "매번 달라지는 부분 — 정가. 순서 tools → system → messages: 앞이 바뀌면 뒤 캐시 전부 무효", 8.5, BLUE)
    return 1.22 + source(slide, x, y + 1.22, w, DOCS + "prompt-caching.html")


def db10_guardrails(slide, x, y, w):
    hchain(slide, x, y, w, 0.55, [
        ("사용자 입력", "질문 + (태그로 일부만 평가)"),
        ("Guardrail — 입력 평가", "6 정책: 콘텐츠 · 거부 주제 · 단어 · PII · 근거 · 자동 추론"),
        ("모델 (Bedrock)", "guardrailIdentifier + 버전"),
        ("Guardrail — 출력 평가", "위반 시 설정 문구로 교체 · PII 마스킹"),
        ("응답", "→ 사용자")], GREEN, gap=0.28, tsize=9, ssize=7.5)
    y2 = y + 0.72
    hchain(slide, x, y2, w * 0.7, 0.5, [
        ("Bedrock 밖 모델 응답", "예: OpenAI gpt-4o Vision"),
        ("ApplyGuardrail API", "모델 호출 없이 텍스트만 평가"),
        ("같은 규칙 적용", "두 경로에 동일한 경계")], PINK, gap=0.28, tsize=9, ssize=7.5)
    label(slide, x + w * 0.7 + 0.15, y2, w * 0.3 - 0.15, 0.5, "티어: Classic / Standard · 드래프트 → 테스트 → 버전 배포 · 크로스리전 분산", 8, MUTED, anchor=MSO_ANCHOR.MIDDLE)
    return 1.3 + source(slide, x, y + 1.3, w, DOCS + "guardrails.html · guardrails-use-independent-api.html")


def db11_rag(slide, x, y, w):
    lane(slide, x, y, w, 0.95, "인제스트 — 데이터 소스 → 벡터스토어 (S3 · SharePoint · Confluence · 웹크롤러 …)", PURPLE)
    hchain(slide, x + 0.2, y + 0.38, w - 0.4, 0.42, [
        ("문서", None), ("파싱", "Smart Parsing: PDF · PPTX · 스캔 · 음성"), ("청킹", "고정 / 의미 / 계층"),
        ("임베딩", "Titan V2 · Cohere · Nova"), ("벡터스토어", "관리형 또는 Aurora · OpenSearch · Neptune")],
        PURPLE, gap=0.3, tsize=9, ssize=7.5)
    y2 = y + 1.05
    lane(slide, x, y2, w, 0.95, "쿼리 — Retrieve (청크만) / RetrieveAndGenerate (청크 + 생성 + 인용)", GREEN)
    hchain(slide, x + 0.2, y2 + 0.38, w - 0.4, 0.42, [
        ("질문", None), ("임베딩", "같은 모델"), ("벡터 검색", "관련 청크 k개 · 리랭커 · Agentic Retrieval"),
        ("프롬프트 보강", "청크를 컨텍스트로"), ("모델", "파운데이션 모델"), ("답 + 인용", "출처 표기")],
        GREEN, gap=0.3, tsize=9, ssize=7.5)
    return 2.0 + source(slide, x, y + 2.0, w, DOCS + "knowledge-base.html")


AGENTCORE = [
    ("Harness", "모델 · 시스템 프롬프트 · 툴을 한 API로 지정 → 관리형 에이전트 루프 (microVM 격리)", ORANGE),
    ("Runtime", "에이전트 · 툴 전용 서버리스 런타임 — 세션 격리 · 장기 실행 · MCP / A2A", GREEN),
    ("Memory", "단기(멀티턴) + 장기(세션 간) 메모리 · 에이전트 간 공유", PURPLE),
    ("Gateway", "기존 API · Lambda · 서비스를 MCP 툴로 변환 · 외부 MCP 서버 연결", BLUE),
    ("Identity", "에이전트용 인증 · 자격증명 — Cognito · Okta · Entra ID", PINK),
    ("Code Interpreter / Browser", "격리 샌드박스 코드 실행 · 클라우드 브라우저", ORANGE),
    ("Observability", "OTEL 기반 트레이스 · 디버그", GREEN),
    ("Evaluations / Optimization", "에이전트 품질 평가 · 프롬프트 · 툴 설명 A/B 최적화", PURPLE),
    ("Policy / Registry / Payments", "Cedar 규칙으로 툴 호출 통제 · 에이전트·MCP 카탈로그 · x402 마이크로결제", BLUE),
]


def db12_agentcore(slide, x, y, w):
    node(slide, x, y, w, 0.5, "내 에이전트 — 프레임워크 무관 (LangGraph · CrewAI · Strands · OpenAI Agents SDK) · 모델 무관 (Bedrock 또는 OpenAI · Gemini)",
         "AgentCore = 에이전트를 '운영'해 주는 플랫폼 · Agents Classic은 유지보수 모드", WHITE, tsize=9.5, ssize=8, fill=LANE_BG)
    cols, ch = 3, 0.78
    cw = (w - GAP * (cols - 1)) / cols
    for i, (t, d, a) in enumerate(AGENTCORE):
        cx = x + (i % cols) * (cw + GAP)
        cy = y + 0.62 + (i // cols) * (ch + GAP)
        rect(slide, cx, cy, cw, ch, CARD_BG)
        rect(slide, cx, cy, cw, 0.05, a)
        label(slide, cx + 0.12, cy + 0.1, cw - 0.24, 0.26, t, 10, a, TITLE_FONT, bold=True)
        label(slide, cx + 0.12, cy + 0.36, cw - 0.24, ch - 0.4, d, 8.5, WHITE)
    h = 0.62 + 3 * (ch + GAP)
    return h + source(slide, x, y + h, w, "docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html")


def db13_ladder(slide, x, y, w):
    steps = [("프롬프트 엔지니어링", "먼저 · 비용 0", GREEN), ("RAG", "지식 — 바뀌는 것", BLUE),
             ("증류 (Distillation)", "큰 모델 품질을 작은 모델 비용에", PURPLE), ("SFT / RFT", "행동 — 안 바뀌는 것 · 마지막 수단", ORANGE)]
    n = 4
    gap = 0.4
    nw = (w - gap * (n - 1)) / n
    for k, (t, s, a) in enumerate(steps):
        nx = x + k * (nw + gap)
        node(slide, nx, y + 0.5 - k * 0.15, nw, 0.6, t, s, a, tsize=10, ssize=8)
        if k > 0:
            arrow(slide, nx - gap + 0.03, y + 0.8 - (k - 1) * 0.15, nx - 0.03, y + 0.8 - k * 0.15)
    return 1.15 + source(slide, x, y + 1.15, w, DOCS + "custom-models.html · model-distillation.html")


def db14_protection(slide, x, y, w):
    nw = (w - 0.9 * 2 - 2.4) / 3
    node(slide, x, y, nw, 1.05, "내 AWS 계정", "VPC → PrivateLink (인터넷 ✗) · KMS 고객 키 · CloudTrail (누가 · 언제 · 어떤 모델) · 모델 호출 로깅(선택)", GREEN, tsize=10, ssize=8)
    node(slide, x + nw + 0.9, y, nw, 1.05, "Bedrock 서비스", "Data retention mode: none (저장 안 함) · default · aws_review (최대 30일) · SCP로 조직 전체 강제", ORANGE, tsize=10, ssize=8)
    node(slide, x + 2 * (nw + 0.9), y, nw, 1.05, "Model Deployment Account", "AWS 소유 · 리전별 제공사 모델 deep copy · 제공사는 계정 · 로그 · 프롬프트 · 응답 접근 ✗", PURPLE, tsize=10, ssize=8)
    arrow(slide, x + nw + 0.02, y + 0.52, x + nw + 0.88, y + 0.52, GREEN, label_text="TLS 1.2+")
    arrow(slide, x + 2 * nw + 0.92, y + 0.52, x + 2 * nw + 1.78, y + 0.52, ORANGE, label_text="추론")
    px = x + 3 * nw + 1.8 + 0.6
    node(slide, px, y + 0.2, w - (px - x), 0.65, "제공사 (OpenAI · Anthropic · DeepSeek …)", "접근 불가 — 학습에도 쓰이지 않음", PINK, tsize=9, ssize=7.5, dashed=True)
    arrow(slide, x + 3 * nw + 1.82, y + 0.52, px - 0.02, y + 0.52, PINK, dashed=True, label_text="✗")
    return 1.1 + source(slide, x, y + 1.1, w, DOCS + "data-protection.html · data-retention.html")


def db15_formula(slide, x, y, w):
    parts = [("① 토큰", "입력 · 출력 · 캐시 쓰기 1.25× · 읽기 −90%", ORANGE, "×"),
             ("② 티어 배율", "Priority ↑ · Standard 1× · Flex ↓ · Reserved 고정", BLUE, "×"),
             ("③ 리전", "in-region · Geo = 정가 · Global ≈ −10%", PURPLE, "×"),
             ("④ 처리 방식", "온디맨드 · 배치 −50% · Provisioned", GREEN, "+"),
             ("⑤ 커스터마이징", "학습 토큰 × epoch + 모델 저장 월정액", PINK, "=")]
    n = len(parts)
    ow = 0.32
    nw = (w - 1.3 - ow * n) / n
    cx = x
    for t, s, a, op in parts:
        node(slide, cx, y, nw, 0.6, t, s, a, tsize=9.5, ssize=7.5)
        label(slide, cx + nw, y, ow, 0.6, op, 14, WHITE, TITLE_FONT, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, bold=True)
        cx += nw + ow
    node(slide, cx, y, 1.3, 0.6, "청구서", "Cost Explorer · 앱 추론 프로필 태그", WHITE, tsize=10, ssize=7.5, fill=LANE_BG)
    return 0.7 + source(slide, x, y + 0.7, w, "aws.amazon.com/bedrock/pricing · " + DOCS + "inference-profiles-create.html")


# ═════════════════════════════════════════════════════════════════════════════
# augment: where each diagram goes
# ═════════════════════════════════════════════════════════════════════════════
def _replace_first(blocks, btype, new, pred=None):
    for i, b in enumerate(blocks):
        if b["type"] == btype and (pred is None or pred(b)):
            blocks[i] = new
            return True
    return False


def _insert_after(blocks, btype, new, pred=None):
    for i, b in enumerate(blocks):
        if b["type"] == btype and (pred is None or pred(b)):
            blocks.insert(i + 1, new)
            return True
    return False


def _drop_list_items(blocks, needles):
    for b in blocks:
        if b["type"] == "list":
            b["items"] = [it for it in b["items"] if not any(n in it[1] for n in needles)]


def augment(sec):
    bl = sec.blocks
    sid = sec.id
    if sid == "03":
        _replace_first(bl, "table", diagram(d03_layers, 5.2))
    elif sid == "04":
        _replace_first(bl, "code", diagram(d04_pipeline, 3.36))
    elif sid == "06":
        for b in bl:
            if b["type"] == "table":
                b["rows"] = [r for r in b["rows"] if not any(k in r[0] for k in ("월 인프라 비용", "요청량", "응답 p99", "메모리", "리전"))]
        bl.insert(0, diagram(d06_stats, 1.25))
    elif sid == "07":
        _insert_after(bl, "table", diagram(d07_costbar, 0.95))
    elif sid == "08":
        _replace_first(bl, "table", diagram(d08_funnel, 1.95))
    elif sid == "16":
        _replace_first(bl, "callout", diagram(d16_decision, 1.55), lambda b: "결정 규칙" in b["text"])
    elif sid == "17":
        _replace_first(bl, "code", diagram(d17_two_paths, 4.37))
    elif sid == "18":
        _insert_after(bl, "table", diagram(d18_paths, 1.55))
    elif sid == "23":
        _insert_after(bl, "table", diagram(d23_bars, 1.2))
    elif sid == "B05":
        _insert_after(bl, "table", diagram(db05_id, 1.25))
    elif sid == "B06":
        _drop_list_items(bl, ["API 고르는 규칙", "OpenAI SDK 코드가 이미", "여러 모델을 한 코드로", "모델 고유 파라미터를 직접"])
        _insert_after(bl, "table", diagram(db06_choose, 1.52))
    elif sid == "B07":
        _replace_first(bl, "code", diagram(db07_tiers, 1.15))
    elif sid == "B08":
        _insert_after(bl, "table", diagram(db08_regions, 2.17))
    elif sid == "B09":
        _insert_after(bl, "table", diagram(db09_cache, 1.42))
    elif sid == "B10":
        _insert_after(bl, "table", diagram(db10_guardrails, 1.5))
    elif sid == "B11":
        _replace_first(bl, "code", diagram(db11_rag, 2.2))
    elif sid == "B12":
        _replace_first(bl, "table", diagram(db12_agentcore, 3.52))
    elif sid == "B13":
        _drop_list_items(bl, ["결정 순서"])
        _insert_after(bl, "list", diagram(db13_ladder, 1.35))
    elif sid == "B14":
        _insert_after(bl, "list", diagram(db14_protection, 1.3))
    elif sid == "B15":
        bl.insert(0, diagram(db15_formula, 0.9))
