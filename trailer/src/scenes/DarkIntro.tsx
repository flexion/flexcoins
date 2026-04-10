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
import { SparkleTrail } from "../components/FallingCoin";

export const DarkIntro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Background fade in
  const bgOpacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Coin drops from top to center
  const coinY = interpolate(frame, [10, 55], [-100, 900], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Coin bounce when landing
  const bounceY =
    frame >= 55
      ? spring({
          frame: frame - 55,
          fps,
          config: { damping: 6, stiffness: 180, mass: 0.8 },
        })
      : 0;

  const finalCoinY = frame >= 55 ? 900 - bounceY * 40 + 40 : coinY;

  // Coin glow intensifies on landing
  const glowIntensity = interpolate(frame, [50, 65, 80, 90], [0.4, 1, 0.8, 0.6], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Coin rotation while falling
  const rotation = frame < 55 ? frame * 6 : interpolate(frame, [55, 80], [55 * 6, 55 * 6 + 20], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Coin scale: small while falling, springs up on landing
  const coinScale =
    frame >= 55
      ? spring({
          frame: frame - 55,
          fps,
          config: { damping: 8, stiffness: 150, mass: 0.6 },
        }) * 0.5 + 0.8
      : interpolate(frame, [10, 55], [0.6, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });

  // Impact flash
  const flashOpacity = interpolate(frame, [55, 58, 68], [0, 0.4, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Vignette
  const vignetteOpacity = interpolate(frame, [0, 30], [0.8, 0.4], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Ambient particles floating
  const ambientParticles = Array.from({ length: 20 }, (_, i) => {
    const seed = i * 137.508;
    const px = (seed * 7.3) % 1080;
    const baseY = (seed * 3.1) % 1920;
    const py = baseY + Math.sin(frame * 0.03 + i) * 40;
    const pOpacity = interpolate(
      (frame * 0.02 + i * 0.3) % 3,
      [0, 1, 2, 3],
      [0, 0.3, 0.3, 0],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
    );
    const pSize = 2 + (i % 4);
    return { key: i, px, py, pOpacity, pSize };
  });

  // Impact screen shake
  const impactShake = interpolate(frame, [55, 58, 65], [0, 8, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const sx = Math.sin(frame * 2.1) * impactShake;
  const sy = Math.cos(frame * 2.7) * impactShake;

  const coinSize = 120;

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0e27", opacity: bgOpacity }}>
      <div style={{ position: "absolute", inset: 0, transform: `translate(${sx}px, ${sy}px)` }}>
      {/* Vignette overlay */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "radial-gradient(ellipse at center, transparent 30%, rgba(0,0,0,0.7) 100%)",
          opacity: vignetteOpacity,
          pointerEvents: "none",
        }}
      />

      {/* Ambient dust particles */}
      {ambientParticles.map((p) => (
        <div
          key={p.key}
          style={{
            position: "absolute",
            left: p.px,
            top: p.py,
            width: p.pSize,
            height: p.pSize,
            borderRadius: "50%",
            backgroundColor: "#ffd70044",
            opacity: p.pOpacity,
          }}
        />
      ))}

      {/* Light beam from above */}
      {frame >= 10 && (
        <div
          style={{
            position: "absolute",
            left: 540 - 60,
            top: 0,
            width: 120,
            height: finalCoinY + coinSize / 2,
            background:
              "linear-gradient(to bottom, rgba(255,215,0,0.08), rgba(255,215,0,0.02), transparent)",
            opacity: interpolate(frame, [10, 30, 60, 90], [0, 0.6, 0.3, 0.15], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        />
      )}

      {/* The coin */}
      {frame >= 10 && (
        <div
          style={{
            position: "absolute",
            left: 540 - coinSize / 2,
            top: finalCoinY - coinSize / 2,
            width: coinSize,
            height: coinSize,
            transform: `rotate(${rotation}deg) scale(${coinScale})`,
            filter: `drop-shadow(0 0 ${20 * glowIntensity}px #ffd700) drop-shadow(0 0 ${40 * glowIntensity}px #ffaa0088)`,
          }}
        >
          <Img
            src={staticFile("flexcoin.png")}
            style={{
              width: coinSize,
              height: coinSize,
              objectFit: "contain",
            }}
          />
        </div>
      )}

      {/* Sparkle trail behind coin while falling */}
      {frame >= 15 && frame < 55 && (
        <SparkleTrail x={540} y={coinY} count={8} />
      )}

      {/* Impact flash */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundColor: "#ffd700",
          opacity: flashOpacity,
          pointerEvents: "none",
        }}
      />

      {/* Impact ring */}
      {frame >= 55 && frame < 80 && (
        <div
          style={{
            position: "absolute",
            left: 540,
            top: 900,
            transform: "translate(-50%, -50%)",
          }}
        >
          {[0, 1, 2].map((ring) => {
            const ringFrame = frame - 55 - ring * 3;
            if (ringFrame < 0) return null;
            const ringScale = interpolate(ringFrame, [0, 20], [0.2, 3], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            const ringOpacity = interpolate(ringFrame, [0, 5, 20], [0, 0.6, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            return (
              <div
                key={ring}
                style={{
                  position: "absolute",
                  left: -60,
                  top: -60,
                  width: 120,
                  height: 120,
                  borderRadius: "50%",
                  border: "2px solid #ffd700",
                  transform: `scale(${ringScale})`,
                  opacity: ringOpacity,
                  boxShadow: "0 0 15px #ffd70066",
                }}
              />
            );
          })}
        </div>
      )}
      </div>
    </AbsoluteFill>
  );
};
