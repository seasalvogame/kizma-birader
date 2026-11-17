// Kızma Birader — tahta, piyon ve zar çizimi (SVG). Veri: board_data.js (board_map.json).
// Görsel kurallar UI_UX_DESIGN_SYSTEM.md §7 ile aynıdır.
(function () {
  const B = window.BOARD;
  const COL = {
    red: { base: "#e5484d", dark: "#a8262b", soft: "#ffd5d6", light: "#ff8e91", sym: "triangle" },
    green: { base: "#2fb463", dark: "#1c7a40", soft: "#cdf2dc", light: "#7be0a3", sym: "circle" },
    yellow: { base: "#f5b70a", dark: "#b27f00", soft: "#ffeeb8", light: "#ffd968", sym: "square" },
    blue: { base: "#3a7bf7", dark: "#1f4fb8", soft: "#d5e3ff", light: "#86adff", sym: "diamond" },
  };
  const NS = "http://www.w3.org/2000/svg";
  const el = (tag, attrs, parent) => {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  };
  const starPath = (cx, cy, r) => {
    let d = "";
    for (let k = 0; k < 10; k++) {
      const rr = k % 2 ? r * 0.46 : r;
      const a = -Math.PI / 2 + (k * Math.PI) / 5;
      d += (k ? "L" : "M") + (cx + rr * Math.cos(a)).toFixed(2) + " " + (cy + rr * Math.sin(a)).toFixed(2);
    }
    return d + "Z";
  };
  const symbol = (g, kind, cx, cy, r, fill) => {
    if (kind === "triangle") el("path", { d: `M${cx} ${cy - r}L${cx + r * 0.95} ${cy + r * 0.7}L${cx - r * 0.95} ${cy + r * 0.7}Z`, fill }, g);
    else if (kind === "circle") el("circle", { cx, cy, r: r * 0.85, fill }, g);
    else if (kind === "square") el("rect", { x: cx - r * 0.75, y: cy - r * 0.75, width: r * 1.5, height: r * 1.5, rx: r * 0.2, fill }, g);
    else el("path", { d: `M${cx} ${cy - r}L${cx + r} ${cy}L${cx} ${cy + r}L${cx - r} ${cy}Z`, fill }, g);
  };

  // Tahta: size px kare. opts.pawns: [{color, at: "yard:0" | step(0..56)}], opts.movable: [{color, at}],
  // opts.targets: [{color, step}], opts.trail: [{color, from, to}]
  let boardSeq = 0;
  window.drawBoard = function (host, size, opts = {}) {
    const C = size / 15;
    const uid = "b" + (++boardSeq) + "-";
    const svg = el("svg", { width: size, height: size, viewBox: `0 0 ${size} ${size}` });
    host.appendChild(svg);
    const defs = el("defs", {}, svg);
    for (const c in COL) {
      const g = el("radialGradient", { id: `${uid}pg-${c}`, cx: "35%", cy: "28%", r: "75%" }, defs);
      el("stop", { offset: "0%", "stop-color": "#ffffff", "stop-opacity": ".95" }, g);
      el("stop", { offset: "22%", "stop-color": COL[c].light }, g);
      el("stop", { offset: "70%", "stop-color": COL[c].base }, g);
      el("stop", { offset: "100%", "stop-color": COL[c].dark }, g);
    }
    const sh = el("filter", { id: uid + "pshadow", x: "-50%", y: "-50%", width: "200%", height: "200%" }, defs);
    el("feDropShadow", { dx: 0, dy: C * 0.12, stdDeviation: C * 0.1, "flood-color": "#1b0f35", "flood-opacity": ".45" }, sh);
    const glow = el("filter", { id: uid + "glow", x: "-80%", y: "-80%", width: "260%", height: "260%" }, defs);
    el("feGaussianBlur", { stdDeviation: C * 0.18 }, glow);

    // Çerçeve ve zemin
    el("rect", { x: 0, y: 0, width: size, height: size, rx: C * 0.9, fill: "#fff6e6" }, svg);
    // Bekleme alanları
    for (const c of B.colors_clockwise) {
      const [x, y] = B.yards[c].rect;
      el("rect", { x: x * C, y: y * C, width: 6 * C, height: 6 * C, rx: C * 0.9, fill: COL[c].base }, svg);
      el("rect", { x: (x + 0.85) * C, y: (y + 0.85) * C, width: 4.3 * C, height: 4.3 * C, rx: C * 0.75, fill: "#fffaf1" }, svg);
      for (const [sx, sy] of B.yards[c].slots) {
        el("circle", { cx: (sx + 0.5) * C, cy: (sy + 0.5) * C, r: C * 0.62, fill: COL[c].soft, stroke: COL[c].base, "stroke-width": C * 0.1 }, svg);
      }
      // Renk sembolü (renk körlüğü desteği) bekleme alanının dış köşesinde
      const corner = { red: [0.5, 0.5], green: [5.5, 0.5], yellow: [5.5, 5.5], blue: [0.5, 5.5] }[c];
      symbol(svg, COL[c].sym, (x + corner[0]) * C, (y + corner[1]) * C, C * 0.24, "rgba(255,255,255,.85)");
    }
    // Parkur
    const startOf = {};
    for (const c of B.colors_clockwise) startOf[B.start_track_index[c]] = c;
    B.track.forEach(([x, y], i) => {
      const c = startOf[i];
      el("rect", { x: x * C + C * 0.06, y: y * C + C * 0.06, width: C * 0.88, height: C * 0.88, rx: C * 0.2,
        fill: c ? COL[c].base : "#ffffff", stroke: c ? COL[c].dark : "#ead7bb", "stroke-width": C * 0.05 }, svg);
      if (c) {
        // Başlangıç karesi: beyaz ok
        const cx = (x + 0.5) * C, cy = (y + 0.5) * C;
        const rot = { red: 0, green: 90, yellow: 180, blue: 270 }[c];
        const g = el("g", { transform: `rotate(${rot} ${cx} ${cy})` }, svg);
        el("path", { d: `M${cx - C * 0.22} ${cy - C * 0.22}L${cx + C * 0.18} ${cy}L${cx - C * 0.22} ${cy + C * 0.22}Z`, fill: "rgba(255,255,255,.9)" }, g);
      } else if (B.star_track_indices.includes(i)) {
        el("path", { d: starPath((x + 0.5) * C, (y + 0.5) * C, C * 0.36), fill: "#ffd04a", stroke: "#d49a00", "stroke-width": C * 0.04 }, svg);
      }
    });
    // Bitiş koridorları
    for (const c of B.colors_clockwise) {
      for (const [x, y] of B.home_columns[c]) {
        el("rect", { x: x * C + C * 0.06, y: y * C + C * 0.06, width: C * 0.88, height: C * 0.88, rx: C * 0.2, fill: COL[c].base, stroke: COL[c].dark, "stroke-width": C * 0.05 }, svg);
      }
    }
    // Orta bitiş: dört üçgen + parlak merkez
    const m = 7.5 * C, a = 6 * C, b = 9 * C;
    const tri = { red: [[a, a], [a, b]], green: [[a, a], [b, a]], yellow: [[b, a], [b, b]], blue: [[a, b], [b, b]] };
    for (const c in tri) {
      const [[x1, y1], [x2, y2]] = tri[c];
      el("path", { d: `M${x1} ${y1}L${x2} ${y2}L${m} ${m}Z`, fill: COL[c].base, stroke: "#fff6e6", "stroke-width": C * 0.08 }, svg);
    }
    el("circle", { cx: m, cy: m, r: C * 0.55, fill: "#fff6e6" }, svg);
    el("path", { d: starPath(m, m, C * 0.42), fill: "#ffd04a", stroke: "#d49a00", "stroke-width": C * 0.04 }, svg);

    const posOf = (p) => {
      if (typeof p.at === "string" && p.at.startsWith("yard:")) {
        const [sx, sy] = B.yards[p.color].slots[+p.at.slice(5)];
        return [(sx + 0.5) * C, (sy + 0.5) * C];
      }
      const cell = B.paths[p.color][p.at];
      if (cell === "GOAL") {
        const off = { red: [-0.75, 0], green: [0, -0.75], yellow: [0.75, 0], blue: [0, 0.75] }[p.color];
        return [m + off[0] * C, m + off[1] * C];
      }
      return [(cell[0] + 0.5) * C, (cell[1] + 0.5) * C];
    };
    // Son hamlenin izi
    for (const t of opts.trail || []) {
      let d = "";
      for (let s = t.from; s <= t.to; s++) {
        const [x, y] = posOf({ color: t.color, at: s });
        d += (s === t.from ? "M" : "L") + x + " " + y;
      }
      el("path", { d, fill: "none", stroke: COL[t.color].base, "stroke-width": C * 0.16, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-dasharray": `${C * 0.05} ${C * 0.32}`, opacity: ".8" }, svg);
    }
    // Hedef kareler (seçili piyonun gideceği yer)
    for (const t of opts.targets || []) {
      const [x, y] = posOf({ color: t.color, at: t.step });
      el("circle", { cx: x, cy: y, r: C * 0.36, fill: "none", stroke: COL[t.color].base, "stroke-width": C * 0.1, "stroke-dasharray": `${C * 0.18} ${C * 0.12}` }, svg);
      el("circle", { cx: x, cy: y, r: C * 0.12, fill: COL[t.color].base }, svg);
    }
    // Piyonlar
    const movableKey = new Set((opts.movable || []).map((p) => p.color + p.at));
    const stacks = {};
    for (const p of opts.pawns || []) {
      const k = posOf(p).join(",");
      stacks[k] = (stacks[k] || 0) + 1;
    }
    const seen = {};
    for (const p of opts.pawns || []) {
      let [x, y] = posOf(p);
      const k = x + "," + y;
      const n = stacks[k];
      const idx = (seen[k] = (seen[k] || 0) + 1) - 1;
      if (n > 1) { x += (idx - (n - 1) / 2) * C * 0.32; y -= idx * C * 0.08; }
      const s = p.at === 56 ? 0.7 : 1;
      const g = el("g", { transform: `translate(${x} ${y}) scale(${s})` }, svg);
      if (movableKey.has(p.color + p.at)) {
        el("circle", { cx: 0, cy: C * 0.05, r: C * 0.62, fill: COL[p.color].light, opacity: ".9", filter: `url(#${uid}glow)` }, g);
        el("circle", { cx: 0, cy: C * 0.05, r: C * 0.56, fill: "none", stroke: "#fff", "stroke-width": C * 0.08 }, g);
      }
      const pg = el("g", { filter: `url(#${uid}pshadow)` }, g);
      // Piyon: taban + gövde + baş
      el("ellipse", { cx: 0, cy: C * 0.26, rx: C * 0.4, ry: C * 0.17, fill: COL[p.color].dark }, pg);
      el("path", { d: `M${-C * 0.34} ${C * 0.22}C${-C * 0.3} ${-C * 0.05} ${-C * 0.12} ${-C * 0.1} ${-C * 0.1} ${-C * 0.2}L${C * 0.1} ${-C * 0.2}C${C * 0.12} ${-C * 0.1} ${C * 0.3} ${-C * 0.05} ${C * 0.34} ${C * 0.22}Z`, fill: `url(#${uid}pg-${p.color})`, stroke: "#fff", "stroke-width": C * 0.06 }, pg);
      el("circle", { cx: 0, cy: -C * 0.3, r: C * 0.25, fill: `url(#${uid}pg-${p.color})`, stroke: "#fff", "stroke-width": C * 0.06 }, pg);
      symbol(pg, COL[p.color].sym, 0, C * 0.08, C * 0.09, "rgba(255,255,255,.85)");
    }
    svg.dataset.uid = uid;
    return svg;
  };

  // Zar: değer 1..6, boyut px
  window.drawDice = function (host, size, value, opts = {}) {
    const svg = el("svg", { width: size, height: size, viewBox: "0 0 100 100" });
    host.appendChild(svg);
    const defs = el("defs", {}, svg);
    const g = el("linearGradient", { id: "dg" + value + size, x1: 0, y1: 0, x2: 0, y2: 1 }, defs);
    el("stop", { offset: "0%", "stop-color": opts.top || "#ffffff" }, g);
    el("stop", { offset: "100%", "stop-color": opts.bottom || "#f1e3cf" }, g);
    el("rect", { x: 6, y: 10, width: 88, height: 86, rx: 22, fill: opts.edge || "#d9c2a0" }, svg);
    el("rect", { x: 6, y: 4, width: 88, height: 86, rx: 22, fill: `url(#dg${value}${size})`, stroke: "rgba(255,255,255,.9)", "stroke-width": 2 }, svg);
    const P = { 1: [[50, 47]], 2: [[30, 27], [70, 67]], 3: [[30, 27], [50, 47], [70, 67]], 4: [[30, 27], [70, 27], [30, 67], [70, 67]],
      5: [[30, 27], [70, 27], [50, 47], [30, 67], [70, 67]], 6: [[30, 25], [70, 25], [30, 47], [70, 47], [30, 69], [70, 69]] };
    for (const [x, y] of P[value]) el("circle", { cx: x, cy: y, r: 8.5, fill: value === 1 ? "#e5484d" : (opts.pip || "#2a1f3d") }, svg);
    return svg;
  };
  window.PLAYER = COL;
})();
