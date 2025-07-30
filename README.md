# About
RetroVisor ~~is~~ will be a macOS application that lets you apply real-time shader-based visual effects to any running window on your desktop. Whether you're enhancing a retro emulator, modern game, or media player, RetroVisor can give your applications the look and feel of old CRTs, vintage displays, or stylized aesthetics — all without modifying the original software.

RetroVisor is inspired by ShaderGlass, which pioneered the concept of applying real-time shader effects to desktop applications on Windows.

<img width="863" height="745" alt="Image" src="https://github.com/user-attachments/assets/bc3465b8-42fe-4b38-8ffe-711aad1d3906" />

**Note: RetroVisor is currently in early development. Functionality is limited, and many features are still experimental or not yet implemented.**

# Roadmap

- **Establish Core Infrastructure**

  Build a robust foundation that enables high-performance, real-time filtering of macOS application windows. Users will be able to place transparent overlay windows on top of existing apps, with a focus on efficient window capture and GPU-accelerated shader rendering. Initial development emphasizes performance and system integration rather than retro-specific effects.

- **Support Existing Retro Shaders **

  Add compatibility for widely used retro-style shaders, such as CRT emulation, scanlines, phosphor glow, and pixel smoothing. The goal is to support GLSL-based shaders from the RetroArch and ReShade ecosystems, allowing users to easily apply authentic retro effects without creating custom filters.
