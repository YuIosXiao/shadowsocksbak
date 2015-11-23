NW_VERSION=v0.8.6
if [ $# == 0 ]; then
  echo 'usage: build.sh version'
  exit 1
fi
pushd `dirname $0`
cd ..
mkdir -p dist
cd dist
rm -rf app
mkdir app
pushd app && \
cp ../../*.js . && \
cp -r ../../css . && \
cp -r ../../img . && \
cp ../../*.json . && \
cp ../../*.htm* . && \
cp ../../*.png . && \
cp -r ../../fonts . && \
cp -r ../../node_modules . || \
exit 1
rm ../app.nw
zip -r ../app.nw * && \
popd && \
rm -rf app || \
exit 1
for platform in linux-x64 win-ia32
do
  if [ -f shadowsocks-gui-$1-$platform.tar.xz ]; then
    continue
  fi
  if [ ! -f node-webkit-$NW_VERSION-$platform.zip ] ; then
    if [ ! -f node-webkit-$NW_VERSION-$platform.tar.gz ] ; then
      axel http://dl.node-webkit.org/$NW_VERSION/node-webkit-$NW_VERSION-$platform.zip || \
      axel http://dl.node-webkit.org/$NW_VERSION/node-webkit-$NW_VERSION-$platform.tar.gz || \
      exit 1
    fi
  fi
  mkdir shadowsocks-gui-$1-$platform && \
  pushd shadowsocks-gui-$1-$platform && \
  unzip ../node-webkit-$NW_VERSION-$platform.zip || \
  tar xf ../node-webkit-$NW_VERSION-$platform.tar.gz || \
  exit 1
  if [ -d node-webkit-$NW_VERSION-$platform ]; then
    mv node-webkit-$NW_VERSION-$platform/* ./ && \
    rm -r node-webkit-$NW_VERSION-$platform || \
    exit 1
  fi
  if [ $platform == win-ia32 ]; then
      cat nw.exe ../app.nw > shadowsocks.exe && \
      rm nwsnapshot.exe && \
      rm ffmpegsumo.dll && \
      rm libEGL.dll && \
      rm libGLESv2.dll && \
      rm nw.exe || \
      exit 1
  fi
  if [ $platform == osx-ia32 ]; then
      rm nwsnapshot && \
      cp ../app.nw node-webkit.app/Contents/Resources/ && \
      cp ../../utils/Info.plist node-webkit.app/Contents/ && \
      cp ../../utils/*.icns node-webkit.app/Contents/Resources/ && \
      /usr/libexec/PlistBuddy -c "Set CFBundleVersion $1" node-webkit.app/Contents/Info.plist  && \
      /usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $1" node-webkit.app/Contents/Info.plist  && \
      mv node-webkit.app shadowsocks.app || \
      exit 1
  fi
  if [ $platform == linux-x64 ]; then
      rm nwsnapshot && \
      cp ../app.nw . && \
      cp ../../utils/linux/start.sh . && \
      rm libffmpegsumo.so || \
      exit 1
  fi
  popd && \
  tar Jcf shadowsocks-gui-$1-$platform.tar.xz shadowsocks-gui-$1-$platform && \
  rm -r shadowsocks-gui-$1-$platform && \
  rsync --progress -e ssh shadowsocks-gui-$1-$platform.tar.xz frs.sourceforge.net:/home/frs/project/shadowsocksgui/dist/shadowsocks-gui-$1-$platform.tar.xz || \
  exit 1
done
popd
