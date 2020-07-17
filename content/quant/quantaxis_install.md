---
title: "Quantaxis_install"
date: 2020-07-17T17:34:59+08:00
draft: true
---

# QUANTAXIS 安装篇

小白建议直接 Docker 安装，这里介绍如何安装本地版本，两个版本都可以读写一份数据，本地版本为了更好的看代码。

1.首先打开pycharm，虚拟一个python 3.6 的虚拟环境。

最好提前下载好 anaconda，然后你就可以在 Pycharm Project-Intepreter 添加 Conda Environment，然后可以选择python版本，选择3.6。

2.左下角打开 Terminal，输入以下代码：

注意，此时terminal打开的就是包含你刚刚创建的python3.6虚拟环境的shell。

```shell
git clone https://github.com/yutiansut/quantaxis --depth 1

# 进入刚刚拉下来的quantaxis项目
cd quantaxis 
pip install --default-timeout=1000 -e . -i https://pypi.doubanio.com/simple
pip install tushare --default-timeout=1000 -i https://pypi.doubanio.com/simple
pip install pytdx --default-timeout=1000 -i https://pypi.doubanio.com/simple
pip install jupyter
```

3.这样能确保环境不会出现依赖错误的情况，可以愉快的进行debug了。

接下来你或许想看看这个[next step](http://www.yutiansut.com:3000/topic/5dc5da7dc466af76e9e3bc5d)