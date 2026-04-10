import React from "react";
import { Composition } from "remotion";
import { Trailer } from "./Trailer";
import "./style.css";

export const Root: React.FC = () => {
  return (
    <Composition
      id="FlexCoinsTrailer"
      component={Trailer}
      durationInFrames={900}
      fps={30}
      width={1080}
      height={1920}
    />
  );
};
