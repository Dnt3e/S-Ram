# S-Ram: Advanced Swap Management Tool

[![GitHub license](https://img.shields.io/github/license/Dnt3e/S-Ram)](https://github.com/Dnt3e/S-Ram/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Dnt3e/S-Ram)](https://github.com/Dnt3e/S-Ram/stargazers)
[![Direct Download](https://img.shields.io/badge/download-script-blue)](https://raw.githubusercontent.com/Dnt3e/S-Ram/main/S-Ram.sh)

**S-Ram** is an intelligent swap space management script for Linux systems (especially Ubuntu) that automates the creation, optimization, and removal of swap space with smart defaults.

📖 [Persian Documentation / مستندات فارسی](#persian-documentation)

## Features

- 🚀 Automatic swap creation with intelligent size calculation
- ⚙️ Environment detection (server/desktop) for optimal settings
- 🔄 Persistent configuration that survives reboots
- 🗑️ Complete removal option to restore default settings
- 📊 Real-time swap status monitoring
- 🧠 Smart optimization of swappiness and cache pressure
- 🎨 Colorful interactive menu system
- ✔️ Root permission checking

## Installation & Quick Start

### Method 1: One-line install and run
```bash
wget https://raw.githubusercontent.com/Dnt3e/S-Ram/main/S-Ram.sh -O S-Ram && chmod +x S-Ram && sudo ./S-Ram
