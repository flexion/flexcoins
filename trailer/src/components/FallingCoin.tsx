import React from "react";
import { useCurrentFrame, interpolate, Img, staticFile } from "remotion";

interface FallingCoinProps {
  startFrame: number;
  startX: number;
  startY?: number;
  endY?: number;
  duration: number;
  size?: number;
  glowColor?: string;
  rotationSpeed?: number;
  delay?: number;
}

export const FallingCoin: React.FC<FallingCoinProps> = ({
  startFrame,
  startX,
  startY = -80,
  endY = 1960,
  duration,
  size = 64,
  glowColor = "#ffd700",
  rotationSpeed = 1,
  delay = 0,
}) => {
  const frame = useCurrentFrame();
  const localFrame = frame - startFrame - delay;

  if (localFrame < 0 || localFrame > duration) return null;

  const y = interpolate(localFrame, [0, duration], [startY, endY], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const rotation = localFrame * rotationSpeed * 4;

  const wobble = Math.sin(localFrame * 0.15) * 15;

  const opacity = interpolate(
    localFrame,
    [0, 8, duration - 15, duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  const pulse = 1 + Math.sin(localFrame * 0.3) * 0.05;

  return (
    <div
      style={{
        position: "absolute",
        left: startX + wobble - size / 2,
        top: y,
        width: size,
        height: size,
        opacity,
        transform: `rotate(${rotation}deg) scale(${pulse})`,
        filter: `drop-shadow(0 0 12px ${glowColor}) drop-shadow(0 0 24px ${glowColor}66)`,
      }}
    >
      <Img
        src={staticFile("flexcoin.png")}
        style={{
          width: size,
          height: size,
          objectFit: "contain",
        }}
      />
    </div>
  );
};

interface SparkleTrailProps {
  x: number;
  y: number;
  color?: string;
  count?: number;
}

export const SparkleTrail: React.FC<SparkleTrailProps> = ({
  x,
  y,
  color = "#ffd700",
  count = 5,
}) => {
  const frame = useCurrentFrame();

  return (
    <>
      {Array.from({ length: count }, (_, i) => {
        const offsetY = -i * 18;
        const offsetX = Math.sin(frame * 0.2 + i * 1.5) * 8;
        const sparkleOpacity = interpolate(
          (frame * 0.15 + i * 0.7) % 1,
          [0, 0.5, 1],
          [0, 1, 0],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
        );
        const sparkleSize = 3 + Math.sin(frame * 0.3 + i) * 2;

        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x + offsetX,
              top: y + offsetY,
              width: sparkleSize,
              height: sparkleSize,
              borderRadius: "50%",
              backgroundColor: color,
              opacity: sparkleOpacity * 0.7,
              boxShadow: `0 0 6px ${color}`,
              pointerEvents: "none",
            }}
          />
        );
      })}
    </>
  );
};
