import React from "react";
import { AbsoluteFill, Sequence, useCurrentFrame, interpolate } from "remotion";
import { LightLeak } from "@remotion/light-leaks";
import { DarkIntro } from "./scenes/DarkIntro";
import { TitleReveal } from "./scenes/TitleReveal";
import { GameplayShowcase } from "./scenes/GameplayShowcase";
import { UpgradeMontage } from "./scenes/UpgradeMontage";
import { AscensionClimax } from "./scenes/AscensionClimax";
import { CallToAction } from "./scenes/CallToAction";

/**
 * Scene layout (30fps, 900 frames total):
 * 0-90:    Dark Intro (3s)
 * 90-210:  Title Reveal (4s)
 * 210-390: Gameplay Showcase (6s)
 * 390-540: Upgrade Montage (5s)
 * 540-720: Ascension Climax (6s)
 * 720-900: Call to Action (6s)
 *
 * Cross-fade transitions overlap by 15 frames between scenes.
 */

const TRANSITION_FRAMES = 15;

export const Trailer: React.FC = () => {
  const frame = useCurrentFrame();

  // Cross-fade helper: opacity for outgoing scene at transition boundary
  const crossFade = (sceneEnd: number): number => {
    return interpolate(
      frame,
      [sceneEnd - TRANSITION_FRAMES, sceneEnd],
      [1, 0],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
    );
  };

  // Cross-fade helper: opacity for incoming scene at transition boundary
  const crossFadeIn = (sceneStart: number): number => {
    return interpolate(
      frame,
      [sceneStart, sceneStart + TRANSITION_FRAMES],
      [0, 1],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
    );
  };

  // Outgoing scene zoom scales
  const darkIntroScale = interpolate(frame, [75, 90], [1.0, 1.05], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const titleRevealScale = interpolate(frame, [195, 210], [1.0, 1.05], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const gameplayScale = interpolate(frame, [375, 390], [1.0, 1.05], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const upgradeScale = interpolate(frame, [525, 540], [1.0, 1.05], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const ascensionScale = interpolate(frame, [705, 720], [1.0, 1.05], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  // Beat-sync flash helper
  const beatFlash = (beatFrame: number): number => {
    return interpolate(frame, [beatFrame, beatFrame + 8], [0.3, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  };
  const beatFrames = [90, 210, 390, 540, 720];
  const combinedFlash = beatFrames.reduce((max, bf) => Math.max(max, beatFlash(bf)), 0);

  return (
    <AbsoluteFill style={{ backgroundColor: "#000000" }}>
      {/* Scene 1: Dark Intro */}
      <Sequence from={0} durationInFrames={90 + TRANSITION_FRAMES}>
        <AbsoluteFill style={{ opacity: frame < 90 - TRANSITION_FRAMES ? 1 : crossFade(90), transform: `scale(${darkIntroScale})` }}>
          <DarkIntro />
        </AbsoluteFill>
      </Sequence>

      {/* Scene 2: Title Reveal */}
      <Sequence from={90 - TRANSITION_FRAMES} durationInFrames={120 + TRANSITION_FRAMES * 2}>
        <AbsoluteFill
          style={{
            opacity:
              frame < 90
                ? crossFadeIn(90 - TRANSITION_FRAMES)
                : frame < 210 - TRANSITION_FRAMES
                ? 1
                : crossFade(210),
            transform: `scale(${titleRevealScale})`,
          }}
        >
          <TitleReveal />
        </AbsoluteFill>
      </Sequence>

      {/* Scene 3: Gameplay Showcase */}
      <Sequence from={210 - TRANSITION_FRAMES} durationInFrames={180 + TRANSITION_FRAMES * 2}>
        <AbsoluteFill
          style={{
            opacity:
              frame < 210
                ? crossFadeIn(210 - TRANSITION_FRAMES)
                : frame < 390 - TRANSITION_FRAMES
                ? 1
                : crossFade(390),
            transform: `scale(${gameplayScale})`,
          }}
        >
          <GameplayShowcase />
        </AbsoluteFill>
      </Sequence>

      {/* Scene 4: Upgrade Montage */}
      <Sequence from={390 - TRANSITION_FRAMES} durationInFrames={150 + TRANSITION_FRAMES * 2}>
        <AbsoluteFill
          style={{
            opacity:
              frame < 390
                ? crossFadeIn(390 - TRANSITION_FRAMES)
                : frame < 540 - TRANSITION_FRAMES
                ? 1
                : crossFade(540),
            transform: `scale(${upgradeScale})`,
          }}
        >
          <UpgradeMontage />
        </AbsoluteFill>
      </Sequence>

      {/* Scene 5: Ascension Climax */}
      <Sequence from={540 - TRANSITION_FRAMES} durationInFrames={180 + TRANSITION_FRAMES * 2}>
        <AbsoluteFill
          style={{
            opacity:
              frame < 540
                ? crossFadeIn(540 - TRANSITION_FRAMES)
                : frame < 720 - TRANSITION_FRAMES
                ? 1
                : crossFade(720),
            transform: `scale(${ascensionScale})`,
          }}
        >
          <AscensionClimax />
        </AbsoluteFill>
      </Sequence>

      {/* Scene 6: Call to Action */}
      <Sequence from={720 - TRANSITION_FRAMES} durationInFrames={180 + TRANSITION_FRAMES}>
        <AbsoluteFill
          style={{
            opacity: frame < 720 ? crossFadeIn(720 - TRANSITION_FRAMES) : 1,
          }}
        >
          <CallToAction />
        </AbsoluteFill>
      </Sequence>

      {/* Light leak: TitleReveal -> GameplayShowcase (gold hue) */}
      <Sequence from={195} durationInFrames={45}>
        <LightLeak seed={1} hueShift={40} />
      </Sequence>

      {/* Light leak: UpgradeMontage -> AscensionClimax (purple hue) */}
      <Sequence from={525} durationInFrames={45}>
        <LightLeak seed={2} hueShift={280} />
      </Sequence>

      {/* Beat-sync flash overlay */}
      {combinedFlash > 0 && (
        <AbsoluteFill
          style={{
            backgroundColor: "#ffffff",
            opacity: combinedFlash,
            pointerEvents: "none",
          }}
        />
      )}
    </AbsoluteFill>
  );
};
