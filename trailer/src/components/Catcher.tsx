import React from "react";
import { useCurrentFrame, interpolate } from "remotion";

interface CatcherProps {
  x: number;
  y: number;
  width?: number;
  height?: number;
  tier?: 0 | 1 | 2 | 3;
  squish?: boolean;
  squishFrame?: number;
}

const tierColors: Record<number, { main: string; stripe: string }> = {
  0: { main: "rgba(74, 143, 217, 1)", stripe: "rgba(100, 170, 240, 0.6)" },
  1: { main: "rgba(140, 89, 43, 1)", stripe: "rgba(166, 115, 64, 0.6)" },
  2: { main: "rgba(179, 184, 191, 1)", stripe: "rgba(255, 255, 255, 0.4)" },
  3: { main: "rainbow", stripe: "rainbow" },
};

export const Catcher: React.FC<CatcherProps> = ({
  x,
  y,
  width = 160,
  height = 24,
  tier = 0,
  squish = false,
  squishFrame = 0,
}) => {
  const frame = useCurrentFrame();
  const localFrame = frame - squishFrame;

  let scaleY = 1;
  let scaleX = 1;
  if (squish && localFrame >= 0 && localFrame < 15) {
    scaleY = interpolate(localFrame, [0, 4, 10, 15], [1, 0.5, 1.15, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    scaleX = interpolate(localFrame, [0, 4, 10, 15], [1, 1.3, 0.9, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  }

  const isRainbow = tier === 3;
  const hue = isRainbow ? (frame * 8) % 360 : 0;
  const mainColor = isRainbow
    ? `hsl(${hue}, 80%, 60%)`
    : tierColors[tier].main;
  const stripeColor = isRainbow
    ? `hsl(${(hue + 108) % 360}, 80%, 70%)`
    : tierColors[tier].stripe;

  return (
    <div
      style={{
        position: "absolute",
        left: x - width / 2,
        top: y,
        width,
        height,
        borderRadius: 6,
        background: mainColor,
        transform: `scaleX(${scaleX}) scaleY(${scaleY})`,
        transformOrigin: "center bottom",
        boxShadow: isRainbow
          ? `0 0 20px hsla(${hue}, 80%, 60%, 1), 0 0 40px hsla(${hue}, 80%, 60%, 0.27)`
          : `0 4px 12px rgba(0,0,0,0.4)`,
        overflow: "hidden",
      }}
    >
      {/* Stripe overlay */}
      <div
        style={{
          position: "absolute",
          top: "40%",
          left: 0,
          right: 0,
          height: "20%",
          backgroundColor: stripeColor,
        }}
      />
      {/* Shine */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          right: 0,
          height: "40%",
          background: "linear-gradient(to bottom, rgba(255,255,255,0.3), transparent)",
          borderRadius: "6px 6px 0 0",
        }}
      />
    </div>
  );
};
