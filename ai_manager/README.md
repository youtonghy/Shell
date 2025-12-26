# aiM 配置管理器

`aiM.sh` 是一个交互式 Bash 脚本，用于在本地快速保存、切换三种 CLI（Codex、Claude Code、Gemini CLI）的用户配置。

## 功能
- 主菜单：三套工具的独立子菜单（Codex / Claude Code / Gemini CLI）+ 退出。
- 保存配置：按工具保存当前配置（Codex 通过添加供应源 + 保存 MCP/信任配置）。
- 切换配置：列出已保存配置并通过编号切换（Codex 先选供应商，再选 MCP/信任配置）。
- 删除配置：按编号删除已保存的配置目录（会二次确认）。
- 容错：
  - 配置文件缺失时保存会提示并停止（Gemini 会跳过缺失的单个文件，仅要求至少存在一份）。
  - 切换时缺文件会提示并中止。

## 目录与文件约定
- Codex：`~/.codex/` 使用 `config.toml`、`auth.json`。存档拆分为：
  - `~/.codex/aiM/providers/<供应商>/provider.env`：记录 API Key、Base URL、供应商名称（官方登录会记录 auth 内容）。
  - `~/.codex/aiM/mcp/mcp-<name>.toml`：记录 MCP 与信任目录设置，可保存多份，与供应商独立。
  - `~/.codex/aiM/global.env`：统一记录 `model` 与 `model_reasoning_effort`。
- Claude Code：`~/.claude/` 使用 `config.json`、`settings.json`，存档于 `~/.claude/aiM/`
- Gemini CLI：`~/.gemini/` 使用 `google_accounts.json`、`oauth_creds.json`、`settings.json`、`state.json`，存档于 `~/.gemini/aiM/`

## 使用方法
```bash
bash aiM.sh
```
- 进入主菜单选择对应工具。
- 子菜单中：
  1) 切换配置（Codex 先选供应商，再选 MCP/信任配置，组合后应用）。
  2) 删除配置（输入编号；输入 `0` 返回；确认删除）。
  3) 批量更新模型/思考强度（Codex 全局生效）。
  4) 保存 MCP/信任配置（Codex）。
  5) 添加自定义API供应源（Codex）。
  0) 返回主菜单。

## 实现结构（摘要）
- `prompt`/`pause`：通用交互。
- `ensure_*_dirs`：按工具确保 `aiM` 存档目录存在。
- `save_*_profile`：校验当前配置文件、命名、覆盖确认、复制到存档。
- `switch_*_profile`：列出存档、编号选择、校验文件并复制回默认路径。
- `delete_*_profile`：列出存档、编号选择、确认并删除存档目录。
- `*_menu`：各工具子菜单；`main_menu` 组装入口。
