# Logic Pro X 模板设置指南

## 创建 Dance 模板项目

为了使用 `dance_go_automator.py` 脚本，你需要创建一个 Logic Pro X 模板项目。

### 步骤 1: 创建基础模板项目

1. **打开 Logic Pro X**
2. **创建新项目**
   - 选择 "Empty Project"
   - 选择 "Software Instrument" 作为第一个轨道类型
   - 点击 "Create"

3. **设置基础配置**
   - 设置默认 tempo 为 120 BPM（脚本会自动修改）
   - 设置默认 key 为 C major（脚本会自动修改）
   - 确保项目格式为 44.1kHz, 24-bit

4. **创建软件乐器轨道**
   - 添加一个软件乐器轨道
   - 选择 "Electric Piano" 作为默认乐器
   - 保存一个预设（可选）

5. **设置界面布局**
   - 关闭 Mixer（脚本会自动处理）
   - 关闭 Library（脚本会自动处理）
   - 确保主窗口可见

### 步骤 2: 保存模板

1. **创建模板目录**
   ```bash
   mkdir -p templates
   ```

2. **保存项目为模板**
   - 在 Logic Pro X 中，选择 File > Save As Template
   - 命名为 "dance_template"
   - 保存到 `templates/` 目录

3. **或者手动复制项目文件**
   ```bash
   # 找到你的 Logic 项目文件（通常在 ~/Music/Logic/）
   cp ~/Music/Logic/your_template.logicx templates/dance_template.logicx
   ```

### 步骤 3: 验证模板

运行以下命令测试模板：

```bash
python3 dance_go_automator.py "test_project" 124 "A minor"
```

## 模板项目结构

你的模板项目应该包含：

```
templates/
└── dance_template.logicx/
    ├── projectdata/
    ├── media/
    └── [其他 Logic 项目文件]
```

## 使用说明

### 基本用法

```bash
# 创建名为 "dance & go" 的项目，124 BPM，A minor key
python3 dance_go_automator.py "dance & go" 124 "A minor"

# 创建项目并导入 MIDI 文件
python3 dance_go_automator.py "dance & go" 124 "A minor" "test.midi"
```

### 参数说明

- `project_name`: 项目名称（必需）
- `tempo`: BPM 速度（可选，默认 124）
- `key`: 调性（可选，默认 "A minor"）
- `midi_file`: MIDI 文件路径（可选）

### 输出

脚本会在 `projects/` 目录下创建新的 Logic 项目：

```
projects/
└── dance & go.logicx/
    ├── projectdata/
    ├── media/
    └── [其他 Logic 项目文件]
```

## 故障排除

### 常见问题

1. **模板未找到**
   - 确保 `templates/dance_template.logicx` 存在
   - 检查文件权限

2. **无法设置 tempo/key**
   - Logic Pro X 的 UI 可能已更改
   - 尝试手动设置，然后重新保存模板

3. **Electric Piano 未找到**
   - 检查 Logic Pro X 中 Electric Piano 的确切路径
   - 可能需要更新 `setupElectricPiano()` 函数中的路径

4. **MIDI 导入失败**
   - 确保 MIDI 文件路径正确
   - 检查 MIDI 文件格式

### 调试模式

如果需要调试，可以在脚本中添加更多日志输出：

```python
# 在 logic.py 中添加调试信息
print(f"Found windows: {[w.AXTitle for w in logic.windows() if 'AXTitle' in w.getAttributes()]}")
```

## 自定义

### 添加更多乐器

修改 `setupElectricPiano()` 函数或创建新的乐器设置函数：

```python
def setupBass():
    bass_path = ["AU Instruments", "Logic Pro X", "Bass", "Stereo"]
    logic.selectInstrument(bass_path)

def setupDrums():
    drums_path = ["AU Instruments", "Logic Pro X", "Drum Machine Designer"]
    logic.selectInstrument(drums_path)
```

### 支持更多调性

在 `setProjectKey()` 函数中添加更多调性支持：

```python
# 支持的调性列表
SUPPORTED_KEYS = [
    "C major", "C minor", "G major", "G minor",
    "D major", "D minor", "A major", "A minor",
    "E major", "E minor", "B major", "B minor",
    "F major", "F minor", "Bb major", "Bb minor",
    "Eb major", "Eb minor", "Ab major", "Ab minor"
]
```

## 注意事项

1. **Logic Pro X 版本兼容性**
   - 脚本基于 Logic Pro X 10.6+ 开发
   - 不同版本的 UI 可能略有不同

2. **macOS 权限**
   - 确保 Logic Pro X 有辅助功能权限
   - 在 System Preferences > Security & Privacy > Privacy > Accessibility 中添加

3. **性能考虑**
   - 创建项目可能需要几秒钟
   - 导入大型 MIDI 文件可能需要更长时间

4. **备份**
   - 定期备份你的模板项目
   - 测试新功能前先备份现有项目
