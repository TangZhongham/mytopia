---
title: "How_to_github_pages"
date: 2019-11-19T13:10:03+08:00
draft: true
categories: ["tutorial"]
authors: ["tzh"]
---

# How to deploy your hugo sites to Github Pages

<!-- TOC -->

- [How to deploy your hugo sites to Github Pages](#how-to-deploy-your-hugo-sites-to-github-pages)
  - [部署到 Github 个人页面](#%e9%83%a8%e7%bd%b2%e5%88%b0-github-%e4%b8%aa%e4%ba%ba%e9%a1%b5%e9%9d%a2)
  - [常见错误](#%e5%b8%b8%e8%a7%81%e9%94%99%e8%af%af)
  - [TODO LIST](#todo-list)

<!-- /TOC -->

## 部署到 Github 个人页面

1. 在github 分别建立 mytopia 和 \<username\>.github.io 的仓库，前者用来存放网页的源文件，后者用来存放最终展示的网站内容

2. 进入之前教程中的本地目录

```shell
cd /mytopia
```

3. 将 mytopia 项目关联到远程的 mytopia 仓库

```shell
git remote add origin git@github.com/TangZhongham/mytopia.git
```

4. 将本地网站全部推送到远程的 mytopia 仓库

```shell
git push -u origin master
```

可能会出现push 不了的原因。可能需要你 ```git add .```然后```git commit -m "first commit"```

前文要注意git submodule 和 git init，所以这边才不用git init了。src refspec master does not match 错误是由于没有 add 东西就 push 了。

5. 此时所有代码已经被推送到 github 上了。

6. 确保服务正常，并确保根目录下没有 ```/public```文件夹。

```shell
rm -r /public
```

1. 关闭hugo服务器```ctrl+C```，执行以下命令创建 public 子模块，将用于github page 展示。

```shell
git submodule add -b master  https://github.com/TangZhongham/tangzhongham.github.io.git public
```

1. 执行```hugo```命令，自动创建 public 文件夹。然后将代码提交到远程 mytopia 仓库

```shell
hugo
cd public
git status
git add .
git commit -m "first commit"
git push -u origin master
```

**不行**，重新rm -r public 试试。tangzhongham.github.io 建点东西，好像听说不能完全为空。

删完又 git add git commit/ git push -u origin master 了一波。

重复第7步
```
cd ./public
git pull --allow-unrelated-histories
git push 解决两边不一样的问题（http那边创建了个README）
```



现在的操作流程就是说，先改文章。然后 /mytopia 下面 hugo -buildDrafts 然后 git add/commit/push 三连，之后 去 /build 里面 三连，页面才能更新。

现在他妈js 又404 了，搞毛线
新问题好像是在外面 git push 之后，里面再 git status 就 检测不到了，然后页面上 mytopia 的 public 被 push 了，但是 io 的没有。
不知道404 是不是由于这个原因。尝试 hugo -buildDrafts 之后先提交里面的试试。

## 常见错误

## TODO LIST

- [ ] 预备流程：go/git/hugo
- [ ] 分两篇，怎样本地启动，怎样部署。注意事项（http 空文件问题）
- [ ] 可以重新部署一次玩（好累，往后稍稍吧)
- [ ] Git submodule 的使用，为啥两边要更新两次
- [ ] deploy 脚本的编写
- [ ] Enjoy！
