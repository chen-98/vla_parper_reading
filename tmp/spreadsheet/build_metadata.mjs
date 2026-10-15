import fs from "node:fs/promises";
import path from "node:path";
import { Workbook } from "@oai/artifact-tool";

const root = path.resolve(import.meta.dirname, "../..");
const draftPath = path.join(root, "draft_selection.md");
const auditPath = path.join(root, "papers", "metadata", "review_audit.json");
const outputPath = path.join(root, "papers", "metadata", "papers.csv");

const draft = await fs.readFile(draftPath, "utf8");
const audit = JSON.parse(await fs.readFile(auditPath, "utf8"));

const order = [
  "A01", "B01", "A02", "A04", "B02", "A05", "A06", "B03", "A07", "A08",
  "A09", "B04", "B05", "B06", "B07", "A03", "A10", "A11", "A12", "A13",
  "B22", "B23", "B24", "A14", "A15", "A16", "B16", "A17", "B17", "B18",
  "B19", "B20", "B21", "B10", "B08", "B09", "B13", "B12", "B14", "B15",
  "B25", "B26", "B27", "B28", "B40", "B31", "B29", "B30", "B11", "B32",
  "A18", "B33", "B34", "A19", "A24", "A20", "B35", "A21", "B36", "A22",
  "A23", "B37", "B38", "B39", "A25",
];
const readingOrder = new Map(order.map((id, index) => [id, index + 1]));

const categoryByB = {
  B01: "planning foundation",
  B02: "end-to-end driving", B03: "end-to-end driving", B04: "end-to-end driving",
  B05: "unified prediction-planning", B06: "unified end-to-end driving", B07: "multimodal end-to-end planning",
  B08: "world model", B09: "world model / trajectory evaluation", B10: "world model / predictive driving",
  B11: "parking / world-model RL", B12: "world-model closed-loop driving", B13: "world-model RL",
  B14: "3DGS reinforcement learning", B15: "world-model reinforcement learning",
  B16: "diffusion planning", B17: "flow planning", B18: "flow planning", B19: "flow planning",
  B20: "diffusion planner RL", B21: "diffusion planning",
  B22: "action representation", B23: "action chunking", B24: "trajectory tokenization",
  B25: "parking", B26: "parking", B27: "parking benchmark", B28: "parking", B29: "multi-shot parking",
  B30: "multi-shot parking / diffusion", B31: "parking / discrete control", B32: "parking VLA",
  B33: "driving VLM benchmark", B34: "driving VLM / behavioral interface", B35: "driving VLA",
  B36: "driving VLA / reinforcement learning", B37: "driving VLA / trajectory token",
  B38: "language-action alignment", B39: "driving VLA / world model", B40: "parking",
};

const blockRegex = /^### ([AB]\d{2}) — ([^\r\n]+)\r?\n([\s\S]*?)(?=^### [AB]\d{2} —|^## 4\.)/gm;
const blocks = [];
for (const match of draft.matchAll(blockRegex)) {
  blocks.push({ id: match[1], title: match[2].trim(), body: match[3] });
}

const auditById = new Map();
for (const item of audit) {
  const base = path.basename(item.local_pdf || "");
  let id = base.match(/^(B\d{2})_/i)?.[1]?.toUpperCase();
  if (!id) {
    const n = base.match(/^(\d{2})_/)?.[1];
    if (n) id = `A${n}`;
  }
  if (id) auditById.set(id, item);
}

function stripMarkdown(value) {
  return value
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/\*\*/g, "")
    .replace(/`/g, "")
    .replace(/\[\^[^\]]+\]/g, "")
    .trim();
}

function labeledLine(body, labels) {
  for (const label of labels) {
    const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const match = body.match(new RegExp(`^- \\*\\*${escaped}\\*\\*[：:]([^\\r\\n]+)`, "m"));
    if (match) return stripMarkdown(match[1]);
  }
  return "";
}

function links(body) {
  const found = [];
  for (const match of body.matchAll(/\[([^\]]+)\]\((https:\/\/[^)]+)\)/g)) {
    found.push({ label: match[1].toLowerCase(), url: match[2] });
  }
  return found;
}

function normalizeClosedLoop(id, evalLine) {
  if (["A03", "A10", "A11", "A12", "B27"].includes(id)) {
    if (id === "A03") return "benchmark supports reactive and non-reactive closed loop";
    if (id === "A10") return "benchmark: interactive CARLA closed loop";
    if (id === "A11") return "no: non-reactive rollout only";
    if (id === "A12") return "no: rater/open-loop benchmark";
    return "benchmark dataset; baseline evaluated in CARLA closed loop";
  }
  const parts = [];
  if (/CL-reactive/i.test(evalLine)) parts.push("reactive closed loop");
  if (/CL-interactive/i.test(evalLine)) parts.push("interactive simulator closed loop");
  if (/\bReal\b|实车/i.test(evalLine)) parts.push("real-vehicle evaluation");
  if (parts.length) return `yes: ${parts.join(" + ")}`;
  if (/NR-rollout|non-reactive/i.test(evalLine)) return "no: non-reactive rollout only";
  if (/OL-log|Rater|open-loop|无.*closed loop|无强.*closed loop|闭环证据有限/i.test(evalLine)) return "no or not demonstrated: open-loop/rater evidence";
  if (/闭环|closed-loop/i.test(evalLine)) return "yes: closed-loop evidence reported; protocol noted in notes";
  return "not demonstrated";
}

function realAction(id, actionType, category) {
  if (["A03", "A10", "A11", "A12", "B27"].includes(id)) return "n/a: benchmark or dataset";
  if (id === "B33") return "partial: agent baseline; paper core is Graph VQA";
  if (id === "B34") return "high-level only: behavioral planning state/meta-action";
  if (/trajectory|control|diffusion|flow|action|hybrid/i.test(actionType)) return "yes";
  if (/benchmark|VQA/i.test(category)) return "no or auxiliary only";
  return "yes; verify execution interface in notes";
}

function csvEscape(value) {
  const string = value == null ? "" : String(value);
  return /[",\r\n]/.test(string) ? `"${string.replaceAll('"', '""')}"` : string;
}

const rows = [];
for (const block of blocks) {
  const bibliographic = labeledLine(block.body, ["作者 / 年份 / venue"])
    .replace(/。\s+(?:paper|code|project).*$/i, "")
    .replace(/。$/, "");
  const parts = bibliographic.split("；").map((x) => x.trim());
  const authors = parts[0] || "";
  const yearMatch = (parts[1] || "").match(/\b(19|20)\d{2}\b/);
  const year = yearMatch ? Number(yearMatch[0]) : "";
  const venue = parts.slice(2).join("；").replace(/[。.]$/, "");
  const allLinks = links(block.body);
  const paperUrl = allLinks.find((x) => x.label.startsWith("paper"))?.url || "";
  const codeLink = allLinks.find((x) => /code/.test(x.label));
  const projectLink = allLinks.find((x) => /project/.test(x.label));
  const codeUrl = codeLink?.url || "";
  const projectUrl = projectLink?.url || (codeLink && /project/.test(codeLink.label) ? codeLink.url : "");
  const position = labeledLine(block.body, ["一句话定位", "定位与影响"]);
  const categoryRole = labeledLine(block.body, ["类别 / 系统角色"]);
  const evalLine = labeledLine(block.body, ["输出 / action type / 评测", "角色 / 输出 / action / 评测"]);
  const influence = labeledLine(block.body, ["影响信号"]);
  const reason = labeledLine(block.body, ["为何 A / 前后关系", "为何 B / 关系 / 顺序 / 复现"]);
  const reproduction = labeledLine(block.body, ["复现建议"]);
  const relation = reason || labeledLine(block.body, ["为何 B / 关系 / 顺序 / 复现"]);
  const category = block.id.startsWith("A")
    ? (categoryRole.split("；")[0] || "").trim()
    : categoryByB[block.id];
  const systemRole = block.id.startsWith("A")
    ? (categoryRole.split("；").slice(1).join("；") || "").trim()
    : evalLine.split("；")[0].trim();
  const actionMatch = block.body.match(/`([^`]+)`/);
  let actionType = actionMatch?.[1] || "";
  if (!actionType && /benchmark/i.test(category)) actionType = "benchmark / n.a.";
  const auditItem = auditById.get(block.id) || {};
  const sectionPages = auditItem.section_pages || {};
  const reviewedSections = Object.entries(sectionPages)
    .filter(([, page]) => page != null)
    .map(([name, page]) => `${name}:p${page}`)
    .join("; ");
  const reviewGaps = Object.entries(sectionPages)
    .filter(([, page]) => page == null)
    .map(([name]) => `${name} not separately detected`)
    .join("; ");

  rows.push({
    tier: block.id[0],
    reading_order: readingOrder.get(block.id),
    id: block.id,
    title: block.title,
    authors,
    year,
    venue,
    category,
    system_role: systemRole,
    paper_url: paperUrl,
    code_url: codeUrl,
    project_url: projectUrl,
    local_pdf: auditItem.local_pdf || "",
    closed_loop: normalizeClosedLoop(block.id, evalLine),
    real_trajectory_or_action: realAction(block.id, actionType, category),
    action_type: actionType,
    reason_for_selection: reason || position,
    influence_signal: influence,
    reproduce_priority: reproduction || (relation.match(/复现[：:]([^。]+)/)?.[1]?.trim() || ""),
    pages: auditItem.pages || "",
    reviewed_sections: reviewedSections,
    review_gaps: reviewGaps,
    notes: [position, evalLine, relation].filter(Boolean).join(" | "),
  });
}

rows.sort((a, b) => a.reading_order - b.reading_order);
const headers = [
  "tier", "reading_order", "id", "title", "authors", "year", "venue", "category", "system_role",
  "paper_url", "code_url", "project_url", "local_pdf", "closed_loop", "real_trajectory_or_action",
  "action_type", "reason_for_selection", "influence_signal", "reproduce_priority", "pages",
  "reviewed_sections", "review_gaps", "notes",
];
const csv = [headers.join(","), ...rows.map((row) => headers.map((key) => csvEscape(row[key])).join(","))].join("\r\n") + "\r\n";
await fs.writeFile(outputPath, csv, "utf8");

// Import through artifact-tool to validate that the delivered CSV is structurally readable.
const workbook = await Workbook.fromCSV(csv, { sheetName: "Papers" });
workbook.recalculate();
const inspected = await workbook.inspect({
  kind: "table",
  range: `Papers!A1:W${rows.length + 1}`,
  include: "values,formulas",
  tableMaxRows: 5,
  tableMaxCols: 23,
  maxChars: 6000,
});
console.log(JSON.stringify({
  outputPath,
  rows: rows.length,
  tiers: rows.reduce((acc, row) => ({ ...acc, [row.tier]: (acc[row.tier] || 0) + 1 }), {}),
  localPdfMissing: rows.filter((row) => !row.local_pdf).map((row) => row.id),
  readingOrderUnique: new Set(rows.map((row) => row.reading_order)).size,
  inspection: inspected.ndjson,
}, null, 2));
