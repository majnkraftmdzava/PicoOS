

# 🖥️ PicoOS for CC:Tweaked (ComputerCraft)

[Русская версия (Russian Version)](README_RU.md)

> A lightweight, Windows-style desktop environment and operating system designed for ComputerCraft / CC:Tweaked in Minecraft. Fully compatible with NovaOS servers and network protocols.

---

## 🌟 Features

* **Windows-Style Desktop Environment** — Interactive blue desktop, bottom taskbar, system clock, and start menu.
* **Window Manager** — Smooth window dragging by the header, dynamic resizing from the bottom-right corner `\`, and active window focus stacking.
* **PicoOS Pro Shell (Terminal)** — Advanced command-line interface with built-in system tools (`ls`, `cat`, `mkdir`, `rm`, `theme`, `ping`, `67`, `reboot`, and more).
* **NovaMessenger Client** — Fully compatible client-server messaging application supporting direct chats, peer relaying, and server integration.
* **Network Config (NetConfig)** — Standalone graphical utility to configure and save server ID and ports (`server_config.txt`).
* **Animated Boot Screen** — Retro ASCII logo and smooth progress bar during system startup.

---

## 🚀 Quick Installation

To install PicoOS on any advanced computer or turtle in Minecraft, run the following command in your CraftOS terminal (assuming you publish the core script to Pastebin):

```bash
pastebin run YDL23ptj

```

*(Alternatively, copy the full `startup` script directly into your computer's root directory).*

---

## ⌨️ Terminal Commands Reference

| Command | Description |
| --- | --- |
| `help` | Displays the full list of available shell commands. |
| `ls` | Lists files and directories with type indicators (`[DIR]`). |
| `cat <file>` | Reads and displays the contents of a text file inside the terminal. |
| `mkdir <dir>` | Creates a new directory in the file system. |
| `rm <path>` | Deletes a specified file or directory. |
| `theme <bg> <header>` | Changes desktop and window header colors on the fly. |
| `ping <id>` | Tests network connectivity with another computer ID. |
| `67` | Renders large digital art of the number **67** on the screen. |
| `killall` | Instantly closes all active background windows. |
| `reboot` | Restarts the operating system and triggers the boot animation. |
| `exit` | Closes the terminal window. |

---

## 🌐 Network Protocol (NovaOS Compatibility)

PicoOS communicates with **NovaOS** master servers using wireless modems via the standard rednet/modem transmit pipeline:

* Supports `NEW_MSG` actions for direct server communication.
* Supports `RELAY_MSG` actions for peer-to-peer messaging through the server relay.
* Configuration is safely stored locally in `server_config.txt`.

---

## 📜 License

This project is open-source and available under the **MIT License**. Feel free to fork, modify, and use it in your CC:Tweaked worlds!

---
