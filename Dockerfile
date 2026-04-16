# 1. Start with a fresh Arch Linux environment
FROM archlinux:latest AS builder

# 2. Install build tools AND pacman-contrib (required for updating checksums)
RUN pacman -Syu --noconfirm base-devel git sudo pacman-contrib

# 3. Create a standard user (makepkg refuses to run as root)
RUN useradd -m builduser && echo "builduser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builduser
USER builduser
WORKDIR /home/builduser

# 4. Clone the broken 0.10.7.1 AUR package
RUN git clone https://aur.archlinux.org/helium-browser.git
WORKDIR /home/builduser/helium-browser

# 5. THE VERSION BUMP (Update to 0.11.2.1)
# Overwrite the version, reset the release number, and recalculate security checksums
RUN sed -i 's/pkgver=.*/pkgver=0.11.2.1/' PKGBUILD && \
    sed -i 's/pkgrel=.*/pkgrel=1/' PKGBUILD && \
    updpkgsums

# 6. THE FIXES & PGO INJECTIONS
# Apply the Reddit user's proper directory creation fix
RUN sed -i '/package()/a \ \ install -d -m 755 "$pkgdir/usr/bin"' PKGBUILD

# Enable Google's pre-collected PGO profile by injecting the GN flag
RUN sed -i '/build()/a \ \ export GN_ARGS="${GN_ARGS} chrome_pgo_phase=2"' PKGBUILD

# 7. THE HARDWARE OPTIMIZATION INJECTION (x86-64-v3 -O3)
RUN echo 'CFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt -fexceptions"' | sudo tee -a /etc/makepkg.conf
RUN echo 'CXXFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt -fexceptions"' | sudo tee -a /etc/makepkg.conf

# 8. Fire the compile
RUN makepkg -s --noconfirm

# 9. Extract only the finished package back to your local PC
FROM scratch AS export
COPY --from=builder /home/builduser/helium-browser/*.pkg.tar.zst /
