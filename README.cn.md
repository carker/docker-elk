[《从docker-ELKa谈一下docker化思路》](http://www.jianshu.com/p/9492e39ca71d)这篇文章介绍了为什么要使用docker-elk，和在使用过程中的主要思想，本篇文章就以[这个项目](https://github.com/jieniu/docker-elk)为基础，介绍下

1. 这个项目的构成
2. 深入了解这个项目

通过这两点内容，你便可以快速成为项目的主人。

## 项目的构成
我们先来看下项目的目录结构
![](http://oekyukinw.bkt.clouddn.com/docker_elk_tree.png)

这个目录结构可以分为3类，为了方便描述，后续会把它们称为模块：

1. docker-compose及其启动项，包括docker-compose.yml、elastalert、elasticsearch、kibana、logstash，整体由docker-compose.yml驱动
2. elastalert的docker化脚本，进入docker-elastalert目录，你可以构建属于你自己的elastalert
3. elk的配置脚本，例如模板配置，参考set_template.sh

## 深入了解
在彻底把[这个项目](https://github.com/jieniu/docker-elk)变成你自己的之前，你需要深入了解下每个模块，这样你才可以根据自己的需要对它做一些定制化的调整。

### 模块1
首先来看第1个模块，看上去第1个模块的内容很多，其实不然，因为你只需要了解其中一个（例如elasticsearch），其他的子模块以此类推，这一点从docker-compose.yml文件中便可以看出来，拿elasticsearch为例，每个子模块包括build、volume、ports、environment、networks和depends_on的设置

build - 会让你进入指定的目录下，执行其中的Dockerfile，启动对应的image，我们看下Dockerfile，这个文件也特别简单，在项目中指定的是我上传到docker hub上的镜像。这里我动了个手脚，就是把原来的路径给替换了，因为`docker.elastic.co`实在是太慢了，不能用加速器加速，而docker hub是可以的，所以我的方法是先把镜像从`docker.elastic.co`下载下来，再push到docker hub上去，把后者作为基本镜像，解决了速度问题。

volumes - volume是docker项目的精髓，你可以通过volume把可能会变化的配置和数据放在宿主机，而把不变的程序放到image中，这样做的好处是，你随时可以在宿主机修改配置、做数据备份，比起要进入容器才能修改的方式高效很多。在CentOS里，**elasticsearch data的volume设置有个小坑**，你需要在宿主机把data目录的user和group权限设置为1000:1000才行，否则elasticsearch没有可写权限，看下面这张图你就会明白了
![](http://oekyukinw.bkt.clouddn.com/docker-elk2.png)

ports - 这个很好理解，即是程序在docker内部的端口和宿主机导出的端口

environment - 通过environment可以设置一些环境变量，例如JVM占用的内存等

networks - 指定这几个服务通过什么方式进行通信，这里使用的是bridge，也是docker自带的网络模式，这种网络模式的特点是只支持单宿主，如果要在多个宿主中进行通信，你需要了解下[docker overlay](https://docs.docker.com/engine/userguide/networking/get-started-overlay/)

depends_on - 组件间的依赖，该项目中所有组件都依赖于elasticsearch

除docker-compose.yml之外，我们需要关注的只剩下volume在宿主的挂载点了，拿elasticsearch来说，也就是docker-elk/elasticsearch目录下除Dockerfile以外的文件了，它们是运行时elasticsearch的配置。特别的，elastalert中的配置相对来说较多一点，它们在容器中的/opt目录下，对应于宿主机的docker-elk/elastalert/opt目录，它包括3方面内容
- config：elastalert配置信息
- logs：日志文件
- rules：匹配规则，详细[参见文档](http://elastalert.readthedocs.io/en/latest/running_elastalert.html)

### 模块2
这里提供模块2，为的是如果你想对elastalert进行升级，或者你想修改容器的时区，你就得重新构建这个image，构建方法在Dockerfile中，它完成了以下工作
1. 设置环境变量
2. 设置pip源
3. 安装依赖，下载elastalert压缩包
4. 安装elastalert

重新打包后，你还要将这个包上传至docker hub，并用新的image远程路径替换掉`elastalert/Dockerfile`文件中的路径

### 模块3
考虑到我目前使用这个项目的场景是收集日志和监控报警，所以我会对elasticsearch的空间占用做一些限制，尽可能的做到磁盘空间最大化，对elasticsearch模板的调整如下：
1. 启用数据压缩
2. 副本数设为0，单机本身也没必要设置副本
3. 字段设为not_analyzed
4. 不启用_all字段，全文搜索就是靠的这个字段，如果启用，每条记录中的字段会被连起来存在_all字段中，没有全文搜索需求不需要启用该字段，节省空间

关于存储空间的优化，可以看这两篇文章：[文章1](https://www.elastic.co/blog/elasticsearch-storage-the-true-story)，[文章2](https://www.elastic.co/blog/elasticsearch-storage-the-true-story-2.0)

在这里，如果你和我的需求一样，则只用在docker-elk启动后，执行`./set_template.sh`脚本即可，而如果你有另外的需求，可以修改完`./filebeat.template.json`之后再执行`./set_template.sh`

通过以上文字，你对[这个项目](https://github.com/jieniu/docker-elk)的了解会更加深入，希望能通过它帮你快速构建一个ELK环境，have fun！
