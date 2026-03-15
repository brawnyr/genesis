import { useState } from "react";

const P = {
  midnight: "#0B1120",
  surface: "#111827",
  elevated: "#1A2332",
  white: "#F8FAFC",
  silver: "#CBD5E1",
  muted: "#64748B",
  electric: "#3B82F6",
  sky: "#7DD3FC",
  ice: "#BAE6FD",
  ember: "#F97316",
  terracotta: "#EA580C",
  sage: "#4ADE80",
  mint: "#34D399",
  gold: "#FBBF24",
  clay: "#EF4444",
  rose: "#FB7185",
  slate: "#1E293B",
  divider: "rgba(59, 130, 246, 0.12)",
};

const PADS = [
  { name: "KICKS", hex: "#F97316", desc: "Bright orange" },
  { name: "SNARES", hex: "#FBBF24", desc: "Electric gold" },
  { name: "HATS", hex: "#7DD3FC", desc: "Sky blue" },
  { name: "PERC", hex: "#4ADE80", desc: "Vivid green" },
  { name: "BASS", hex: "#3B82F6", desc: "Electric blue" },
  { name: "KEYS", hex: "#A78BFA", desc: "Soft violet" },
  { name: "VOX", hex: "#FB7185", desc: "Warm rose" },
  { name: "FX", hex: "#34D399", desc: "Mint" },
];

function Swatch({ color, name, hex, size = "normal", glow = false }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
      <div style={{ width: size === "large" ? 72 : 48, height: size === "large" ? 72 : 48, borderRadius: 8, backgroundColor: color, border: "1px solid rgba(255,255,255,0.08)", boxShadow: glow ? `0 0 20px ${color}40, 0 0 40px ${color}20` : "none" }} />
      <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: "#94A3B8", letterSpacing: 0.5 }}>{name}</span>
      <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: "#475569" }}>{hex}</span>
    </div>
  );
}

function Section({ title, subtitle, children }) {
  return (
    <section style={{ marginBottom: 64, scrollMarginTop: 32 }}>
      <div style={{ marginBottom: 24 }}>
        <h2 style={{ fontFamily: "'Space Grotesk', sans-serif", fontSize: 28, fontWeight: 700, color: "#F8FAFC", margin: 0, letterSpacing: -0.5 }}>{title}</h2>
        {subtitle && <p style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: "#64748B", margin: "8px 0 0", lineHeight: 1.6 }}>{subtitle}</p>}
      </div>
      {children}
    </section>
  );
}

function CodeBlock({ code }) {
  return (
    <pre style={{ backgroundColor: "#0B1120", border: "1px solid rgba(59,130,246,0.15)", borderRadius: 8, padding: 20, fontFamily: "'JetBrains Mono', monospace", fontSize: 12, lineHeight: 1.7, color: "#CBD5E1", overflow: "auto", margin: "16px 0 0" }}>{code}</pre>
  );
}

function MockupHUD() {
  return (
    <div style={{ background: P.midnight, borderRadius: 12, border: `1px solid ${P.divider}`, overflow: "hidden" }}>
      {/* HOTKEYS */}
      <div style={{ background: P.surface, padding: "8px 20px 10px", display: "flex", flexDirection: "column", gap: 8, borderBottom: `1px solid ${P.divider}` }}>
        <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: P.electric, letterSpacing: 3, fontWeight: 600 }}>HOTKEYS</div>
        <div style={{ display: "flex", gap: 24 }}>
          {[
            { keys: "SPC", action: "play/stop", color: P.sage },
            { keys: "ESC", action: "stop", color: P.sage },
            { keys: "R", action: "rec", color: P.clay },
            { keys: "←→", action: "pad", color: P.white },
            { keys: "Q", action: "mute", color: P.ember },
            { keys: "O", action: "oracle", color: P.electric },
          ].map((h, i) => (
            <div key={i} style={{ display: "flex", alignItems: "baseline", gap: 4 }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, fontWeight: 700, color: h.color, textShadow: `0 0 8px ${h.color}40` }}>{h.keys}</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, color: P.muted }}>{h.action}</span>
            </div>
          ))}
        </div>
      </div>

      {/* TERMINAL */}
      <div style={{ padding: "12px 20px 20px", minHeight: 130, position: "relative" }}>
        <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: P.electric, letterSpacing: 3, marginBottom: 10, fontWeight: 600 }}>TERMINAL</div>
        {[
          { ts: "00:12", text: "loading KICKS — 808_kick.wav", color: P.sky },
          { ts: "00:12", text: "BPM locked → 128", color: P.sage },
          { ts: "00:13", text: "HIT kicks vel:92 pos:1.1", color: PADS[0].hex },
          { ts: "00:13", text: "HIT snares vel:110 pos:1.3", color: PADS[1].hex },
          { ts: "00:14", text: "oracle: try hi-hat pattern ×2", color: P.electric },
        ].map((line, i) => (
          <div key={i} style={{ display: "flex", gap: 8, fontFamily: "'JetBrains Mono', monospace", fontSize: 17, lineHeight: 1.8 }}>
            <span style={{ color: P.slate, minWidth: 48 }}>{line.ts}</span>
            <span style={{ color: `${line.color}60` }}>{">"}</span>
            <span style={{ color: line.color, textShadow: `0 0 6px ${line.color}30` }}>{line.text}</span>
          </div>
        ))}
        <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, color: P.electric, animation: "blink 1s step-end infinite" }}>▌</span>
      </div>

      {/* Beat tracker */}
      <div style={{ display: "flex", justifyContent: "center", padding: "0 0 16px" }}>
        <div style={{ background: `${P.surface}F0`, border: `1px solid ${P.divider}`, borderRadius: 10, padding: "10px 28px", display: "flex", alignItems: "center", gap: 0, backdropFilter: "blur(8px)" }}>
          {[{ val: "128", label: "BPM" }, { val: "3", label: "BEAT" }, { val: "4", label: "BAR" }].map((item, i) => (
            <div key={i} style={{ display: "flex", alignItems: "center" }}>
              {i > 0 && <div style={{ width: 1, height: 36, background: P.divider, margin: "0 24px" }} />}
              <div style={{ textAlign: "center" }}>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 36, fontWeight: 700, color: P.white, textShadow: `0 0 12px ${P.electric}30` }}>{item.val}</div>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, color: P.electric, letterSpacing: 2, fontWeight: 600 }}>{item.label}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Bottom bar */}
      <div style={{ display: "flex", borderTop: `1px solid ${P.divider}` }}>
        <div style={{ width: 260, padding: 16, borderRight: `1px solid ${P.divider}`, background: P.surface }}>
          <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, color: P.electric, letterSpacing: 3, marginBottom: 8, fontWeight: 600 }}>MASTER</div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginBottom: 4 }}>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 36, fontWeight: 700, color: P.white }}>100</span>
            <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, color: P.sage, fontWeight: 600 }}>VOL</span>
          </div>
          <div style={{ display: "flex", gap: 12, marginTop: 8 }}>
            {[
              { label: "VEL", on: true, color: P.sage },
              { label: "METRO", on: false, color: P.sage },
              { label: "REC", on: false, color: P.clay },
            ].map((s, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 4 }}>
                <div style={{ width: 9, height: 9, borderRadius: "50%", background: s.on ? s.color : P.slate, boxShadow: s.on ? `0 0 6px ${s.color}80` : "none" }} />
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, fontWeight: 600, color: s.on ? P.white : P.slate }}>{s.label}</span>
              </div>
            ))}
          </div>
        </div>
        <div style={{ flex: 1, padding: "8px 8px", display: "flex", flexDirection: "column", gap: 4, background: P.surface }}>
          <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, color: P.electric, letterSpacing: 3, fontWeight: 600, paddingLeft: 4 }}>PAD_SELECT</div>
          <div style={{ display: "flex", gap: 3, flex: 1 }}>
            {PADS.map((pad, i) => (
              <div key={i} style={{
                flex: 1, background: i === 0 ? `${pad.hex}18` : "transparent",
                border: i === 0 ? `1px solid ${pad.hex}50` : "1px solid transparent",
                borderRadius: 4, padding: "6px 4px", textAlign: "center",
                boxShadow: i === 0 ? `0 0 12px ${pad.hex}20` : "none",
              }}>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, fontWeight: 700, color: pad.hex, textShadow: i === 0 ? `0 0 8px ${pad.hex}40` : "none" }}>{pad.name}</div>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 17, color: P.muted, marginTop: 4 }}>{[100, 85, 72, 90, 100, 65, 80, 55][i]}%</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function ComparisonRow({ label, oldVal, newVal }) {
  return (
    <div style={{ display: "flex", alignItems: "center", padding: "8px 0", borderBottom: "1px solid rgba(59, 130, 246, 0.06)" }}>
      <div style={{ flex: 1, fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#94A3B8" }}>{label}</div>
      <div style={{ flex: 1, fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#64748B" }}>{oldVal}</div>
      <div style={{ flex: 1, fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#F8FAFC" }}>{newVal}</div>
    </div>
  );
}

export default function GenesisDesignVision() {
  const [activeTab, setActiveTab] = useState("vision");

  const tabs = [
    { id: "vision", label: "VISION" },
    { id: "palette", label: "PALETTE" },
    { id: "type", label: "TYPE" },
    { id: "mockup", label: "MOCKUP" },
    { id: "code", label: "THEME.SWIFT" },
    { id: "rules", label: "RULES" },
  ];

  return (
    <div style={{ minHeight: "100vh", background: "#0B1120", color: "#F8FAFC", fontFamily: "'Space Grotesk', sans-serif" }}>
      <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet" />
      <style>{`
        @keyframes blink { 50% { opacity: 0; } }
        @keyframes gradientShift { 0% { background-position: 0% 50%; } 50% { background-position: 100% 50%; } 100% { background-position: 0% 50%; } }
        * { box-sizing: border-box; }
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: #0B1120; }
        ::-webkit-scrollbar-thumb { background: #1E293B; border-radius: 3px; }
      `}</style>

      <header style={{ padding: "48px 48px 0", maxWidth: 960, margin: "0 auto" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 8 }}>
          <div style={{ width: 10, height: 10, borderRadius: "50%", background: P.electric, boxShadow: `0 0 12px ${P.electric}40, 0 0 24px ${P.electric}20` }} />
          <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: P.electric, letterSpacing: 3 }}>GENESIS DESIGN SYSTEM</span>
        </div>
        <h1 style={{ fontSize: 48, fontWeight: 700, margin: "0 0 12px", letterSpacing: -1.5, background: "linear-gradient(135deg, #F8FAFC 0%, #7DD3FC 50%, #3B82F6 100%)", backgroundSize: "200% 200%", animation: "gradientShift 6s ease infinite", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent", lineHeight: 1.1 }}>
          Codename: First Light
        </h1>
        <p style={{ fontSize: 16, color: "#64748B", lineHeight: 1.7, maxWidth: 600, margin: 0 }}>
          Aesthetic & ideatic vision for Genesis. Midnight canvas, bright whites,
          vivid blues, full-spectrum pads, and every piece of text big enough to read without squinting.
        </p>

        <nav style={{ display: "flex", gap: 0, marginTop: 32, borderBottom: "1px solid rgba(59, 130, 246, 0.15)" }}>
          {tabs.map((tab) => (
            <button key={tab.id} onClick={() => setActiveTab(tab.id)} style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, letterSpacing: 2, padding: "12px 20px", background: "none", border: "none", borderBottom: activeTab === tab.id ? "2px solid #3B82F6" : "2px solid transparent", color: activeTab === tab.id ? "#F8FAFC" : "#475569", cursor: "pointer", transition: "all 0.2s" }}>
              {tab.label}
            </button>
          ))}
        </nav>
      </header>

      <main style={{ padding: "48px 48px 96px", maxWidth: 960, margin: "0 auto" }}>

        {/* ═══ VISION ═══ */}
        {activeTab === "vision" && (
          <div>
            <Section title="The Problem" subtitle="What's wrong with Forest Chrome">
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 24, marginTop: 16 }}>
                <div style={{ background: "#111827", borderRadius: 10, padding: 24, border: "1px solid rgba(255,255,255,0.04)" }}>
                  <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#EF4444", letterSpacing: 2, marginBottom: 12 }}>CURRENT ISSUES</div>
                  {["Dark green on dark green = no contrast", "Earth tones all sit in the same muddy range", "Chrome/silver reads as gray, not bright", "Small text everywhere — 11pt, 14pt, unreadable", "Pad colors blur together on dark backgrounds", "Sections unlabeled — you guess what's what"].map((issue, i) => (
                    <div key={i} style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#94A3B8", padding: "6px 0", display: "flex", gap: 8 }}>
                      <span style={{ color: "#EF4444" }}>×</span> {issue}
                    </div>
                  ))}
                </div>
                <div style={{ background: "#111827", borderRadius: 10, padding: 24, border: "1px solid rgba(59, 130, 246, 0.1)" }}>
                  <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#3B82F6", letterSpacing: 2, marginBottom: 12 }}>FIRST LIGHT FIXES</div>
                  {["Deep midnight blue base — clean, not tinted green", "True bright white (#F8FAFC) for hero numbers", "Electric blue (#3B82F6) as the signature accent", "17pt minimum everywhere — nothing smaller, ever", "Pad colors span the full spectrum, not just warm", "Every zone gets a labeled title"].map((fix, i) => (
                    <div key={i} style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#CBD5E1", padding: "6px 0", display: "flex", gap: 8 }}>
                      <span style={{ color: "#3B82F6" }}>→</span> {fix}
                    </div>
                  ))}
                </div>
              </div>
            </Section>

            <Section title="Design Pillars" subtitle="The non-negotiable principles">
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16, marginTop: 16 }}>
                {[
                  { n: "01", title: "Midnight Canvas", desc: "Deep navy-black backgrounds. No green tint, no warm browns. Clean, neutral darkness that lets colors breathe.", color: "#3B82F6" },
                  { n: "02", title: "White Heat", desc: "Hero numbers burn true white (#F8FAFC). Not silver, not cream — actual bright white that reads from across the room.", color: "#F8FAFC" },
                  { n: "03", title: "Electric Accent", desc: "Blue is the signature. Electric blue for labels, dividers, oracle, and the soul of the interface.", color: "#7DD3FC" },
                  { n: "04", title: "17pt Floor", desc: "Nothing renders below 17pt. Effect labels, file names, volume %, hit counts — all 17pt+. Big text stays big. Small text comes UP.", color: "#4ADE80" },
                  { n: "05", title: "Every Zone Titled", desc: "MASTER, TERMINAL, HOTKEYS, PAD_SELECT, INSPECT, BROWSER — every section has a labeled title.", color: "#FBBF24" },
                  { n: "06", title: "Full Spectrum Pads", desc: "Each pad gets a truly distinct color spanning warm AND cool — orange, gold, sky blue, green, electric, violet, rose, mint.", color: "#FB7185" },
                ].map((pillar) => (
                  <div key={pillar.n} style={{ background: "#111827", borderRadius: 10, padding: 20, border: "1px solid rgba(59,130,246,0.08)" }}>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 32, fontWeight: 700, color: pillar.color, marginBottom: 8, textShadow: `0 0 20px ${pillar.color}30` }}>{pillar.n}</div>
                    <div style={{ fontSize: 16, fontWeight: 600, color: "#F8FAFC", marginBottom: 8 }}>{pillar.title}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#64748B", lineHeight: 1.6 }}>{pillar.desc}</div>
                  </div>
                ))}
              </div>
            </Section>

            <Section title="Mood" subtitle="The studio at 4am">
              <div style={{ background: "#111827", borderRadius: 10, padding: 24, marginTop: 16, border: "1px solid rgba(59,130,246,0.08)" }}>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: "#94A3B8", lineHeight: 2 }}>
                  Think of standing in a recording studio at 4am. The equipment racks glow deep midnight blue.
                  LED meters burn <span style={{ color: "#F8FAFC", fontWeight: 700 }}>clean white</span>. Status indicators pulse vivid colors —
                  <span style={{ color: "#4ADE80", fontWeight: 700 }}> green</span> for active,
                  <span style={{ color: "#FBBF24", fontWeight: 700 }}> amber</span> for levels,
                  <span style={{ color: "#3B82F6", fontWeight: 700 }}> blue</span> for system.
                  The room is dark but everything that matters is <span style={{ color: "#F8FAFC", fontWeight: 700 }}>brilliantly legible</span>.
                  That's Genesis. A <span style={{ color: "#3B82F6", fontWeight: 700 }}>studio at first light</span>.
                </div>
              </div>
            </Section>
          </div>
        )}

        {/* ═══ PALETTE ═══ */}
        {activeTab === "palette" && (
          <div>
            <Section title="Core Palette" subtitle="Backgrounds, text, and structural colors">
              <div style={{ display: "flex", gap: 20, flexWrap: "wrap", marginTop: 16, padding: 24, background: "#111827", borderRadius: 10, border: "1px solid rgba(59,130,246,0.08)" }}>
                <Swatch color={P.midnight} name="midnight" hex="#0B1120" size="large" />
                <Swatch color={P.surface} name="surface" hex="#111827" size="large" />
                <Swatch color={P.elevated} name="elevated" hex="#1A2332" size="large" />
                <Swatch color={P.slate} name="slate" hex="#1E293B" size="large" />
                <Swatch color={P.muted} name="muted" hex="#64748B" size="large" />
                <Swatch color={P.silver} name="silver" hex="#CBD5E1" size="large" />
                <Swatch color={P.white} name="white" hex="#F8FAFC" size="large" />
              </div>
            </Section>

            <Section title="Signature Blues" subtitle="The soul of Genesis">
              <div style={{ display: "flex", gap: 20, flexWrap: "wrap", marginTop: 16, padding: 24, background: "#111827", borderRadius: 10, border: "1px solid rgba(59,130,246,0.08)" }}>
                <Swatch color={P.electric} name="electric" hex="#3B82F6" size="large" glow />
                <Swatch color={P.sky} name="sky" hex="#7DD3FC" size="large" glow />
                <Swatch color={P.ice} name="ice" hex="#BAE6FD" size="large" glow />
              </div>
              <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#64748B", marginTop: 12 }}>
                Electric = section titles, dividers, oracle. Sky = terminal highlights, links. Ice = rare emphasis.
              </div>
            </Section>

            <Section title="Semantic Colors" subtitle="Status, state, and feedback">
              <div style={{ display: "flex", gap: 20, flexWrap: "wrap", marginTop: 16, padding: 24, background: "#111827", borderRadius: 10, border: "1px solid rgba(59,130,246,0.08)" }}>
                <Swatch color={P.sage} name="sage" hex="#4ADE80" size="large" glow />
                <Swatch color={P.mint} name="mint" hex="#34D399" size="large" glow />
                <Swatch color={P.ember} name="ember" hex="#F97316" size="large" glow />
                <Swatch color={P.gold} name="gold" hex="#FBBF24" size="large" glow />
                <Swatch color={P.clay} name="clay" hex="#EF4444" size="large" glow />
                <Swatch color={P.rose} name="rose" hex="#FB7185" size="large" glow />
              </div>
              <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#64748B", marginTop: 12 }}>
                Sage = active/playing. Ember = hot/recording. Gold = edit/warning. Clay = stop/danger. Mint = system msgs. Rose = vox accent.
              </div>
            </Section>

            <Section title="Pad Colors — Full Spectrum" subtitle="8 distinct colors spanning warm AND cool">
              <div style={{ display: "flex", gap: 12, marginTop: 16 }}>
                {PADS.map((pad, i) => (
                  <div key={i} style={{ flex: 1, background: `${pad.hex}15`, border: `1px solid ${pad.hex}40`, borderRadius: 8, padding: 16, textAlign: "center", boxShadow: `0 0 16px ${pad.hex}15` }}>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, fontWeight: 700, color: pad.hex, textShadow: `0 0 8px ${pad.hex}40`, marginBottom: 6 }}>{pad.name}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: "#64748B" }}>{pad.hex}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: "#475569", marginTop: 2 }}>{pad.desc}</div>
                  </div>
                ))}
              </div>
            </Section>
          </div>
        )}

        {/* ═══ TYPE ═══ */}
        {activeTab === "type" && (
          <div>
            <Section title="Type Scale" subtitle="17pt is the absolute floor — nothing goes below it, anywhere, ever">
              <div style={{ background: "#111827", borderRadius: 10, padding: 32, marginTop: 16, border: "1px solid rgba(59,130,246,0.08)" }}>
                <div style={{ background: "rgba(239,68,68,0.08)", border: "1.5px solid rgba(239,68,68,0.2)", borderRadius: 8, padding: 16, marginBottom: 24 }}>
                  <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: P.clay, fontWeight: 700, marginBottom: 4 }}>HARD RULE: 17pt MINIMUM</div>
                  <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#CBD5E1", lineHeight: 1.6 }}>
                    No text in the entire application renders below 17pt. Effect labels, file browser items, volume percentages, hit counts, pad data rows, timestamps — everything is 17pt or larger. The old 11pt and 14pt tokens are gone. Big text stays the same or gets bigger. Small text comes UP to 17.
                  </div>
                </div>
                {[
                  { name: "hero", size: "52pt", weight: "Bold", sample: "128", desc: "BPM, volume, dB — scoreboard", color: P.white },
                  { name: "title", size: "36pt", weight: "Bold", sample: "KICKS", desc: "Channel name in inspector", color: P.white },
                  { name: "monoLarge", size: "22pt", weight: "Bold", sample: "SPC", desc: "Hotkey keys, big labels", color: P.electric },
                  { name: "sectionLabel", size: "20pt", weight: "Semibold", sample: "MASTER", desc: "Zone titles — every view has one", color: P.electric },
                  { name: "mono", size: "17pt", weight: "Regular", sample: "> HIT kicks vel:92", desc: "EVERYTHING ELSE — the floor", color: P.silver },
                ].map((t, i) => (
                  <div key={i} style={{ display: "flex", alignItems: "baseline", padding: "16px 0", borderBottom: i < 4 ? "1px solid rgba(59,130,246,0.06)" : "none" }}>
                    <div style={{ width: 130 }}>
                      <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: P.electric }}>{t.name}</div>
                      <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#475569" }}>{t.size} {t.weight}</div>
                    </div>
                    <div style={{ flex: 1, fontFamily: "'JetBrains Mono', monospace", fontSize: Math.max(parseInt(t.size) * 0.65, 14), fontWeight: t.weight === "Bold" ? 700 : t.weight === "Semibold" ? 600 : 400, color: t.color, textShadow: t.name === "hero" ? `0 0 12px ${P.electric}30` : "none" }}>{t.sample}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#475569", textAlign: "right" }}>{t.desc}</div>
                  </div>
                ))}
              </div>
            </Section>

            <Section title="What This Means in Practice" subtitle="Every old small-text element maps to 17pt mono">
              <div style={{ background: "#111827", borderRadius: 10, padding: 24, marginTop: 16, border: "1px solid rgba(59,130,246,0.08)" }}>
                {[
                  { old: "monoTiny (11pt)", was: "Effect dots, hit counts, hints", now: "All become mono (17pt)" },
                  { old: "monoSmall (14pt)", was: "Labels, status, BPM/VOL/BAR", now: "All become mono (17pt)" },
                  { old: "sectionLabel (15pt)", was: "MASTER, INSPECT, PAD_SELECT", now: "Bumped to sectionLabel (20pt semibold)" },
                  { old: "File browser items", was: "10-14pt depending on state", now: "All become mono (17pt)" },
                  { old: "PadDataRow values", was: "12pt", now: "All become mono (17pt)" },
                  { old: "Nav hints (W/S, ↑↓)", was: "8-9pt", now: "All become mono (17pt)" },
                ].map((row, i) => (
                  <div key={i} style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16, padding: "8px 0", borderBottom: i < 5 ? "1px solid rgba(59,130,246,0.06)" : "none" }}>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#64748B", textDecoration: "line-through" }}>{row.old}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: "#94A3B8" }}>{row.was}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: P.electric, fontWeight: 600 }}>{row.now}</div>
                  </div>
                ))}
              </div>
            </Section>
          </div>
        )}

        {/* ═══ MOCKUP ═══ */}
        {activeTab === "mockup" && (
          <div>
            <Section title="Interface Mockup" subtitle="Genesis in First Light — midnight canvas, zone titles, 17pt floor, full-spectrum pads">
              <MockupHUD />
            </Section>
            <Section title="Before → After">
              <div style={{ background: "#111827", borderRadius: 10, padding: 24, marginTop: 16, border: "1px solid rgba(59,130,246,0.08)" }}>
                <div style={{ display: "flex", padding: "8px 0", borderBottom: "1px solid rgba(59,130,246,0.1)", marginBottom: 8 }}>
                  <div style={{ flex: 1, fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: P.electric, letterSpacing: 2 }}>ELEMENT</div>
                  <div style={{ flex: 1, fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: "#475569", letterSpacing: 2 }}>FOREST CHROME</div>
                  <div style={{ flex: 1, fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: P.electric, letterSpacing: 2 }}>FIRST LIGHT</div>
                </div>
                <ComparisonRow label="Background" oldVal="Deep green #0d1a12" newVal="Midnight #0B1120" />
                <ComparisonRow label="Hero numbers" oldVal="Chrome silver #f0f4f1" newVal="True white #F8FAFC" />
                <ComparisonRow label="Section labels" oldVal="Chrome (no titles)" newVal="Electric blue (every zone)" />
                <ComparisonRow label="Smallest text" oldVal="11pt (monoTiny)" newVal="17pt (hard floor)" />
                <ComparisonRow label="Active indicators" oldVal="Sage #66b06b" newVal="Vivid sage #4ADE80" />
                <ComparisonRow label="Dividers" oldVal="Green-tinted" newVal="Blue-tinted rgba(blue, 0.12)" />
                <ComparisonRow label="Pad 3 (HATS)" oldVal="Gold #d4a828" newVal="Sky blue #7DD3FC" />
                <ComparisonRow label="Pad 5 (BASS)" oldVal="Emerald #38903a" newVal="Electric blue #3B82F6" />
                <ComparisonRow label="Pad 6 (KEYS)" oldVal="Sienna #b87040" newVal="Soft violet #A78BFA" />
                <ComparisonRow label="Pad 7 (VOX)" oldVal="Mauve #c06070" newVal="Warm rose #FB7185" />
              </div>
            </Section>
          </div>
        )}

        {/* ═══ THEME.SWIFT ═══ */}
        {activeTab === "code" && (
          <div>
            <Section title="Theme.swift — First Light" subtitle="Drop-in replacement for Views/Theme.swift">
              <CodeBlock code={`import SwiftUI

enum Theme {
    // ═══════════════════════════════════════════════════════════════
    //  GENESIS — First Light design system
    // ═══════════════════════════════════════════════════════════════

    // Backgrounds — midnight studio
    static let bg       = Color(red: 0.043, green: 0.067, blue: 0.125)     // #0B1120
    static let canvasBg = Color(red: 0.067, green: 0.094, blue: 0.153)     // #111827
    static let elevated = Color(red: 0.102, green: 0.137, blue: 0.196)     // #1A2332

    // Text — true bright white
    static let text   = Color(red: 0.796, green: 0.835, blue: 0.882)       // #CBD5E1
    static let chrome = Color(red: 0.973, green: 0.980, blue: 0.988)       // #F8FAFC

    // Signature blues
    static let electric = Color(red: 0.231, green: 0.510, blue: 0.965)     // #3B82F6
    static let sky      = Color(red: 0.490, green: 0.827, blue: 0.988)     // #7DD3FC
    static let ice      = Color(red: 0.729, green: 0.902, blue: 0.992)     // #BAE6FD

    // Semantic — vivid, not muted
    static let sage       = Color(red: 0.290, green: 0.871, blue: 0.502)   // #4ADE80
    static let mint       = Color(red: 0.204, green: 0.827, blue: 0.600)   // #34D399
    static let ember      = Color(red: 0.976, green: 0.451, blue: 0.086)   // #F97316
    static let terracotta = Color(red: 0.918, green: 0.345, blue: 0.047)   // #EA580C
    static let gold       = Color(red: 0.984, green: 0.749, blue: 0.141)   // #FBBF24
    static let clay       = Color(red: 0.937, green: 0.267, blue: 0.267)   // #EF4444
    static let rose       = Color(red: 0.984, green: 0.443, blue: 0.522)   // #FB7185

    // Structural
    static let subtle    = Color(red: 0.118, green: 0.161, blue: 0.231)    // #1E293B
    static let muted     = Color(red: 0.392, green: 0.455, blue: 0.545)    // #64748B
    static let separator = Color(red: 0.231, green: 0.510, blue: 0.965)
                            .opacity(0.12)                                  // electric @ 12%

    // Pad colors — full spectrum
    static let padColors: [Color] = [
        Color(red: 0.976, green: 0.451, blue: 0.086),  // kicks  — bright orange  #F97316
        Color(red: 0.984, green: 0.749, blue: 0.141),  // snares — electric gold  #FBBF24
        Color(red: 0.490, green: 0.827, blue: 0.988),  // hats   — sky blue       #7DD3FC
        Color(red: 0.290, green: 0.871, blue: 0.502),  // perc   — vivid green    #4ADE80
        Color(red: 0.231, green: 0.510, blue: 0.965),  // bass   — electric blue  #3B82F6
        Color(red: 0.655, green: 0.545, blue: 0.984),  // keys   — soft violet    #A78BFA
        Color(red: 0.984, green: 0.443, blue: 0.522),  // vox    — warm rose      #FB7185
        Color(red: 0.204, green: 0.827, blue: 0.600),  // fx     — mint           #34D399
    ]

    static func padColor(_ index: Int) -> Color {
        padColors[index % padColors.count]
    }

    // ═══════════════════════════════════════════════════════════════
    //  TYPOGRAPHY — 17pt HARD FLOOR. Nothing smaller. Ever.
    // ═══════════════════════════════════════════════════════════════

    static let hero         = Font.system(size: 52, design: .monospaced).weight(.bold)
    static let title        = Font.system(size: 36, design: .monospaced).weight(.bold)
    static let monoLarge    = Font.system(size: 22, design: .monospaced).weight(.bold)
    static let sectionLabel = Font.system(size: 20, design: .monospaced).weight(.semibold)
    static let mono         = Font.system(size: 17, design: .monospaced)

    // REMOVED: monoSmall (was 14pt), monoTiny (was 11pt)
    static let monoSmall    = mono    // ← was 14pt, now 17pt
    static let monoTiny     = mono    // ← was 11pt, now 17pt

    // Legacy aliases
    static let blue   = electric
    static let ice_   = sky
    static let orange = ember
    static let green  = sage
    static let red    = clay
    static let amber  = gold
    static let moss   = mint
    static let forest = sage
    static let wheat  = gold
}`} />
            </Section>
          </div>
        )}

        {/* ═══ RULES ═══ */}
        {activeTab === "rules" && (
          <div>
            <Section title="Usage Rules" subtitle="How to apply First Light consistently in every new view">
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginTop: 16 }}>
                {[
                  { title: "17pt floor — no exceptions", desc: "Every piece of text in the app is 17pt or larger. Effect labels, file names, pad data, hit counts, volume %, nav hints — all 17pt mono. monoTiny and monoSmall alias to mono. If text doesn't fit, resize the container, not the font.", color: P.clay },
                  { title: "Every zone gets a title", desc: "MASTER, TERMINAL, HOTKEYS, PAD_SELECT, INSPECT, BROWSER — every section has a labeled title in sectionLabel (20pt semibold, electric blue, tracking 3). You never guess what part of the app you're in.", color: P.electric },
                  { title: "Hero numbers = white + blue glow", desc: "BPM, volume, dB use Theme.chrome (bright white) with shadow: electric.opacity(0.25), radius: 8. Never gray, never silver.", color: P.white },
                  { title: "Section labels = electric blue", desc: "Every zone title uses Theme.electric with tracking: 3. This is the signature. No other color for section headers.", color: P.electric },
                  { title: "Active indicators = sage green", desc: "VEL, METRO, CHOKE ON, playing state — all glow Theme.sage. Green means alive. Reserve ember/clay for recording and danger.", color: P.sage },
                  { title: "Glow = the element's own color", desc: "Active pad glows its padColor. Active toggle glows sage. Recording glows clay. The glow shadow always matches the element, opacity 0.2-0.4, radius 6-12.", color: P.gold },
                  { title: "Terminal lines = colored by type", desc: "System → mint, transport → mint, hit → padColor, state → silver, capture → ember, browse → sky, oracle → electric. Each type has ONE color.", color: P.sky },
                  { title: "No cold black", desc: "Even the darkest background (#0B1120) has a hint of blue. The whole app lives in midnight blue, never void-black.", color: P.midnight },
                ].map((rule, i) => (
                  <div key={i} style={{ background: "#111827", borderRadius: 10, padding: 20, border: "1px solid rgba(59,130,246,0.08)" }}>
                    <div style={{ fontSize: 14, fontWeight: 600, color: rule.color, marginBottom: 8, textShadow: `0 0 12px ${rule.color}25` }}>{rule.title}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#94A3B8", lineHeight: 1.6 }}>{rule.desc}</div>
                  </div>
                ))}
              </div>
            </Section>

            <Section title="Do / Don't" subtitle="Quick reference for staying on brand">
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 24, marginTop: 16 }}>
                <div style={{ background: "#111827", borderRadius: 10, padding: 24, border: "1px solid rgba(74, 222, 128, 0.15)" }}>
                  <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: P.sage, letterSpacing: 2, marginBottom: 12 }}>DO</div>
                  {[
                    "Set 17pt as the minimum — every label, every value, everywhere",
                    "Give every zone a titled header in electric blue (20pt semibold)",
                    "Use bright white for any number that matters",
                    "Use electric blue for all section labels and dividers",
                    "Give active elements a glow shadow in their color",
                    "Keep pads visually distinct — use the full spectrum",
                    "Use midnight blue backgrounds (neutral, not tinted)",
                    "If text doesn't fit, make the container bigger, not the font smaller",
                  ].map((item, i) => (
                    <div key={i} style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#94A3B8", padding: "4px 0" }}>
                      <span style={{ color: P.sage }}>✓</span> {item}
                    </div>
                  ))}
                </div>
                <div style={{ background: "#111827", borderRadius: 10, padding: 24, border: "1px solid rgba(239, 68, 68, 0.15)" }}>
                  <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: P.clay, letterSpacing: 2, marginBottom: 12 }}>DON'T</div>
                  {[
                    "Use any font size below 17pt — not 14, not 11, not 9",
                    "Create a section without a labeled title",
                    "Use gray or silver where white should be",
                    "Tint backgrounds green or brown",
                    "Make all pad colors from the same warm range",
                    "Use ember for non-recording states",
                    "Add borders where a glow shadow would work",
                    "Shrink text to fit a layout — resize the layout instead",
                  ].map((item, i) => (
                    <div key={i} style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#94A3B8", padding: "4px 0" }}>
                      <span style={{ color: P.clay }}>✗</span> {item}
                    </div>
                  ))}
                </div>
              </div>
            </Section>

            <Section title="Migration Checklist" subtitle="Per-file changes from Forest Chrome → First Light">
              <div style={{ background: "#111827", borderRadius: 10, padding: 24, marginTop: 16, border: "1px solid rgba(59,130,246,0.08)" }}>
                {[
                  { file: "Theme.swift", action: "Replace entirely — midnight palette, 17pt floor, monoSmall/monoTiny aliased to mono" },
                  { file: "GHUD.swift", action: "Add MASTER sectionLabel title. All labels → mono (17pt). Heroes → chrome (white). Shadows → electric" },
                  { file: "BeatTrackerHUD.swift", action: "Labels (BPM, BEAT, BAR) → mono (17pt). Numbers → chrome. Border → separator" },
                  { file: "ContentView.swift", action: "Add HOTKEYS and TERMINAL sectionLabel titles to respective zones" },
                  { file: "PadInspectPanel.swift", action: "INSPECT title → electric. All rows → mono (17pt). Channel name → chrome" },
                  { file: "PadSelect.swift", action: "PAD_SELECT → electric. ALL data rows → mono (17pt)" },
                  { file: "SampleBrowserView.swift", action: "BROWSER → electric. File items → mono (17pt). Nav hints → 17pt" },
                  { file: "TerminalTextLayer.swift", action: "Add TERMINAL title. All lines 17pt. oracle→electric, browse→sky" },
                ].map((item, i) => (
                  <div key={i} style={{ display: "flex", gap: 16, padding: "10px 0", borderBottom: i < 7 ? "1px solid rgba(59,130,246,0.06)" : "none" }}>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: P.sky, minWidth: 200 }}>{item.file}</div>
                    <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#94A3B8" }}>{item.action}</div>
                  </div>
                ))}
              </div>
            </Section>
          </div>
        )}
      </main>
    </div>
  );
}