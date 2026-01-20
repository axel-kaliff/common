FROM docker.io/library/alpine:latest AS build

COPY --from=ghcr.io/ublue-os/bluefin-wallpapers-gnome:latest / /out/bluefin/usr/share

RUN apk add just curl

# artwork repo points to ~/.local/share for metadata
RUN mkdir -p /out/bluefin/usr/share/backgrounds/bluefin && \
  mv /out/bluefin/usr/share/*.jxl /out/bluefin/usr/share/*.xml /out/bluefin/usr/share/backgrounds/bluefin && \
  sed -i 's|~\/\.local\/share|\/usr\/share|' /out/bluefin/usr/share/backgrounds/bluefin/*.xml /out/bluefin/usr/share/gnome-background-properties/*.xml

RUN install -d /out/shared/usr/share/bash-completion/completions /out/shared/usr/share/zsh/site-functions /out/shared/usr/share/fish/vendor_completions.d/ && \
  just --completions bash | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/bash-completion/completions/ujust && \
  just --completions zsh | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/zsh/site-functions/_ujust && \
  just --completions fish | sed -E 's/([\(_" ])just/\1ujust/g' > /out/shared/usr/share/fish/vendor_completions.d/ujust.fish

RUN curl -fsSLo - https://codeberg.org/fabiscafe/game-devices-udev/archive/0.25.tar.gz | tar xzvf - -C /tmp/ && \
  install -Dpm0644 -t /out/shared/usr/lib/udev/rules.d/ /tmp/game-devices-udev/*.rules && \
  curl -fsSLo /out/shared/usr/lib/udev/rules.d/70-u2f.rules https://raw.githubusercontent.com/Yubico/libfido2/refs/heads/main/udev/70-u2f.rules

# Create extensions directory for sysext
RUN mkdir -p /out/shared/usr/lib/extensions

FROM scratch AS ctx
COPY /system_files/shared /system_files/shared/
COPY /bluefin-branding/system_files /system_files/bluefin
COPY /system_files/bluefin /system_files/bluefin

COPY --from=build /out/shared /system_files/shared
COPY --from=build /out/bluefin /system_files/bluefin

# Copy containerd sysext (amd64 - adjust if you need multi-arch in the common image itself)
# The sysext-artifacts directory is created by the GitHub Actions workflow
COPY sysext-artifacts/amd64/containerd.raw /system_files/shared/usr/lib/extensions/containerd.raw

