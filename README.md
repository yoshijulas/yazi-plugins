# yazi-plugins

A monorepo containing custom and refactored plugins for the Yazi file manager.

## Included Plugins

- `eza-preview.yazi`: Directory tree previewer powered by eza with native FreeDesktop trash:// VFS resolution.
- `smart-filter.yazi`: Smart filtering plugin for Yazi file manager.

## Installation

Install individual plugins from this monorepo using Yazi's package manager:

```bash
ya pkg add yoshijulas/yazi-plugins:eza-preview
ya pkg add yoshijulas/yazi-plugins:smart-filter
```

## Updating Plugins

To update all installed plugins to their latest versions:

```bash
ya pkg upgrade
```

To update a specific plugin dependency, edit `package.toml` in your Yazi configuration directory (`~/.config/yazi/package.toml`) or run `ya pkg upgrade`.

## Upstream Maintenance

This monorepo tracks upstream repositories for plugin updates.

### Fetching Upstream Updates for smart-filter.yazi

```bash
git fetch upstream-yazi
git checkout upstream-yazi/main -- smart-filter.yazi
git add smart-filter.yazi
git commit -m "feat(smart-filter): update from upstream yazi-rs/plugins"
```

## License

Each plugin in this repository retains its original open-source license. Refer to the LICENSE file inside each plugin directory for specific terms.
