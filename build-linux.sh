#!/bin/bash
set -e
arch="64"
if [ "$arch" != "64" ]; then
	echo "Usage: bash build-linux.sh ARCH"
	echo " ARCH = 32 or 64"
	exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if [ ! -d java-cef ]; then
	mkdir java-cef
fi
cd java-cef
if [ ! -d src ]; then
	git clone https://github.com/shannah/java-cef src
fi
cd src
git pull origin master

if [ "$1" = "clean" ]; then
	rm -rf jcef_build
fi
if [ ! -d jcef_build ]; then
	mkdir jcef_build
fi

if [ "$arch" = "32" ]; then
	PROJECT_ARCH="x86"
fi
if [ "$arch" = "64" ]; then
	PROJECT_ARCH="x86_64"
fi

# Lê a versão correta do arquivo version.txt que criamos na raiz do projeto
if [ -f "$SCRIPTPATH/version.txt" ]; then
	export CEF_VERSION_RAW=$(cat $SCRIPTPATH/version.txt)
	export CEF_VERSION="cef_binary_${CEF_VERSION_RAW}"
else
	export CEF_VERSION_RAW="84.4.1+gfdc7504+chromium-84.0.4147.105"
	export CEF_VERSION="cef_binary_${CEF_VERSION_RAW}"
fi

# Sobrescreve o arquivo de versão interno do repositório clonado para forçar a versão correta
echo "${CEF_VERSION_RAW}" > ../version.txt
echo "${CEF_VERSION_RAW}" > ./version.txt

cd third_party/cef
FILENAME=${CEF_VERSION}_linux64

# Se o diretório da versão não existir, baixa do repositório oficial do CEF (Spotify)
if [ ! -d "$FILENAME" ]; then
	if [ ! -f "$FILENAME.tar.bz2" ]; then
		echo "Baixando $FILENAME.tar.bz2 do servidor do CEF..."
		curl -O "https://cef-builds.spotifycdn.com/${FILENAME}.tar.bz2"
	fi
	echo "Extraindo arquivos do CEF..."
	tar -xvjf "${FILENAME}.tar.bz2"
fi

cd ../..
cd jcef_build

# Executa o CMake passando o caminho exato (CEF_ROOT) e a versão correta para burlar o download automático interno
cmake -G "Unix Makefiles" \
      -DPROJECT_ARCH="$PROJECT_ARCH" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCEF_ROOT="$SCRIPTPATH/java-cef/src/third_party/cef/${FILENAME}" \
      -DCEF_VERSION="${CEF_VERSION_RAW}" ..

make -j4

cd ../tools
./compile.sh linux$arch
./make_distrib.sh linux$arch
strip ../binary_distrib/linux$arch/bin/lib/linux$arch/*.so

if [ -d $SCRIPTPATH/build ]; then
	rm -rf $SCRIPTPATH/build
fi
mkdir $SCRIPTPATH/build
TMPCEF=$SCRIPTPATH/build/cef
if [ -d $TMPCEF ]; then
	rm -rf $TMPCEF
fi

CEFROOT=$TMPCEF
cp -r ../binary_distrib/linux$arch/bin $CEFROOT
cd $SCRIPTPATH/build

jar -cvf cef-linux$arch.zip -C cef/ .

if [ ! -d $SCRIPTPATH/dist ]; then
	mkdir $SCRIPTPATH/dist
fi
mv cef-linux$arch.zip $SCRIPTPATH/dist/
