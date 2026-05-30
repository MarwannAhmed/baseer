// Baseer – Onboarding screens
// Color palette pulled from logo:
//   navy   #152E3E  (primary)
//   steel  #2D6A8E  (accent / iris)
//   cream  #F7F5F0  (bg)
//   ink    #3C4B57  (secondary text)

const C = {
  navy:  '#152E3E',
  steel: '#2D6A8E',
  cream: '#F7F5F0',
  ink:   '#3C4B57',
  line:  'rgba(21,46,62,0.12)',
  soft:  '#EDE8DE',
  white: '#FFFFFF',
};

const FONT = "'Plus Jakarta Sans', 'Helvetica Neue', Helvetica, system-ui, sans-serif";

// ─── Logo mark (simplified original eye symbol – not the Arabic wordmark) ───
function EyeMark({ size = 72, color = C.navy, iris = C.steel }) {
  return (
    <svg width={size} height={size * 0.58} viewBox="0 0 120 70" aria-hidden="true">
      <path d="M4 35 Q 60 -10 116 35 Q 60 80 4 35 Z"
            fill="none" stroke={color} strokeWidth="6" strokeLinejoin="round"/>
      <circle cx="60" cy="35" r="14" fill={iris}/>
      <circle cx="60" cy="35" r="5" fill={color}/>
      <circle cx="65" cy="30" r="2" fill="#fff"/>
    </svg>
  );
}

// ─── Reusable primary button ───
function PrimaryBtn({ label, sub, bg = C.navy, fg = C.cream, full = true }) {
  return (
    <div style={{
      width: full ? '100%' : 'auto',
      background: bg, color: fg, borderRadius: 14,
      padding: '18px 24px', textAlign: 'center',
      fontFamily: FONT, fontWeight: 600, fontSize: 18,
      boxShadow: '0 1px 0 rgba(0,0,0,0.04)',
      boxSizing: 'border-box',
    }}>
      {label}
      {sub && <div style={{ fontSize: 12, fontWeight: 400, opacity: 0.7, marginTop: 2 }}>{sub}</div>}
    </div>
  );
}
function GhostBtn({ label, full = true }) {
  return (
    <div style={{
      width: full ? '100%' : 'auto',
      color: C.navy, borderRadius: 14,
      padding: '18px 24px', textAlign: 'center',
      fontFamily: FONT, fontWeight: 600, fontSize: 16,
      border: `1.5px solid ${C.line}`, background: 'transparent',
      boxSizing: 'border-box',
    }}>{label}</div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 01 – Splash
// ─────────────────────────────────────────────────────────────────────────────
function Screen_Splash() {
  return (
    <AndroidDevice width={360} height={780}>
      <div style={{
        height: '100%', background: C.navy, color: C.cream,
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        fontFamily: FONT, padding: 32, boxSizing: 'border-box',
      }}>
        <EyeMark size={140} color={C.cream} iris={C.steel} />
        <div style={{
          marginTop: 36, fontSize: 56, fontWeight: 700, letterSpacing: -1.5,
        }}>Baseer</div>
        <div style={{
          marginTop: 10, fontSize: 16, opacity: 0.7, letterSpacing: 0.5,
        }}>Your second pair of eyes</div>
        <div style={{
          marginTop: 80, width: 44, height: 44, borderRadius: 22,
          border: `3px solid ${C.steel}`, borderTopColor: 'transparent',
        }} />
      </div>
    </AndroidDevice>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 02 – Welcome / language
// ─────────────────────────────────────────────────────────────────────────────
function Screen_Welcome() {
  return (
    <AndroidDevice width={360} height={780}>
      <div style={{
        height: '100%', background: C.cream, color: C.navy,
        display: 'flex', flexDirection: 'column',
        fontFamily: FONT, padding: '24px 24px 28px', boxSizing: 'border-box',
      }}>
        <div style={{ paddingTop: 24 }}>
          <EyeMark size={56} color={C.navy} iris={C.steel} />
        </div>

        <div style={{ marginTop: 48 }}>
          <div style={{ fontSize: 40, fontWeight: 700, lineHeight: 1.05, letterSpacing: -1 }}>
            Welcome.
          </div>
          <div style={{ marginTop: 16, fontSize: 18, color: C.ink, lineHeight: 1.45 }}>
            Baseer describes the world around you through your phone's camera and a simple voice.
          </div>
        </div>

        <div style={{ marginTop: 'auto' }}>
          <div style={{ fontSize: 13, color: C.ink, marginBottom: 10, letterSpacing: 0.5, textTransform: 'uppercase' }}>
            Language
          </div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 24 }}>
            {[
              { l: 'English', sel: true },
              { l: 'العربية' },
              { l: 'Français' },
            ].map(o => (
              <div key={o.l} style={{
                flex: 1, padding: '14px 0', textAlign: 'center',
                borderRadius: 12, fontSize: 15, fontWeight: 600,
                background: o.sel ? C.navy : 'transparent',
                color: o.sel ? C.cream : C.navy,
                border: o.sel ? 'none' : `1.5px solid ${C.line}`,
              }}>{o.l}</div>
            ))}
          </div>

          <PrimaryBtn label="Get started" />
          <div style={{ height: 12 }} />
          <div style={{ textAlign: 'center', fontSize: 14, color: C.ink }}>
            I already have an account
          </div>
        </div>
      </div>
    </AndroidDevice>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 03 – Permissions
// ─────────────────────────────────────────────────────────────────────────────
function Screen_Permissions() {
  const Row = ({ label, desc, on = false, required }) => (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 14,
      padding: '18px 0', borderTop: `1px solid ${C.line}`,
    }}>
      <div style={{
        width: 44, height: 44, borderRadius: 12, flexShrink: 0,
        background: C.soft, display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: C.navy, fontWeight: 700, fontSize: 14,
      }}>
        {label[0]}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 16, fontWeight: 600, color: C.navy, display: 'flex', gap: 8, alignItems: 'center' }}>
          {label}
          {required && (
            <span style={{ fontSize: 11, color: C.steel, fontWeight: 600, letterSpacing: 0.6 }}>REQUIRED</span>
          )}
        </div>
        <div style={{ fontSize: 14, color: C.ink, marginTop: 4, lineHeight: 1.4 }}>{desc}</div>
      </div>
      <div style={{
        width: 44, height: 26, borderRadius: 13,
        background: on ? C.steel : '#CFCABF',
        position: 'relative', flexShrink: 0, marginTop: 8,
      }}>
        <div style={{
          position: 'absolute', top: 3, left: on ? 21 : 3,
          width: 20, height: 20, borderRadius: 10, background: '#fff',
          boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
        }}/>
      </div>
    </div>
  );

  return (
    <AndroidDevice width={360} height={780}>
      <div style={{
        height: '100%', background: C.cream, color: C.navy,
        display: 'flex', flexDirection: 'column',
        fontFamily: FONT, padding: '28px 24px', boxSizing: 'border-box',
      }}>
        <div style={{ fontSize: 13, color: C.steel, fontWeight: 600, letterSpacing: 1 }}>
          STEP 1 OF 3
        </div>
        <div style={{ fontSize: 32, fontWeight: 700, marginTop: 8, letterSpacing: -0.5, lineHeight: 1.1 }}>
          A few permissions
        </div>
        <div style={{ fontSize: 15, color: C.ink, marginTop: 10, lineHeight: 1.45 }}>
          Baseer only uses what it needs to describe your surroundings.
        </div>

        <div style={{ marginTop: 24 }}>
          <Row label="Camera"       desc="To see and describe scenes, text and objects."      on required />
          <Row label="Microphone"   desc="So you can ask questions and give voice commands."   on required />
          <Row label="Location"     desc="For nearby places, addresses and safe navigation."   />
          <Row label="Notifications" desc="Gentle reminders, never sounds without your OK."   on />
        </div>

        <div style={{ marginTop: 'auto', paddingTop: 16 }}>
          <PrimaryBtn label="Allow and continue" />
          <div style={{ height: 10 }} />
          <div style={{ textAlign: 'center', fontSize: 13, color: C.ink }}>
            You can change any of these later in Settings.
          </div>
        </div>
      </div>
    </AndroidDevice>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 04 – Voice calibration
// ─────────────────────────────────────────────────────────────────────────────
function Screen_Voice() {
  const bars = Array.from({ length: 28 }, (_, i) => {
    const h = 8 + Math.abs(Math.sin(i * 0.7) * 38) + (i % 3) * 6;
    return Math.min(h, 58);
  });
  return (
    <AndroidDevice width={360} height={780}>
      <div style={{
        height: '100%', background: C.cream, color: C.navy,
        display: 'flex', flexDirection: 'column',
        fontFamily: FONT, padding: '28px 24px', boxSizing: 'border-box',
      }}>
        <div style={{ fontSize: 13, color: C.steel, fontWeight: 600, letterSpacing: 1 }}>
          STEP 2 OF 3
        </div>
        <div style={{ fontSize: 32, fontWeight: 700, marginTop: 8, letterSpacing: -0.5, lineHeight: 1.1 }}>
          Let me hear you
        </div>
        <div style={{ fontSize: 15, color: C.ink, marginTop: 10, lineHeight: 1.45 }}>
          Say the phrase below so Baseer learns your voice.
        </div>

        <div style={{
          marginTop: 28, background: C.white,
          border: `1px solid ${C.line}`, borderRadius: 18,
          padding: '28px 22px', textAlign: 'center',
        }}>
          <div style={{ fontSize: 12, color: C.ink, letterSpacing: 1.5, fontWeight: 600 }}>
            REPEAT AFTER ME
          </div>
          <div style={{ fontSize: 26, fontWeight: 600, marginTop: 12, lineHeight: 1.2, letterSpacing: -0.3 }}>
            "Hey Baseer, what do you see?"
          </div>
        </div>

        <div style={{
          marginTop: 28, display: 'flex', alignItems: 'center', justifyContent: 'center',
          gap: 3, height: 70,
        }}>
          {bars.map((h, i) => (
            <div key={i} style={{
              width: 4, height: h, borderRadius: 2,
              background: i < 14 ? C.steel : C.line,
            }}/>
          ))}
        </div>

        <div style={{
          margin: '12px auto 0', width: 92, height: 92, borderRadius: 46,
          background: C.navy, display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: `0 0 0 10px rgba(45,106,142,0.18)`,
        }}>
          <div style={{
            width: 18, height: 28, borderRadius: 9, background: C.cream,
          }}/>
        </div>
        <div style={{ textAlign: 'center', marginTop: 14, fontSize: 14, color: C.ink }}>
          Listening…  tap to stop
        </div>

        <div style={{ marginTop: 'auto', paddingTop: 16 }}>
          <GhostBtn label="Skip for now" />
        </div>
      </div>
    </AndroidDevice>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 05 – What Baseer can do
// ─────────────────────────────────────────────────────────────────────────────
function Screen_Features() {
  const Feat = ({ n, title, desc }) => (
    <div style={{
      display: 'flex', gap: 16, padding: '18px 0',
      borderTop: `1px solid ${C.line}`,
    }}>
      <div style={{
        width: 40, height: 40, borderRadius: 20, flexShrink: 0,
        border: `1.5px solid ${C.navy}`, color: C.navy,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontWeight: 700, fontSize: 15,
      }}>{n}</div>
      <div style={{ flex: 1, paddingTop: 4 }}>
        <div style={{ fontSize: 17, fontWeight: 600, color: C.navy }}>{title}</div>
        <div style={{ fontSize: 14, color: C.ink, marginTop: 4, lineHeight: 1.45 }}>{desc}</div>
      </div>
    </div>
  );

  return (
    <AndroidDevice width={360} height={780}>
      <div style={{
        height: '100%', background: C.cream, color: C.navy,
        display: 'flex', flexDirection: 'column',
        fontFamily: FONT, padding: '28px 24px', boxSizing: 'border-box',
      }}>
        <div style={{ fontSize: 13, color: C.steel, fontWeight: 600, letterSpacing: 1 }}>
          STEP 3 OF 3
        </div>
        <div style={{ fontSize: 32, fontWeight: 700, marginTop: 8, letterSpacing: -0.5, lineHeight: 1.1 }}>
          What I can do
        </div>
        <div style={{ fontSize: 15, color: C.ink, marginTop: 10, lineHeight: 1.45 }}>
          Point, ask, or hold to capture. I'll describe it out loud.
        </div>

        <div style={{ marginTop: 20 }}>
          <Feat n="1" title="Describe a scene"
            desc="Aim your camera. I'll narrate what's in front of you — people, places, mood." />
          <Feat n="2" title="Read any text"
            desc="Menus, mail, signs, medicine labels. Works on printed and handwritten." />
          <Feat n="3" title="Find objects"
            desc="'Where are my keys?' I'll guide you with left/right cues." />
          <Feat n="4" title="Call a helper"
            desc="One tap connects you to a trusted contact on live video." />
        </div>

        <div style={{ marginTop: 'auto', paddingTop: 20 }}>
          <PrimaryBtn label="I'm ready" />
        </div>
      </div>
    </AndroidDevice>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 06 – Ready / home
// ─────────────────────────────────────────────────────────────────────────────
function Screen_Ready() {
  const feedBg = `
    radial-gradient(120% 80% at 30% 20%, rgba(45,106,142,0.55) 0%, rgba(21,46,62,0.85) 55%, #0A1822 100%),
    repeating-linear-gradient(135deg, rgba(255,255,255,0.03) 0 8px, transparent 8px 16px)
  `;

  return (
    <AndroidDevice width={360} height={780}>
      <div style={{
        height: '100%', position: 'relative', overflow: 'hidden',
        fontFamily: FONT, color: C.cream,
        background: feedBg, backgroundBlendMode: 'normal',
      }}>
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
          fontSize: 11, letterSpacing: 2, color: 'rgba(247,245,240,0.35)',
        }}>
          [ LIVE CAMERA FEED ]
        </div>

        {[
          { top: 110, left: 24,  rot: 0 },
          { top: 110, right: 24, rot: 90 },
          { bottom: 230, left: 24,  rot: 270 },
          { bottom: 230, right: 24, rot: 180 },
        ].map((p, i) => (
          <div key={i} style={{
            position: 'absolute', ...p,
            width: 22, height: 22,
            borderTop: '2px solid rgba(247,245,240,0.7)',
            borderLeft: '2px solid rgba(247,245,240,0.7)',
            transform: `rotate(${p.rot}deg)`,
          }}/>
        ))}

        <div style={{
          position: 'absolute', top: 16, left: 20, right: 20,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            background: 'rgba(10,24,34,0.55)', backdropFilter: 'blur(8px)',
            padding: '8px 12px', borderRadius: 100,
            border: '1px solid rgba(247,245,240,0.12)',
          }}>
            <div style={{ width: 8, height: 8, borderRadius: 4, background: '#E45858' }}/>
            <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: 1 }}>LIVE</div>
          </div>
          <div style={{
            background: 'rgba(10,24,34,0.55)', backdropFilter: 'blur(8px)',
            padding: '8px 12px', borderRadius: 100,
            border: '1px solid rgba(247,245,240,0.12)',
            fontSize: 12, fontWeight: 600,
          }}>
            Hello, Sara
          </div>
        </div>

        <div style={{
          position: 'absolute', top: 70, left: 20, right: 20,
          background: 'rgba(10,24,34,0.55)', backdropFilter: 'blur(10px)',
          border: '1px solid rgba(247,245,240,0.1)',
          borderRadius: 14, padding: '12px 14px',
          display: 'flex', gap: 10, alignItems: 'flex-start',
        }}>
          <div style={{
            width: 24, height: 24, borderRadius: 12, flexShrink: 0,
            background: C.steel, display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 11, fontWeight: 700,
          }}>B</div>
          <div>
            <div style={{ fontSize: 11, opacity: 0.6, letterSpacing: 1, fontWeight: 600 }}>I SEE</div>
            <div style={{ fontSize: 14, lineHeight: 1.4, marginTop: 2 }}>
              A kitchen counter. A white mug on the left, keys next to it.
            </div>
          </div>
        </div>

        <div style={{
          position: 'absolute', left: 0, right: 0, bottom: 0,
          background: 'linear-gradient(180deg, rgba(10,24,34,0) 0%, rgba(10,24,34,0.75) 40%, rgba(10,24,34,0.92) 100%)',
          padding: '40px 20px 24px',
        }}>
          <div style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            marginBottom: 22,
          }}>
            <div style={{
              width: 96, height: 96, borderRadius: 48,
              background: C.steel, display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 0 0 10px rgba(45,106,142,0.28), 0 0 0 22px rgba(45,106,142,0.14)',
            }}>
              <div style={{ width: 18, height: 28, borderRadius: 9, background: C.cream }}/>
            </div>
            <div style={{ marginTop: 12, fontSize: 15, fontWeight: 600 }}>
              Hold to talk
            </div>
            <div style={{ fontSize: 12, opacity: 0.65, marginTop: 2 }}>
              or say "Hey Baseer"
            </div>
          </div>

          <div style={{ display: 'flex', gap: 10 }}>
            {['Describe', 'Read text', 'Call helper'].map(l => (
              <div key={l} style={{
                flex: 1, padding: '14px 0', textAlign: 'center',
                borderRadius: 12, fontSize: 13, fontWeight: 600,
                background: 'rgba(247,245,240,0.1)', color: C.cream,
                border: '1px solid rgba(247,245,240,0.16)',
                backdropFilter: 'blur(6px)',
              }}>{l}</div>
            ))}
          </div>
        </div>
      </div>
    </AndroidDevice>
  );
}

Object.assign(window, {
  Screen_Splash, Screen_Welcome, Screen_Permissions,
  Screen_Voice, Screen_Features, Screen_Ready,
});
