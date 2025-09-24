# Audio tuning role (low-latency PipeWire + rtkit)
_: {
  security.rtkit.enable = true;

  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 256;
      "default.clock.min-quantum" = 256;
      "default.clock.max-quantum" = 256;
    };
  };

  services.pipewire.extraConfig.pipewire-pulse."92-low-latency" = {
    "context.properties" = [
      {
        name = "libpipewire-module-protocol-pulse";
        args = {};
      }
    ];
    "pulse.properties" = {
      "pulse.min.req" = "256/48000";
      "pulse.default.req" = "256/48000";
      "pulse.max.req" = "256/48000";
      "pulse.min.quantum" = "256/48000";
      "pulse.max.quantum" = "256/48000";
    };
    "stream.properties" = {
      "node.latency" = "256/48000";
      "resample.quality" = 1;
    };
  };
}
