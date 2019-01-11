# Docker Micka
Docker Geospatial metadata catalogue http://micka.bnhelp.cz

## Install
```
$ git clone https://github.com/samtux/docker-micka.git
$ cd docker-micka
$ docker build -t samtux/micka .
```

## Run

```
$ docker run --name micka -p 3080:80 -v $HOME/micka_db:/var/lib/postgresql/data samtux/micka
```
