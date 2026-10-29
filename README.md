# ohNet for MinimServer on FreeBSD

[MinimServer](https://minimserver.com) runs on FreeBSD (it is Java), except
for ohNet, the native UPnP library it uses. MinimServer ships ohNet only for
Linux, Windows and macOS. On FreeBSD it fails to start with:

    java.lang.UnsatisfiedLinkError: .../libohNet.so: Shared object "libm.so.6" not found

This repository builds a drop-in replacement for the Linux ohNet zip. For
years airflow did this and shared it in the forum thread
[MinimServer on FreeBSD](https://forum.minimserver.com/showthread.php?tid=2891).
He stopped in 2025 when he moved away from FreeBSD. Many thanks to him for
all those years of builds.

## Which zip

MinimServer keeps ohNet in `libext/` as a zip named after its version, for
example `ohnet(linux-intel)-1.37.5521.2.zip`. Download the zip with the same
name from [Releases](../../releases).

| MinimServer | Zip | ohNet |
|---|---|---|
| 2.2, update 255 and later | `ohnet(linux-intel)-1.37.5521.2.zip` | 1.37.5521 |

These zips need FreeBSD 13.2 or later on amd64, including TrueNAS CORE
jails. They need no packages beyond the Java that MinimServer already uses:
unlike earlier builds, they don't need `lang/gcc`. They're tested on FreeBSD
13.1 with OpenJDK 8, MinimServer 2.2 updates 272 and 275.

## Installing

The commands assume MinimServer is installed in `/usr/local/share/minimserver`
and runs as the `minimserver` service, as in airflow's tutorial. Run them
inside the jail.

1. Check that `stopall` can see the running server:

       grep -n 'PSOPT="-' /usr/local/share/minimserver/bin/stopall

   If it shows `-eo pid,...`, it can't. FreeBSD's `ps -e` lists only
   processes that have a terminal, and a service has none. Fix it:

       sed -i '' 's/-eo pid,user/-axo pid,user/' /usr/local/share/minimserver/bin/stopall

   MinimServer updates replace this script, so check this again after an
   update.

2. Stop MinimServer, and check that it did stop:

       service minimserver stop
       pgrep -f mserver.jar || echo stopped

3. Replace the zip, keeping the old one outside `libext/`:

       cd /usr/local/share/minimserver/libext
       mkdir -p /root/ohnet-backup && cp -p ohnet*.zip /root/ohnet-backup/
       fetch 'https://github.com/imush/ohnet-freebsd/releases/download/v1.37.5521.2/ohnet(linux-intel)-1.37.5521.2.zip'
       sha256 'ohnet(linux-intel)-1.37.5521.2.zip'

   Compare the checksum with the `.sha256` file on the release page.

4. Start MinimServer:

       service minimserver start

   MinimServer unpacks the libraries into `tmp/native/` as it starts. Check
   that they're the new ones and that it's running:

       ls -la /usr/local/share/minimserver/tmp/native/
       tail -3 /usr/local/share/minimserver/data/minimserver.log

## After a MinimServer update

Most updates leave ohNet alone. When one moves to a new ohNet, MinimServer
downloads the Linux zip and fails with the error above. The new zip appears
here under the new name; install it as above. Auto-update, which is on by
default, does this on its own, so you may prefer to turn it off and update
after checking here.

## How it's built

- `scripts/build-native.sh` runs on FreeBSD. It builds `libohNet.so` and
  `libohNetJni.so` from the
  [upstream ohNet](https://github.com/openhome/ohNet) release with the base
  system compiler, plus two small fixes in `patches/`: FreeBSD's names for
  the IPv6 multicast options, and the Wi-Fi check, which is Linux-only.
- `scripts/build-jar.sh` builds `ohnet.jar` from the same source with JDK 8.
- `scripts/package.sh` packs them under MinimServer's name. Both the `.32`
  and `.64` names hold the same 64-bit library. `LICENSE.txt` and
  `module.properties` are as in MinimServer's own zip.

GitHub Actions builds every version in `VERSIONS` on FreeBSD 13.2. A tag
`vZIP_VERSION` publishes that zip as a release.

To build one yourself on FreeBSD:

    sh scripts/build-native.sh 1.37.5521 build/1.37.5521
    sh scripts/build-jar.sh 1.37.5521 build/1.37.5521     # anywhere with JDK 8
    sh scripts/package.sh 1.37.5521.2 build/1.37.5521 dist

## License

The scripts and patches are under the BSD 3-Clause License (`LICENSE`).
ohNet is OpenHome's, under the MIT license: see `files/LICENSE.txt`.
MinimServer is Simon Nash's, and this project is not part of it.
