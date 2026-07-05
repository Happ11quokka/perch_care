const pptxgen = require("pptxgenjs");

let pres = new pptxgen();
pres.layout = "LAYOUT_16x9";
pres.title = "Hybrid LLM Pipeline - 앵박사";

// Color palette (dark navy theme like reference slide)
const C = {
  bg: "1A1A2E",        // deep navy background
  panel: "16213E",     // slightly lighter panel
  accent: "0F3460",    // dark blue card bg
  purple: "533483",    // purple accent
  violet: "7B2FBE",    // violet highlight
  teal: "00B4D8",      // teal arrow/connector
  green: "4CAF50",     // green label
  orange: "FF9A42",    // brand orange (perchcare)
  white: "FFFFFF",
  light: "E0E0E0",
  muted: "9E9E9E",
  boxBg: "0D1B2A",     // box background
  boxBorder: "1E3A5F",
  red: "E53935",
};

const makeShadow = () => ({
  type: "outer", blur: 8, offset: 3, angle: 135, color: "000000", opacity: 0.3,
});

let slide = pres.addSlide();
slide.background = { color: C.bg };

// ─── TITLE AREA ─────────────────────────────────────────────────────────────
slide.addShape(pres.shapes.RECTANGLE, {
  x: 0, y: 0, w: 10, h: 0.7, fill: { color: C.panel }, line: { color: C.panel },
});
slide.addText("Key Contributions — Hybrid LLM", {
  x: 0.3, y: 0.08, w: 5.5, h: 0.54, fontSize: 22, bold: true,
  color: C.white, fontFace: "Arial Black", margin: 0,
});
slide.addText("앵박사 AI 파이프라인", {
  x: 5.9, y: 0.08, w: 3.8, h: 0.54, fontSize: 16,
  color: C.teal, fontFace: "Arial", margin: 0, align: "right",
});

// ─── LEFT COLUMN: 설명 + 기술스택 + 트러블슈팅 ──────────────────────────────
const LX = 0.2;

// 설명 section
slide.addShape(pres.shapes.RECTANGLE, {
  x: LX, y: 0.78, w: 0.06, h: 0.55,
  fill: { color: C.orange }, line: { color: C.orange },
});
slide.addText("설명", {
  x: LX + 0.14, y: 0.78, w: 1.0, h: 0.28,
  fontSize: 13, bold: true, color: C.orange, fontFace: "Arial", margin: 0,
});
slide.addText([
  { text: "하이브리드 LLM 구조:", options: { bold: true, breakLine: true } },
  { text: "중국 조류 문화·법규 컨텍스트 → DeepSeek 메인 추론·요약", options: { breakLine: true } },
  { text: "→ GPT 계열 → 언어·도메인별 최적 모델 자동 배분", options: {} },
], {
  x: LX + 0.14, y: 1.05, w: 4.4, h: 0.7,
  fontSize: 10.5, color: C.light, fontFace: "Arial", margin: 0,
});

// 기술스택
slide.addText([
  { text: "사용 기술 스택    ", options: { bold: true } },
  { text: "OpenAI, DeepSeek, ChromaDB, FastAPI, LangSmith", options: { color: C.teal } },
], {
  x: LX + 0.14, y: 1.72, w: 4.4, h: 0.3,
  fontSize: 10.5, color: C.light, fontFace: "Arial", margin: 0,
});

// 트러블슈팅 header
slide.addShape(pres.shapes.RECTANGLE, {
  x: LX, y: 2.1, w: 0.06, h: 2.8,
  fill: { color: C.violet }, line: { color: C.violet },
});
slide.addText("트러블슈팅", {
  x: LX + 0.14, y: 2.1, w: 2.0, h: 0.3,
  fontSize: 13, bold: true, color: C.violet, fontFace: "Arial", margin: 0,
});

// 문제
slide.addText("문제:", {
  x: LX + 0.14, y: 2.42, w: 4.4, h: 0.25,
  fontSize: 11, bold: true, color: C.white, fontFace: "Arial", margin: 0,
});
const problems = [
  "GPT-only → 중국어 정확도·문화 자연스러움 부족",
  "모든 질문에 동일 모델 → 비용·품질 조정 불가",
  "흐릿·가려진 이미지도 정상 판단 + 높은 confidence 환각",
  "SSE 스트림 중 DB 커넥션 점유",
];
problems.forEach((p, i) => {
  slide.addText(`${i + 1}. ${p}`, {
    x: LX + 0.28, y: 2.67 + i * 0.27, w: 4.3, h: 0.25,
    fontSize: 9.5, color: C.light, fontFace: "Arial", margin: 0,
  });
});

// 해결법
slide.addText("해결법:", {
  x: LX + 0.14, y: 3.8, w: 4.4, h: 0.25,
  fontSize: 11, bold: true, color: C.white, fontFace: "Arial", margin: 0,
});
const solutions = [
  ["Counter 빈도 기반 언어 감지 → DeepSeek RAG 보충", null],
  ["_select_model(tier, category) 도입", "질병: 4o-mini / 일상: 4.1-nano / 비전: 4o"],
  ["VIS-1 품질 사전 검증 → VIS-2 not_visible 강제", "VIS-3 _calibrate_confidence()  (not_visible당 -8, 상한 80캡)"],
  ["Quota / Log 세션 분리", null],
];
let sy = 4.05;
solutions.forEach((s, i) => {
  slide.addText(`${i + 1}. ${s[0]}`, {
    x: LX + 0.28, y: sy, w: 4.3, h: 0.25,
    fontSize: 9.5, color: C.light, fontFace: "Arial", margin: 0,
  });
  sy += 0.25;
  if (s[1]) {
    slide.addText(`    — ${s[1]}`, {
      x: LX + 0.28, y: sy, w: 4.3, h: 0.22,
      fontSize: 9, color: C.muted, fontFace: "Arial", margin: 0,
    });
    sy += 0.22;
  }
});

// ─── RIGHT COLUMN: Pipeline Diagram ─────────────────────────────────────────
const RX = 5.1;
const RW = 4.7;

// Section label
slide.addText("파이프라인 구조", {
  x: RX, y: 0.75, w: RW, h: 0.3,
  fontSize: 11, bold: true, color: C.muted, fontFace: "Arial",
  align: "center", margin: 0,
});

// Helper: draw a box node
function addNode(slide, x, y, w, h, label, sublabel, bgColor) {
  slide.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: bgColor || C.accent },
    line: { color: C.teal, width: 1 },
    shadow: makeShadow(),
  });
  const items = [{ text: label, options: { bold: true, breakLine: sublabel ? true : false } }];
  if (sublabel) items.push({ text: sublabel, options: { fontSize: 8, color: C.muted } });
  slide.addText(items, {
    x, y, w, h,
    fontSize: 10, color: C.white, fontFace: "Arial",
    align: "center", valign: "middle", margin: 2,
  });
}

// Helper: horizontal arrow
function hArrow(slide, x, y, w) {
  slide.addShape(pres.shapes.LINE, {
    x, y, w, h: 0,
    line: { color: C.teal, width: 1.5, endArrowType: "arrow" },
  });
}

// Helper: vertical arrow down
function vArrow(slide, x, y, h) {
  slide.addShape(pres.shapes.LINE, {
    x, y, w: 0, h,
    line: { color: C.teal, width: 1.5, endArrowType: "arrow" },
  });
}

// ── Row 1: User Input → Mode Routing ──────────────────────────────────────
const nodeH = 0.42;
const nodeW = 0.9;

// User
addNode(slide, RX + 0.05, 1.1, 0.8, nodeH, "사용자", null, C.purple);

// Arrow: user → mode
hArrow(slide, RX + 0.86, 1.31, 0.24);

// Mode diamond
slide.addShape(pres.shapes.RECTANGLE, {
  x: RX + 1.12, y: 1.1, w: 0.75, h: nodeH,
  fill: { color: C.accent }, line: { color: C.orange, width: 1.5 },
  shadow: makeShadow(),
});
slide.addText("Mode", {
  x: RX + 1.12, y: 1.1, w: 0.75, h: nodeH,
  fontSize: 10, bold: true, color: C.orange, align: "center", valign: "middle", margin: 0,
});

// Chat label + arrow right
slide.addText("Chat", { x: RX + 1.92, y: 1.05, w: 0.55, h: 0.2, fontSize: 8.5, color: C.teal, margin: 0 });
hArrow(slide, RX + 1.88, 1.31, 0.35);

// Chat bubble icon box
addNode(slide, RX + 2.25, 1.1, 0.75, nodeH, "앵박사\n챗봇", null, C.accent);

// Vision label + arrow down
slide.addText("Vision", { x: RX + 1.15, y: 1.58, w: 0.65, h: 0.2, fontSize: 8.5, color: C.teal, margin: 0 });
vArrow(slide, RX + 1.495, 1.54, 0.28);

// Vision box
addNode(slide, RX + 1.12, 1.84, 0.75, nodeH, "비전\n분석", null, C.accent);

// ── Context Retrieval panel ──────────────────────────────────────────────
slide.addShape(pres.shapes.RECTANGLE, {
  x: RX + 3.1, y: 1.0, w: 1.45, h: 2.1,
  fill: { color: C.boxBg }, line: { color: C.boxBorder, width: 1 },
  shadow: makeShadow(),
});
slide.addText("Context Retrieval", {
  x: RX + 3.1, y: 1.0, w: 1.45, h: 0.28,
  fontSize: 8.5, bold: true, color: C.muted, align: "center", margin: 2,
});

// Counter box
addNode(slide, RX + 3.18, 1.3, 1.28, 0.32, "Counter (언어감지)", null, C.accent);
// arrow down
vArrow(slide, RX + 3.82, 1.63, 0.22);
// KO/EN + ZH row
addNode(slide, RX + 3.18, 1.87, 0.58, 0.32, "KO/EN", null, C.accent);
addNode(slide, RX + 3.82, 1.87, 0.58, 0.32, "ZH·CN", null, C.accent);
// arrow down from ZH
vArrow(slide, RX + 4.11, 2.2, 0.2);
// DeepSeek box
slide.addShape(pres.shapes.RECTANGLE, {
  x: RX + 3.55, y: 2.41, w: 0.92, h: 0.32,
  fill: { color: C.accent }, line: { color: C.red, width: 1.2 },
  shadow: makeShadow(),
});
slide.addText("DeepSeek\nCN Culture", {
  x: RX + 3.55, y: 2.41, w: 0.92, h: 0.32,
  fontSize: 8, color: C.white, align: "center", valign: "middle", margin: 1,
});
// arrow down
vArrow(slide, RX + 4.01, 2.74, 0.18);
// ChromaDB
addNode(slide, RX + 3.55, 2.93, 0.92, 0.32, "ChromaDB\nvector DB", null, C.accent);

// ── Merge → Model Routing ────────────────────────────────────────────────
// Arrow from chat box → merge area
hArrow(slide, RX + 3.01, 1.31, 0.08);

// Merge label
slide.addText("Merge", {
  x: RX + 3.1, y: 3.3, w: 1.45, h: 0.25,
  fontSize: 8.5, bold: true, color: C.teal, align: "center", margin: 0,
});

// ── Model Routing panel ──────────────────────────────────────────────────
slide.addShape(pres.shapes.RECTANGLE, {
  x: RX + 3.1, y: 3.55, w: 1.45, h: 1.8,
  fill: { color: C.boxBg }, line: { color: C.boxBorder, width: 1 },
  shadow: makeShadow(),
});
slide.addText("Model Routing", {
  x: RX + 3.1, y: 3.55, w: 1.45, h: 0.28,
  fontSize: 8.5, bold: true, color: C.muted, align: "center", margin: 2,
});
// select box
slide.addShape(pres.shapes.RECTANGLE, {
  x: RX + 3.55, y: 3.87, w: 0.92, h: 0.32,
  fill: { color: C.accent }, line: { color: C.orange, width: 1.5 },
  shadow: makeShadow(),
});
slide.addText("_select_model()", {
  x: RX + 3.55, y: 3.87, w: 0.92, h: 0.32,
  fontSize: 7.5, bold: true, color: C.orange, align: "center", valign: "middle", margin: 1,
});
// arrow down
vArrow(slide, RX + 4.01, 4.2, 0.2);
// OpenAI label
slide.addText("OpenAI GPT", {
  x: RX + 3.3, y: 4.4, w: 1.1, h: 0.22,
  fontSize: 8, bold: true, color: C.white, align: "center", margin: 0,
});
// 3 model boxes
const models = [["4o-mini\n질병", "1E88E5"], ["4.1-nano\n일상", "43A047"], ["4o\n비전", "E53935"]];
const mw = 0.4, mx0 = RX + 3.12;
models.forEach((m, i) => {
  slide.addShape(pres.shapes.RECTANGLE, {
    x: mx0 + i * (mw + 0.02), y: 4.62, w: mw, h: 0.45,
    fill: { color: m[1] }, line: { color: m[1] },
    shadow: makeShadow(),
  });
  slide.addText(m[0], {
    x: mx0 + i * (mw + 0.02), y: 4.62, w: mw, h: 0.45,
    fontSize: 7.5, color: C.white, align: "center", valign: "middle", margin: 1,
  });
});

// ── VIS pipeline annotation (bottom left of diagram) ─────────────────────
slide.addShape(pres.shapes.RECTANGLE, {
  x: RX + 0.05, y: 2.45, w: 2.9, h: 0.85,
  fill: { color: C.boxBg }, line: { color: C.boxBorder, width: 1 },
  shadow: makeShadow(),
});
slide.addText("VIS 파이프라인 (비전 confidence 보정)", {
  x: RX + 0.1, y: 2.46, w: 2.8, h: 0.25,
  fontSize: 8.5, bold: true, color: C.muted, margin: 2,
});
const visItems = [
  "VIS-1  이미지 품질 사전 검증",
  "VIS-2  not_visible 부위 강제 표시",
  "VIS-3  _calibrate_confidence()  (−8/항목, 상한 80)",
];
visItems.forEach((v, i) => {
  slide.addText(v, {
    x: RX + 0.18, y: 2.72 + i * 0.19, w: 2.7, h: 0.18,
    fontSize: 8, color: C.light, margin: 0,
  });
});

// arrow from vision → VIS panel
vArrow(slide, RX + 1.495, 2.27, 0.17);

// ── LangSmith annotation ─────────────────────────────────────────────────
slide.addShape(pres.shapes.RECTANGLE, {
  x: RX + 0.05, y: 3.42, w: 2.9, h: 0.55,
  fill: { color: C.boxBg }, line: { color: C.boxBorder, width: 1 },
});
slide.addText([
  { text: "LangSmith ", options: { bold: true, color: C.orange } },
  { text: "Traces GPT vision call → DeepSeek CN supplement\nQuota / Log 세션 분리로 커넥션 풀 보호", options: { color: C.light } },
], {
  x: RX + 0.12, y: 3.44, w: 2.78, h: 0.5,
  fontSize: 8, fontFace: "Arial", margin: 2,
});

// page number
slide.addText("8", {
  x: 9.6, y: 5.3, w: 0.35, h: 0.25,
  fontSize: 10, color: C.muted, align: "center", margin: 0,
});

pres.writeFile({ fileName: "hybrid_llm_pipeline.pptx" });
console.log("✅ hybrid_llm_pipeline.pptx saved");
