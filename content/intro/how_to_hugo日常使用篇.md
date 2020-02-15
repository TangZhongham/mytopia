---
title: "How_to_hugo日常使用篇"
date: 2020-02-15T14:34:05+08:00
draft: true
authors: ["tzh"]
tags: ["hugo", "markdown", "github"]
categories: ["tutorial"]
---

# How to hugo 日常使用篇

> 本篇介绍如何发布一篇文章并编写shell脚本快捷发布/

<!-- TOC -->

- [How to hugo 日常使用篇](#how-to-hugo-%e6%97%a5%e5%b8%b8%e4%bd%bf%e7%94%a8%e7%af%87)
  - [本地撰写博文](#%e6%9c%ac%e5%9c%b0%e6%92%b0%e5%86%99%e5%8d%9a%e6%96%87)
  - [发布](#%e5%8f%91%e5%b8%83)
  - [shell 脚本自动发布](#shell-%e8%84%9a%e6%9c%ac%e8%87%aa%e5%8a%a8%e5%8f%91%e5%b8%83)
  - [TODO](#todo)
  - [Ref](#ref)

<!-- /TOC -->

> 本篇文章介绍如何发布一篇文章并上传到网页端. 一共只有两个步骤

## 本地撰写博文

```shell
cd ./mytopia
hugo server -D // 此时开启的是fast render 模式, 会热更新你的博文编辑.
hugo new /posts/new_intro.md // 创建一篇新的博文
```

## 发布

```shell
cd ./mytopia
hugo -D // 默认hugo new出来的文章都有个标签是草稿, -D 指的是build 所有草稿
cd build
git add .
git commit -m "xxx"
git push original master
```

**注意**, 以上这部分推送之后, 页面就更新了, 但是其实本体文件并没有上传到github保存, 建议先如下操作:

```shell
cd ./mytopia
hugo -D
git add .
git commit -m "xxx"
git push original master
```

由于每次想写文章都要**敲**以上那么多条命令, 当然我们还是写一个shell脚本更加方便.

## shell 脚本自动发布

deploy.sh 使用方法:

1. 复制如下脚本并```chomd + x deploy.sh```
2. 自动commit ```./deploy.sh``` 自动push 到github并更新page, 或者```./deploy.sh + xxx```

```shell
#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to tangzhongham...\033[0m\n"

# Build the project.
hugo -D # if using a theme, replace with `hugo -t <YOURTHEME>`

# push your files to github
msg="saving file and rebuilding site $(date)"
if [ -n "$*" ]; then
        msg="$*"
fi
git add .
git commit -m "$msg"

# Push source and build repos.
git push origin master

# Go To Public folder
cd public

# Add changes to git.
git add .

# Commit changes.
git commit -m "$msg"

# Push source and build repos.
git push origin master

printf "upload success, enjoy your journey! "
```

## TODO

- [x] deployment 文件撰写

创建了一个改版的sh文件,不知道咋样,试试.

- [ ] search 功能暂时去掉

一个很坑的事情, 按照文档添加 search 则会把homepage的介绍挤掉. 放到sidebar 则无法使用... 暂时去掉搜索吧.

## Ref

[minimo模版](https://minimo.netlify.com/docs/page/2/)

[hugo官方部署文档](https://gohugo.io/hosting-and-deployment/hosting-on-github/)
