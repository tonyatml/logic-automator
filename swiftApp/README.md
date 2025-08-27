# Dance & Go Automator - 菜单栏应用

这是一个Mac菜单栏驻留应用，用于控制Dance & Go Logic Automator。

## 功能特性

1. **菜单栏驻留**: 应用图标显示在菜单栏中，点击即可打开控制面板
2. **初始化设置**: 点击"Initialize Setup"按钮执行setup.sh脚本
3. **命令执行**: 在文本框中输入命令，点击"Send"调用dance_go_automator.py
4. **实时输出**: 显示命令执行的结果和状态
5. **紧凑界面**: 专为菜单栏设计的紧凑UI

## 使用方法

### 1. 构建和运行
```bash
cd swiftApp
open logic.xcodeproj
```

在Xcode中：
- 选择目标设备为"Mac"
- 按Cmd+R运行应用
- 应用启动后会在菜单栏显示音乐图标

### 2. 使用应用
1. 点击菜单栏中的音乐图标打开控制面板
2. 首次使用时，点击"Initialize Setup"按钮执行初始化
3. 在命令输入框中输入参数，例如：
   ```
   'dance & go' 124 'A minor' 'test.midi'
   ```
4. 点击"Send"执行命令
5. 在输出区域查看执行结果

## 项目结构

```
swiftApp/
├── logic.xcodeproj/          # Xcode项目文件
├── logic/                   # 源代码目录
│   ├── logicApp.swift       # 应用入口（菜单栏配置）
│   ├── ContentView.swift    # 主界面
│   ├── logic.entitlements   # 权限配置
│   └── Assets.xcassets/     # 资源文件
└── README.md               # 说明文档
```

## 技术特点

- **MenuBarExtra**: 使用SwiftUI的MenuBarExtra创建菜单栏应用
- **异步执行**: 使用DispatchQueue避免UI阻塞
- **权限管理**: 配置了必要的文件访问和执行权限
- **紧凑设计**: 320x400的窗口尺寸适合菜单栏显示
- **状态管理**: 使用@State管理UI状态

## 权限说明

应用需要以下权限：
- 文件系统访问：读取和执行脚本
- 用户选择的文件读写权限
- 特定路径的访问权限（项目目录）

## 注意事项

1. 确保Python环境已正确配置
2. 首次运行前需要执行初始化设置
3. 命令参数需要正确格式化，用引号包围包含空格的参数
4. 应用会在菜单栏显示，不会在Dock中显示图标

## 开发说明

- 最低macOS版本: 14.0
- 开发工具: Xcode 15.0+
- Swift版本: 5.0+
- 使用SwiftUI MenuBarExtra框架

## 故障排除

1. **权限错误**: 确保在entitlements中配置了正确的权限
2. **路径错误**: 确保项目路径正确配置
3. **菜单栏不显示**: 检查应用是否正确启动，查看控制台日志
