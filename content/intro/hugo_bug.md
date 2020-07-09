---
title: "Hugo_bug"
date: 2020-07-09T18:26:37+08:00
draft: true
---

# hugo 碰见的bug们

上周自己手贱，把mac系统搞坏了，结果后来只有抹掉磁盘重装解决。。。结果这么一折腾，hugo装上报错。

```shell
Error: Error building site: render of "404" failed: execute of template failed: template: 404.html:1:3: executing "404.html" at <partial "header" .>: error calling partial: "/Users/tangmoumou/ComeIn/总目录/坚果云同步/个人文档/Markdown/mytopia/themes/minimo/layouts/partials/header.html:10:19": execute of template failed: template: partials/header.html:10:8: executing "partials/header.html" at <partial "sidebar/sidebar" .>: error calling partial: execute of template failed: template: partials/sidebar/sidebar.html:10:6: executing "partials/sidebar/sidebar.html" at <partial "extras/widget_area" (dict "Widgets" $sidebarWidgets "Scope" .)>: error calling partial: execute of template failed: template: partials/extras/widget_area.html:7:8: executing "partials/extras/widget_area.html" at <partial (print "widgets/" .) $.Scope>: error calling partial: "/Users/tangmoumou/ComeIn/总目录/坚果云同步/个人文档/Markdown/mytopia/themes/minimo/layouts/partials/widgets/about.html:10:19": execute of template failed: template: partials/widgets/about.html:10:19: executing "partials/widgets/about.html" at <$.Site.Home.RelPermalink>: error calling RelPermalink: runtime error: invalid memory address or nil pointer dereference
(base) 
```

看起来贼吓人，build 不起来。

然后灵机一动，估计是hugo版本不对头，直接全域搜索 hugo_ , 赫然发现还好主题自带的有个 netlify.toml 指定了当初用的hugo version 0.55.4, 赶紧把 mac/linux/windows 都给下载下来了。

最后成功无痛切换，舒服。