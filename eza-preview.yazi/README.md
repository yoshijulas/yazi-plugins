# 🌲 eza-preview.yazi

A zero-dependency directory tree previewer plugin for [Yazi](https://github.com/sxyazi/yazi) using [`eza`](https://github.com/eza-community/eza), featuring native support for Yazi Nightly `trash://` virtual VFS URIs.

> [!WARNING]
> **Maintenance & PR Notice**
> This is a personal fork tailored specifically for my personal workflow (zero-dependency single-file, embedded TDD test suite, and Yazi Nightly `trash://` VFS engine).
> **I will likely not be accepting Pull Requests or active feature requests.**
> If you are looking for an actively maintained version that accepts community PRs, please use the original repository:
> 👉 **[ahkohd/eza-preview.yazi](https://github.com/ahkohd/eza-preview.yazi)**

---

## ✨ Features

- ⚡ **Zero External Dependencies**: Pure Lua standard library implementation.
- 🗑️ **Yazi Nightly `trash://` VFS Engine**: Full support for FreeDesktop `.trashinfo` metadata decoding, subfolder paths at any depth $N$, timestamp collision IDs, and dynamic external drive mount paths (`.Trash-1000/files`).
- 🚀 **100x Speed Protection**: Automatically disables heavy git status scans (`--git-ignore`) and unbounded symlink traversals (`--follow-symlinks`) inside Trash directories to prevent UI freezes.
- 🧪 **Embedded TDD Test Runner**: Embedded unit test suite executable directly via `lua main.lua --test`.

---

## 📦 Installation

Add `eza-preview.yazi` using Yazi's package manager:

```bash
ya pkg add yoshijulas/eza-preview.yazi
```

---

## ⚙️ Configuration

### 1. Previewer Rule (`yazi.toml`)

Add the previewer rule to your `yazi.toml`:

```toml
[[plugin.prepend_previewers]]
url = "*/"
run = "eza-preview"
```

### 2. Keybindings (`keymap.toml`)

Add actions to your `keymap.toml`:

```toml
# eza-preview.yazi
[[mgr.prepend_keymap]]
on   = ["e", "t"]
run  = "plugin eza-preview"
desc = "Toggle tree/list dir preview"

[[mgr.prepend_keymap]]
on   = ["e", "-"]
run  = "plugin eza-preview inc-level"
desc = "Increment tree level"

[[mgr.prepend_keymap]]
on   = ["e", "_"]
run  = "plugin eza-preview dec-level"
desc = "Decrement tree level"

[[mgr.prepend_keymap]]
on   = ["e", "$"]
run  = "plugin eza-preview toggle-follow-symlinks"
desc = "Toggle tree follow symlinks"

[[mgr.prepend_keymap]]
on   = ["e", "*"]
run  = "plugin eza-preview toggle-hidden"
desc = "Toggle hidden files"

[[mgr.prepend_keymap]]
on   = ["e", "g", "i"]
run  = "plugin eza-preview toggle-git-ignore"
desc = "Toggle .gitignore files"

[[mgr.prepend_keymap]]
on   = ["e", "g", "s"]
run  = "plugin eza-preview toggle-git-status"
desc = "Toggle showing git status"
```

---

## 🧪 Testing

Run the embedded zero-dependency unit test suite:

```bash
lua main.lua --test
```

---

## 📄 License & Attribution

Licensed under the [MIT License](LICENSE).

### 🤖 AI Assistance Disclosure
This refactor, `trash://` VFS engine implementation, and embedded unit test suite were developed with AI pair programming assistance, guided by human architectural design, specification alignment (Yazi PR #4144), and TDD verification.
