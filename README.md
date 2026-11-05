# lavapipe-steamrt

Mesa's lavapipe Vulkan software ICD with the cs2 patch series (`patches/`, see
`patches/README.md`), built inside the Steam Runtime 4 SDK
(`registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk`) against its LLVM 22,
for cs2-docker.

Releases mirror Mesa tags (`mesa-26.3.0`, `mesa-26.3.0-rc3`). rc builds are not
marked prerelease, so `releases/latest` always points at the newest build. A
weekly job builds the newest tag matching `MESA_TRACK` in `track.env` if there
is no release for it yet. Patches that no longer apply
fail the build; that is expected, rebase them and bump `REVISION`. Bumping
`REVISION` rebuilds the same tag and replaces its release.

Asset `lavapipe-x86_64.tar.gz`: `libvulkan_lvp.so`, `lvp_icd.x86_64.json`
(`library_path` = `/usr/local/lib/x86_64-linux-gnu/libvulkan_lvp.so`) and
`BUILDINFO` (tag, commit, revision, libllvm22 version, patch hashes).
`libvulkan_lvp.so` links `libLLVM.so.22` dynamically; install `libllvm22` from
steamrt4 at runtime.

Local build:

```bash
docker build --build-arg UPSTREAM_REF=mesa-26.3.0-rc3 --output type=local,dest=out .
```
