---
title: "New_intro"
date: 2020-02-13T18:24:45+08:00
draft: true
authors: ["tzh"]
tags: ["hugo", "markdown", "github"]
categories: ["tutorial"]
---

# hugo 日志操作流程

[toc]

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
hugo -D
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

deploy文件:
