# aiM 配置管理器

`aiM.sh` 是一个交互式 Bash 脚本，用于在本地快速保存、切换三种 CLI（Codex、Claude Code、Gemini CLI）的用户配置。

## 功能
- 主菜单：三套工具的独立子菜单（Codex / Claude Code / Gemini CLI）+ 退出。
- 保存配置：为当前配置起名并保存到对应 `~/.<tool>/aiM/<name>` 目录，支持覆盖确认。
- 切换配置：列出已保存配置并通过编号切换，自动复制所需文件到默认路径。
- 容错：
  - 配置文件缺失时保存会提示并停止（Gemini 会跳过缺失的单个文件，仅要求至少存在一份）。
  - 切换时缺文件会提示并中止。

## 目录与文件约定
- Codex：`~/.codex/` 使用 `config.toml`、`auth.json`，存档于 `~/.codex/aiM/`
- Claude Code：`~/.claude/` 使用 `config.json`、`settings.json`，存档于 `~/.claude/aiM/`
- Gemini CLI：`~/.gemini/` 使用 `google_accounts.json`、`oauth_creds.json`、`settings.json`、`state.json`，存档于 `~/.gemini/aiM/`

## 使用方法
```bash
bash aiM.sh
```
- 进入主菜单选择对应工具。
- 子菜单中：
  1) 保存当前配置为新配置（输入名称，确认是否覆盖）。
  2) 切换到已保存的配置（输入编号）。
  3) 返回主菜单。

## 实现结构（摘要）
- `prompt`/`pause`：通用交互。
- `ensure_*_dirs`：按工具确保 `aiM` 存档目录存在。
- `save_*_profile`：校验当前配置文件、命名、覆盖确认、复制到存档。
- `switch_*_profile`：列出存档、编号选择、校验文件并复制回默认路径。
- `*_menu`：各工具子菜单；`main_menu` 组装入口。
