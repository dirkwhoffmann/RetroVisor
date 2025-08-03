<img width="1757" height="791" alt="Image" src="https://github.com/user-attachments/assets/2f590576-54db-4042-aaaa-9f2c2adaa533" />

# About
RetroVisor will be a macOS application that lets you apply real-time shader-based visual effects to any running window on your desktop. Whether you're enhancing a retro emulator, modern game, or media player, RetroVisor can give your applications the look and feel of old CRTs, vintage displays, or stylized aesthetics — all without modifying the original software.

RetroVisor is inspired by [ShaderGlass](https://github.com/mausimus/ShaderGlass), which pioneered the concept of applying real-time shader effects to desktop applications on Windows.

## ⚠️ Early Development Notice

RetroVisor is currently in early development. Functionality is limited, and many features remain experimental or are yet to be implemented. Your feedback and contributions are welcome!


# Roadmap

- **1. Establish Core Infrastructure**

  Build a robust foundation that enables high-performance, real-time filtering of macOS application windows. Users will be able to place transparent overlay windows on top of existing apps, with a focus on efficient window capture and GPU-accelerated shader rendering. Initial development emphasizes performance and system integration rather than retro-specific effects.

- **2. Integrate a Flagship CRT Shader**

  To showcase the app’s potential, the next milestone is integrating a powerful CRT shader. Possible approaches include:
Porting shaders from existing emulators like vAmiga and VirtualC64, which already use Metal shaders to simulate authentic CRT monitor effects. Incorporating a lightweight, easy-to-use shader such as CRT Easy Mode to provide a polished demo with minimal complexity.

- **3. Support a Wide Range of Retro Shaders**
  
  Ultimately, RetroVisor aims to offer a universal shader interface that supports a large library of existing shaders.
This will require a detailed analysis of popular shader frameworks and designing a flexible, extensible architecture for shader integration.Since diving deep into other people’s shader code isn’t my favorite pastime, this phase will likely rely heavily on community involvement and contributions.
