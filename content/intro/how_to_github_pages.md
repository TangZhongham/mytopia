---
title: "How_to_github_pages"
date: 2019-11-19T13:10:03+08:00
draft: true
categories: ["tutorial"]
authors: ["tzh"]
---

# How to deploy your hugo sites to Github Pages

[toc]

## 部署到 Github 个人页面 

1. 在github 分别建立 mytopia 和 \<username\>.github.io 的仓库，前者用来存放网页的源文件，后者用来存放最终展示的网站内容
</br>
2. 进入之前教程中的本地目录
```cd /mytopia```
3. 将 mytopia 项目关联到远程的 mytopia 仓库
```git remote add origin git@github.com/TangZhongham/mytopia.git```
4. 将本地网站全部推送到远程的 mytopia 仓库
```git push -u origin master```
> 可能会出现push 不了的原因。可能需要你 ```git add .```然后```git commit -m "first commit"``` 
>
> > 前文要注意git submodule 和 git init，所以这边才不用git init了。src refspec master does not match 错误是由于没有 add 东西就 push 了。
5. 此时所有代码已经被推送到 github 上了。

6. 确保服务正常，并确保根目录下没有 ```/public```文件夹。
```shell
rm -r /public
```
7. 关闭hugo服务器```ctrl+C```，执行以下命令创建 public 子模块，将用于github page 展示。
```git submodule add -b master  https://github.com/TangZhongham/tangzhongham.github.io.git public```
8. 执行```hugo```命令，自动创建 public 文件夹。然后将代码提交到远程 mytopia 仓库
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



## 常见错误