#!/bin/bash

# Install script for the TODO Application

# Variables
SCRIPT_NAME="todo.sh"
TARGET_NAME="todo"

# Determine installation directory
if [ "$EUID" -ne 0 ]; then
  # Non-root user, install to ~/.local/bin
  INSTALL_DIR="$HOME/.local/bin"
else
  # Root user, install to /usr/local/bin
  INSTALL_DIR="/usr/local/bin"
fi

# Check if dependencies are installed
echo "🔍 Checking for required dependencies..."

# Function to check for a command
check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Dependency missing: $1"
    missing_deps=true
  else
    echo "✅ $1 is installed."
  fi
}

missing_deps=false

check_command "sqlite3"
check_command "gum"

# For macOS, check for GNU date (gdate)
if [ "$(uname)" = "Darwin" ]; then
  if ! command -v "gdate" >/dev/null 2>&1; then
    echo "❌ Dependency missing: gdate (GNU date). Install with 'brew install coreutils'."
    missing_deps=true
  else
    echo "✅ gdate is installed."
  fi
else
  check_command "date"
fi

if [ "$missing_deps" = true ]; then
  echo "Please install the missing dependencies and try again."
  exit 1
fi

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  echo "📁 Creating installation directory: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

# Add INSTALL_DIR to PATH in shell profile if not already in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  PROFILE_FILE="$HOME/.bashrc"
  [ -f "$HOME/.bash_profile" ] && PROFILE_FILE="$HOME/.bash_profile"
  [ -f "$HOME/.zshrc" ] && PROFILE_FILE="$HOME/.zshrc"
  echo "🔧 Adding $INSTALL_DIR to PATH in $PROFILE_FILE"
  echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >>"$PROFILE_FILE"
  echo "Please restart your terminal or run 'source $PROFILE_FILE' to update your PATH."
fi

# Create symlink
echo "🔗 Creating symlink to $SCRIPT_NAME in $INSTALL_DIR"
ln -sf "$(pwd)/$SCRIPT_NAME" "$INSTALL_DIR/$TARGET_NAME"

# Make sure the script is executable
chmod +x "$INSTALL_DIR/$TARGET_NAME"

echo "🎉 Installation complete! You can now run the TODO application by typing 'todo' in your terminal."
