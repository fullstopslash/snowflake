default:
  just -l

fmt:
  alejandra .

lint:
  statix check
  deadnix

check:
  nix flake check

build-iso:
  ./scripts/build-iso.sh

quickemu:
  ./scripts/quickemu-orchestrate.sh

vm-test host="malphas":
  ./scripts/anywhere-vm-test.sh {{host}}

switch host="malphas":
  nh os switch -u -H {{host}}

validate host="malphas":
  ./scripts/config-validate.sh {{host}}

verify host="root@malphas":
  ./scripts/post-deploy-verify.sh {{host}}

deploy host="malphas":
  nix run github:serokell/deploy-rs -- --hostname {{host}}

publish msg="publish" bm="main":
  jj commit -m "{{msg}}"
  jj bookmark set "{{bm}}" -r @
  jj git export --bookmark "{{bm}}"
  jj git push --remote origin

ci:
  just fmt
  just lint
  just check
  just build-iso
  just quickemu
  just vm-test malphas

