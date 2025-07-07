# 🚀 GH200 ComfyUI Bootstrap

This project automates the setup of a full **ComfyUI stack** (for image & video generation) on a remote **GH200 + H100 GPU VM**. It installs the necessary **CUDA**, **PyTorch**, **Docker**, and **NVIDIA Container Toolkit** components inside a GPU-enabled Docker container, so you can generate AI video on cutting-edge hardware without manually configuring drivers.

---

## 🧠 What It Does

This bootstrap process:

- Sets up a **VM with NVIDIA drivers and CUDA 12.4** (compatible with H100 GPUs on ARM64).
- Installs **Docker** and the **NVIDIA Container Toolkit** for GPU access in containers.
- Creates and configures a **Docker container** running ComfyUI with full **CUDA + PyTorch** support.
- Exposes ComfyUI on port `8188` and launches it with GPU access.

---

## 🛠️ Prerequisites

Before running anything, make sure you have:

- A **GH200 VM** (e.g. rented from a cloud provider) with:
  - Public IP address (you'll need this)
  - Ubuntu 22.04 ARM64
  - SSH key access
- Your SSH private key located at `~/.ssh/id_ed25519` (or update `SSH_KEY` in the script)

You do **not** need to pre-install Docker, NVIDIA drivers, or ComfyUI — the script handles all of that automatically.

---

## 📁 Files

| File              | Description |
|-------------------|-------------|
| `bootstrap.sh`    | Main script to orchestrate the entire setup via SSH |
| `step1-os.sh`     | Installs kernel headers, Python, and tools – reboots |
| `step2-gpu.sh`    | Installs H100-compatible NVIDIA driver + CUDA 12.4 |
| `step3-docker.sh` | Installs Docker CE and NVIDIA container toolkit |
| `step4-comfyui.sh`| Creates Docker container and installs ComfyUI inside |
| `step5-run.sh`    | Launches ComfyUI and sets up browser access |

---

## 🧪 How This Works

- **CUDA** is NVIDIA’s GPU computing toolkit. Version 12.4 is required for H100.
- **PyTorch** is installed inside the container with CUDA 12.4 compatibility.
- **Docker** allows containerized apps; we use `--gpus all` to pass GPU access.
- **NVIDIA Container Toolkit** bridges the host GPU with the container.

---

## 🚦 Quickstart

### 1. Clone the Repo

```bash
git clone https://github.com/MichaelWStuart/gh200-vm.git
cd gh200-comfyui-bootstrap
```

### 2. Make Scripts Executable

```bash
chmod +x bootstrap.sh step*.sh
```

### 3. Run the Bootstrap Script

```bash
./bootstrap.sh <VM_IP>
```

Replace `<VM_IP>` with the public IP of your VM.

This will:

- Upload all step scripts to the VM
- Make them executable
- Run each setup step (auto-handling reboots)
- Launch ComfyUI in a GPU container
- Open the ComfyUI UI in your browser

---

## 🌐 Accessing ComfyUI

After completion, ComfyUI will be running on:

```
http://localhost:8188
```

If you're accessing remotely, the script opens an SSH tunnel and auto-opens the browser.

---

## 🧯 Recovery / Re-run

If any step fails or the container crashes:

```bash
./step5-run.sh <VM_IP>
```

This will:
- Relaunch the container if it stopped
- Reopen the SSH tunnel
- Relaunch the browser

---

## 🧾 Notes

- Make sure your cloud VM provider enables GPU access for the container.
- Your user must have `sudo` permissions on the VM.
- SSH reboots are handled automatically (step scripts return code `42`).

---

## 🤖 Why This Repo Exists

Setting up GPU-accelerated video generation with ComfyUI on GH200 systems is **extremely error-prone** due to:

- ARM64 driver requirements
- CUDA version mismatches
- Docker + GPU compatibility issues
- PyTorch + CUDA installation pain

This repo makes the entire process **repeatable and seamless**.

---

## 📝 License

MIT – use freely, modify deeply.