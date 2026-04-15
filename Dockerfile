# 1. Start with a fresh Arch Linux environment
FROM archlinux:latest AS builder

# 2. Update and install the necessary build tools
RUN pacman -Syu --noconfirm base-devel git sudo

# 3. Arch Linux refuses to build packages as root, so we create a standard user
RUN useradd -m builduser && echo "builduser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builduser
USER builduser
WORKDIR /home/builduser

# 4. Download the Helium Browser source code from the AUR
RUN git clone https://aur.archlinux.org/helium-browser.git
WORKDIR /home/builduser/helium-browser
RUN sed -i '/package()/a \ \ mkdir -p "$pkgdir/usr/bin"' PKGBUILD

# 5. THE OPTIMIZATION INJECTION (x86-64-v3 + O3)
# Append custom flags to the bottom of the config to override the defaults
RUN echo 'CFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt -fexceptions"' | sudo tee -a /etc/makepkg.conf
RUN echo 'CXXFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt -fexceptions"' | sudo tee -a /etc/makepkg.conf

# 6. Start the compile
RUN makepkg -s --noconfirm

# 7. Extract only the finished package back to your local PC
FROM scratch AS export
COPY --from=builder /home/builduser/helium-browser/*.pkg.tar.zst /
