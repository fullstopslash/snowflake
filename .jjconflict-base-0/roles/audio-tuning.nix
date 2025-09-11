# Audio tuning role (low-latency PipeWire + rtkit)
_: {
  security.rtkit.enable = true;

  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 512;
      "default.clock.min-quantum" = 512;
      "default.clock.max-quantum" = 512;
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
      "pulse.min.req" = "512/48000";
      "pulse.default.req" = "512/48000";
      "pulse.max.req" = "512/48000";
      "pulse.min.quantum" = "512/48000";
      "pulse.max.quantum" = "512/48000";
    };
    "stream.properties" = {
      "node.latency" = "512/48000";
      "resample.quality" = 1;
    };
  };
}
