import React from "react";
import { useCurrentFrame, interpolate } from "remotion";

interface ProgressBarProps {
  x: number;
  y: number;
  width?: number;
  height?: number;
  progress: number;
  color?: string;
  bgColor?: string;
  startFrame?: number;
  animDuration?: number;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({
  x,
  y,
  width = 400,
  height = 16,
  progress,
  color = "#ffd700",
  bgColor = "rgba(255,255,255,0.1)",
  startFrame = 0,
  animDuration = 20,
}) => {
  const frame = useCurrentFrame();
  const localFrame = frame - startFrame;

  const animatedProgress = interpolate(
    localFrame,
    [0, animDuration],
    [0, progress],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width,
        height,
        backgroundColor: bgColor,
        borderRadius: height / 2,
        overflow: "hidden",
        border: "1px solid rgba(255,255,255,0.15)",
      }}
    >
      <div
        style={{
          width: `${animatedProgress * 100}%`,
          height: "100%",
          background: `linear-gradient(90deg, ${color}, ${color}cc)`,
          borderRadius: height / 2,
          boxShadow: `0 0 12px ${color}66`,
          transition: "none",
        }}
      />
    </div>
  );
};
