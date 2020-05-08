# oci-image-ejabberd
Build an ejabberd OCI image

## How to build the image

* make sure bash, jq, rsync, [Podman](https://podman.io/) and
  [Buildah](https://buildah.io/) are installed

* clone this repository

```
$ git clone https://github.com/lmeunier/oci-image-ejabberd.git
$ cd oci-image-ejabberd
```

* run the `build.sh` script

```
$ ./build.sh
```

This will create an OCI image named `localhost/ejabberd`.

* start the builed OCI image with Podman

```
$ podman run -it                                      \
             --volume ejabberd_etc:/etc/ejabberd      \
             --volume ejabberd_log:/var/log/ejabberd  \
             --volume ejabberd_data:/var/lib/ejabberd \
             --publish 5222:5222                      \
             --publish 5269:5269                      \
             --publish 5280:5280                      \
             --publish 5443:5443                      \
             --name my_ejabberd_container             \
             ejabberd
```

## Volumes

* /etc/ejabberd: ejabberd configuration
* /var/lib/ejabberd: data directory (database, upload, ...)
* /var/log/ejabberd: log directory

## Ports

* 5222: XMPP c2s port
* 5269: XMPP s2s port
* 5280: HTTP port (admin interface)
* 5443: HTTPS port (admin interface and other things...)
