{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  meson,
  ninja,
  wayland-scanner,
  python3,
  wayland,
  gitUpdater,
  testers,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "wayland-protocols";
  version = "1.48";

  doCheck =
    stdenv.hostPlatform == stdenv.buildPlatform
    &&
      # https://gitlab.freedesktop.org/wayland/wayland-protocols/-/issues/48
      stdenv.hostPlatform.linker == "bfd"
    &&
      # Even with bfd linker, the above issue occurs on platforms with stricter linker requirements
      # https://gitlab.freedesktop.org/wayland/wayland-protocols/-/issues/48#note_1453201
      !(stdenv.hostPlatform.isPower64 && stdenv.hostPlatform.isBigEndian)
    && lib.meta.availableOn stdenv.hostPlatform wayland;

  src = fetchurl {
    url = "https://gitlab.freedesktop.org/wayland/${finalAttrs.pname}/-/releases/${finalAttrs.version}/downloads/${finalAttrs.pname}-${finalAttrs.version}.tar.xz";
    hash = "sha256-OYA2rA62SEmC3b3n/4aEjXUyMfnN7q6YPwa1KUZiWqE=";
  };

  postPatch = lib.optionalString finalAttrs.finalPackage.doCheck ''
    patchShebangs tests/
  '';

  depsBuildBuild = [ pkg-config ];
  nativeBuildInputs = [
    meson
    ninja
    wayland-scanner
  ];
  nativeCheckInputs = [
    python3
    wayland
  ];
  checkInputs = [ wayland ];
  strictDeps = true;

  mesonFlags = [ "-Dtests=${lib.boolToString finalAttrs.finalPackage.doCheck}" ];

  # On ppc64le (and other stricter-linker platforms), 12 of the
  # test-build-pedantic-* tests fail at *runtime* with e.g. "symbol lookup
  # error: undefined symbol: xdg_toplevel_interface". These are protocols
  # whose generated -code.c references interfaces defined in another
  # protocol; the test executables link only thanks to
  # -Wl,--unresolved-symbols=ignore-all, so they build but cannot run.
  # Upstream: https://gitlab.freedesktop.org/wayland/wayland-protocols/-/issues/48
  # The protocol files themselves are fine; only these self-tests break.
  # Instead of disabling the whole suite, run every test EXCEPT those 12,
  # so the other 179 (all scan-*, all cxx-*, and the ~52 good pedantic
  # tests) still guard against regressions. meson test only accepts an
  # inclusion list, so we pass the complement of the known-broken set.
  checkPhase =
    lib.optionalString (stdenv.hostPlatform.isPower64 && stdenv.hostPlatform.isLittleEndian) ''
      runHook preCheck
      ninja -j"$NIX_BUILD_CORES" meson-test-prereq
      brokenTests="\
      test-build-pedantic-experimental_xx_keyboard_filter_xx_keyboard_filter_v1_xml
      test-build-pedantic-experimental_xx_session_management_xx_session_management_v1_xml
      test-build-pedantic-experimental_xx_zones_xx_zones_v1_xml
      test-build-pedantic-staging_cursor_shape_cursor_shape_v1_xml
      test-build-pedantic-staging_ext_image_capture_source_ext_image_capture_source_v1_xml
      test-build-pedantic-staging_ext_image_copy_capture_ext_image_copy_capture_v1_xml
      test-build-pedantic-staging_xdg_dialog_xdg_dialog_v1_xml
      test-build-pedantic-staging_xdg_session_management_xdg_session_management_v1_xml
      test-build-pedantic-staging_xdg_toplevel_drag_xdg_toplevel_drag_v1_xml
      test-build-pedantic-staging_xdg_toplevel_icon_xdg_toplevel_icon_v1_xml
      test-build-pedantic-staging_xdg_toplevel_tag_xdg_toplevel_tag_v1_xml
      test-build-pedantic-unstable_xdg_decoration_xdg_decoration_unstable_v1_xml"
      allTests=$(meson test --list | sed 's/^wayland-protocols://' | sort)
      badTests=$(echo "$brokenTests" | sed 's/^[[:space:]]*//' | sort)
      runTests=$(comm -23 <(echo "$allTests") <(echo "$badTests"))
      echo "wayland-protocols: running $(echo "$runTests" | wc -l)/$(echo "$allTests" | wc -l) tests" \
        "(skipping $(echo "$badTests" | wc -l) known-broken pedantic tests on ppc64le, upstream issue 48)"
      meson test --no-rebuild --print-errorlogs $runTests
      runHook postCheck
    '';

  meta = {
    description = "Wayland protocol extensions";
    longDescription = ''
      wayland-protocols contains Wayland protocols that add functionality not
      available in the Wayland core protocol. Such protocols either add
      completely new functionality, or extend the functionality of some other
      protocol either in Wayland core, or some other protocol in
      wayland-protocols.
    '';
    homepage = "https://gitlab.freedesktop.org/wayland/wayland-protocols";
    license = lib.licenses.mit; # Expat version
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ wineee ];
    pkgConfigModules = [ "wayland-protocols" ];
  };

  passthru.updateScript = gitUpdater {
    url = "https://gitlab.freedesktop.org/wayland/wayland-protocols.git";
  };
  passthru.version = finalAttrs.version;
  passthru.tests.pkg-config = testers.hasPkgConfigModules {
    package = finalAttrs.finalPackage;
  };
})
