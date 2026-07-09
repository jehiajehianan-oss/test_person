---
name: autodaily
description: 自动化任务创建与管理。指导如何创建定时自动化任务：项目文件放哪、怎么配 Windows 任务计划、注意事项。Trigger when user says "创建自动化", "autodaily", "定时任务", "自动跑", "每天自动", "定期执行", "schedule task", 或想了解自动化流程/规范/文件夹结构。
---

# autodaily — 自动化任务创建规范

为 Codex 创建的自动化任务提供统一的目录结构、触发方式和注意事项。

## 目录规范

所有自动化项目统一放在：

```
D:\Project_codex\a_Daily\
├── <项目名>\
│   ├── config\           ← 配置文件 (yaml / json / ini)
│   ├── scripts\          ← 主控脚本 (Python / PowerShell)
│   └── deps\             ← 依赖文件 (requirements.txt / package.json)
```

每个自动化项目一个独立文件夹，按用途命名（如 `paper-daily`、`backup-weekly`、`report-monthly`）。

## 创建流程

### Step 1: 确定需求
与用户确认：做什么、多久跑一次、输出到哪。

### Step 2: 创建项目目录
```powershell
New-Item -ItemType Directory -Path "D:\Project_codex\a_Daily\<项目名>\config" -Force
New-Item -ItemType Directory -Path "D:\Project_codex\a_Daily\<项目名>\scripts" -Force
New-Item -ItemType Directory -Path "D:\Project_codex\a_Daily\<项目名>\deps" -Force
```

### Step 3: 编写主控脚本
放在 `scripts/` 下，确保：
- 路径均使用绝对路径，不依赖当前工作目录
- 必要的环境变量在脚本开头设置
- 打印清晰的运行日志，方便排查

### Step 4: 创建配置文件
放在 `config/` 下，将可变参数（关键词、时间、路径、Token 等）抽离到配置文件，避免硬编码。

### Step 5: 安装依赖
```powershell
# Python
pip install -r "D:\Project_codex\a_Daily\<项目名>\deps\requirements.txt"
```

### Step 6: 创建 Windows 定时任务
```powershell
$action = New-ScheduledTaskAction -Execute "<python.exe 路径>" `
    -Argument '"D:\Project_codex\a_Daily\<项目名>\scripts\<主控>.py"' `
    -WorkingDirectory "D:\Project_codex\a_Daily\<项目名>\scripts"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Thursday -At 08:00

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName "<任务名>" `
    -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
    -Description "<任务描述>" -Force
```

参数说明：
- `-Weekly` / `-Daily`: 触发频率
- `-DaysOfWeek`: 周几运行 (逗号分隔多个)
- `-At`: 运行时间 (HH:MM)
- `-ExecutionTimeLimit`: 单次最长运行时间，防卡死
- `-MultipleInstances IgnoreNew`: 上次未结束时跳过本次

### Step 7: 手动测试一次
```powershell
python "D:\Project_codex\a_Daily\<项目名>\scripts\<主控>.py"
```

确认无报错、输出符合预期后，等待下次定时触发验证。

### Step 8: 告知用户可配置项
创建完成后，必须清晰告知用户：
- 哪些文件可以改（配置文件路径）
- 改了之后何时生效（立即 / 下次定时触发）
- 如何手动触发和查看状态

## 常用管理命令

```powershell
# 查看任务状态
Get-ScheduledTask -TaskName "<任务名>" | Select-Object State

# 查看上次运行结果
Get-ScheduledTaskInfo -TaskName "<任务名>"

# 查看触发器详情
Get-ScheduledTask -TaskName "<任务名>" | Select-Object -ExpandProperty Triggers

# 禁用任务
Disable-ScheduledTask -TaskName "<任务名>"

# 启用任务
Enable-ScheduledTask -TaskName "<任务名>"

# 删除任务
Unregister-ScheduledTask -TaskName "<任务名>" -Confirm:$false
```

## ⚠️ 注意事项

创建自动化时务必提醒用户：

1. **电脑需开机**：定时任务依赖 Windows 在运行，关机到点不会执行。默认设置错过时间会自动补跑。
2. **网络连接**：涉及 API 调用（arXiv、Semantic Scholar、GitHub 等）的任务需要联网。
3. **路径硬编码**：所有脚本使用绝对路径，迁移到其他电脑需重新配置。
4. **Token/Key 安全**：API Key 等敏感信息放在 `config/` 下，不要硬编码在脚本中。
5. **日志保留**：建议脚本输出关键步骤日志，方便排查「到时间了但没跑」的问题。
6. **Python 环境**：使用 `(Get-Command python).Source` 获取当前 Python 路径写入定时任务。
7. **权限**：定时任务以当前用户身份运行，能访问用户有权限的所有文件。

## 关联项目

| 项目 | 目录 | 说明 |
|------|------|------|
| paper-daily | `a_Daily\config\` | 每周二/五搜索论文 → Obsidian + Zotero |
