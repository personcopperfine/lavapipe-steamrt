# Mesa lavapipe (Vulkan software ICD) + the cs2 patch series, built with the steamrt4 toolchain.
#   docker build --build-arg UPSTREAM_REF=mesa-26.3.0 --output type=local,dest=out .
FROM registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk AS build

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install --yes --no-install-recommends --no-install-suggests \
        zlib1g-dev llvm-22-dev \
        python3-mako python3-yaml python3-packaging \
        libx11-xcb-dev libxcb1-dev libxcb-shm0-dev libxcb-randr0-dev \
        libxcb-xfixes0-dev libxcb-sync-dev libxcb-present-dev libxcb-dri3-dev \
        libxshmfence-dev x11proto-dev \
    && rm -rf /var/lib/apt/lists/*

# The base's unversioned llvm-config is LLVM 19 and meson ignores LLVM_CONFIG; pin via native file.
ENV LLVM_CONFIG=llvm-config-22
RUN llvm-config-22 --version && meson --version \
    && printf "[binaries]\nllvm-config = '%s'\n" "$(command -v llvm-config-22)" > /llvm22.ini

ARG LIBDRM_REF=2.4.133
RUN mkdir -p /src \
    && curl -fsSL "https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_REF}.tar.xz" \
        | tar -xJ -C /src \
    && cd "/src/libdrm-${LIBDRM_REF}" \
    && meson setup build -Dprefix=/usr/local -Ddefault_library=static -Dintel=disabled -Damdgpu=disabled -Dfreedreno=disabled -Dvmwgfx=disabled -Detnaviv=disabled -Dexynos=disabled -Domap=disabled \
    && ninja -C build install

ARG UPSTREAM_REF
RUN test -n "$UPSTREAM_REF" \
    && git clone --depth 1 --branch "$UPSTREAM_REF" https://gitlab.freedesktop.org/mesa/mesa.git /src/mesa

COPY patches/ /patches/
RUN cd /src/mesa \
    && for p in /patches/*.patch; do echo "applying $p"; git apply -p1 "$p" || exit 1; done \
    && grep -q 'lvp-cs2-fork-0003:' src/gallium/frontends/lavapipe/lvp_device.c \
       || { echo "FATAL: lvp_device.c lacks the fork-0003 UUID seed"; exit 1; }

RUN cd /src/mesa \
    && meson setup /src/mesa/build --native-file /llvm22.ini \
        -Dvulkan-drivers=swrast \
        -Dgallium-drivers= \
        -Dplatforms=x11 \
        -Dopengl=false \
        -Dglx=disabled \
        -Dgbm=disabled \
        -Dxmlconfig=disabled \
        -Dbuild-tests=false \
        -Dbuildtype=release \
        -Dllvm=enabled \
    && meson compile -C /src/mesa/build \
    && readelf -d /src/mesa/build/src/gallium/targets/lavapipe/libvulkan_lvp.so | grep -q 'libLLVM.so.22'

ARG REVISION=1
RUN T=/src/mesa/build/src/gallium/targets/lavapipe \
    && mkdir -p /out \
    && cp "$T/libvulkan_lvp.so" "$T/lvp_icd.x86_64.json" /out/ \
    && { echo "upstream=https://gitlab.freedesktop.org/mesa/mesa"; \
         echo "tag=$UPSTREAM_REF"; \
         echo "commit=$(git -C /src/mesa rev-parse HEAD)"; \
         echo "revision=$REVISION"; \
         echo "llvm=$(dpkg-query -W -f '${Version}' libllvm22)"; \
         echo "libdrm=$LIBDRM_REF"; \
         echo "steamrt=$(. /etc/os-release && echo "$VERSION_CODENAME $BUILD_ID")"; \
         echo "patches:"; (cd /patches && sha256sum *.patch); \
       } > /out/BUILDINFO \
    && cat /out/BUILDINFO

FROM scratch
COPY --from=build /out/ /
