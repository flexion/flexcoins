import React from "react";
import { useCurrentFrame, interpolate } from "remotion";

interface ParticleProps {
  startFrame: number;
  duration: number;
  startX: number;
  startY: number;
  endX: number;
  endY: number;
  size?: number;
  color?: string;
  shape?: "circle" | "star" | "square";
  fadeIn?: number;
  fadeOut?: number;
}

export const Particle: React.FC<ParticleProps> = ({
  startFrame,
  duration,
  startX,
  startY,
  endX,
  endY,
  size = 8,
  color = "#ffd700",
  shape = "circle",
  fadeIn = 5,
  fadeOut = 10,
}) => {
  const frame = useCurrentFrame();
  const localFrame = frame - startFrame;

  if (localFrame < 0 || localFrame > duration) return null;

  const progress = interpolate(localFrame, [0, duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const x = interpolate(progress, [0, 1], [startX, endX], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const y = interpolate(progress, [0, 1], [startY, endY], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const opacity = interpolate(
    localFrame,
    [0, fadeIn, duration - fadeOut, duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  const scale = interpolate(progress, [0, 0.3, 1], [0.2, 1, 0.3], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const borderRadius = shape === "circle" ? "50%" : shape === "star" ? "2px" : "0%";
  const rotation = shape === "star" ? progress * 360 : 0;

  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: size,
        height: size,
        backgroundColor: color,
        borderRadius,
        opacity,
        transform: `scale(${scale}) rotate(${rotation}deg)`,
        boxShadow: `0 0 ${size}px ${color}, 0 0 ${size * 2}px ${color}66`,
        pointerEvents: "none",
      }}
    />
  );
};

interface ParticleBurstProps {
  centerX: number;
  centerY: number;
  count: number;
  startFrame: number;
  duration?: number;
  radius?: number;
  colors?: string[];
  sizes?: [number, number];
  shape?: "circle" | "star" | "square";
}

export const ParticleBurst: React.FC<ParticleBurstProps> = ({
  centerX,
  centerY,
  count,
  startFrame,
  duration = 30,
  radius = 300,
  colors = ["#ffd700", "#ffaa00", "#fff", "#ffcc44"],
  sizes = [4, 12],
  shape = "circle",
}) => {
  const particles = Array.from({ length: count }, (_, i) => {
    const angle = (i / count) * Math.PI * 2 + (i * 0.37);
    const dist = radius * (0.4 + ((i * 137.508) % 1) * 0.6);
    const seed = (i * 137.508) % 1;
    return {
      key: i,
      endX: centerX + Math.cos(angle) * dist,
      endY: centerY + Math.sin(angle) * dist,
      size: sizes[0] + seed * (sizes[1] - sizes[0]),
      color: colors[i % colors.length],
      delay: Math.floor(seed * 5),
    };
  });

  return (
    <>
      {particles.map((p) => (
        <Particle
          key={p.key}
          startFrame={startFrame + p.delay}
          duration={duration}
          startX={centerX}
          startY={centerY}
          endX={p.endX}
          endY={p.endY}
          size={p.size}
          color={p.color}
          shape={shape}
        />
      ))}
    </>
  );
};
