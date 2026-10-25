#!/usr/bin/env bash
# 一键构建 Windows 可执行文件 (Git Bash)
# 用法: ./build.sh [Godot.exe 路径]   (Godot 已在 PATH 中时可省略参数)
set -euo pipefail
cd "$(dirname "$0")"

# ---- 定位 Godot ----
GODOT="${1:-${GODOT:-}}"
if [ -z "$GODOT" ]; then
	for c in godot godot4 Godot.exe \
		"$LOCALAPPDATA/Programs/Godot/Godot.exe" \
		"/c/Program Files/Godot/Godot.exe" \
		"/c/Program Files/Godot/Godot_x86_64.exe" \
		"$HOME/Desktop/Godot.exe" "$HOME/Downloads/Godot.exe"; do
		if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
			GODOT="$c"
			break
		fi
	done
fi
if [ -z "$GODOT" ]; then
	echo "未找到 Godot。请先下载 Godot 4.3+, 然后运行:  ./build.sh /path/to/Godot.exe" >&2
	exit 1
fi

echo "== Godot: $GODOT =="
"$GODOT" --version

# ---- 检查导出模板 (与 Godot 版本须一致) ----
TPL_DIR="${APPDATA:-$HOME/AppData/Roaming}/Godot/export_templates"
if ! ls "$TPL_DIR"/*/windows_release_x86_64.exe >/dev/null 2>&1; then
	cat >&2 <<'EOF'
未检测到导出模板 (export templates)。
请打开 Godot 编辑器 → Editor → Manage Export Templates → Download and Install
(模板版本须与 Godot 版本一致), 然后重新运行本脚本。
EOF
	exit 1
fi

# ---- 导入资源(生成 .godot 缓存, 顺带暴露着色器/脚本解析错误) ----
echo "== 导入资源 =="
"$GODOT" --headless --path . --import

# ---- 导出 ----
echo "== 导出 Windows x86_64 (嵌入 PCK, 单文件) =="
mkdir -p build
"$GODOT" --headless --path . --export-release "Windows Desktop" build/4DWormholeEngine.exe

echo "完成: build/4DWormholeEngine.exe (控制台版: build/4DWormholeEngine_console.exe)"
