---
title: "Rust_intro"
date: 2020-07-20T18:30:23+08:00
draft: true
---

# Rust 入门指南

> How to install rust and offer learning materials

- [ ] start rust 项目学习 rust

## 安装rust环境

```shell
wget https://mirrors.ustc.edu.cn/rust-static/rustup/dist/x86_64-apple-darwin/rustup-init  

chmod +x ./rustup-init

RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup ./rustup-init

# Cargo 添加国内源
echo "RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup"  >> ~./env

# 添加国内源环境变量 vi ~/.zshrc （bash 的话 bashrc）
echo "
# Rust
export RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup
# For downloading fail
CARGO_HTTP_MULTIPLEXING=false
" >> ~/.zshrc

# 安装成功 (我改成了nightly版本)
rustc --version 
rustc 1.46.0-nightly (346aec9b0 2020-07-11)
```

rust 的nightly有一些实验功能是stable没有的，可能会遇到stable编译nightly项目失败的问题

nightly 安装如下：

```shell
rustup install nightly

rustup default nightly

rustc -version
rustc 1.46.0-nightly (346aec9b0 2020-07-11)

# 如果要build项目
cargo build
```

### 报错

cargo build

spurious network error (2 tries remaining): [6] Couldn't resolve host name (Could not resolve host: crates)

据说是因为下载连接过多，设置
export CARGO_HTTP_MULTIPLEXING=false
加到环境变量即可。

编译失败，发现是需要用nightly版本的rust，自己默认下载的是stable版本


rustup install nightly

rustup default nightly

rustc -version

重新执行 cargo build




https://github.com/wyhaya/see


## IDEA

Rust 插件

https://blog.jetbrains.com/clion/2020/05/whats-new-in-intellij-rust/
nativeDebug 

## 阅读

https://github.com/KaiserY/trpl-zh-cn

https://rust.cc/

内存模型
https://doc.rust-lang.org/1.4.0/book/the-stack-and-the-heap.html

## Ref

https://www.cnblogs.com/hustcpp/p/12341098.html
