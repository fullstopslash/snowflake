{ ... }:
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ]; # Apply to all keyboards
      settings = {
        main = {
          capslock = "noop"; # TODO(keyboard): should change this to be overload(\, |) to match moonlander
          numlock = "noop"; # numlock state on by default via hyprland config
        };
      };
    };
  };
}
