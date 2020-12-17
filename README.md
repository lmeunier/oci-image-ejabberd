# oci-image-ejabberd

OCI image for the famous XMPP server

## How to use the image

### Docker Hub

Builded images for amd64 and armv7 architectures are available on Docker Hub:

* https://hub.docker.com/r/lmeunier/ejabberd

### Volumes

* /etc/ejabberd: ejabberd configuration
* /var/lib/ejabberd: data directory (database, upload, ...)
* /var/log/ejabberd: log directory

### Ports

* 5222: XMPP c2s port
* 5269: XMPP s2s port
* 5280: HTTP port (admin interface)
* 5443: HTTPS port (admin interface and other things...)

### systemd integration

* create a new container

```
podman create                                                    \
  --volume ejabberd_etc:/etc/ejabberd                            \
  --volume ejabberd_log:/var/log/ejabberd                        \
  --volume ejabberd_data:/var/lib/ejabberd                       \
  --mount type=bind,src=/etc/letsencrypt,target=/etc/letsencrypt \
  --network host-bridge                                          \
  --ip 192.168.1.220                                             \
  --name ejabberd                                                \
  docker.io/lmeunier/ejabberd:20.12
```

* generate a systemd unit file

```
podman generate systemd --restart-policy=always -t 10 ejabberd \
  > /etc/systemd/system/container_ejabberd.service
```

* use the `container_ejabberd` service like any other systemd service

```
systemctl status container_ejabberd
systemctl start  container_ejabberd
systemctl enable container_ejabberd
```

## How to build the image

* make sure that bash, rsync, [Podman](https://podman.io/) and
  [Buildah](https://buildah.io/) are installed

* clone this repository

```
git clone https://github.com/lmeunier/oci-image-ejabberd.git
cd oci-image-ejabberd
```

* run the `build.sh` script
 * for rootfull builds, just execute the `build.sh` script

  ```
  ./build.sh
  ```

 * for rootless builds, you need to run the `build.sh` script in a [buildah
unshare](https://github.com/containers/buildah/blob/master/docs/buildah-unshare.md)
namespace:

  ```
  buildah unshare ./build.sh
  ```

The `build.sh` script will create an OCI image named `localhost/ejabberd` with a
TAG based on the current CPU architecture and the ejabberd version.

```
$ podman images
REPOSITORY                   TAG          IMAGE ID      CREATED        SIZE
localhost/ejabberd           armv7-20.12  b9921295d4bc  3 minutes ago  134 MB
docker.io/library/alpine     latest       7e4bece93b3e  2 months ago   4.05 MB

```

* test the builed OCI image

```
podman run -it --rm ejabberd:armv7-20.12
```


## Push images to Docker Hub

### Login to the Docker Hub registry

```
buildah login docker.io
```

### Push an architecture specific image to Docker Hub


```
TAG="armv7-20.12"
USERNAME="lmeunier"

buildah push ejabberd:$TAG docker://docker.io/$USERNAME/ejabberd:$TAG
```

### Push a multi-arch image to Docker Hub

```
EJABBERD_VERSION="20.12"
USERNAME="lmeunier"

ARCHS="amd64 armv7"

buildah manifest create ejabberd:$EJABBERD_VERSION
for ARCH in $ARCHS; do
  VARIANT=""
  if [[ $ARCH == arm* ]]; then
    VARIANT="--variant ${ARCH:3}"
  fi
  TAG="$ARCH-$EJABBERD_VERSION"
  buildah pull docker.io/$USERNAME/ejabberd:$TAG
  buildah manifest add $VARIANT ejabberd:$EJABBERD_VERSION docker.io/$USERNAME/ejabberd:$TAG
done
buildah manifest inspect ejabberd:$EJABBERD_VERSION
buildah manifest push --all --format v2s2 ejabberd:$EJABBERD_VERSION docker://docker.io/$USERNAME/ejabberd:$EJABBERD_VERSION
```
