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
import { Catcher } from "../components/Catcher";

const { fontFamily: orbitronFamily } = loadFont();

export const AscensionClimax: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Phase 1: Gold flash (frames 0-20)
  const flashOpacity = interpolate(frame, [0, 5, 12, 20], [0, 0.8, 0.6, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Phase 2: ASCENSION text (frames 15-90)
  const ascensionScale = frame >= 15
    ? spring({
        frame: frame - 15,
        fps,
        config: { damping: 9, stiffness: 120, mass: 1.0 },
      })
    : 0;

  const ascensionOpacity = interpolate(frame, [15, 25, 140, 160], [0, 1, 1, 0.7], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Pulsing glow
  const glowPulse = 1 + Math.sin(frame * 0.12) * 0.2;

  // Phase 3: Multiplier text sequence (frames 50-130)
  const multipliers = [
    { text: "1.5x", startFrame: 55, color: "#b366ff" },
    { text: "2.25x", startFrame: 75, color: "#cc88ff" },
    { text: "3.375x", startFrame: 95, color: "#eeccff" },
  ];

  // Phase 4: Rainbow catcher (frames 80-180)
  const catcherOpacity = interpolate(frame, [80, 95], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Background energy rings
  const ringCount = 8;
  const rings = Array.from({ length: ringCount }, (_, i) => {
    const ringStartFrame = 10 + i * 8;
    const ringLocalFrame = frame - ringStartFrame;
    if (ringLocalFrame < 0) return null;
    const ringScale = interpolate(ringLocalFrame, [0, 60], [0.2, 4 + i * 0.5], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    const ringOpacity = interpolate(ringLocalFrame, [0, 10, 50, 60], [0, 0.4, 0.1, 0], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    return { key: i, scale: ringScale, opacity: ringOpacity };
  });

  // Star burst particles
  const starBurstVisible = frame >= 20;

  // Floating ascension symbols
  const symbols = Array.from({ length: 60 }, (_, i) => {
    const seed = i * 137.508;
    const angle = (seed % 360) * (Math.PI / 180);
    const dist = 200 + (seed % 400);
    const speed = 0.02 + (i % 5) * 0.008;
    const currentAngle = angle + frame * speed;
    const x = 540 + Math.cos(currentAngle) * dist;
    const y = 700 + Math.sin(currentAngle) * dist * 0.6;
    const opacity = interpolate(frame, [20, 40], [0, 0.5], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }) * (0.3 + (i % 3) * 0.2);
    const size = 20 + (i % 4) * 10;
    return { key: i, x, y, opacity, size, rotation: frame * (1 + i % 3) };
  });

  // Screen shake
  const shakeIntensity = interpolate(frame, [0, 8, 25], [0, 12, 0], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
  });
  const shakeX = Math.sin(frame * 1.3) * shakeIntensity;
  const shakeY = Math.cos(frame * 1.7) * shakeIntensity;

  // Purple lightning bolts (decorative lines)
  const lightningOpacity = interpolate(
    frame,
    [8, 12, 16, 20, 24, 28],
    [0, 0.7, 0, 0.5, 0, 0.3],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0e27" }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          transform: `translate(${shakeX}px, ${shakeY}px)`,
        }}
      >
      {/* Deep purple background glow */}
      <div
        style={{
          position: "absolute",
          left: 540,
          top: 700,
          transform: "translate(-50%, -50%)",
          width: 1400,
          height: 1400,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(136,68,204,0.2) 0%, rgba(136,68,204,0.05) 40%, transparent 70%)",
          opacity: interpolate(frame, [0, 20], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />

      {/* Energy rings */}
      {rings.map((ring) => {
        if (!ring) return null;
        return (
          <div
            key={ring.key}
            style={{
              position: "absolute",
              left: 540,
              top: 700,
              transform: `translate(-50%, -50%) scale(${ring.scale})`,
              width: 300,
              height: 300,
              borderRadius: "50%",
              border: "2px solid #b366ff",
              opacity: ring.opacity,
              boxShadow: "0 0 20px #b366ff44, inset 0 0 20px #b366ff22",
            }}
          />
        );
      })}

      {/* Lightning flashes */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "linear-gradient(180deg, rgba(136,68,204,0.15) 0%, transparent 30%, transparent 70%, rgba(136,68,204,0.1) 100%)",
          opacity: lightningOpacity,
        }}
      />

      {/* Floating star particles */}
      {symbols.map((s) => (
        <div
          key={s.key}
          style={{
            position: "absolute",
            left: s.x - s.size / 2,
            top: s.y - s.size / 2,
            width: s.size,
            height: s.size,
            opacity: s.opacity,
            transform: `rotate(${s.rotation}deg)`,
            filter: "drop-shadow(0 0 4px #b366ff88)",
          }}
        >
          <Img
            src={staticFile(s.key % 3 === 0 ? "star_yellow.png" : s.key % 3 === 1 ? "star_blue.png" : "star_red.png")}
            style={{ width: s.size, height: s.size, objectFit: "contain" }}
          />
        </div>
      ))}

      {/* Gold flash overlay */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundColor: "#ffd700",
          opacity: flashOpacity,
        }}
      />

      {/* ASCENSION title */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 550,
          textAlign: "center",
          transform: `scale(${ascensionScale * glowPulse})`,
          opacity: ascensionOpacity,
        }}
      >
        <GlowText fontSize={100} color="#b366ff" glowColor="#9944dd">
          ASCENSION
        </GlowText>
      </div>

      {/* Multiplier sequence */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 750,
          display: "flex",
          justifyContent: "center",
          gap: 40,
        }}
      >
        {multipliers.map((m, i) => {
          const localF = frame - m.startFrame;
          if (localF < 0) return <div key={i} style={{ width: 200 }} />;

          const mScale = spring({
            frame: localF,
            fps,
            config: { damping: 7, stiffness: 160, mass: 0.6 },
          });

          const mOpacity = interpolate(localF, [0, 8], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });

          return (
            <div
              key={i}
              style={{
                transform: `scale(${mScale})`,
                opacity: mOpacity,
              }}
            >
              <span
                style={{
                  color: m.color,
                  fontSize: 56,
                  fontWeight: 900,
                  fontFamily: orbitronFamily,
                  textShadow: `0 0 15px ${m.color}88, 0 0 30px ${m.color}44`,
                }}
              >
                {m.text}
              </span>
            </div>
          );
        })}
      </div>

      {/* Arrow connectors between multipliers */}
      {multipliers.slice(1).map((m, i) => {
        const localF = frame - m.startFrame;
        if (localF < 0) return null;
        const arrowOpacity = interpolate(localF, [0, 10], [0, 0.6], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
        const arrowX = 320 + i * 240;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: arrowX,
              top: 770,
              color: "#b366ff88",
              fontSize: 40,
              opacity: arrowOpacity,
              fontFamily: orbitronFamily,
            }}
          >
            →
          </div>
        );
      })}

      {/* Rainbow catcher showcase */}
      <div style={{ opacity: catcherOpacity }}>
        <Catcher x={540} y={1350} width={280} height={32} tier={3} />
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 1410,
            textAlign: "center",
          }}
        >
          <span
            style={{
              color: `hsl(${(frame * 8) % 360}, 80%, 70%)`,
              fontSize: 28,
              fontWeight: 700,
              fontFamily: orbitronFamily,
              textShadow: `0 0 10px hsla(${(frame * 8) % 360}, 80%, 70%, 0.53)`,
              opacity: interpolate(frame, [100, 115], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }),
            }}
          >
            RAINBOW TIER UNLOCKED
          </span>
        </div>
      </div>

      {/* Star particle burst */}
      {starBurstVisible && (
        <ParticleBurst
          centerX={540}
          centerY={700}
          count={60}
          startFrame={20}
          duration={60}
          radius={600}
          colors={["#b366ff", "#9944dd", "#ffd700", "#cc88ff", "#ffffff"]}
          sizes={[4, 14]}
          shape="star"
        />
      )}

      {/* Second burst at multiplier reveal */}
      {frame >= 95 && (
        <ParticleBurst
          centerX={540}
          centerY={780}
          count={25}
          startFrame={95}
          duration={40}
          radius={400}
          colors={["#eeccff", "#b366ff", "#ffd700"]}
          sizes={[3, 10]}
          shape="square"
        />
      )}

      {/* Vignette */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "radial-gradient(ellipse at center, transparent 30%, rgba(0,0,0,0.6) 100%)",
          pointerEvents: "none",
        }}
      />
      </div>
    </AbsoluteFill>
  );
};
