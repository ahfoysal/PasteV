import React from "react";
import { createRoot } from "react-dom/client";
import { Clipboard, Github, Pin, Search, ShieldCheck, Sparkles, MousePointer2, Download } from "lucide-react";
import "./styles.css";

const githubUrl = "https://github.com/ahfoysal/PasteV";
const releaseUrl = "https://github.com/ahfoysal/PasteV/releases/latest";

function ClipboardCard() {
  const rows = [
    { icon: <Pin />, text: "ssh foysal@production-server", meta: "Pinned · Text · 2:35 PM", hotkey: "⌘1", pinned: true },
    { icon: <Clipboard />, text: "Windows-style clipboard history, opening exactly beside your pointer.", meta: "Text · 2:29 PM", hotkey: "⌘2" },
    { icon: <Search />, text: "https://developer.apple.com/documentation/appkit/nspasteboard", meta: "Link · 2:18 PM", hotkey: "⌘3" },
  ];

  return (
    <div className="panel-demo" aria-label="PasteV clipboard panel preview">
      <div className="panel-head">
        <strong>Clipboard</strong>
        <button aria-label="Clear unpinned history">⌫</button>
      </div>
      <div className="panel-list">
        {rows.map((row, index) => (
          <div className={row.pinned ? "clip-row pinned" : "clip-row"} key={row.text}>
            <div className="row-icon">{row.icon}</div>
            <div>
              <p>{row.text}</p>
              <span>{row.meta}</span>
            </div>
            <kbd>{row.hotkey}</kbd>
          </div>
        ))}
      </div>
      <div className="panel-foot">
        <span></span>
        Ready to paste · 3 items
      </div>
    </div>
  );
}

function App() {
  return (
    <main>
      <nav className="topbar">
        <a className="brand" href="/">
          <img src="/logo.svg" alt="" className="brand-logo" />
          PASTEV
        </a>
        <div className="navlinks">
          <a href="#how">how it works</a>
          <a href="#features">features</a>
          <a href="#install">install</a>
          <a className="star" href={githubUrl}>
            <Github size={15} />
            star
          </a>
        </div>
      </nav>

      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">▸ CONTROL + V · MACOS</p>
          <img src="/logo.svg" alt="PasteV logo" className="hero-logo" />
          <h1>PASTEV</h1>
          <p className="lede">
            A tiny macOS clipboard history panel that opens where your mouse is, keeps pinned snippets close,
            and pastes back into the app you were using.
          </p>
          <div className="hero-actions">
            <a className="primary" href={releaseUrl}>
              <Download size={18} />
              get the dmg
            </a>
            <a className="secondary" href={githubUrl}>
              <Github size={18} />
              source on github
            </a>
          </div>
        </div>
        <div className="stage">
          <div className="fake-window">
            <div className="traffic"><i></i><i></i><i></i><span>Notes.md</span></div>
            <p>Meeting notes</p>
            <p>- Paste selected clipboard item here</p>
            <p>- Keep pinned items available</p>
            <p>- Open panel at the pointer</p>
          </div>
          <ClipboardCard />
        </div>
      </section>

      <section id="how" className="strip">
        <p className="eyebrow">▚ FAST LOOP</p>
        <h2>OPEN. PICK. PASTE.</h2>
        <div className="steps">
          <article><MousePointer2 /><h3>Where You Are</h3><p>Press Control + V and the panel appears at the mouse position.</p></article>
          <article><Pin /><h3>Pin The Good Stuff</h3><p>Right-click items to pin, unpin, copy only, or delete.</p></article>
          <article><ShieldCheck /><h3>Local First</h3><p>History stays on your Mac and Accessibility is used only for paste automation.</p></article>
        </div>
      </section>

      <section id="features" className="features">
        <p className="eyebrow">▚ POWER KEYS</p>
        <h2>SMALL PANEL. SERIOUS SPEED.</h2>
        <div className="feature-grid">
          {[
            "Global Control + V shortcut",
            "Mouse-positioned floating panel",
            "Pinned clipboard items",
            "Right-click item actions",
            "Compact content-sized height",
            "Scrollable long history",
            "Menu bar utility",
            "DMG install"
          ].map((feature) => <div className="feature" key={feature}><Sparkles size={16} />{feature}</div>)}
        </div>
      </section>

      <section id="install" className="install">
        <p className="eyebrow">▚ TWO MINUTES</p>
        <h2>BRING IT HOME</h2>
        <pre><code>{`curl -L https://github.com/ahfoysal/PasteV/releases/latest/download/PasteV-0.1.1.dmg -o PasteV.dmg
open PasteV.dmg
# drag PasteV to Applications
# enable PasteV in Privacy & Security > Accessibility`}</code></pre>
      </section>

      <footer>
        <strong>PASTEV</strong>
        <span>Open source · macOS · built by ahfoysal</span>
        <a href={githubUrl}>GitHub</a>
      </footer>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
