"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { toPng } from "html-to-image";
import JSZip from "jszip";

/* ─── Canvas Dimensions ─── */
const IPHONE_W = 1320;
const IPHONE_H = 2868;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

/* ─── Brand Tokens ─── */
const BRAND = {
  accent: "#FF9A42",
  gradTop: "#FDCD66",
  gradBottom: "#FF572D",
  text: "#1A1A1A",
  bg: "#FFFFFF",
  warmBg: "#FFF8F0",
  softOrange: "#FFF0E0",
  muted: "#8B7355",
};

/* ─── Mockup Measurements ─── */
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

/* ─── Locales ─── */
const LOCALES = ["zh", "ko", "en"] as const;
type Locale = (typeof LOCALES)[number];

const LOCALE_LABELS: Record<Locale, string> = {
  zh: "中文",
  ko: "한국어",
  en: "English",
};

const SCREENSHOT_FILES = [
  "0_splash.png",
  "1_WCI.png",
  "2_weight.png",
  "3_chart.png",
  "4_chat.png",
  "5_ans.png",
  "6_vans.png",
  "7_vision.png",
  "9_re.png",
  "10_report.png",
];

/* ─── Copy by Locale ─── */
const COPY = {
  zh: {
    heroHeadline: "懂你的<br/><gradient>小鸡宝宝</gradient>",
    heroSub: "AI驱动的鹦鹉健康管理",
    slides: [
      { label: "", headline: "" }, // placeholder for hero (handled separately)
      { label: "WCI 健康评估", headline: "数据管理<br/>它的状态" },
      { label: "健康指标", headline: "每一克<br/>都有意义" },
      { label: "趋势追踪", headline: "体重变化<br/>一目了然" },
      { label: "鹦鹉博士", headline: "有问题？<br/>随时问我" },
      { label: "专业解答", headline: "靠谱的<br/>养鸟建议" },
      { label: "AI 视觉检查", headline: "拍一张<br/>就知道" },
      { label: "健康档案", headline: "每次检查<br/>都有记录" },
      { label: "就诊准备", headline: "一键分享<br/>给兽医" },
      { label: "完整报告", headline: "安心就诊<br/>有据可依" },
    ],
  },
  ko: {
    heroHeadline: "반려조의<br/><gradient>건강 파트너</gradient>",
    heroSub: "AI 기반 앵무새 건강 관리",
    slides: [
      { label: "", headline: "" },
      { label: "WCI 건강 평가", headline: "데이터로<br/>건강을 읽다" },
      { label: "건강 지표", headline: "하루하루<br/>기록의 중요성" },
      { label: "추세 추적", headline: "체중 변화<br/>놓치지 않게" },
      { label: "앵박사", headline: "궁금할 땐<br/>바로 물어보세요" },
      { label: "전문 답변", headline: "신뢰할 수 있는<br/>반려 조언" },
      { label: "AI 건강체크", headline: "사진 한 장이면<br/>충분해요" },
      { label: "건강 기록", headline: "모든 검사<br/>기록으로" },
      { label: "병원 방문 준비", headline: "수의사에게<br/>바로 공유" },
      { label: "건강 보고서", headline: "기록이 있으니까<br/>신뢰 진료" },
    ],
  },
  en: {
    heroHeadline: "Your Bird's<br/><gradient>Health Partner</gradient>",
    heroSub: "AI-Powered Parrot Health Management",
    slides: [
      { label: "", headline: "" },
      { label: "WCI Health Score", headline: "Understand<br/>Their Health" },
      { label: "Health Metrics", headline: "Every Gram<br/>Matters" },
      { label: "Trend Tracking", headline: "Weight Changes<br/>At a Glance" },
      { label: "Dr. Parrot", headline: "Got Questions?<br/>Just Ask" },
      { label: "Expert Answers", headline: "Trusted<br/>Bird Care Advice" },
      { label: "AI Health Check", headline: "One Photo<br/>Says It All" },
      { label: "Health Records", headline: "Every Checkup<br/>Recorded" },
      { label: "Vet Visit Prep", headline: "Share With<br/>Your Vet" },
      { label: "Health Report", headline: "Data-Backed<br/>Vet Visits" },
    ],
  },
} as const;

/* ─── Image Preloading ─── */
const IMAGE_PATHS = [
  "/mockup.png",
  "/app-icon.png",
  "/perch-logo.svg",
  ...LOCALES.flatMap((l) =>
    SCREENSHOT_FILES.map((f) => `/screenshots/${l}/${f}`)
  ),
];

const imageCache: Record<string, string> = {};

async function preloadAllImages() {
  await Promise.all(
    IMAGE_PATHS.map(async (path) => {
      const resp = await fetch(path);
      const blob = await resp.blob();
      const dataUrl = await new Promise<string>((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result as string);
        reader.readAsDataURL(blob);
      });
      imageCache[path] = dataUrl;
    })
  );
}

function img(path: string): string {
  return imageCache[path] || path;
}

/* ─── Components ─── */

function Phone({
  src,
  alt,
  style,
  className = "",
}: {
  src: string;
  alt: string;
  style?: React.CSSProperties;
  className?: string;
}) {
  return (
    <div
      className={`relative ${className}`}
      style={{ aspectRatio: `${MK_W}/${MK_H}`, ...style }}
    >
      <img
        src={img("/mockup.png")}
        alt=""
        className="block w-full h-full"
        draggable={false}
      />
      <div
        className="absolute z-10 overflow-hidden"
        style={{
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        <img
          src={img(src)}
          alt={alt}
          className="block w-full h-full object-cover object-top"
          draggable={false}
        />
      </div>
    </div>
  );
}

function Caption({
  label,
  headline,
  color = BRAND.text,
  labelColor,
  canvasW = IPHONE_W,
}: {
  label: string;
  headline: string;
  color?: string;
  labelColor?: string;
  canvasW?: number;
}) {
  return (
    <div style={{ textAlign: "center" }}>
      <div
        style={{
          fontSize: canvasW * 0.04,
          fontWeight: 600,
          color: labelColor || BRAND.accent,
          letterSpacing: "0.05em",
          marginBottom: canvasW * 0.018,
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: canvasW * 0.11,
          fontWeight: 900,
          color,
          lineHeight: 1.05,
        }}
        dangerouslySetInnerHTML={{ __html: headline }}
      />
    </div>
  );
}

function Blob({
  color,
  size,
  top,
  left,
  right,
  bottom,
  opacity = 0.3,
}: {
  color: string;
  size: number;
  top?: string;
  left?: string;
  right?: string;
  bottom?: string;
  opacity?: number;
}) {
  return (
    <div
      style={{
        position: "absolute",
        width: size,
        height: size,
        borderRadius: "50%",
        background: color,
        filter: `blur(${size * 0.4}px)`,
        opacity,
        top,
        left,
        right,
        bottom,
        pointerEvents: "none",
      }}
    />
  );
}

/* ─── Decorative Components ─── */

function FloatingIcon({
  size,
  top,
  left,
  right,
  bottom,
  opacity = 0.15,
  rotate = 0,
}: {
  size: number;
  top?: string;
  left?: string;
  right?: string;
  bottom?: string;
  opacity?: number;
  rotate?: number;
}) {
  return (
    <img
      src={img("/app-icon.png")}
      alt=""
      draggable={false}
      style={{
        position: "absolute",
        width: size,
        height: size,
        borderRadius: size * 0.22,
        opacity,
        top,
        left,
        right,
        bottom,
        transform: rotate ? `rotate(${rotate}deg)` : undefined,
        pointerEvents: "none",
      }}
    />
  );
}

function PerchIcons({
  count,
  size,
  top,
  left,
  right,
  bottom,
  opacity = 0.1,
  rotate = 0,
  spread = 200,
}: {
  count: number;
  size: number;
  top?: string;
  left?: string;
  right?: string;
  bottom?: string;
  opacity?: number;
  rotate?: number;
  spread?: number;
}) {
  const positions = Array.from({ length: count }, (_, i) => ({
    x: ((i * 137.5) % spread),
    y: ((i * 89.3) % spread),
    r: ((i * 47) % 60) - 30,
    s: 0.7 + ((i * 31) % 50) / 100,
    o: 0.5 + ((i * 23) % 50) / 100,
  }));
  return (
    <div
      style={{
        position: "absolute",
        width: spread,
        height: spread,
        opacity,
        top,
        left,
        right,
        bottom,
        transform: rotate ? `rotate(${rotate}deg)` : undefined,
        pointerEvents: "none",
      }}
    >
      {positions.map((p, i) => (
        <img
          key={i}
          src={img("/app-icon.png")}
          alt=""
          draggable={false}
          style={{
            position: "absolute",
            width: size * p.s,
            height: size * p.s,
            left: p.x,
            top: p.y,
            borderRadius: size * 0.22,
            transform: `rotate(${p.r}deg)`,
            opacity: p.o,
          }}
        />
      ))}
    </div>
  );
}

function RoundedRect({
  w,
  h,
  color,
  top,
  left,
  right,
  bottom,
  opacity = 0.1,
  rotate = 0,
  radius,
}: {
  w: number;
  h: number;
  color: string;
  top?: string;
  left?: string;
  right?: string;
  bottom?: string;
  opacity?: number;
  rotate?: number;
  radius?: number;
}) {
  return (
    <div
      style={{
        position: "absolute",
        width: w,
        height: h,
        borderRadius: radius ?? h * 0.3,
        background: color,
        opacity,
        top,
        left,
        right,
        bottom,
        transform: rotate ? `rotate(${rotate}deg)` : undefined,
        pointerEvents: "none",
      }}
    />
  );
}

/* ─── Slide Definitions ─── */
type SlideProps = { W: number; H: number; locale: Locale };

/* Helper: parse headline with <gradient> tags */
function GradientHeadline({ html, W }: { html: string; W: number }) {
  const parts = html.split(/(<gradient>.*?<\/gradient>)/);
  return (
    <div style={{ fontSize: W * 0.09, fontWeight: 900, color: BRAND.text, lineHeight: 1.1 }}>
      {parts.map((part, i) => {
        const match = part.match(/<gradient>(.*?)<\/gradient>/);
        if (match) {
          return (
            <span
              key={i}
              style={{
                background: `linear-gradient(135deg, ${BRAND.accent}, ${BRAND.gradBottom})`,
                WebkitBackgroundClip: "text",
                WebkitTextFillColor: "transparent",
              }}
            >
              {match[1]}
            </span>
          );
        }
        return <span key={i} dangerouslySetInnerHTML={{ __html: part }} />;
      })}
    </div>
  );
}

/* 01 Hero */
function Slide1({ W, H, locale }: SlideProps) {
  const copy = COPY[locale];
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(165deg, ${BRAND.warmBg} 0%, #FFF5EB 40%, ${BRAND.softOrange} 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.gradTop} size={W * 0.8} top="-15%" right="-20%" opacity={0.25} />
      <Blob color={BRAND.accent} size={W * 0.5} bottom="10%" left="-15%" opacity={0.15} />
      <Blob color={BRAND.gradBottom} size={W * 0.35} top="35%" right="5%" opacity={0.08} />
      <FloatingIcon size={W * 0.12} top="2%" left="-4%" opacity={0.1} rotate={-15} />
      <FloatingIcon size={W * 0.08} bottom="38%" right="2%" opacity={0.08} rotate={10} />
      <PerchIcons count={3} size={W * 0.06} top="20%" right="2%" opacity={0.06} rotate={15} spread={W * 0.25} />
      <RoundedRect w={W * 0.2} h={W * 0.06} color={BRAND.gradTop} top="16%" left="-8%" opacity={0.1} rotate={-20} />

      <div style={{ marginTop: H * 0.06, display: "flex", flexDirection: "column", alignItems: "center", gap: W * 0.012, position: "relative", zIndex: 10 }}>
        <img
          src={img("/app-icon.png")}
          alt="Perch Care"
          style={{
            width: W * 0.13,
            height: W * 0.13,
            borderRadius: W * 0.03,
            boxShadow: "0 16px 48px rgba(255,154,66,0.3)",
          }}
          draggable={false}
        />
        <img
          src={img("/perch-logo.svg")}
          alt="p.e.r.c.h"
          style={{
            width: W * 0.28,
            height: "auto",
          }}
          draggable={false}
        />
      </div>

      <div style={{ marginTop: H * 0.02, textAlign: "center", padding: `0 ${W * 0.08}px`, position: "relative", zIndex: 10 }}>
        <GradientHeadline html={copy.heroHeadline} W={W} />
        <div
          style={{
            fontSize: W * 0.03,
            color: BRAND.muted,
            marginTop: H * 0.008,
            lineHeight: 1.5,
          }}
        >
          {copy.heroSub}
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(12%)",
          width: "84%",
        }}
      >
        <Phone src={`/screenshots/${locale}/0_splash.png`} alt="Splash" />
      </div>
    </div>
  );
}

/* 02 WCI Health */
function Slide2({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(180deg, #FFFFFF 0%, ${BRAND.warmBg} 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.gradTop} size={W * 0.6} top="5%" left="-25%" opacity={0.2} />
      <Blob color={BRAND.accent} size={W * 0.4} bottom="25%" right="-15%" opacity={0.1} />
      <FloatingIcon size={W * 0.12} bottom="40%" left="65%" opacity={0.07} rotate={20} />
      <FloatingIcon size={W * 0.08} top="8%" right="10%" opacity={0.1} rotate={-10} />
      <PerchIcons count={4} size={W * 0.07} bottom="15%" left="3%" opacity={0.06} rotate={-10} spread={W * 0.3} />
      <RoundedRect w={W * 0.3} h={W * 0.06} color={BRAND.gradTop} top="30%" right="-10%" opacity={0.1} rotate={25} />
      <RoundedRect w={W * 0.15} h={W * 0.15} color={BRAND.softOrange} top="5%" left="70%" opacity={0.2} rotate={45} radius={W * 0.03} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption label={COPY[locale].slides[1].label} headline={COPY[locale].slides[1].headline} canvasW={W} />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          right: "-5%",
          width: "82%",
          transform: "translateY(10%)",
        }}
      >
        <Phone src={`/screenshots/${locale}/1_WCI.png`} alt="WCI Health" />
      </div>
    </div>
  );
}

/* 03 Weight Dashboard */
function Slide3({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(170deg, ${BRAND.softOrange} 0%, #FFFFFF 50%, ${BRAND.warmBg} 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.accent} size={W * 0.5} bottom="20%" right="-10%" opacity={0.15} />
      <Blob color={BRAND.gradTop} size={W * 0.6} top="-5%" left="50%" opacity={0.12} />
      <FloatingIcon size={W * 0.14} top="15%" left="-5%" opacity={0.06} rotate={15} />
      <FloatingIcon size={W * 0.09} top="3%" right="8%" opacity={0.08} rotate={-12} />
      <PerchIcons count={4} size={W * 0.06} top="18%" left="-2%" opacity={0.07} rotate={5} spread={W * 0.28} />
      <RoundedRect w={W * 0.2} h={W * 0.07} color={BRAND.accent} bottom="30%" left="-5%" opacity={0.08} rotate={-15} />
      <RoundedRect w={W * 0.12} h={W * 0.12} color={BRAND.gradTop} top="10%" right="-3%" opacity={0.15} rotate={30} radius={W * 0.025} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption label={COPY[locale].slides[2].label} headline={COPY[locale].slides[2].headline} canvasW={W} />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(12%)",
          width: "84%",
        }}
      >
        <Phone src={`/screenshots/${locale}/2_weight.png`} alt="Weight Dashboard" />
      </div>
    </div>
  );
}

/* 04 Weight Chart — Dark contrast slide */
function Slide4({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(160deg, #1A1A1A 0%, #2D2215 50%, #3D2A10 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.accent} size={W * 0.7} top="-10%" right="-20%" opacity={0.1} />
      <Blob color={BRAND.gradBottom} size={W * 0.4} bottom="30%" left="-10%" opacity={0.08} />
      <Blob color={BRAND.gradTop} size={W * 0.3} top="40%" right="10%" opacity={0.06} />
      <FloatingIcon size={W * 0.15} bottom="12%" left="-4%" opacity={0.05} rotate={18} />
      <FloatingIcon size={W * 0.08} top="5%" left="15%" opacity={0.07} rotate={-8} />
      <FloatingIcon size={W * 0.1} top="25%" right="2%" opacity={0.04} rotate={25} />
      <PerchIcons count={5} size={W * 0.065} top="6%" right="0%" opacity={0.06} rotate={-20} spread={W * 0.32} />
      <RoundedRect w={W * 0.35} h={W * 0.05} color={BRAND.accent} top="35%" left="-12%" opacity={0.06} rotate={18} />
      <RoundedRect w={W * 0.1} h={W * 0.1} color={BRAND.gradTop} bottom="35%" right="5%" opacity={0.05} rotate={45} radius={W * 0.02} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption
          label={COPY[locale].slides[3].label}
          headline={COPY[locale].slides[3].headline}
          color="#FFFFFF"
          labelColor={BRAND.gradTop}
          canvasW={W}
        />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "8%",
          width: "82%",
          transform: "translateY(10%)",
        }}
      >
        <Phone src={`/screenshots/${locale}/3_chart.png`} alt="Weight Chart" />
      </div>
    </div>
  );
}

/* 05 AI Chat */
function Slide5({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(175deg, #FFFFFF 0%, #FFF8F0 40%, #FFEDD5 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.gradTop} size={W * 0.6} top="15%" right="-15%" opacity={0.2} />
      <Blob color={BRAND.accent} size={W * 0.3} top="5%" left="10%" opacity={0.1} />
      <Blob color={BRAND.gradBottom} size={W * 0.45} bottom="20%" left="-20%" opacity={0.08} />
      <FloatingIcon size={W * 0.11} top="2%" right="5%" opacity={0.07} rotate={-15} />
      <FloatingIcon size={W * 0.09} bottom="32%" left="5%" opacity={0.06} rotate={12} />
      <PerchIcons count={3} size={W * 0.07} top="3%" left="0%" opacity={0.06} rotate={10} spread={W * 0.25} />
      <RoundedRect w={W * 0.18} h={W * 0.06} color={BRAND.accent} top="22%" right="-3%" opacity={0.1} rotate={-12} />
      <RoundedRect w={W * 0.22} h={W * 0.06} color={BRAND.gradTop} bottom="25%" right="65%" opacity={0.08} rotate={20} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.08}px`, position: "relative", zIndex: 10 }}>
        <Caption label={COPY[locale].slides[4].label} headline={COPY[locale].slides[4].headline} canvasW={W} />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-45%) translateY(14%)",
          width: "86%",
        }}
      >
        <Phone src={`/screenshots/${locale}/4_chat.png`} alt="AI Chat" />
      </div>
    </div>
  );
}

/* 06 AI Answer — Two phones */
function Slide6({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(180deg, ${BRAND.warmBg} 0%, #FFFFFF 60%, ${BRAND.softOrange} 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.gradBottom} size={W * 0.5} bottom="15%" left="-20%" opacity={0.12} />
      <Blob color={BRAND.gradTop} size={W * 0.5} top="-5%" right="-10%" opacity={0.15} />
      <FloatingIcon size={W * 0.1} top="8%" left="65%" opacity={0.07} rotate={20} />
      <FloatingIcon size={W * 0.13} bottom="22%" right="-3%" opacity={0.05} rotate={-18} />
      <PerchIcons count={4} size={W * 0.065} top="12%" left="1%" opacity={0.07} rotate={-8} spread={W * 0.28} />
      <RoundedRect w={W * 0.15} h={W * 0.15} color={BRAND.softOrange} top="3%" left="5%" opacity={0.2} rotate={15} radius={W * 0.03} />
      <RoundedRect w={W * 0.28} h={W * 0.05} color={BRAND.gradTop} top="28%" right="-5%" opacity={0.08} rotate={-22} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption label={COPY[locale].slides[5].label} headline={COPY[locale].slides[5].headline} canvasW={W} />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "-6%",
          width: "62%",
          transform: "translateY(15%) rotate(-4deg)",
          opacity: 0.5,
        }}
      >
        <Phone src={`/screenshots/${locale}/4_chat.png`} alt="Chat bg" />
      </div>
      <div
        style={{
          position: "absolute",
          bottom: 0,
          right: "-4%",
          width: "82%",
          transform: "translateY(10%)",
        }}
      >
        <Phone src={`/screenshots/${locale}/5_ans.png`} alt="AI Answer" />
      </div>
    </div>
  );
}

/* 07 Vision Check */
function Slide7({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(165deg, #FFF5EB 0%, #FFFFFF 40%, ${BRAND.warmBg} 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.accent} size={W * 0.6} top="-5%" left="-15%" opacity={0.18} />
      <Blob color={BRAND.gradBottom} size={W * 0.35} bottom="25%" right="-10%" opacity={0.1} />
      <Blob color={BRAND.gradTop} size={W * 0.4} top="30%" right="60%" opacity={0.08} />
      <FloatingIcon size={W * 0.1} top="5%" right="5%" opacity={0.08} rotate={10} />
      <FloatingIcon size={W * 0.14} bottom="18%" left="-3%" opacity={0.05} rotate={-20} />
      <PerchIcons count={5} size={W * 0.07} top="8%" right="0%" opacity={0.08} rotate={12} spread={W * 0.3} />
      <RoundedRect w={W * 0.2} h={W * 0.07} color={BRAND.accent} bottom="35%" left="-5%" opacity={0.09} rotate={-18} />
      <RoundedRect w={W * 0.1} h={W * 0.1} color={BRAND.gradTop} top="15%" right="10%" opacity={0.12} rotate={25} radius={W * 0.02} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption label={COPY[locale].slides[6].label} headline={COPY[locale].slides[6].headline} canvasW={W} />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          right: "3%",
          width: "82%",
          transform: "translateY(12%)",
        }}
      >
        <Phone src={`/screenshots/${locale}/6_vans.png`} alt="Vision Check" />
      </div>
    </div>
  );
}

/* 08 Health Records — Dark contrast */
function Slide8({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(160deg, #1F1A14 0%, #2A2018 50%, #352A1C 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.accent} size={W * 0.5} top="10%" right="-10%" opacity={0.1} />
      <Blob color={BRAND.gradTop} size={W * 0.35} bottom="20%" left="-15%" opacity={0.07} />
      <Blob color={BRAND.gradBottom} size={W * 0.25} top="5%" left="20%" opacity={0.05} />
      <FloatingIcon size={W * 0.12} top="3%" left="-2%" opacity={0.05} rotate={15} />
      <FloatingIcon size={W * 0.08} bottom="35%" right="8%" opacity={0.05} rotate={-10} />
      <FloatingIcon size={W * 0.13} bottom="-2%" right="-3%" opacity={0.03} rotate={22} />
      <PerchIcons count={4} size={W * 0.06} top="10%" left="3%" opacity={0.05} rotate={-15} spread={W * 0.28} />
      <RoundedRect w={W * 0.25} h={W * 0.04} color={BRAND.accent} top="30%" right="-8%" opacity={0.06} rotate={15} />
      <RoundedRect w={W * 0.08} h={W * 0.08} color={BRAND.gradTop} top="8%" right="15%" opacity={0.06} rotate={30} radius={W * 0.015} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption
          label={COPY[locale].slides[7].label}
          headline={COPY[locale].slides[7].headline}
          color="#FFFFFF"
          labelColor={BRAND.gradTop}
          canvasW={W}
        />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "50%",
          transform: "translateX(-50%) translateY(12%)",
          width: "84%",
        }}
      >
        <Phone src={`/screenshots/${locale}/7_vision.png`} alt="Health Records" />
      </div>
    </div>
  );
}

/* 09 Vet Summary */
function Slide9({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(170deg, #FFFFFF 0%, #FFF8F0 50%, ${BRAND.softOrange} 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.gradTop} size={W * 0.5} top="0%" right="-20%" opacity={0.2} />
      <Blob color={BRAND.gradBottom} size={W * 0.3} bottom="25%" left="-10%" opacity={0.1} />
      <Blob color={BRAND.accent} size={W * 0.4} top="20%" left="-15%" opacity={0.1} />
      <FloatingIcon size={W * 0.1} bottom="32%" right="5%" opacity={0.07} rotate={-15} />
      <FloatingIcon size={W * 0.12} top="2%" left="35%" opacity={0.06} rotate={18} />
      <PerchIcons count={4} size={W * 0.07} bottom="12%" right="1%" opacity={0.06} rotate={-5} spread={W * 0.3} />
      <RoundedRect w={W * 0.22} h={W * 0.07} color={BRAND.gradTop} top="18%" left="-3%" opacity={0.1} rotate={10} />
      <RoundedRect w={W * 0.14} h={W * 0.14} color={BRAND.softOrange} top="5%" right="3%" opacity={0.18} rotate={20} radius={W * 0.03} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption label={COPY[locale].slides[8].label} headline={COPY[locale].slides[8].headline} canvasW={W} />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "10%",
          width: "80%",
          transform: "translateY(12%)",
        }}
      >
        <Phone src={`/screenshots/${locale}/9_re.png`} alt="Vet Summary" />
      </div>
    </div>
  );
}

/* 10 Full Report — Two phones */
function Slide10({ W, H, locale }: SlideProps) {
  return (
    <div
      style={{
        width: W,
        height: H,
        background: `linear-gradient(180deg, ${BRAND.warmBg} 0%, #FFFFFF 40%, ${BRAND.softOrange} 100%)`,
        position: "relative",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <Blob color={BRAND.accent} size={W * 0.7} bottom="-10%" right="-15%" opacity={0.15} />
      <Blob color={BRAND.gradTop} size={W * 0.5} top="5%" left="-15%" opacity={0.15} />
      <Blob color={BRAND.gradBottom} size={W * 0.3} top="25%" right="10%" opacity={0.06} />
      <FloatingIcon size={W * 0.1} top="3%" right="5%" opacity={0.07} rotate={-12} />
      <FloatingIcon size={W * 0.13} bottom="22%" left="-3%" opacity={0.05} rotate={15} />
      <PerchIcons count={5} size={W * 0.065} top="5%" left="3%" opacity={0.06} rotate={8} spread={W * 0.32} />
      <RoundedRect w={W * 0.2} h={W * 0.06} color={BRAND.gradTop} top="25%" left="-5%" opacity={0.1} rotate={-15} />
      <RoundedRect w={W * 0.12} h={W * 0.12} color={BRAND.softOrange} top="5%" left="65%" opacity={0.15} rotate={35} radius={W * 0.025} />

      <div style={{ marginTop: H * 0.07, padding: `0 ${W * 0.1}px`, position: "relative", zIndex: 10 }}>
        <Caption label={COPY[locale].slides[9].label} headline={COPY[locale].slides[9].headline} canvasW={W} />
      </div>

      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: "-8%",
          width: "60%",
          transform: "translateY(18%) rotate(-3deg)",
          opacity: 0.45,
        }}
      >
        <Phone src={`/screenshots/${locale}/9_re.png`} alt="Summary bg" />
      </div>
      <div
        style={{
          position: "absolute",
          bottom: 0,
          right: "-2%",
          width: "82%",
          transform: "translateY(10%)",
        }}
      >
        <Phone src={`/screenshots/${locale}/10_report.png`} alt="Full Report" />
      </div>
    </div>
  );
}

/* ─── Slide Registry ─── */
const SLIDES = [
  { id: "hero", component: Slide1 },
  { id: "wci", component: Slide2 },
  { id: "weight", component: Slide3 },
  { id: "chart", component: Slide4 },
  { id: "chat", component: Slide5 },
  { id: "answer", component: Slide6 },
  { id: "vision", component: Slide7 },
  { id: "records", component: Slide8 },
  { id: "vet", component: Slide9 },
  { id: "report", component: Slide10 },
];

function getSlideName(index: number, locale: Locale) {
  if (index === 0) {
    if (locale === "zh") return "Hero — 懂你的小鸡宝宝";
    if (locale === "ko") return "Hero — 반려조의 건강 파트너";
    return "Hero — Your Bird's Health Partner";
  }
  return COPY[locale].slides[index].label;
}

/* ─── Preview Component ─── */
function ScreenshotPreview({
  slide,
  index,
  W,
  H,
  exportW,
  exportH,
  locale,
}: {
  slide: (typeof SLIDES)[number];
  index: number;
  W: number;
  H: number;
  exportW: number;
  exportH: number;
  locale: Locale;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const exportRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.15);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const obs = new ResizeObserver(([entry]) => {
      const cw = entry.contentRect.width;
      setScale(cw / W);
    });
    obs.observe(el);
    return () => obs.disconnect();
  }, [W]);

  const handleExport = useCallback(async () => {
    const el = exportRef.current;
    if (!el || exporting) return;
    setExporting(true);

    el.style.left = "0px";
    el.style.opacity = "1";
    el.style.zIndex = "9999";

    const opts = { width: W, height: H, pixelRatio: 1, cacheBust: true };

    try {
      await toPng(el, opts);
      let dataUrl = await toPng(el, opts);

      // Resize if target differs from design size
      if (exportW !== W || exportH !== H) {
        const image = new Image();
        dataUrl = await new Promise<string>((resolve) => {
          image.onload = () => {
            const canvas = document.createElement("canvas");
            canvas.width = exportW;
            canvas.height = exportH;
            const ctx = canvas.getContext("2d")!;
            ctx.drawImage(image, 0, 0, exportW, exportH);
            resolve(canvas.toDataURL("image/png"));
          };
          image.src = dataUrl;
        });
      }

      const link = document.createElement("a");
      link.download = `${String(index + 1).padStart(2, "0")}-${slide.id}-${exportW}x${exportH}.png`;
      link.href = dataUrl;
      link.click();
    } finally {
      el.style.left = "-9999px";
      el.style.opacity = "";
      el.style.zIndex = "";
      setExporting(false);
    }
  }, [W, H, exportW, exportH, index, slide.id, exporting]);

  const SlideComponent = slide.component;

  return (
    <div>
      <div
        ref={containerRef}
        className="relative cursor-pointer rounded-xl overflow-hidden shadow-lg hover:shadow-2xl transition-shadow"
        style={{ aspectRatio: `${W}/${H}` }}
        onClick={handleExport}
      >
        <div
          style={{
            width: W,
            height: H,
            transform: `scale(${scale})`,
            transformOrigin: "top left",
          }}
        >
          <SlideComponent W={W} H={H} locale={locale} />
        </div>
        {exporting && (
          <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
            <div className="text-white text-sm font-medium">导出中...</div>
          </div>
        )}
      </div>

      <div className="mt-2 text-xs text-gray-500 text-center">
        {String(index + 1).padStart(2, "0")}. {getSlideName(index, locale)}
      </div>

      <div
        ref={exportRef}
        style={{
          position: "fixed",
          left: "-9999px",
          top: 0,
          width: W,
          height: H,
          overflow: "hidden",
          fontFamily: "inherit",
        }}
      >
        <SlideComponent W={W} H={H} locale={locale} />
      </div>
    </div>
  );
}

/* ─── Main Page ─── */
export default function ScreenshotsPage() {
  const [ready, setReady] = useState(false);
  const [sizeIdx, setSizeIdx] = useState(0);
  const [locale, setLocale] = useState<Locale>("zh");
  const [exportingAll, setExportingAll] = useState(false);

  const selectedSize = IPHONE_SIZES[sizeIdx];

  useEffect(() => {
    preloadAllImages().then(() => setReady(true));
  }, []);

  const resizeDataUrl = useCallback(
    (dataUrl: string, targetW: number, targetH: number): Promise<string> => {
      return new Promise((resolve) => {
        const image = new Image();
        image.onload = () => {
          const canvas = document.createElement("canvas");
          canvas.width = targetW;
          canvas.height = targetH;
          const ctx = canvas.getContext("2d")!;
          ctx.drawImage(image, 0, 0, targetW, targetH);
          resolve(canvas.toDataURL("image/png"));
        };
        image.src = dataUrl;
      });
    },
    []
  );

  const exportAll = useCallback(async () => {
    setExportingAll(true);
    const zip = new JSZip();
    const exportEls = document.querySelectorAll<HTMLDivElement>("[data-export-slide]");

    for (let i = 0; i < SLIDES.length; i++) {
      const el = exportEls[i];
      if (!el) continue;

      el.style.left = "0px";
      el.style.opacity = "1";
      el.style.zIndex = "9999";

      const opts = {
        width: IPHONE_W,
        height: IPHONE_H,
        pixelRatio: 1,
        cacheBust: true,
      };

      try {
        // Double-call trick
        await toPng(el, opts);
        let dataUrl = await toPng(el, opts);

        // Resize if needed
        if (selectedSize.w !== IPHONE_W || selectedSize.h !== IPHONE_H) {
          dataUrl = await resizeDataUrl(dataUrl, selectedSize.w, selectedSize.h);
        }

        const base64 = dataUrl.split(",")[1];
        const filename = `${String(i + 1).padStart(2, "0")}-${SLIDES[i].id}-${selectedSize.w}x${selectedSize.h}.png`;
        zip.file(filename, base64, { base64: true });
      } finally {
        el.style.left = "-9999px";
        el.style.opacity = "";
        el.style.zIndex = "";
      }

      await new Promise((r) => setTimeout(r, 300));
    }

    const blob = await zip.generateAsync({ type: "blob" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `perch-screenshots-${locale}-${selectedSize.label.replace('"', "in")}-${selectedSize.w}x${selectedSize.h}.zip`;
    link.click();
    URL.revokeObjectURL(link.href);

    setExportingAll(false);
  }, [selectedSize, resizeDataUrl]);

  if (!ready) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-50">
        <div className="text-center">
          <div className="text-lg font-medium text-gray-700">加载图片中...</div>
          <div className="text-sm text-gray-400 mt-1">预加载所有素材以确保导出质量</div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Toolbar */}
      <div className="sticky top-0 z-50 bg-white/80 backdrop-blur border-b border-gray-200 px-6 py-3">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-4">
            <img
              src={img("/app-icon.png")}
              alt="Perch Care"
              className="w-8 h-8 rounded-lg"
            />
            <span className="font-bold text-gray-800">Perch Care — App Store 截图</span>
          </div>

          <div className="flex items-center gap-3">
            {/* Locale tabs */}
            <div className="flex gap-1 bg-gray-100 rounded-lg p-1">
              {LOCALES.map((l) => (
                <button
                  key={l}
                  onClick={() => setLocale(l)}
                  className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${
                    locale === l
                      ? "bg-white text-gray-900 shadow-sm"
                      : "text-gray-500 hover:text-gray-700"
                  }`}
                >
                  {LOCALE_LABELS[l]}
                </button>
              ))}
            </div>

            {/* Size selector */}
            <div className="flex gap-1 bg-gray-100 rounded-lg p-1">
              {IPHONE_SIZES.map((s, i) => (
                <button
                  key={s.label}
                  onClick={() => setSizeIdx(i)}
                  className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${
                    sizeIdx === i
                      ? "bg-white text-gray-900 shadow-sm"
                      : "text-gray-500 hover:text-gray-700"
                  }`}
                >
                  {s.label}
                </button>
              ))}
            </div>

            <button
              onClick={exportAll}
              disabled={exportingAll}
              className="px-4 py-1.5 bg-orange-500 hover:bg-orange-600 disabled:bg-orange-300 text-white text-xs font-medium rounded-lg transition-colors"
            >
              {exportingAll ? "导出中..." : "导出全部"}
            </button>
          </div>
        </div>
      </div>

      {/* Grid */}
      <div className="max-w-7xl mx-auto p-6">
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
          {SLIDES.map((slide, i) => (
            <ScreenshotPreview
              key={`${slide.id}-${locale}`}
              slide={slide}
              index={i}
              W={IPHONE_W}
              H={IPHONE_H}
              exportW={selectedSize.w}
              exportH={selectedSize.h}
              locale={locale}
            />
          ))}
        </div>

        <div className="mt-6 text-center text-xs text-gray-400">
          点击单张截图可单独导出 · 右上角「导出全部」批量导出当前尺寸
        </div>
      </div>

      {/* Hidden export containers for batch export */}
      {SLIDES.map((slide) => {
        const SlideComponent = slide.component;
        return (
          <div
            key={`export-${slide.id}`}
            data-export-slide={slide.id}
            style={{
              position: "fixed",
              left: "-9999px",
              top: 0,
              width: IPHONE_W,
              height: IPHONE_H,
              overflow: "hidden",
              fontFamily: "inherit",
            }}
          >
            <SlideComponent W={IPHONE_W} H={IPHONE_H} locale={locale} />
          </div>
        );
      })}
    </div>
  );
}
