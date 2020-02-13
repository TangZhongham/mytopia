---
title: "How_to_hugo_1"
date: 2019-11-19T11:23:09+08:00
draft: true
authors: ["tzh"]
tags: ["hugo", "markdown", "github"]
categories: ["tutorial"]
---

# How to Hugo

[toc]

## 安装篇

### Git 安装

略

### Hugo 安装

#### Windows

**下载二进制文件**: Windows 安装其实要比 Mac 舒服一些.找到 binary 二进制文件 的Releases, 下载下来安装就行.
[下载链接](https://gohugo.io/getting-started/installing)

**添加到Path**: 不会的可以谷歌.

#### Mac

诚然, 我一开始当然是愉快的使用 ```brew install hugo``` 的方式. 问题来了...由于方方面的原因,这样下载的 hugo 版本太低了,和我喜欢的主题有冲突, 所以 mac 也老老实实和 win 一样找二进制安装然后配置path 吧~

> ps: Mac 软链接有点小坑, 没搞定的谷歌可以解决.

## 启动篇

> Hugo 是目前最舒服的markdown 静态网站方案了.
> 简单五步开始搭建博客吧.

### 第一步: 网站

由于静态网站的便捷性, hugo 建立一个网站只需要一条命令.

```shell
hugo new site mytopiia
此时 hugo 生成的目录结构如下:

mytopiia
├── archetypes # 存放生成博客的模版
│   └── default.md
├── config.toml # tommy 的改良版 yaml
├── content # 你写markdown 的地方
├── data # Hugo 处理的数据
├── layouts # 布局文件
├── static # 静态文件
└── themes # 主题
```

严格意义上来说, 这一步已经可以部署你的“网站”了. 先挑一个[主题](https://themes.gohugo.io/)吧.

### 第二步: 主题

选好主题后, 这里涉及到一些 git 的知识, 先照着敲就对了.

```shell
cd mytopiia

# 下载你喜欢的 theme, 下面是我喜欢的.
git init
git submodule add https://github.com/panr/hugo-theme-terminal.git themes/terminal

# 把主题名称添加到 config 里生效.
echo 'theme = "terminal"' >> config.toml
```

### 第三步: Config

### 第四步: Markdown
m
### 第五步: Server

## 润色篇

