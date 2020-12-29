---
title: "Redo_blog"
date: 2020-12-29T22:23:08+08:00
draft: true
---

# 重新弄blog

- [x] 搜索
- [x] 评论系统支持
- [ ] 二级标题？
- [x] 404

## 搜索

config.toml 添加

```md
[params.search]
client = "fuse"
```

添加search.md在 /content 目录即可。

```md
---
type: page
layout: search
outputs:
  - html
  - json
---
```

## 添加评论功能--Utterances

Utterances 只支持github，但是很方便

config.toml 中

[params.comments]
enable = true

[params.comments.utterances]
enable = true
issueTerm = "pathname" # pathname / url / title / og:title / <string>
label = ""
theme = "github-light"

[params.comments.utterances.github]
username = "Tangzhongham"
repository = "blog-comments"

username 填写自己的github用户名，repository 为自己新建1个仓库即可。

😄😁

## 404

404 页面本地跑位于 http://localhost:1313/404.html

