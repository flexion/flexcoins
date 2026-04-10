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
import { loadFont as loadOrbitron } from "@remotion/google-fonts/Orbitron";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { GlowText } from "../components/GlowText";

const { fontFamily: orbitronFamily } = loadOrbitron();
const { fontFamily: interFamily } = loadInter();

export const CallToAction: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // "PLAY NOW" spring in
  const playNowScale = spring({
    frame: frame - 10,
    fps,
    config: { damping: 6, stiffness: 100, mass: 1.2 },
  });

  const playNowOpacity = interpolate(frame, [5, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Pulsing glow on "PLAY NOW"
  const pulseScale = 1 + Math.sin(frame * 0.15) * 0.06;
  const pulseGlow = 1 + Math.sin(frame * 0.15) * 0.3;

  // Spinning coin
  const coinRotation = frame * 3;
  const coinOpacity = interpolate(frame, [25, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const coinScale = frame >= 25
    ? spring({
        frame: frame - 25,
        fps,
        config: { damping: 10, stiffness: 120, mass: 0.8 },
      })
    : 0;

  // Tagline
  const taglineOpacity = interpolate(frame, [55, 70], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Fade to dark at end
  const fadeOut = interpolate(frame, [145, 180], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Background particles - slow-moving ambient
  const particles = Array.from({ length: 30 }, (_, i) => {
    const seed = i * 137.508;
    const startX = (seed * 7.3) % 1080;
    const startY = (seed * 3.1) % 1920;
    const dx = Math.sin(seed) * 0.3;
    const dy = -0.3 - (i % 5) * 0.1;
    const px = startX + frame * dx;
    const py = startY + frame * dy;
    const pOpacity =
      interpolate(frame, [0, 30], [0, 0.25], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      }) * (0.3 + (i % 4) * 0.2);
    const pSize = 2 + (i % 5);
    const color = i % 3 === 0 ? "#ffd700" : i % 3 === 1 ? "#b366ff" : "#ffffff";
    return { key: i, px, py, pOpacity, pSize, color };
  });

  // Orbiting stars around the coin
  const orbitStars = Array.from({ length: 6 }, (_, i) => {
    const angle = (i / 6) * Math.PI * 2 + frame * 0.05;
    const radius = 140 + Math.sin(frame * 0.06 + i) * 20;
    const x = 540 + Math.cos(angle) * radius;
    const y = 1000 + Math.sin(angle) * radius;
    const starOpacity = interpolate(frame, [35, 50], [0, 0.7], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    const starFile = ["star_yellow.png", "star_blue.png", "star_red.png", "star_green.png"][i % 4];
    return { key: i, x, y, opacity: starOpacity, file: starFile };
  });

  // Decorative line under "PLAY NOW"
  const lineWidth = interpolate(frame, [20, 50], [0, 400], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0e27" }}>
      {/* Background radial */}
      <div
        style={{
          position: "absolute",
          left: 540,
          top: 700,
          transform: "translate(-50%, -50%)",
          width: 1200,
          height: 1200,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(255,215,0,0.06) 0%, rgba(136,68,204,0.03) 50%, transparent 70%)",
        }}
      />

      {/* Ambient particles */}
      {particles.map((p) => (
        <div
          key={p.key}
          style={{
            position: "absolute",
            left: p.px,
            top: p.py,
            width: p.pSize,
            height: p.pSize,
            borderRadius: "50%",
            backgroundColor: p.color,
            opacity: p.pOpacity,
            boxShadow: `0 0 4px ${p.color}66`,
          }}
        />
      ))}

      {/* PLAY NOW */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 600,
          textAlign: "center",
          display: "flex",
          justifyContent: "center",
          transform: `scale(${playNowScale * pulseScale})`,
          opacity: playNowOpacity,
        }}
      >
        <div
          style={{
            display: "inline-block",
            padding: "20px 60px",
            borderRadius: 20,
            border: `2px solid #ffd700`,
            background: "rgba(10, 14, 39, 0.7)",
            boxShadow: `0 0 ${15 + Math.sin(frame * 0.15) * 10}px #ffd700, 0 0 ${30 + Math.sin(frame * 0.15) * 20}px #ffd70066`,
          }}
        >
          <GlowText
            fontSize={120}
            color="#ffd700"
            glowColor="#ffaa00"
            style={{
              filter: `brightness(${pulseGlow})`,
            }}
          >
            PLAY NOW
          </GlowText>
        </div>
      </div>

      {/* Decorative line */}
      <div
        style={{
          position: "absolute",
          left: 540 - lineWidth / 2,
          top: 740,
          width: lineWidth,
          height: 3,
          background: "linear-gradient(90deg, transparent, #ffd700, transparent)",
          opacity: interpolate(frame, [20, 35], [0, 0.7], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />

      {/* Spinning coin */}
      <div
        style={{
          position: "absolute",
          left: 540 - 60,
          top: 940,
          width: 120,
          height: 120,
          transform: `rotate(${coinRotation}deg) scale(${coinScale})`,
          opacity: coinOpacity,
          filter: "drop-shadow(0 0 15px #ffd700) drop-shadow(0 0 30px #ffaa0066)",
        }}
      >
        <Img
          src={staticFile("flexcoin.png")}
          style={{ width: 120, height: 120, objectFit: "contain" }}
        />
      </div>

      {/* Orbiting stars */}
      {orbitStars.map((s) => (
        <div
          key={s.key}
          style={{
            position: "absolute",
            left: s.x - 12,
            top: s.y - 12,
            width: 24,
            height: 24,
            opacity: s.opacity,
            filter: "drop-shadow(0 0 4px #ffd70088)",
          }}
        >
          <Img
            src={staticFile(s.file)}
            style={{ width: 24, height: 24, objectFit: "contain" }}
          />
        </div>
      ))}

      {/* Tagline */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 1150,
          textAlign: "center",
          opacity: taglineOpacity,
        }}
      >
        <span
          style={{
            color: "#ffffff",
            fontSize: 42,
            fontWeight: 400,
            fontFamily: orbitronFamily,
            letterSpacing: "0.15em",
            textShadow: "0 0 20px rgba(255,255,255,0.2)",
          }}
        >
          Every coin counts.
        </span>
      </div>

      {/* Small FlexCoins branding */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          bottom: 180,
          textAlign: "center",
          opacity: interpolate(frame, [70, 85], [0, 0.5], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        <span
          style={{
            color: "#ffffff77",
            fontSize: 22,
            fontFamily: interFamily,
            letterSpacing: "0.3em",
            textTransform: "uppercase",
          }}
        >
          Built with Godot 4.6
        </span>
      </div>

      {/* Fade to black */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundColor: "#000000",
          opacity: fadeOut,
          pointerEvents: "none",
        }}
      />

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
