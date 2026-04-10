import React from "react";
import { useCurrentFrame, interpolate, spring, useVideoConfig } from "remotion";
import { loadFont } from "@remotion/google-fonts/Orbitron";

const { fontFamily: orbitronFamily } = loadFont();

interface FloatingTextProps {
  text: string;
  x: number;
  y: number;
  startFrame: number;
  duration?: number;
  color?: string;
  fontSize?: number;
}

export const FloatingText: React.FC<FloatingTextProps> = ({
  text,
  x,
  y,
  startFrame,
  duration = 25,
  color = "#ffd700",
  fontSize = 36,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const localFrame = frame - startFrame;

  if (localFrame < 0 || localFrame > duration) return null;

  const offsetY = interpolate(localFrame, [0, duration], [0, -80], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const opacity = interpolate(
    localFrame,
    [0, 4, duration - 8, duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  const scale = spring({
    frame: localFrame,
    fps,
    config: { damping: 8, stiffness: 200, mass: 0.5 },
  });

  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y + offsetY,
        opacity,
        transform: `scale(${scale}) translateX(-50%)`,
        color,
        fontSize,
        fontWeight: 700,
        fontFamily: orbitronFamily,
        textShadow: `0 0 10px ${color}, 0 0 20px ${color}88`,
        pointerEvents: "none",
        whiteSpace: "nowrap",
      }}
    >
      {text}
    </div>
  );
};
