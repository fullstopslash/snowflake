# Syncall - bi-directional sync between task managers
# https://github.com/bergercookie/syncall
{
  lib,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
}:
let
  # Pin bidict to 0.21.4 - syncall requires <0.22 due to API changes
  bidict-pinned = python3Packages.buildPythonPackage rec {
    pname = "bidict";
    version = "0.21.4";
    format = "setuptools";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-QshP++b43omK9gc7S+nqfM7c1400dKqETFTknVoHn28=";
    };

    # No dependencies for bidict
    propagatedBuildInputs = [ ];

    pythonImportsCheck = [ "bidict" ];

    # Skip tests - they require pytest plugins not available
    doCheck = false;

    meta = {
      description = "Bidirectional mapping library";
      homepage = "https://github.com/jab/bidict";
      license = lib.licenses.mpl20;
    };
  };
  # bubop - utility functions library (not in nixpkgs)
  bubop = python3Packages.buildPythonPackage rec {
    pname = "bubop";
    version = "0.1.12";
    format = "pyproject";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-i+z1APhb7rgW1v+zzmHzWaucTnMAfC9NQiSlIuMzUIs=";
    };

    nativeBuildInputs = with python3Packages; [
      poetry-core
      pythonRelaxDepsHook
    ];

    # Relax strict version constraints (nixpkgs has newer versions)
    pythonRelaxDeps = [
      "pyyaml"
      "loguru"
    ];

    propagatedBuildInputs = with python3Packages; [
      loguru
      tqdm
      python-dateutil
      pyyaml
      click
    ];

    pythonImportsCheck = [ "bubop" ];

    meta = {
      description = "Apopse's shared Python utility functions";
      homepage = "https://github.com/bergercookie/bubop";
      license = lib.licenses.mit;
    };
  };

  # item-synchronizer - synchronization framework (not in nixpkgs)
  item-synchronizer = python3Packages.buildPythonPackage rec {
    pname = "item-synchronizer";
    version = "1.1.5";
    format = "pyproject";

    src = fetchPypi {
      pname = "item_synchronizer";
      inherit version;
      hash = "sha256-lKpALH6ET9Tp2jTKnJwvXv1Vdl5IlFKCpg8mYDG1ID4=";
    };

    nativeBuildInputs = with python3Packages; [
      poetry-core
      pythonRelaxDepsHook
    ];

    # Relax strict version constraints (nixpkgs has newer versions)
    pythonRelaxDeps = [
      "bidict"
      "bubop"
    ];

    propagatedBuildInputs = with python3Packages; [
      bidict-pinned
      bubop
    ];

    pythonImportsCheck = [ "item_synchronizer" ];

    meta = {
      description = "Synchronization framework for arbitrary items";
      homepage = "https://github.com/bergercookie/item_synchronizer";
      license = lib.licenses.mit;
    };
  };

  # taskw-ng - TaskWarrior Python bindings (not in nixpkgs)
  taskw-ng = python3Packages.buildPythonPackage rec {
    pname = "taskw-ng";
    version = "0.2.6";
    format = "pyproject";

    src = fetchPypi {
      pname = "taskw_ng";
      inherit version;
      hash = "sha256-5tMinG+Gp1YiqmaubBjLcH95dmG2q/A3+GdET2riPvw=";
    };

    nativeBuildInputs = with python3Packages; [
      poetry-core
      poetry-dynamic-versioning
      pythonRelaxDepsHook
    ];

    # Relax strict version constraints (nixpkgs has newer versions)
    pythonRelaxDeps = [
      "packaging"
      "pytz"
    ];

    propagatedBuildInputs = with python3Packages; [
      kitchen
      pytz
      python-dateutil
      packaging
    ];

    # Tests require taskwarrior to be installed
    doCheck = false;

    # Import check disabled - requires taskwarrior to be installed
    pythonImportsCheck = [ ];

    meta = {
      description = "Python bindings for TaskWarrior";
      homepage = "https://github.com/bergercookie/taskw-ng";
      license = lib.licenses.mit;
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "syncall";
  version = "1.8.4";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "bergercookie";
    repo = "syncall";
    rev = "v${version}";
    hash = "sha256-Si2nhlwJ6s7u+lJhhVXv3p4+36LOhvzmHg1zPETjDMk=";
  };

  # Patch to include "tags" in change detection comparison
  # Without this, tag changes aren't detected and won't sync
  postPatch = ''
    substituteInPlace syncall/taskwarrior/taskwarrior_side.py \
      --replace '"uuid",' '"uuid", "tags",'
  '';

  nativeBuildInputs = with python3Packages; [
    poetry-core
    poetry-dynamic-versioning
    pythonRelaxDepsHook
  ];

  # Relax strict version constraints for nixpkgs compatibility
  pythonRelaxDeps = true;

  # Remove typing - it's built into Python 3.5+
  pythonRemoveDeps = [ "typing" ];

  propagatedBuildInputs = with python3Packages; [
    # Core dependencies
    pyyaml
    bidict-pinned  # Must use 0.21.x - newer versions have incompatible serialization
    click
    loguru
    python-dateutil
    rfc3339
    setuptools

    # Custom packages (not in nixpkgs)
    item-synchronizer
    bubop

    # TaskWarrior support
    taskw-ng
    xdg

    # CalDAV support
    caldav
    icalendar
  ];

  # Disable tests - they require network access and various services
  doCheck = false;

  pythonImportsCheck = [ "syncall" ];

  # Allow duplicate bidict versions - caldav uses 0.23.1 but syncall needs 0.21.x API
  catchConflicts = false;

  meta = {
    description = "Bi-directional sync between task managers (Taskwarrior, CalDAV, etc.)";
    homepage = "https://github.com/bergercookie/syncall";
    license = lib.licenses.mit;
    mainProgram = "tw_caldav_sync";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
