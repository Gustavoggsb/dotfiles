#!/usr/bin/env bash

set -euo pipefail

echo_task() {
  printf "\033[0;34m--> %s\033[0m\n" "$@"
}

echo_sub_task() {
  printf "\033[0;34m----> %s\033[0m\n" "$@"
}

is_wsl() {
  if [ -n "${WSL_DISTRO_NAME+x}" ] || [ -n "${IS_WSL+x}" ]; then
    return 0
  else
    return 1
  fi
}

is_devcontainer() {
  # VSCODE_REMOTE_CONTAINERS_SESSION:
  # https://github.com/microsoft/vscode-remote-release/issues/3517#issuecomment-698617749
  if [ -n "${REMOTE_CONTAINERS+x}" ] || [ -n "${CODESPACES+x}" ] || [ -n "${VSCODE_REMOTE_CONTAINERS_SESSION+x}" ]; then
    return 0
  else
    return 1
  fi
}

is_ubuntu() {
  local version=${1-'20.04'}

  if [[ "$(cat /etc/os-release)" = *VERSION_ID=\"$version\"* ]]; then
    return 0
  else
    return 1
  fi
}

is_gnome() {
  # This is not the best way of doing it, but at least it works inside the
  # Visual Studio Code integrated terminal, which is enough for me now.
  if [ "$(command -v gnome-shell)" ]; then
    return 0
  else
    return 1
  fi
}

brew() {
  bash <<EOM
  if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -f "\$HOME/.linuxbrew/bin/brew" ]]; then
    eval "\$("\$HOME/.linuxbrew/bin/brew" shellenv)"
  else
    echo "brew is not installed" >&2
    exit 127
  fi
  brew $@
EOM
}

nvm() {
  bash <<EOM
  export NVM_DIR="\$([ -z "\${XDG_CONFIG_HOME-}" ] && printf %s "\${HOME}/.nvm" || printf %s "\${XDG_CONFIG_HOME}/nvm")"
  if [[ -f "\$NVM_DIR/nvm.sh" ]]; then
    . "\$NVM_DIR/nvm.sh"
  else
    echo "nvm is not installed" >&2
    exit 127
  fi
  nvm $@
EOM
}

volta() {
  bash <<EOM
  export VOLTA_HOME="\$HOME/.volta"
  if [[ -f "\$VOLTA_HOME/bin/volta" ]]; then
    export PATH="\$VOLTA_HOME/bin:\$PATH"
  else
    echo "volta is not installed" >&2
    exit 127
  fi
  volta $@
EOM
}

sdk() {
  bash <<EOM
  export SDKMAN_DIR="\$HOME/.sdkman"
  if [[ -f "\$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    . "\$SDKMAN_DIR/bin/sdkman-init.sh"
  else
    echo "sdk is not installed" >&2
    exit 127
  fi
  sdk $@
EOM
}

ran_apt_update=false

# See: https://github.com/microsoft/vscode-remote-release/issues/3531#issuecomment-675278804
if [ -z "${USER+x}" ]; then
  USER="$(id -un)"
fi

if ! sudo -n true 2>/dev/null; then
  echo_task "Prompting for sudo password"
  sudo true
fi

echo_task "Adding user to sudoers"
echo "$USER  ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER"

echo_task "Installing zsh"
if ! zsh --version &>/dev/null; then
  sudo apt update
  ran_apt_update=true
  sudo apt install -y zsh
else
  echo "zsh already installed"
fi

echo_task "Making zsh the default shell"
sudo chsh -s "$(which zsh)" "$USER"

echo_task "Initializing zsh"
(
  # We need to be in a git repository, so gitstatusd initiliazes
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  cd "$script_dir"
  # We also need to emulate a TTY
  script -qec "zsh -is </dev/null" /dev/null
)
echo "Done."

if ! is_devcontainer; then
  echo_task "Installing common packages"
  if [[ "$ran_apt_update" == false ]]; then
    sudo apt update
  fi
  sudo apt install -y software-properties-common build-essential curl wget tree parallel file zip

  echo_task "Adding apt repositories"
  sudo add-apt-repository --no-update -y ppa:git-core/ppa
  curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$(lsb_release -sr)/Release.key" | sudo apt-key add -
  sudo add-apt-repository -y "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$(lsb_release -sr)/ /"

  echo_task "Installing git"
  sudo apt install -y git

  echo_task "Installing skopeo"
  sudo apt install -y skopeo

  # echo_task "Installing podman"
  # sudo apt install -y podman
  # if is_wsl; then
  #   echo_sub_task "Setting up podman for WSL2"
  #   if [[ ! -f "/etc/containers/containers.conf" ]]; then
  #     sudo mkdir -p /etc/containers
  #     sudo cp -f /usr/share/containers/containers.conf /etc/containers/containers.conf
  #   fi
  #   sudo sed -i "s/.*cgroup_manager.*=.*/cgroup_manager = \"cgroupfs\"/g" /etc/containers/containers.conf
  #   sudo sed -i "s/.*events_logger.*=.*/events_logger = \"file\"/g" /etc/containers/containers.conf
  # fi

  # echo_task "Installing buildah"
  # sudo apt install -y buildah

  echo_task "Installing brew"
  if ! brew --version &>/dev/null; then
    CI=true bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  else
    echo "brew is already installed"
  fi

  echo_task "Installing brew packages"
  brew bundle install --global

  # Uninstalling previously installed chezmoi because it was already installed
  # by Homebrew.
  local_bin_chezmoi="$HOME/.local/bin/chezmoi"
  if [ -f "$local_bin_chezmoi" ]; then
    echo_task "Uninstalling chezmoi at $local_bin_chezmoi"
    rm -f "$local_bin_chezmoi"
  fi
  unset local_bin_chezmoi

  echo_task "Installing deno"
  if ! deno --version &>/dev/null; then
    sh -c "$(curl -fsSL https://deno.land/x/install/install.sh)"
  else
    echo "deno is already installed"
  fi

  echo_task "Installing volta"
  if ! volta --version &>/dev/null; then
    bash -c "$(curl -fsSL https://get.volta.sh)" -- --skip-setup
  else
    echo "volta is already installed"
  fi

  echo_task "Installing node, npm, and yarn"
  volta install node npm yarn

  echo_task "Installing sdk"
  if ! sdk version &>/dev/null; then
    bash -c "$(curl -fsSL "https://get.sdkman.io/?rcupdate=false")"
  else
    echo "sdk is already installed"
  fi

  echo_task "Installing Java"
  (
    set +o pipefail
    yes | sdk install java
  )

  # Install latest Java 8
  # get the identifier for java 8
  # identifier="$(sdk ls java | grep -m 1 -o ' 8.*.hs-adpt ' | awk '{print $NF}')"
  # sdk i java "$identifier"
  # unset identifier

  if is_wsl; then
    echo_task "Performing WSL specific steps"

    echo_task "Syncing .ssh folder from Windows to WSL"
    USERPROFILE="$(wslpath "$(wslvar USERPROFILE)")"
    if [ -f "$USERPROFILE/.ssh/id_rsa" ]; then
      cp -rf "$USERPROFILE/.ssh/." "$HOME/.ssh"
      chmod 600 "$HOME/.ssh/id_rsa"
    else
      echo "No keys to sync"
    fi
    unset USERPROFILE

    echo_task "Setting up Git credential helper"
    sudo git config --system credential.helper "/mnt/c/Program\ Files/Git/mingw64/libexec/git-core/git-credential-manager.exe"

  elif is_gnome; then
    echo_task "Performing GNOME specific steps"

    echo_task "Installing and setting up Fira Code Nerd Font"
    curl -fsSL --create-dirs -o "$HOME/.local/share/fonts/Fira Code Regular Nerd Font Complete.ttf" \
      "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/complete/Fira%20Code%20Regular%20Nerd%20Font%20Complete.ttf"
    gsettings set org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font 13'

    echo_task "Setting up Git credential helper"
    sudo apt install -y libsecret-1-0 libsecret-1-dev
    sudo make --directory /usr/share/doc/git/contrib/credential/libsecret
    sudo git config --system credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret

    echo_task "Adding 'Open Code here' in Nautilus context menu"
    bash -c "$(wget -qO- https://raw.githubusercontent.com/harry-cpp/code-nautilus/master/install.sh)"

    if is_ubuntu 20.04; then
      echo_task "Setting up dark theme"
      sudo apt install -y gnome-shell-extensions
      gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
      gsettings set org.gnome.desktop.interface gtk-theme "Yaru-dark"
      gsettings set org.gnome.shell.extensions.user-theme name "Yaru-dark"
    fi
  fi
fi
