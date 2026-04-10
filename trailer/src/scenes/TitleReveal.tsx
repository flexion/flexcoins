import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
  Img,
  staticFile,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Orbitron";
import { GlowText } from "../components/GlowText";
import { ParticleBurst } from "../components/Particle";

const { fontFamily: orbitronFamily } = loadFont();

export const TitleReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Title spring in
  const titleScale = spring({
    frame: frame - 5,
    fps,
    config: { damping: 8, stiffness: 120, mass: 1.2 },
  });

  const titleOpacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Title glow pulse
  const glowPulse = 1 + Math.sin(frame * 0.15) * 0.15;

  // Subtitle typewriter effect
  const subtitle = "COLLECT.  UPGRADE.  ASCEND.";
  const charsToShow = interpolate(frame, [35, 90], [0, subtitle.length], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const visibleSubtitle = subtitle.slice(0, Math.floor(charsToShow));

  // Subtitle opacity
  const subtitleOpacity = interpolate(frame, [30, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Cursor blink
  const cursorVisible = frame >= 35 && frame < 95 && Math.floor(frame / 8) % 2 === 0;

  // Decorative lines
  const lineWidth = interpolate(frame, [15, 45], [0, 300], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Coin orbiting particles
  const orbitParticles = Array.from({ length: 8 }, (_, i) => {
    const angle = (i / 8) * Math.PI * 2 + frame * 0.06;
    const radius = 320 + Math.sin(frame * 0.08 + i) * 30;
    const x = 540 + Math.cos(angle) * radius;
    const y = 800 + Math.sin(angle) * radius * 0.3;
    const opacity = interpolate(frame, [20, 40], [0, 0.6], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    const size = 30 + (i % 3) * 10;
    return { key: i, x, y, opacity, size, angle };
  });

  // Background light rays
  const rayOpacity = interpolate(frame, [0, 25, 80, 120], [0, 0.12, 0.08, 0.04], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0e27" }}>
      {/* Radial light behind title */}
      <div
        style={{
          position: "absolute",
          left: 540,
          top: 780,
          transform: "translate(-50%, -50%)",
          width: 900,
          height: 900,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(255,215,0,0.1) 0%, rgba(255,170,0,0.03) 40%, transparent 70%)",
          opacity: interpolate(frame, [0, 30], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />

      {/* Light rays */}
      {Array.from({ length: 12 }, (_, i) => {
        const rayAngle = (i / 12) * 360 + frame * 0.5;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: 540,
              top: 780,
              width: 3,
              height: 600,
              background: `linear-gradient(to top, rgba(255,215,0,${rayOpacity}), transparent)`,
              transformOrigin: "bottom center",
              transform: `rotate(${rayAngle}deg)`,
            }}
          />
        );
      })}

      {/* Orbiting coin particles */}
      {orbitParticles.map((p) => (
        <div
          key={p.key}
          style={{
            position: "absolute",
            left: p.x - p.size / 2,
            top: p.y - p.size / 2,
            width: p.size,
            height: p.size,
            opacity: p.opacity,
            transform: `rotate(${p.angle * 60}deg)`,
            filter: "drop-shadow(0 0 8px #ffd70088)",
          }}
        >
          <Img
            src={staticFile("flexcoin.png")}
            style={{ width: p.size, height: p.size, objectFit: "contain" }}
          />
        </div>
      ))}

      {/* Main title */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 700,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          transform: `scale(${titleScale})`,
          opacity: titleOpacity,
        }}
      >
        <GlowText
          fontSize={110}
          fontWeight={900}
          color="#ffd700"
          style={{ transform: `scale(${glowPulse})` }}
        >
          FLEXCOINS
        </GlowText>
      </div>

      {/* Decorative lines */}
      <div
        style={{
          position: "absolute",
          left: 540 - lineWidth / 2,
          top: 835,
          width: lineWidth,
          height: 3,
          background: "linear-gradient(90deg, transparent, #ffd700, transparent)",
          opacity: interpolate(frame, [15, 30], [0, 0.8], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />

      {/* Subtitle */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 870,
          textAlign: "center",
          opacity: subtitleOpacity,
        }}
      >
        <span
          style={{
            color: "#ffffff",
            fontSize: 36,
            fontFamily: orbitronFamily,
            fontWeight: 400,
            letterSpacing: "0.2em",
            textShadow: "0 0 20px rgba(255,255,255,0.3)",
          }}
        >
          {visibleSubtitle}
          {cursorVisible && (
            <span style={{ color: "#ffd700" }}>|</span>
          )}
        </span>
      </div>

      {/* Particle burst on title appearance */}
      {frame >= 10 && (
        <ParticleBurst
          centerX={540}
          centerY={780}
          count={50}
          startFrame={10}
          duration={50}
          radius={500}
          colors={["#ffd700", "#ffaa00", "#ffffff", "#ffcc44", "#ff8800"]}
          sizes={[3, 10]}
          shape="star"
        />
      )}

      {/* Vignette */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,0.6) 100%)",
          pointerEvents: "none",
        }}
      />
    </AbsoluteFill>
  );
};
