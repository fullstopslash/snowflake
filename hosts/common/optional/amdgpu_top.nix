{ pkgs, ... }:
{
  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      amdgpu_top
      ;
    inherit (pkgs.nvtopPackages)
      amd
      intel
      #nvidia
      ;
  };

}
