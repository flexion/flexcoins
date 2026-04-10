import React from "react";
import { loadFont } from "@remotion/google-fonts/Orbitron";

const { fontFamily: orbitronFamily } = loadFont();

interface GlowTextProps {
  children: React.ReactNode;
  color?: string;
  glowColor?: string;
  fontSize?: number;
  fontWeight?: number;
  style?: React.CSSProperties;
}

export const GlowText: React.FC<GlowTextProps> = ({
  children,
  color = "#ffd700",
  glowColor,
  fontSize = 72,
  fontWeight = 900,
  style = {},
}) => {
  const glow = glowColor || color;
  return (
    <div
      style={{
        color,
        fontSize,
        fontWeight,
        fontFamily: orbitronFamily,
        textShadow: `0 0 20px ${glow}, 0 0 40px ${glow}, 0 0 80px ${glow}44, 0 0 120px ${glow}22`,
        letterSpacing: "0.05em",
        textAlign: "center",
        ...style,
      }}
    >
      {children}
    </div>
  );
};
