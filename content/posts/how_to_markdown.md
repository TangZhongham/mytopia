---
title: "How_to_markdown"
date: 2019-11-18T22:13:43+08:00
draft: true
authors: ["tzh"]
tags: ["create", "markdown"]
categories: ["posts"]
---

# Markdown 5分钟使用指南

<!-- TOC -->

- [Markdown 5分钟使用指南](#markdown-5%e5%88%86%e9%92%9f%e4%bd%bf%e7%94%a8%e6%8c%87%e5%8d%97)
  - [Why Markdown](#why-markdown)
  - [How to Markdown](#how-to-markdown)
    - [结构](#%e7%bb%93%e6%9e%84)
    - [段落](#%e6%ae%b5%e8%90%bd)
      - [分隔符](#%e5%88%86%e9%9a%94%e7%ac%a6)
      - [引用](#%e5%bc%95%e7%94%a8)
      - [代码块](#%e4%bb%a3%e7%a0%81%e5%9d%97)
        - [单行代码](#%e5%8d%95%e8%a1%8c%e4%bb%a3%e7%a0%81)
        - [多行代码](#%e5%a4%9a%e8%a1%8c%e4%bb%a3%e7%a0%81)
    - [句子](#%e5%8f%a5%e5%ad%90)
      - [换行](#%e6%8d%a2%e8%a1%8c)
      - [Bullet Dot](#bullet-dot)
    - [文本](#%e6%96%87%e6%9c%ac)
      - [链接](#%e9%93%be%e6%8e%a5)
  - [Others](#others)
    - [杂](#%e6%9d%82)

<!-- /TOC -->

## Why Markdown

> Markdown is a lightweight markup language that you can use to add formatting elements to plaintext text documents.

Markdown 本质上就是一种标记语言，让你在不需要过度关注文章结构的同时，提供了符合逻辑的文章结构。

## How to Markdown

正如以上所说，**Markdown** 只是为了让你更舒服的组织好文章架构，那么从以下几个方面来使用则很符合逻辑。

### 结构

**Markdown** 把一篇文章分为如下结构:

> # 这是一级标题 
> ## 这是二级标题
> ### 这是三级标题
> #### 这是四级标题
> ##### 这是五级标题

一级标题只能有一个，等价于文章的标题，所有其他等级标题都在一级标题下面。

### 段落

正文直接手写就行。

#### 分隔符

如下：
***

#### 引用

> 这样就可以引用别人的话。

>> 引用功能可以嵌套。

>>> 哈哈

#### 代码块

##### 单行代码

单行代码可以这么写：```def```

##### 多行代码

多行代码一样的，同时在后接 python 等可以支持不同语法的代码高亮。

```python
def hello_world():
    """
    代码里面就一样的
    """
    pass
```

### 句子

#### 换行

Markdown 的换行有点傻逼。</br>
可以这么换(貌似没有更好的解决办法)

#### Bullet Dot

- [x] 这样就行
- [ ] 会自动往后添加，不用每个都手打，放心。

### 文本

文本的内容就比较有趣了。</br>
比方说可以**加粗**，可以~~划去内容~~，可以 *斜体字* ，也可以<u>下划线</u>。

#### 链接

[可以直接这样](http://www.hao123.com)

<http://www.hao123.com>

图片的话：</br>
![图片](favicon.ico)

## Others

### 杂

