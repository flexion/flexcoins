/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: "flexcoins",
      removal: input?.stage === "production" ? "retain" : "remove",
      home: "aws",
      providers: {
        aws: {
          region: "us-east-1",
        },
      },
    };
  },
  async run() {
    // Godot 4.x web exports require these headers for SharedArrayBuffer (threading)
    const headers = new aws.cloudfront.ResponseHeadersPolicy("GodotHeaders", {
      name: $interpolate`flexcoins-${$app.stage}-godot-headers`,
      customHeadersConfig: {
        items: [
          {
            header: "Cross-Origin-Opener-Policy",
            value: "same-origin",
            override: true,
          },
          {
            header: "Cross-Origin-Embedder-Policy",
            value: "require-corp",
            override: true,
          },
        ],
      },
    });

    const site = new sst.aws.StaticSite("FlexCoins", {
      path: "build/web",
      transform: {
        cdn: (args: any) => {
          args.defaultCacheBehavior.responseHeadersPolicyId = headers.id;
        },
      },
    });

    return {
      url: site.url,
    };
  },
});
