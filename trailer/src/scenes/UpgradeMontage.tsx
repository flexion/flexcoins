import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Orbitron";
import { GlowText } from "../components/GlowText";
import { ProgressBar } from "../components/ProgressBar";

const { fontFamily: orbitronFamily } = loadFont();

interface UpgradeItem {
  id: string;
  label: string;
  icon: string;
  color: string;
  startFrame: number;
  progress: number;
}

const upgrades: UpgradeItem[] = [
  { id: "spawn", label: "SPAWN RATE", icon: ">>", color: "#44aaff", startFrame: 8, progress: 0.7 },
  { id: "value", label: "COIN VALUE", icon: "$", color: "#ffd700", startFrame: 28, progress: 0.55 },
  { id: "speed", label: "CATCHER SPEED", icon: ">>", color: "#44ff88", startFrame: 48, progress: 0.8 },
  { id: "width", label: "CATCHER WIDTH", icon: "<>", color: "#ff8844", startFrame: 68, progress: 0.65 },
  { id: "magnet", label: "MAGNET", icon: "U", color: "#b366ff", startFrame: 88, progress: 0.4 },
];

export const UpgradeMontage: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Header animation
  const headerScale = spring({
    frame: frame - 2,
    fps,
    config: { damping: 10, stiffness: 150, mass: 0.8 },
  });

  const headerOpacity = interpolate(frame, [0, 10], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0e27" }}>
      {/* Background glow */}
      <div
        style={{
          position: "absolute",
          left: 540,
          top: 960,
          transform: "translate(-50%, -50%)",
          width: 1200,
          height: 1200,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(68,170,255,0.06) 0%, rgba(179,102,255,0.03) 40%, transparent 70%)",
        }}
      />

      {/* Header */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 260,
          textAlign: "center",
          transform: `scale(${headerScale})`,
          opacity: headerOpacity,
        }}
      >
        <GlowText fontSize={72} color="#ffffff" glowColor="#4488ff">
          UPGRADES
        </GlowText>
        <div
          style={{
            marginTop: 16,
            width: 200,
            height: 3,
            background: "linear-gradient(90deg, transparent, #4488ff, transparent)",
            margin: "16px auto 0",
          }}
        />
      </div>

      {/* Upgrade items */}
      {upgrades.map((upgrade, index) => {
        const localFrame = frame - upgrade.startFrame;
        const isVisible = localFrame >= 0;

        const slideX = isVisible
          ? spring({
              frame: localFrame,
              fps,
              config: { damping: 12, stiffness: 120, mass: 0.7 },
            })
          : 0;

        const itemOpacity = isVisible
          ? interpolate(localFrame, [0, 8], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })
          : 0;

        const glowIntensity = isVisible
          ? interpolate(localFrame, [0, 8, 18, 30], [0, 1, 0.5, 0.3], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })
          : 0;

        // Level counter
        const level = isVisible
          ? Math.floor(
              interpolate(localFrame, [5, 30], [0, Math.floor(upgrade.progress * 30)], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              })
            )
          : 0;

        const yPos = 430 + index * 210;

        return (
          <div
            key={upgrade.id}
            style={{
              position: "absolute",
              left: interpolate(slideX, [0, 1], [-600, 80], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }),
              top: yPos,
              opacity: itemOpacity,
              width: 920,
            }}
          >
            {/* Glow background */}
            <div
              style={{
                position: "absolute",
                inset: -10,
                borderRadius: 20,
                backgroundColor: upgrade.color,
                opacity: glowIntensity * 0.08,
                filter: "blur(20px)",
              }}
            />

            {/* Card */}
            <div
              style={{
                background: "rgba(255,255,255,0.04)",
                borderRadius: 16,
                border: `1px solid ${upgrade.color}33`,
                padding: "24px 32px",
                display: "flex",
                flexDirection: "column",
                gap: 14,
              }}
            >
              {/* Top row: icon + label + level */}
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
                  <div
                    style={{
                      width: 44,
                      height: 44,
                      borderRadius: 10,
                      background: `${upgrade.color}22`,
                      border: `2px solid ${upgrade.color}66`,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      color: upgrade.color,
                      fontSize: 22,
                      fontWeight: 900,
                      fontFamily: orbitronFamily,
                    }}
                  >
                    {upgrade.icon}
                  </div>
                  <span
                    style={{
                      color: upgrade.color,
                      fontSize: 34,
                      fontWeight: 700,
                      fontFamily: orbitronFamily,
                      textShadow: `0 0 10px ${upgrade.color}44`,
                    }}
                  >
                    {upgrade.label}
                  </span>
                </div>
                <span
                  style={{
                    color: "#ffffff",
                    fontSize: 30,
                    fontWeight: 600,
                    fontFamily: orbitronFamily,
                    opacity: 0.8,
                  }}
                >
                  Lv.{level}
                </span>
              </div>

              {/* Progress bar */}
              <div style={{ position: "relative", height: 20 }}>
                <ProgressBar
                  x={0}
                  y={0}
                  width={856}
                  height={18}
                  progress={upgrade.progress}
                  color={upgrade.color}
                  startFrame={upgrade.startFrame + 5}
                  animDuration={25}
                />
              </div>
            </div>
          </div>
        );
      })}

      {/* Floating particles */}
      {Array.from({ length: 15 }, (_, i) => {
        const seed = (i * 137.508) % 1;
        const px = seed * 1080;
        const baseY = ((i * 233.3) % 1) * 1920;
        const py = baseY + Math.sin(frame * 0.04 + i * 2) * 30;
        const pOpacity = interpolate(
          (frame * 0.02 + i * 0.4) % 2,
          [0, 0.5, 1.5, 2],
          [0, 0.2, 0.2, 0],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
        );
        const color = upgrades[i % upgrades.length].color;

        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: px,
              top: py,
              width: 4,
              height: 4,
              borderRadius: "50%",
              backgroundColor: color,
              opacity: pOpacity,
              boxShadow: `0 0 6px ${color}66`,
            }}
          />
        );
      })}

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
