<img width="1757" height="791" alt="Image" src="https://github.com/user-attachments/assets/2f590576-54db-4042-aaaa-9f2c2adaa533" />

## About
RetroVisor is a macOS application that applies real-time, shader-based visual effects to any running window on your desktop. Whether you're enhancing a retro emulator, a modern game, or a media player, RetroVisor gives your applications the authentic look and feel of classic CRT displays — all without modifying the original software.

RetroVisor is inspired by [ShaderGlass](https://github.com/mausimus/ShaderGlass), which pioneered the concept of applying real-time shader effects to desktop applications on Windows.

## How to use 

When you launch RetroVisor, an effect window appears that can be freely moved around your screen.
Position this window over the target application — for example, your favorite retro emulator — and double-click it. The window will then "freeze" in place and stop responding to user input. To unfreeze it, click the small RetroVisor icon in the macOS menu bar to open the options menu, or click on the app icon in the dock. 

You can zoom in on the displayed portion of the screen using the trackpad’s magnification gesture or by selecting magnification options from the menu bar.

## How it works

RetroVisor uses ScreenCaptureKit to capture your screen in real-time. The captured image is processed by a GPU pipeline that applies the selected visual effects. The result is rendered back onto the screen, precisely aligned with the original window position — creating the illusion of a transparent overlay.

⚠️ Note: Screen recording on macOS requires user permission. You'll need to grant screen recording access in System Settings > Privacy & Security > Screen Recording. Without these permissions, the app won’t function.

## Roadmap

RetroVisor is being developed in two stages:

- **Establish Core Infrastructure**
  
  Stage 1 focused on building a functional prototype with all the necessary infrastructure. A proof-of-concept shader (CRT-Easymode) was integrated to showcase the app’s potential. This stage is now complete.

- **Support a Wider Range of Retro Shaders**

  Stage 2 will bring more advanced shader support. The ultimate goal is to provide a universal shader interface capable of running a wide variety of existing shaders. Achieving this will require a deep dive into popular shader frameworks and designing a flexible, extensible architecture for shader integration. Since exploring complex shader code isn't my favorite activity, this stage will rely heavily on community contributions.

I’d love to see forks of RetroVisor that experiment with different shaders. If these experiments yield great results, I'm happy to merge them back into the main project.

