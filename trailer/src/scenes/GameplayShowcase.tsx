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
import { FallingCoin } from "../components/FallingCoin";
import { Catcher } from "../components/Catcher";
import { FloatingText } from "../components/FloatingText";

const { fontFamily: orbitronFamily } = loadOrbitron();
const { fontFamily: interFamily } = loadInter();

interface CoinDef {
  id: number;
  x: number;
  startFrame: number;
  duration: number;
  type: "silver" | "gold" | "frenzy" | "bomb";
  size: number;
}

const COIN_GLOWS: Record<string, string> = {
  silver: "#e0e0e0",
  gold: "#ffd700",
  frenzy: "#22ff66",
  bomb: "#ff2222",
};

export const GameplayShowcase: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Generate coins to fall
  const coins: CoinDef[] = [
    { id: 0, x: 200, startFrame: 0, duration: 80, type: "silver", size: 56 },
    { id: 1, x: 500, startFrame: 5, duration: 80, type: "silver", size: 56 },
    { id: 2, x: 800, startFrame: 10, duration: 80, type: "gold", size: 64 },
    { id: 3, x: 350, startFrame: 15, duration: 80, type: "silver", size: 56 },
    { id: 4, x: 650, startFrame: 20, duration: 85, type: "frenzy", size: 60 },
    { id: 5, x: 150, startFrame: 25, duration: 80, type: "silver", size: 56 },
    { id: 6, x: 900, startFrame: 30, duration: 80, type: "gold", size: 64 },
    { id: 7, x: 450, startFrame: 35, duration: 80, type: "silver", size: 56 },
    { id: 8, x: 270, startFrame: 40, duration: 80, type: "bomb", size: 58 },
    { id: 9, x: 700, startFrame: 45, duration: 80, type: "silver", size: 56 },
    { id: 10, x: 540, startFrame: 50, duration: 80, type: "gold", size: 64 },
    { id: 11, x: 100, startFrame: 55, duration: 80, type: "silver", size: 56 },
    { id: 12, x: 380, startFrame: 60, duration: 80, type: "silver", size: 56 },
    { id: 13, x: 780, startFrame: 65, duration: 80, type: "frenzy", size: 60 },
    { id: 14, x: 600, startFrame: 70, duration: 80, type: "silver", size: 56 },
    { id: 15, x: 300, startFrame: 75, duration: 80, type: "gold", size: 64 },
    { id: 16, x: 480, startFrame: 80, duration: 80, type: "silver", size: 56 },
    { id: 17, x: 850, startFrame: 85, duration: 80, type: "silver", size: 56 },
    { id: 18, x: 200, startFrame: 90, duration: 80, type: "bomb", size: 58 },
    { id: 19, x: 660, startFrame: 95, duration: 80, type: "gold", size: 64 },
    { id: 20, x: 420, startFrame: 100, duration: 80, type: "silver", size: 56 },
    { id: 21, x: 150, startFrame: 108, duration: 80, type: "silver", size: 56 },
    { id: 22, x: 750, startFrame: 112, duration: 80, type: "silver", size: 56 },
    { id: 23, x: 540, startFrame: 120, duration: 80, type: "gold", size: 64 },
  ];

  // Catcher movement (keyframed positions simulating real gameplay)
  const catcherX = interpolate(
    frame,
    [0, 15, 30, 45, 60, 80, 100, 120, 140, 160, 180],
    [540, 300, 300, 700, 700, 200, 540, 800, 400, 540, 540],
    { extrapolateRight: "clamp", extrapolateLeft: "clamp" }
  );
  const catcherY = 1650;

  // Currency counter
  const currency = Math.floor(
    interpolate(frame, [30, 180], [0, 2847], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })
  );

  // Floating text events - triggered at specific catch moments
  const floatingTexts = [
    { text: "+5", x: 400, y: 1600, startFrame: 40, color: "#ffd700" },
    { text: "+1", x: 550, y: 1610, startFrame: 55, color: "#ffffff" },
    { text: "+5", x: 700, y: 1590, startFrame: 70, color: "#ffd700" },
    { text: "+10", x: 350, y: 1605, startFrame: 85, color: "#ffaa00", },
    { text: "COMBO x3!", x: 540, y: 1550, startFrame: 92, color: "#ff8800" },
    { text: "+1", x: 600, y: 1600, startFrame: 105, color: "#ffffff" },
    { text: "+5", x: 300, y: 1610, startFrame: 118, color: "#ffd700" },
    { text: "+25", x: 540, y: 1580, startFrame: 130, color: "#ffcc00" },
    { text: "COMBO x5!", x: 540, y: 1530, startFrame: 138, color: "#ff4400" },
    { text: "+1", x: 750, y: 1600, startFrame: 148, color: "#ffffff" },
    { text: "+10", x: 450, y: 1590, startFrame: 158, color: "#ffaa00" },
  ];

  // Scene fade in
  const fadeIn = interpolate(frame, [0, 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Combo meter
  const comboValue = frame >= 92 && frame < 138 ? 3 : frame >= 138 ? 5 : 1;
  const getComboSpring = (triggerFrame: number) => {
    if (frame < triggerFrame || frame > triggerFrame + 15) return 0;
    return spring({ frame: frame - triggerFrame, fps, config: { damping: 6, stiffness: 200 } });
  };
  const comboScale = 1 + getComboSpring(92) * 0.3 + getComboSpring(138) * 0.3;

  // HUD panel background
  const hudOpacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0e27", opacity: fadeIn }}>
      {/* Subtle grid background */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "linear-gradient(rgba(255,215,0,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,215,0,0.03) 1px, transparent 1px)",
          backgroundSize: "60px 60px",
        }}
      />

      {/* Falling coins */}
      {coins.map((coin) => (
        <FallingCoin
          key={coin.id}
          startFrame={coin.startFrame}
          startX={coin.x}
          startY={-80}
          endY={1800}
          duration={coin.duration}
          size={coin.size}
          glowColor={COIN_GLOWS[coin.type]}
        />
      ))}

      {/* Catcher */}
      {(() => {
        const squishFrames = [40, 55, 70, 85, 105, 118, 130, 148, 158];
        const activeSquish = squishFrames.find((sf) => frame >= sf && frame < sf + 15);
        const catcherTier: 0 | 1 | 2 = frame < 60 ? 0 : frame < 120 ? 1 : 2;
        return (
          <Catcher
            x={catcherX}
            y={catcherY}
            width={180}
            height={26}
            tier={catcherTier}
            squish={activeSquish !== undefined}
            squishFrame={activeSquish ?? 0}
          />
        );
      })()}

      {/* Floating text */}
      {floatingTexts.map((ft, i) => (
        <FloatingText
          key={i}
          text={ft.text}
          x={ft.x}
          y={ft.y}
          startFrame={ft.startFrame}
          duration={28}
          color={ft.color}
          fontSize={ft.text.includes("COMBO") ? 44 : 38}
        />
      ))}

      {/* HUD - Currency counter */}
      <div
        style={{
          position: "absolute",
          left: 40,
          top: 60,
          opacity: hudOpacity,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 16,
          }}
        >
          <div
            style={{
              width: 48,
              height: 48,
              filter: "drop-shadow(0 0 8px #ffd700)",
            }}
          >
            <Img
              src={staticFile("flexcoin.png")}
              style={{ width: 48, height: 48, objectFit: "contain" }}
            />
          </div>
          <span
            style={{
              color: "#ffd700",
              fontSize: 52,
              fontWeight: 700,
              fontFamily: orbitronFamily,
              textShadow: "0 0 15px #ffd70066",
            }}
          >
            {currency.toLocaleString()}
          </span>
        </div>
      </div>

      {/* Combo indicator */}
      {comboValue > 1 && (
        <div
          style={{
            position: "absolute",
            right: 50,
            top: 65,
            opacity: hudOpacity,
            transform: `scale(${comboScale})`,
          }}
        >
          <span
            style={{
              color: comboValue >= 5 ? "#ff4400" : "#ff8800",
              fontSize: 42,
              fontWeight: 900,
              fontFamily: orbitronFamily,
              textShadow: `0 0 15px ${comboValue >= 5 ? "#ff440088" : "#ff880088"}`,
            }}
          >
            x{comboValue}
          </span>
        </div>
      )}

      {/* Coin type legend (bottom-left) */}
      <div
        style={{
          position: "absolute",
          left: 40,
          bottom: 160,
          display: "flex",
          flexDirection: "column",
          gap: 12,
          opacity: interpolate(frame, [60, 80], [0, 0.7], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        {[
          { label: "Silver", color: "#c0c0c0" },
          { label: "Gold x5", color: "#ffd700" },
          { label: "Frenzy", color: "#44ff88" },
          { label: "Bomb", color: "#ff4444" },
        ].map((t) => (
          <div key={t.label} style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div
              style={{
                width: 14,
                height: 14,
                borderRadius: "50%",
                backgroundColor: t.color,
                boxShadow: `0 0 8px ${t.color}88`,
              }}
            />
            <span
              style={{
                color: t.color,
                fontSize: 22,
                fontFamily: interFamily,
                fontWeight: 600,
              }}
            >
              {t.label}
            </span>
          </div>
        ))}
      </div>

      {/* Vignette */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.5) 100%)",
          pointerEvents: "none",
        }}
      />
    </AbsoluteFill>
  );
};
