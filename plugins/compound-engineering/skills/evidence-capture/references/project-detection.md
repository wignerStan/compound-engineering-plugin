# Project Type Detection

Detect the project type by reading manifest files using native file-read tools. Check in priority order -- some project types overlap (e.g., Electron apps contain React).

## Detection Order

**1. Desktop app** (check first -- Electron apps also have web framework deps)

Read `package.json` if it exists. Check `dependencies` and `devDependencies` for any of: `electron`, `electron-builder`, `electron-forge`, `electron-vite`, `electron-packager`. If found -> `desktop-app`.

**2. Web app**

Check these manifests in order (stop at first match):

- **package.json**: Look for web framework deps: `react`, `vue`, `svelte`, `astro`, `next`, `nuxt`, `angular`, `solid-js`, `remix`, `gatsby`, `vite` (with framework deps). If found -> `web-app`.
- **Gemfile**: Look for `rails`, `sinatra`, `hanami`, `roda`. If found -> `web-app`.
- **go.mod**: Look for `gin`, `echo`, `fiber`, `chi`, `gorilla/mux`, `net/http` with a `cmd/server` or `main.go`. If found -> `web-app`.
- **pyproject.toml** or **requirements.txt**: Look for `flask`, `django`, `fastapi`, `starlette`, `tornado`. If found -> `web-app`.
- **Cargo.toml**: Look for `actix-web`, `axum`, `rocket`, `warp`. If found -> `web-app`.

**3. CLI tool**

- **package.json**: Has a `"bin"` field, or a `bin/` directory exists at repo root -> `cli-tool`.
- **go.mod** + `cmd/` directory exists -> `cli-tool`.
- **Cargo.toml**: Has `[[bin]]` section -> `cli-tool`.
- **pyproject.toml**: Has `[project.scripts]` or `[tool.poetry.scripts]` with entry points, or uses `click`, `typer`, `argparse` as deps -> `cli-tool`.
- **Gemfile**: Has `thor`, `gli`, `dry-cli` deps, or a `bin/` or `exe/` directory exists -> `cli-tool`.
- Repo root has `main.go` without web framework deps -> `cli-tool`.

**4. Library** (has a package manifest but no strong UI/CLI signal)

If any package manifest exists (`package.json`, `Gemfile`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `setup.py`, `*.gemspec`) but none of the above matched -> `library`.

**5. Text-only** (fallback)

No recognized package manifest, or the diff only touches documentation/config files -> `text-only`.

## Output

Print the detected type:

```
Detected project type: [web-app / cli-tool / desktop-app / library / text-only]
Reason: [one-line explanation, e.g., "package.json contains react dependency"]
```
