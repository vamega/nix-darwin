{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.security.pam;
in
{
  options = {
    security.pam = {
      enableSudoTouchIdAuth = mkEnableOption ''
        Enable sudo authentication with Touch ID

        When enabled, this option adds the following line to /etc/pam.d/sudo:

            auth       sufficient     pam_tid.so

        (Note that macOS resets this file when doing a system update. As such, sudo
        authentication with Touch ID won't work after a system update until the nix-darwin
        configuration is reapplied.)
      '';
      enablePamReattach = mkEnableOption ''
        Enable re-attaching a program to the user's bootstrap session.

        This allows programs like tmux and screen that run in the background to
        survive across user sessions to work with PAM services that are tied to the
        bootstrap session.

        When enabled, this option adds the following line to /etc/pam.d/sudo:

            auth       optional       /path/in/nix/store/lib/pam/pam_reattach.so"

        (Note that macOS resets this file when doing a system update. As such, sudo
        authentication with Touch ID won't work after a system update until the nix-darwin
        configuration is reapplied.)
      '';
      sudoPamFile = mkOption {
        type = types.path;
        default = "/etc/pam.d/sudo";
        description = ''
          Defines the path to the sudo file inside pam.d directory.
        '';
      };
    };
  };

  config =
    let
      anyEnabled = cfg.enableSudoTouchIdAuth || cfg.enablePamReattach;
    in
    {
      environment.systemPackages = optional anyEnabled pkgs.pam-reattach;

      environment.pathsToLink = optional anyEnabled "/lib/pam";

      system.patches =
        optional anyEnabled
          (
            let
              newLineCount = toString (
                4 + (count (x: x) [ cfg.enableSudoTouchIdAuth cfg.enablePamReattach ])
              );
              reattachLine = (
                if cfg.enablePamReattach
                then "\n+auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so"
                else ""
              );
              touchIdLine = (
                if cfg.enableSudoTouchIdAuth
                then "\n+auth       sufficient     pam_tid.so"
                else ""
              );
            in
            pkgs.writeText "pam.patch" (
              ''
                --- a/etc/pam.d/sudo
                +++ b/etc/pam.d/sudo
                @@ -1,4 +1,${newLineCount} @@
                 # sudo: auth account password session${reattachLine}${touchIdLine}
                 auth       sufficient     pam_smartcard.so
                 auth       required       pam_opendirectory.so
                 account    required       pam_permit.so
              ''
            )
          );
    };
}
